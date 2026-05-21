# OWASP WSTG v4.2 — Complete Testing Checklist
> Source: OWASP Web Security Testing Guide v4.2

## How to Use This Checklist
- Each test has an ID in format `WSTG-<CATEGORY>-<NN>`
- Mark: `[✓]` Tested & Passed | `[!]` Finding | `[N/A]` Not Applicable
- For full test procedures, see the full WSTG documentation

---

## 4.1 Information Gathering

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-INFO-01 | Search Engine Discovery | Google/Bing/Shodan dorks, cached pages, sensitive file exposure |
| WSTG-INFO-02 | Fingerprint Web Server | Banner grabbing, response headers (`Server:`, `X-Powered-By:`), error pages |
| WSTG-INFO-03 | Review Webserver Metafiles | robots.txt, sitemap.xml, humans.txt, .well-known/ |
| WSTG-INFO-04 | Enumerate Applications | All ports, VHosts, non-default applications on same IP |
| WSTG-INFO-05 | Review Webpage Content | HTML comments, hidden fields, metadata in files, source review |
| WSTG-INFO-06 | Identify Application Entry Points | All params (URL, body, headers, cookies), file uploads, WebSockets |
| WSTG-INFO-07 | Map Execution Paths | Spidering, flow mapping for all user roles |
| WSTG-INFO-08 | Fingerprint Web Application Framework | Cookies, URL structure, HTML signatures, error pages |
| WSTG-INFO-09 | Fingerprint Web Application | Wappalyzer, WhatWeb, BuiltWith, version identification |
| WSTG-INFO-10 | Map Application Architecture | Load balancers, WAFs, CDNs, reverse proxies, app/db servers |

---

## 4.2 Configuration and Deployment Management Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-CONF-01 | Test Network Infrastructure Configuration | TLS versions, cipher suites, certificate validity, reverse proxy config |
| WSTG-CONF-02 | Test Application Platform Configuration | Default pages, sample apps, error handling, debug info |
| WSTG-CONF-03 | Test File Extensions Handling | Dangerous extensions served, filtering bypass, upload dir execution |
| WSTG-CONF-04 | Review Old Backup and Unreferenced Files | .bak, ~, .old, .orig, .swp, .tmp files in web root |
| WSTG-CONF-05 | Enumerate Infrastructure and Application Admin Interfaces | /admin, /phpmyadmin, /console, /actuator, /wp-admin |
| WSTG-CONF-06 | Test HTTP Methods | OPTIONS to enumerate, TRACE (XST), PUT/DELETE for file creation/deletion |
| WSTG-CONF-07 | Test HTTP Strict Transport Security | HSTS header presence, max-age, includeSubDomains, preload |
| WSTG-CONF-08 | Test RIA Cross Domain Policy | crossdomain.xml and clientaccesspolicy.xml permissiveness |
| WSTG-CONF-09 | Test File Permission | World-readable config files, writable web root, executable upload dirs |
| WSTG-CONF-10 | Test for Subdomain Takeover | Dangling CNAME/NS records, unclaimed service accounts |
| WSTG-CONF-11 | Test Cloud Storage | S3/GCS/Azure blob public access, list/write permissions |

---

## 4.3 Identity Management Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-IDNT-01 | Test Role Definitions | Identify all roles, map permissions matrix, check for missing role validation |
| WSTG-IDNT-02 | Test User Registration Process | Self-registration without verification, username enumeration, weak validation |
| WSTG-IDNT-03 | Test Account Provisioning Process | Over-provisioned accounts, provisioning without approval, mass provisioning |
| WSTG-IDNT-04 | Testing for Account Enumeration | Different responses for valid/invalid users in login, registration, password reset |
| WSTG-IDNT-05 | Testing for Weak or Unenforced Username Policy | Predictable usernames, no username uniqueness, long/short username edge cases |

---

