# Reporting Reference — Bug Bounty & Pentest Report Writing

**Mobile-specific CVSS v3.1, finding templates per OWASP Mobile Top 10 category**
**Evidence checklists, HackerOne/Bugcrowd submission best practices**

## Table of Contents
1. [CVSS v3.1 Mobile-Specific Guidance](#cvss)
2. [Finding Template](#template)
3. [OWASP Mobile Top 10 Report Templates](#m1-m10)
4. [Evidence Checklist](#evidence)
5. [HackerOne Submission Best Practices](#h1)
6. [Bugcrowd Submission Best Practices](#bugcrowd)
7. [PoC Writeup Structure](#poc-writeup)
8. [Severity Quick Reference](#severity)

---

## 1. CVSS v3.1 Mobile-Specific Guidance <a name="cvss"></a>

### Attack Vector (AV)
- **Network (N):** Exploitable remotely over internet (API vulnerabilities, backend flaws) — most common
- **Adjacent (A):** Same WiFi network required (MITM on LAN, Bluetooth attacks)
- **Local (L):** Physical access or local shell required (file system, ADB attacks)
- **Physical (P):** Device in hand required (unlock screen, hardware attacks)

### Attack Complexity (AC)
- **Low (L):** No special conditions — exported activity, unprotected endpoint
- **High (H):** Race condition, specific device state, non-default configuration required

### Privileges Required (PR)
- **None (N):** No app installed, or installed without special privileges
- **Low (L):** Basic user account / victim must be logged in
- **High (H):** Admin access required in target app

### User Interaction (UI)
- **None (N):** Pure technical exploitation, no victim action required
- **Required (R):** Victim must click deep link, open malicious content, visit URL

### Scope (S)
- **Unchanged (U):** Exploit affects only the target app
- **Changed (C):** Exploit pivots to other apps, system, or backend

### Confidentiality/Integrity/Availability Impact
- **High (H):** Complete disclosure / total corruption / total loss
- **Low (L):** Partial exposure / minor corruption / reduced performance
- **None (N):** No impact

### Common Mobile CVSS Examples

| Finding | AV | AC | PR | UI | S | C | I | A | Score |
|---------|----|----|----|----|---|---|---|---|-------|
| Hardcoded API key → backend access | N | L | N | N | C | H | H | H | **10.0** |
| Exported activity bypasses auth | L | L | N | N | U | H | H | N | **8.1** |
| IDOR — read other users' data | N | L | L | N | U | H | N | N | **6.5** |
| SSL pinning bypassable | A | H | N | R | U | H | N | N | **5.3** |
| Insecure data in SharedPrefs | L | L | N | N | U | H | N | N | **5.5** |
| Tapjacking | L | L | N | R | U | L | L | N | **3.9** |
| Cleartext traffic on HTTP | A | H | N | N | U | H | N | N | **5.9** |
| WebView XSS | N | L | N | R | U | H | N | N | **6.1** |
| Content provider SQLi → DB dump | L | L | N | N | U | H | N | N | **5.5** |
| Deep link open redirect | N | L | N | R | U | L | L | N | **4.3** |

---

## 2. Finding Template <a name="template"></a>

```markdown
# [FINDING_TITLE]

## Summary
One paragraph describing: what the vulnerability is, where it exists,
what an attacker can achieve, and why it matters.

## Severity
**Critical / High / Medium / Low / Informational**
CVSS v3.1 Score: [X.X]
Vector: AV:[]/AC:[]/PR:[]/UI:[]/S:[]/C:[]/I:[]/A:[]

## OWASP Mobile Top 10
[M1-M10]: [Title]

## MASVS Control
[MASVS-CATEGORY-N]: [Description]

## Affected Component
- Application: [TARGET_PACKAGE] v[VERSION]
- Component: [Activity/Service/Provider/Receiver/API endpoint]
- File: [path in decompiled source if applicable]

## Vulnerability Details

### Technical Description
Detailed technical explanation of the flaw, including:
- Root cause
- Attack vector
- What data/functionality is exposed

### Reproduction Steps
1. [Step 1 — be extremely precise, include exact commands]
2. [Step 2]
3. [Step N — observe [SPECIFIC_RESULT]]

### Proof of Concept
```
[EXACT_COMMANDS_OR_CODE_TO_REPRODUCE]
```

### Impact
What can an attacker do? What data can be accessed/modified?
Is this theoretical or demonstrated?

## Evidence
- [ ] Screenshot: [path]
- [ ] Video recording: [path]
- [ ] Logcat output: [path]
- [ ] Frida output: [path]
- [ ] Burp traffic capture: [path]
- [ ] Source code snippet: [jadx path:line]

## Remediation
### Recommended Fix
[Specific code change or configuration fix]

### Code Example
// VULNERABLE
[vulnerable_code]

// FIXED
[fixed_code]

## References
- [OWASP Mobile Top 10 Link]
- [MASTG Test ID]
- [CWE-XXX]
- [CVE if applicable]
```

---

## 3. OWASP Mobile Top 10 Report Templates <a name="m1-m10"></a>

### M1: Improper Credential Usage

```markdown
# Hardcoded API Key in APK Binary

## Severity: Critical — CVSS 9.0
## OWASP: M1 — Improper Credential Usage
## MASVS: MASVS-STORAGE-2

The application [TARGET_PACKAGE] contains a hardcoded [service] API key
embedded in the compiled APK. Any user who downloads the app can extract
this key and use it to make authenticated requests to the [service] API,
resulting in [financial impact / data access / service abuse].

### Reproduction Steps
1. Download APK from [Play Store]
2. Decompile: `jadx -d decoded/ app.apk`
3. Search: `rg -i 'api_key' decoded/`
4. Observe credential at `decoded/sources/com/example/Config.java:42`

### PoC
```
curl -H "Authorization: Bearer [EXTRACTED_KEY]" https://api.service.com/users
```
Response: [200 OK with sensitive data]

### Impact
Attacker obtains full access to [service] API without authorization.
Estimated cost of key abuse: [$X/month].
```

### M3: Insecure Authentication/Authorization

```markdown
# Authentication Bypass — Exported Activity Allows Unauthenticated Access

## Severity: High — CVSS 8.1
## OWASP: M3 — Insecure Authentication/Authorization

The `com.example.AdminActivity` is exported without requiring any permission,
allowing any app on the device or any ADB command to launch the admin panel
without authentication.

### Reproduction Steps
1. Install [TARGET_PACKAGE]
2. Do not log in
3. Run: `adb shell am start -n [TARGET_PACKAGE]/com.example.AdminActivity`
4. Observe: admin panel opens with full functionality
```

### M5: Insecure Communication

```markdown
# SSL Certificate Validation Disabled — MITM Attack Possible

## Severity: High — CVSS 7.4
## OWASP: M5 — Insecure Communication

The application overrides `checkServerTrusted()` with an empty implementation,
accepting any TLS certificate including expired or attacker-controlled certs.

### Reproduction Steps
1. Set up mitmproxy: `mitmproxy --listen-port 8080`
2. Configure device WiFi proxy to [BURP_IP]:8080
3. Launch [TARGET_PACKAGE] and log in
4. Observe credentials in mitmproxy (even with self-signed cert)

### Vulnerable Code (jadx decompile)
```java
// com/example/network/TrustAllCerts.java:15
public void checkServerTrusted(X509Certificate[] chain, String authType) {
    // Empty — accepts any certificate
}
```
```

### M9: Insecure Data Storage

```markdown
# Authentication Token Stored in Plaintext SharedPreferences

## Severity: Medium — CVSS 5.5
## OWASP: M9 — Insecure Data Storage
## MASVS: MASVS-STORAGE-1

The application stores the user's authentication token in plaintext
SharedPreferences. Any app with root access, any backup extraction,
or any debuggable device can read this token and authenticate as the user.

### Reproduction Steps
1. Log in to [TARGET_PACKAGE]
2. Run: `adb shell run-as [TARGET_PACKAGE] cat shared_prefs/prefs.xml`
3. Observe: `<string name="auth_token">eyJhbGc...</string>`

### Impact
Session token valid for [X] days allows full account takeover.
```

---

## 4. Evidence Checklist <a name="evidence"></a>

Before submitting any bug bounty report, collect ALL of:

```
Evidence Checklist for [FINDING_TITLE]:

Static Evidence:
[ ] Source code snippet showing vulnerability (jadx path + line number)
[ ] Manifest entry for exported component (if applicable)
[ ] NSC configuration showing missing pinning (if applicable)
[ ] Credential found in source (exact file:line)

Dynamic Evidence:
[ ] scrcpy video recording of full exploitation (30-60 seconds)
    Path: evidence/poc-[finding]-[date].mp4
[ ] Screenshot of key exploitation moment
    Path: evidence/screenshot-[finding]-[date].png
[ ] Logcat showing app behavior during exploit
    Path: evidence/logcat-[finding]-[date].txt
[ ] Burp traffic capture (if network-related)
    Path: evidence/burp-capture-[finding]-[date].xml
[ ] Frida output (if dynamic instrumentation used)
    Path: evidence/frida-output-[finding]-[date].txt

PoC:
[ ] Exact ADB commands to reproduce (copy-paste ready)
[ ] Exact Frida script (if used)
[ ] PoC APK (if app built)
[ ] curl commands (if API-related)

Impact Evidence:
[ ] Response showing unauthorized data access (redacted PII)
[ ] Screenshot of admin panel (if IDOR/auth bypass)
[ ] Proof of successful decryption (if crypto bug)
```

---

## 5. HackerOne Submission Best Practices <a name="h1"></a>

### Title Format
`[Android] [Vulnerability Type] in [Component] — [Impact]`

Examples:
- `[Android] Exported Activity Bypasses Authentication — Unauthenticated Admin Access`
- `[Android] Hardcoded API Key in Binary — Full Backend Access`
- `[Android] Content Provider SQL Injection — Database Disclosure`
- `[Android] SSL Certificate Validation Disabled — MITM Attack`

### Structure for H1 Mobile Reports

```markdown
**Summary:** [1-2 sentences: what + impact]

**Platform:** Android [API level range]
**App Version:** [X.X.X] (from Play Store or APK metadata)
**Device Context:** [Tested on: rooted Pixel 4 emulator / unrooted Samsung Galaxy S21]

**Steps To Reproduce:**
1. Install [PACKAGE] v[VERSION] from Play Store
2. [Specific steps — every step numbered, exact commands]
3. Observe: [SPECIFIC BEHAVIOR proving vulnerability]

**Supporting Material/References:**
[Attach: video, screenshots, logcat, Burp capture]

**Impact:**
[Clear, specific, worst-case impact — avoid vague "could lead to data breach"]
What data? Which users? What actions? What's the blast radius?

**Suggested Fix:**
[Specific, actionable fix — not generic "fix the security issue"]
```

### H1 Mobile Severity Guidance
- **Critical (9-10):** Backend auth bypass, RCE, full database access
- **High (7-9):** Significant data exposure, auth bypass, IDOR to sensitive data
- **Medium (4-7):** Limited data exposure, SSL bypass (no real attack chain), tapjacking
- **Low (1-4):** Informational disclosure, weak crypto without clear exploit, theoretical
- **Informational:** Debug flag in prod, missing best-practice headers

### H1 Duplicate Avoidance
- Search program's resolved reports for similar titles before submitting
- Check: is the component actually in scope? Check program's asset list
- Test on LATEST production version from Play Store

---

## 6. Bugcrowd Submission Best Practices <a name="bugcrowd"></a>

### VRT (Vulnerability Rating Taxonomy) Mapping for Mobile

| Finding | Bugcrowd Category |
|---------|------------------|
| Hardcoded credentials | Server Security Misconfiguration → Hardcoded credentials |
| Exported activity | Android — Activity Exported |
| Content provider SQLi | Android — Content Provider Injection |
| Insecure data storage | Android — Insecure Data Storage |
| SSL bypass | Transport Layer Security — Missing Certificate Pinning |
| Intent redirection | Android — Intent Redirection |
| Tapjacking | Android — Tapjacking |
| WebView XSS | Client-Side Injection → Cross-Site Scripting (XSS) — Stored/Reflected |

### Bugcrowd Report Format

```markdown
**Description:**
[Clear description linking directly to what was found in the app]

**Steps to Reproduce:**
1. Download [APP] version [X] from Play Store
2. [Exact step]
3. Expected result: [what secure behavior should be]
4. Actual result: [what happens — the vulnerability]

**Proof of Concept:**
[Commands, code, or attached files]

**Suggested Remediation:**
[Specific, implementable fix]

**References:**
- OWASP Mobile Top 10 2024: [M-number and title]
- CWE: [CWE-number and title]
```

---

## 7. PoC Writeup Structure <a name="poc-writeup"></a>

```markdown
# PoC: [VULNERABILITY_TITLE]

**Date:** [DATE]
**Target:** [TARGET_PACKAGE] v[VERSION]
**Tester:** [NAME/HANDLE]
**Environment:** [Context A: Rooted Emulator / Context B: Unrooted Device]

## Attack Description
[2-3 sentence technical summary]

## Preconditions
- [ ] [TARGET_PACKAGE] installed (version [X])
- [ ] [Any setup steps]
- [ ] [Frida server running (if applicable)]

## Exploitation

### Step 1: [Step name]
```
[exact command or code]
```
**Observed:** [what happened]

### Step 2: [Step name]
```
[exact command]
```
**Observed:** [result]

### Step N: [Confirm exploitation]
**Evidence:** [describe what was seen/captured]

## Evidence Files
- Video: `evidence/poc-[type]-[date].mp4`
- Screenshot: `evidence/screenshot-[date].png`
- Logcat: `evidence/logcat-[date].txt`
- Frida output: `evidence/frida-[date].txt`
- Burp capture: `evidence/burp-[date].xml`

## Impact
[Specific impact — data accessible, actions possible, affected user count]

## CVSS
[Vector string and score]

## Remediation
[Specific fix with code example]
```

---

## 8. Severity Quick Reference <a name="severity"></a>

| Finding | Typical Severity | Notes |
|---------|-----------------|-------|
| Hardcoded credentials → backend RCE | Critical | Depends on access level |
| Auth bypass → admin access | Critical/High | Depends on scope |
| IDOR → all users' PII | Critical/High | Depends on PII sensitivity |
| Unencrypted user password in DB | High | If accessible |
| SSL pinning bypassable (no chain) | Medium | Theoretical if no MITM setup shown |
| Insecure data in SharedPrefs (token) | Medium | Physical access required |
| Exported activity (limited function) | Medium/Low | Depends on what it exposes |
| Cleartext HTTP for auth | Medium | If credentials visible |
| Weak crypto (MD5/DES) | Medium | If protecting sensitive data |
| Tapjacking | Low/Medium | Requires user interaction |
| allowBackup=true | Low | If backup contains sensitive data |
| debuggable=true (prod) | Low/Medium | Rarely accepted by programs |
| Missing cert pinning (theory) | Informational | Programs want attack chain |
| Missing security headers (API) | Low | Context-dependent |
| Open redirect | Low | Typically phishing risk only |
