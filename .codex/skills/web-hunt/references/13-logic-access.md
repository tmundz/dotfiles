# Application Logic & Access Control
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## Table of Contents
1. [Business Logic Vulnerabilities](#1-business-logic-vulnerabilities)
2. [Multi-Factor Authentication Bypass](#2-multi-factor-authentication-bypass)
3. [Authentication Bypass / Forced Browsing](#3-authentication-bypass--forced-browsing)
4. [Password Reset & Account Recovery Flaws](#4-password-reset--account-recovery-flaws)
5. [Session Management Testing (WSTG)](#5-session-management-testing-wstg)
6. [Privilege Escalation & Access Control (WSTG)](#6-privilege-escalation--access-control-wstg)
7. [Mass Assignment](#7-mass-assignment)
8. [Account Enumeration](#8-account-enumeration)

---

## 1. Business Logic Vulnerabilities

### Categories
1. **Workflow bypass** — skip required steps (skip payment, skip verification, skip email confirmation)
2. **Negative values** — enter -1 quantity, negative price → credit your account
3. **Integer overflow** — max int + 1 wraps to 0 or negative
4. **Horizontal privilege escalation** — act as another user at same level (IDOR)
5. **Vertical privilege escalation** — act as higher-privilege user
6. **Mass assignment** — submit extra fields the app shouldn't accept
7. **Time-of-check to time-of-use (TOCTOU)** — race condition variant

### Testing Approach
For each feature, ask:
1. What is this feature supposed to do?
2. What is it NOT supposed to allow?
3. What happens if I:
   - Skip required steps?
   - Repeat steps (apply same coupon twice)?
   - Go backwards in a workflow?
   - Submit unexpected values (0, -1, null, empty, very large number)?
   - Submit extra parameters?
   - Submit requests out of order?
   - Combine this feature with another feature?

### WSTG Business Logic Tests
| ID | Test | Key Actions |
|---|---|---|
| WSTG-BUSL-01 | Data Validation | Negative values, overflow, invalid data types |
| WSTG-BUSL-02 | Forge Requests | Modify hidden fields, change flow parameters |
| WSTG-BUSL-03 | Integrity Checks | Tamper with price, discount, quantity |
| WSTG-BUSL-04 | Process Timing | Race conditions, TOCTOU |
| WSTG-BUSL-05 | Function Use Count | Apply discount N+1 times, redeem coupon twice |
| WSTG-BUSL-06 | Workflow Circumvention | Skip required steps, reverse workflow |
| WSTG-BUSL-07 | Application Mis-use | API abuse, credential stuffing |
| WSTG-BUSL-08 | Unexpected File Types | Bypass extension/MIME check |
| WSTG-BUSL-09 | Malicious File Upload | Malware, XML bombs, zip bombs |

### Real-World Examples
- **Shopify** ($500): Admin privilege bypass through partner account flow
- **Twitter** ($5,040): API allowed reading protected tweet despite protection being enabled
- **GitLab** ($1,500): Bypass 2FA by using backup codes as sole auth method
- **HackerOne**: Race condition in team invitation — unlimited members

---

## 2. Multi-Factor Authentication Bypass

```
1. Skip MFA step entirely — go directly to authenticated URL after providing credentials
   (Server may check auth step but not MFA completion flag)

2. CSRF on MFA disable endpoint
   — CSRF to disable victim's MFA via authenticated CSRF

3. Response manipulation
   — Intercept MFA validation response in Burp
   — Change "success: false" to "success: true"
   — Change HTTP 401 to 200

4. Brute-force OTP (if no rate limiting)
   — 6-digit TOTP = 1,000,000 combinations
   — 4-digit SMS OTP = 10,000 combinations

5. Race condition on OTP validation
   — Send two requests with same OTP simultaneously
   — One may succeed even after OTP "consumed"

6. Backup code enumeration
   — 8-character alphanumeric backup codes may be predictable or reusable

7. Lack of MFA on alternative login methods
   — OAuth/SAML login bypasses MFA
   — API key authentication bypasses MFA
   — Mobile app uses different auth flow without MFA
```

---

## 3. Authentication Bypass / Forced Browsing

### Default Credentials
```
admin:admin, admin:password, admin:1234, admin:admin123
root:root, root:toor
test:test, demo:demo, guest:guest
Administrator:Administrator (Windows)
sa:(blank) (SQL Server)
```

### Direct URL Access (Forced Browsing)
- Access `/admin/dashboard` directly without going through login
- Access `/user/profile/123` without authentication
- On `403 Forbidden`: try different HTTP methods, case variation in URL, path traversal
- Look for admin interfaces not linked from main navigation

```
# Path variations to try
/Admin, /ADMIN, /admin.php, /admin.html, /admin.json
/admin.bak, /admin~
# Add to URL: ?debug=true, ?admin=true, ?role=admin
```

### Login Bypass via SQL Injection
```sql
admin'-- 
admin'#
' OR '1'='1
' OR 1=1--
') OR ('1'='1
admin'/*
```

---

## 4. Password Reset & Account Recovery Flaws

### Full Testing Checklist
```
1. TOKEN PREDICTABILITY
   - Reset token entropy: short? time-based? sequential?
   - Request many resets → are tokens similar? predictable pattern?
   - 4-6 digit tokens → brute-forceable

2. TOKEN EXPIRY
   - Does token expire after fixed time?
   - Does old token expire when new one is generated?
   - Does token expire after first use?
   - Does token expire after logout?

3. HOST HEADER INJECTION IN PASSWORD RESET EMAIL
   Test by adding headers:
     Host: attacker.com
     X-Forwarded-Host: attacker.com
     X-Host: attacker.com
     X-Forwarded-Server: attacker.com
     X-HTTP-Host-Override: attacker.com
   → Reset email link goes to attacker.com → capture reset token
   → Login as victim

4. TOKEN LEAKAGE
   - Is token in URL? → Referer header leaks it to third-party analytics on the reset page
   - Is token in HTTP request to analytics embedded in reset page?

5. RATE LIMITING
   - Can you request unlimited resets?
   - OTP in reset flow — brute-forceable without lockout?

6. RESPONSE MANIPULATION
   - Change HTTP status/body in reset validation response

7. USERNAME/EMAIL ORACLE
   - "Email not found" vs. no error → user enumeration

8. SECOND FACTOR BYPASS
   - Does password reset skip MFA entirely?
   - Does reset link bypass 2FA requirement on login?
```

---

## 5. Session Management Testing (WSTG)

| ID | Test | Key Actions |
|---|---|---|
| WSTG-SESS-01 | Session Schema Analysis | Token entropy ≥128 bits, random, time-limited, no user data in token |
| WSTG-SESS-02 | Cookie Attributes | Secure, HttpOnly, SameSite, Domain scope too broad, Expires |
| WSTG-SESS-03 | Session Fixation | New session ID issued after login? Old ID same after auth? |
| WSTG-SESS-04 | Exposed Session Variables | Token in URL (GET param), HTTP body, leaked via Referer |
| WSTG-SESS-05 | CSRF | Missing/bypassable CSRF tokens, missing SameSite cookie attribute |
| WSTG-SESS-06 | Logout Functionality | Session invalidated server-side? Old token works after logout? |
| WSTG-SESS-07 | Session Timeout | Absolute + sliding timeout enforced? Never-expiring sessions? |
| WSTG-SESS-08 | Session Puzzling | Same session variable used for different purposes (overloading) |
| WSTG-SESS-09 | Session Hijacking | XSS to steal cookie, subdomain cookie scope, MITM on HTTP |

### Cookie Scoping Issues
```
# Domain too broad: domain=.example.com
# → Shared across all subdomains
# → Subdomain XSS steals parent domain cookies

# Session fixation: pre-login session ID same after login
# → Set-Cookie before login, authenticate, check if same session now privileged
```

---

## 6. Privilege Escalation & Access Control (WSTG)

### WSTG Authorization Tests
```
WSTG-ATHZ-01: Path Traversal / File Include
../../../etc/passwd
..\..\..\windows\win.ini
....//....//....//etc/passwd
%2e%2e%2f%2e%2e%2f
..%252f..%252f (double URL encoding)
%c0%ae%c0%ae/ (overlong UTF-8)

WSTG-ATHZ-02: Authorization Schema Bypass
- Access admin URLs as regular user
- Try: /admin, /administrator, /manage, /management, /superuser
- URL case variation: /Admin, /ADMIN
- Extension change: /admin.php → /admin.html, /admin.json
- Parameter injection: ?admin=true, ?debug=true, ?role=admin

WSTG-ATHZ-03: Privilege Escalation
- Horizontal: access other users' data at same privilege level
- Vertical: access higher-privilege functionality
- Parameter-based: user_type=2 (normal) → user_type=1 (admin)

WSTG-ATHZ-04: IDOR
(See references/06-idor.md)
```

### Automated Authorization Testing
```
# Autorize (Burp Suite extension) — most important tool for access control testing
# Setup:
1. Log in as low-privilege user, copy session cookie/token
2. In Autorize: paste low-priv cookie in "Auth Header"
3. Browse app as admin
4. Autorize replays every request with low-priv session
5. Red = bypassed (low-priv can do admin action)
6. Yellow = possibly bypassed (check manually)
7. Green = correctly blocked

# AuthMatrix (Burp extension): test multiple roles simultaneously
```

---

## 7. Mass Assignment

```
# Extra fields in registration/profile update
POST /api/register
{"username": "attacker", "password": "pass", "role": "admin"}       # Add role param
{"username": "attacker", "password": "pass", "isAdmin": true}
{"username": "attacker", "password": "pass", "verified": true}

# Common mass assignment fields to try:
role, isAdmin, admin, verified, email_verified, credits, balance, discount
plan, subscription, premium, staff, superuser, user_type, permissions

# Tools: Param Miner, Arjun — add discovered params to requests
# Find field names from: API documentation, JS source, similar endpoints
```

---

## 8. Account Enumeration (WSTG-IDNT-04)

```
# Test login, registration, password reset for different responses:
- Different error messages: "Username not found" vs "Wrong password"
- Different response times (DB lookup takes longer for valid user)
- Different HTTP status codes
- Different response sizes

# Test vectors:
- Login: valid user / wrong password vs. invalid user / wrong password
- Registration: "email already taken" for valid email
- Password reset: "email sent" vs "email not found"

# Timing attack for username enumeration
for user in admin root test; do
  time curl -s -o /dev/null -X POST https://target.com/login \
    -d "username=$user&password=wrongpassword"
done
```