## 4.4 Authentication Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-ATHN-01 | Testing for Credentials Transported over Encrypted Channel | Login form over HTTP, credentials in URL params, HTTP→HTTPS redirect |
| WSTG-ATHN-02 | Testing for Default Credentials | Default creds for all discovered services, admin panels, IoT devices |
| WSTG-ATHN-03 | Testing for Weak Lock Out Mechanism | Brute-force protection, account lockout policy, IP-based vs. account-based |
| WSTG-ATHN-04 | Testing for Bypassing Authentication Schema | Direct URL access, forced browsing, parameter tampering (role=admin) |
| WSTG-ATHN-05 | Testing for Vulnerable Remember Password | Remember-me token entropy, cookie with password stored, long-lived tokens |
| WSTG-ATHN-06 | Testing for Browser Cache Weaknesses | `Cache-Control: no-store` on authenticated pages, sensitive data in cache |
| WSTG-ATHN-07 | Testing for Weak Password Policy | Min length, complexity, common password check, password history |
| WSTG-ATHN-08 | Testing for Weak Security Question Answer | Guessable questions, enumerable answers, public info required |
| WSTG-ATHN-09 | Testing for Weak Password Change or Reset Functionalities | Token entropy/expiry, host header injection, reuse of tokens, oracle |
| WSTG-ATHN-10 | Testing for Weaker Authentication in Alternative Channel | Mobile app, API, SSO bypass vs. web, SOAP/REST auth differences |

---

## 4.5 Authorization Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-ATHZ-01 | Testing Directory Traversal / File Include | `../` sequences, encoded traversal, absolute paths, LFI/RFI |
| WSTG-ATHZ-02 | Testing for Bypassing Authorization Schema | Access admin functions as user, forced browsing, missing auth check |
| WSTG-ATHZ-03 | Testing for Privilege Escalation | Horizontal (access other user's data), vertical (access higher-privilege func) |
| WSTG-ATHZ-04 | Testing for Insecure Direct Object References | Modify object IDs in params/body/cookies, Autorize extension |

---

## 4.6 Session Management Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-SESS-01 | Testing for Session Management Schema | Token entropy (Burp Sequencer), predictability, contains user info |
| WSTG-SESS-02 | Testing for Cookies Attributes | Secure, HttpOnly, SameSite, Domain scope, Path scope, Expires |
| WSTG-SESS-03 | Testing for Session Fixation | Pre-login session ID same after login? Server issues new ID after auth? |
| WSTG-SESS-04 | Testing for Exposed Session Variables | Session token in URL, HTTP body, not in header |
| WSTG-SESS-05 | Testing for Cross-Site Request Forgery | Missing/bypassable CSRF tokens, missing SameSite cookie attribute |
| WSTG-SESS-06 | Testing for Logout Functionality | Session actually invalidated server-side? Old token still works after logout? |
| WSTG-SESS-07 | Testing Session Timeout | Absolute + sliding timeout enforced? Never-expiring sessions? |
| WSTG-SESS-08 | Testing for Session Puzzling | Session variable overloading — same variable used for different purposes |
| WSTG-SESS-09 | Testing for Session Hijacking | MITM risk, XSS to steal cookie, subdomain cookie scope |

---

## 4.7 Input Validation Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-INPV-01 | Testing for Reflected XSS | All inputs → reflected in response, context-appropriate payloads |
| WSTG-INPV-02 | Testing for Stored XSS | Persistent inputs → XSS in later pages, admin vs. user context |
| WSTG-INPV-03 | Testing for HTTP Verb Tampering | Change GET→POST, OPTIONS→GET — bypass auth or trigger actions |
| WSTG-INPV-04 | Testing for HTTP Parameter Pollution | Duplicate params: `?a=1&a=2`, last-wins vs. first-wins behavior |
| WSTG-INPV-05 | Testing for SQL Injection | `'` detection, boolean/time-based blind, union-based, all SQL DBs |
| WSTG-INPV-05.1 | MySQL Testing | @@version, information_schema, LOAD_FILE, INTO OUTFILE |
| WSTG-INPV-05.2 | Oracle Testing | v$version, all_tables, dual table, dbms_xmlquery for RCE |
| WSTG-INPV-05.3 | PostgreSQL Testing | version(), COPY TO PROGRAM (RCE), large objects |
| WSTG-INPV-05.4 | MS SQL Server Testing | @@version, xp_cmdshell, stacked queries, OPENROWSET |
| WSTG-INPV-05.5 | MS Access Testing | Version tables, union-based |
| WSTG-INPV-05.6 | NoSQL Injection Testing | MongoDB `$ne`, `$gt`, `$where` operators |
| WSTG-INPV-05.7 | ORM Injection Testing | Hibernate HQL, Doctrine DQL, Django ORM injection |
| WSTG-INPV-05.8 | Client-Side Testing | SQLite in browser (WebSQL), IndexedDB injection |
| WSTG-INPV-06 | Testing for LDAP Injection | `)(uid=*))(|(uid=*`, wildcard auth bypass |
| WSTG-INPV-07 | Testing for XML Injection | XXE, XPath injection, XSLT injection |
| WSTG-INPV-08 | Testing for SSI Injection | `<!--#exec cmd="id"-->`, `<!--#include virtual="/etc/passwd"-->` |
| WSTG-INPV-09 | Testing for XPath Injection | `' or '1'='1`, boolean-blind XPath |
| WSTG-INPV-10 | Testing for IMAP/SMTP Injection | Email headers injection, CRLF in email fields |
| WSTG-INPV-11 | Testing for Code Injection | eval(), include(), require(), LFI/RFI |
| WSTG-INPV-12 | Testing for Command Injection | `;id`, `$(id)`, `|id`, `&&id`, blind via delay/OOB |
| WSTG-INPV-13 | Testing for Format String Injection | `%s%s%s%s`, `%x%x%x`, `%n` (write-to-memory on C targets) |
| WSTG-INPV-14 | Testing for Incubated Vulnerabilities | Second-order SQLi, stored XSS triggered elsewhere |
| WSTG-INPV-15 | Testing for HTTP Splitting/Smuggling | CRLF injection in headers, CL.TE/TE.CL smuggling |
| WSTG-INPV-16 | Testing for HTTP Incoming Requests | Proxy request validation, Host header injection |
| WSTG-INPV-17 | Testing for Host Header Injection | Password reset poisoning, cache poisoning via Host |
| WSTG-INPV-18 | Testing for Server-Side Template Injection | `{{7*7}}`, `${7*7}`, `<%= 7*7 %>` in all template contexts |
| WSTG-INPV-19 | Testing for Server-Side Request Forgery | URL params fetched by server, internal endpoints, cloud metadata |

---

## 4.8 Error Handling

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-ERRH-01 | Testing for Improper Error Handling | Verbose error messages exposing stack traces, DB structure, file paths |
| WSTG-ERRH-02 | Testing for Stack Traces | Send invalid input to trigger exceptions, observe disclosed info |

---

## 4.9 Cryptography

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-CRYP-01 | Testing for Weak Transport Layer Security | testssl.sh — weak ciphers, deprecated protocols, cert issues |
| WSTG-CRYP-02 | Testing for Padding Oracle | CBC padding oracle in encrypted params/cookies |
| WSTG-CRYP-03 | Testing for Sensitive Information Sent via Unencrypted Channels | PII, creds over HTTP |
| WSTG-CRYP-04 | Testing for Weak Encryption | MD5/SHA1 passwords, ECB mode, Math.random() for security, hardcoded keys |

---

## 4.10 Business Logic Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-BUSL-01 | Test Business Logic Data Validation | Negative values, overflow, invalid data types accepted |
| WSTG-BUSL-02 | Test Ability to Forge Requests | Modify hidden fields, change flow parameters |
| WSTG-BUSL-03 | Test Integrity Checks | Tamper with price, discount, quantity — bypassed by client-side only checks |
| WSTG-BUSL-04 | Test for Process Timing | Race conditions, TOCTOU |
| WSTG-BUSL-05 | Test Number of Times a Function Can be Used | Apply discount N+1 times, redeem same coupon twice |
| WSTG-BUSL-06 | Testing for the Circumvention of Work Flows | Skip required steps, reverse workflow, repeat steps |
| WSTG-BUSL-07 | Test Defenses Against Application Mis-use | API abuse, scraping, credential stuffing |
| WSTG-BUSL-08 | Test Upload of Unexpected File Types | Bypass extension/MIME check, polyglot files |
| WSTG-BUSL-09 | Test Upload of Malicious Files | Malware, XML bombs, billion laughs, zip bombs |

---

## 4.11 Client-Side Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-CLNT-01 | Testing for DOM-based XSS | JS source→sink analysis, document.write/innerHTML/eval with user input |
| WSTG-CLNT-02 | Testing for JavaScript Execution | JSONP callback injection, eval() of attacker data |
| WSTG-CLNT-03 | Testing for HTML Injection | HTML tags reflected without encoding, form injection |
| WSTG-CLNT-04 | Testing for Client-Side URL Redirect | location.href/assign/replace with user input |
| WSTG-CLNT-05 | Testing for CSS Injection | CSS expression(), import, exfiltration via attribute selectors |
| WSTG-CLNT-06 | Testing for Client-Side Resource Manipulation | Script/CSS src manipulable by user (DOM manipulation) |
| WSTG-CLNT-07 | Test Cross Origin Resource Sharing | CORS reflected origin + credentials, null origin, wildcard |
| WSTG-CLNT-08 | Testing for Cross-Site Flashing | (Legacy Flash — check for crossdomain.xml) |
| WSTG-CLNT-09 | Testing for Clickjacking | Missing X-Frame-Options + missing CSP frame-ancestors |
| WSTG-CLNT-10 | Testing WebSockets | Message tampering, authentication over WebSocket, XSS via WS messages |
| WSTG-CLNT-11 | Test Web Messaging | postMessage without origin validation, eval of message data |
| WSTG-CLNT-12 | Testing Browser Storage | Sensitive data in localStorage/sessionStorage, IndexedDB |
| WSTG-CLNT-13 | Testing for Cross-Site Script Inclusion | JSONP, dynamic script inclusion with user-controlled URL |

---

## 4.12 API Testing

| ID | Test Name | Key Actions |
|---|---|---|
| WSTG-APIT-01 | Testing GraphQL | Introspection, IDOR, injection, batching abuse, subscription |

---

## Quick Priority Matrix

### Test in Order for Maximum Bug Bounty ROI

**Always Test First (Highest ROI):**
- WSTG-ATHZ-04 (IDOR) — highest impact, easiest to find
- WSTG-INPV-19 (SSRF) — critical impact in cloud environments
- WSTG-ATHN-04/09 (Auth bypass / Password reset) — account takeover
- WSTG-SESS-05 (CSRF) — state-changing actions without protection
- WSTG-INPV-05 (SQLi) — data breach, auth bypass

**High Value:**
- WSTG-INPV-18 (SSTI) — often leads to RCE
- WSTG-INPV-07 (XXE) — file read, SSRF, sometimes RCE
- WSTG-CONF-10 (Subdomain Takeover) — phishing, XSS
- WSTG-CLNT-07 (CORS) — data theft if ACAO+credentials

**Medium Value (Test When Time Permits):**
- WSTG-INPV-01/02 (XSS) — session hijack if stored, lower if reflected
- WSTG-BUSL-* (Business Logic) — depends heavily on application
- WSTG-CLNT-09 (Clickjacking) — UI redressing on valuable actions
- WSTG-CLNT-11 (postMessage) — often overlooked, can be high impact

**Test Last (Low Bounty Value):**
- WSTG-CONF-07 (Missing HSTS) — informational in most programs
- WSTG-ERRH-01 (Verbose errors) — informational
- WSTG-CLNT-12 (Browser storage) — context-dependent, usually low
