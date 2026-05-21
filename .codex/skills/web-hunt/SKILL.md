---
name: web-hunt
description: >
  Comprehensive web hacking and bug bounty skill from Bug Bounty Bootcamp, OWASP WSTG v4.2,
  The Tangled Web, and JavaScript for Hackers. Use for web security testing, bug bounty hunting,
  vulnerability assessment, penetration testing, recon, exploit development, report writing, or
  code review. Attack coverage includes XSS, SQLi, SSRF, IDOR, CSRF, RCE, XXE, SSTI,
  deserialization, OAuth/JWT/SAML attacks, subdomain takeover, prototype pollution,
  HTTP smuggling, clickjacking, CORS misconfiguration, GraphQL hacking, API fuzzing, and more.
---

# Web Hacking & Bug Bounty — Master Skill

> Synthesized from: Bug Bounty Bootcamp (Li) · Real-World Bug Hunting (Yaworski) · OWASP WSTG v4.2 · The Tangled Web (Zalewski) · JavaScript for Hackers

## How to Use This Skill

Read the relevant reference file for each topic. This SKILL.md is the entry point.

| Reference | Contents |
|---|---|
| `references/00-program-selection.md` | Platforms, program selection criteria, VDP vs bug bounty |
| `references/01-recon.md` | Full recon: subdomains, OSINT, JS analysis, WSTG INFO checklist, automation |
| `references/02-xss.md` | All XSS types, JS for Hackers: DOM clobbering, parenthesis-free, JSFuck, popover XSS |
| `references/03-open-redirect.md` | Open redirect hunting, bypasses, OAuth chaining |
| `references/04-clickjacking.md` | Frame busting bypass, sandbox bypass, PoC templates |
| `references/05-csrf.md` | CSRF bypass techniques, SameSite bypass, JSON CSRF, PoC |
| `references/06-idor.md` | Horizontal/vertical, encoded IDs, blind IDORs, Autorize, array wrapping |
| `references/07-sqli.md` | UNION, error-based, blind, time-based, per-DB, NoSQL, second-order, sqlmap |
| `references/08-race-conditions.md` | TOCTOU, parallel requests, Turbo Intruder, single-packet attack |
| `references/09-ssrf.md` | Blocklist bypass (hex/octal/dword), cloud metadata, gopher://, blind OOB |
| `references/10-deserialization.md` | PHP POP chains, Java ysoserial, Python pickle, .NET, Node.js PP gadgets |
| `references/11-xxe.md` | Classic, blind OOB, DTD exfiltration, SVG/DOCX, XInclude, SOAP |
| `references/12-ssti.md` | Jinja2, Twig, FreeMarker, ERB, Smarty, Velocity, Pebble, tplmap |
| `references/13-logic-access.md` | MFA bypass, payment bypass, mass assignment, session WSTG, password reset, WSTG ATHZ |
| `references/14-rce.md` | Command injection, LFI/RFI, file upload bypass, log poisoning, ImageTragick, Log4Shell |
| `references/15-sop-cors.md` | SOP internals, CORS misconfig, postMessage, JSONP, document.domain (Tangled Web) |
| `references/16-sso-oauth.md` | OAuth attacks, SAML wrapping, JWT alg=none/JWK/RS256→HS256/kid injection, jwt_tool |
| `references/17-info-disclosure.md` | .git exposure, .env, stack traces, Shodan, GitHub recon, Spring Boot actuator |
| `references/18-code-review.md` | Dangerous functions table PHP/Python/JS/Ruby/Java, grep patterns, crypto review |
| `references/19-api-hacking.md` | REST, GraphQL attacks, SOAP, mass assignment, OWASP API Top 10, version bypass |
| `references/20-fuzzing.md` | Burp Intruder types, wfuzz, ffuf, Nuclei, SecLists/FuzzDB/BLNS |
| `references/21-hpp.md` | HTTP parameter pollution, signature bypass, OAuth redirect_uri HPP |
| `references/22-html-injection.md` | HTML injection, Markdown injection, CSS selector exfiltration, CRLF, LDAP, XPath |
| `references/23-report-writing.md` | 8-component report template, CVSS table, PoC standards, disclosure etiquette, triage |
| `references/24-prototype-pollution.md` | Client-side PP, SSPP detection (status:510), RCE via Node.js spawn, gadget chains |
| `references/25-http-smuggling.md` | CL.TE, TE.CL, detection, cache poisoning, credential theft via smuggling |
| `references/26-wstg-checklist.md` | Complete OWASP WSTG v4.2 checklist (INFO through CLIENT + API, priority matrix) |
| `references/27-payloads.md` | Payload cheatsheets: XSS, SQLi, SSRF, XXE, SSTI, command injection, path traversal, WAF bypass |
| `references/28-android-crypto.md` | Android app hacking (Frida, ADB, cert pinning bypass), cryptographic testing (testssl, padding oracle) |
| `references/29-subdomain-takeover.md` | CNAME dangling, fingerprint table, service-specific exploitation, nuclei scanning |

---

## Bug Bounty Engagement Workflow

### Phase 0 — Program Selection & Scoping
See `references/00-program-selection.md`

Quick rules:
- Prefer programs with **broad wildcard scope** (`*.example.com`), high payouts, and low competition
- Read the **entire policy** before testing: in-scope assets, prohibited actions, disclosure timelines
- Track scope in a structured file; never test out-of-scope assets
- Prioritize: payment/auth flows > admin panels > file uploads > API endpoints > marketing pages

### Phase 1 — Reconnaissance
**→ Read `references/01-recon.md` for the complete methodology**

Recon layers (in order):
1. **Passive**: WHOIS, ASN lookup, crt.sh certificate transparency, Shodan/Censys, Wayback Machine, GitHub
2. **Subdomain Enum**: Subfinder + Amass + Assetfinder + Findomain → dnsx resolution → altdns permutations
3. **Live Host Discovery**: httpx/httprobe → screenshot with Aquatone/Gowitness
4. **Port/Service**: Nmap targeted ports, Masscan for speed
5. **Content Discovery**: ffuf/feroxbuster/dirsearch + backup/sensitive file checklist
6. **JS Analysis**: LinkFinder, JSParser, gau, waybackurls → grep for secrets; source map recovery
7. **Parameter Discovery**: Arjun, x8, ParamSpider + Burp Param Miner
8. **Tech Fingerprinting**: Wappalyzer, WhatWeb, response headers, cookie names, error pages

### Phase 2 — Target Mapping
- Spider with Burp Pro or ZAP — capture all endpoints, parameters, forms
- Identify authentication: session cookies, JWT, API keys, OAuth
- Map user roles (unauthenticated, user, admin, API)
- Find: file uploads, webhooks, export functions, import functions, third-party integrations
- Note: URL parameters, JSON body params, hidden form fields, custom headers, WebSocket connections

### Phase 3 — Vulnerability Testing
**→ Read the relevant `references/` file for each vulnerability class**

Priority testing order (highest ROI in bug bounty):
1. **Authentication/Authorization** — login bypass, password reset flaws, IDOR, privilege escalation
2. **Injection** — SSRF (cloud metadata), SQLi, XXE, SSTI, command injection
3. **Business Logic** — race conditions, negative prices, workflow bypass, mass assignment
4. **Session Management** — CSRF, session fixation, token predictability
5. **Client-Side** — Stored XSS, DOM XSS, reflected XSS
6. **Configuration** — subdomain takeover, exposed admin panels, S3 misconfiguration, CORS

### Phase 4 — Exploitation & Impact Maximization
- Always demonstrate concrete impact — account takeover > theoretical XSS
- Chain vulnerabilities: SSRF → internal port scan → RCE; open redirect → OAuth token theft
- For blind vulnerabilities (blind SQLi, blind SSRF, blind XSS): use OOB (Burp Collaborator, interactsh)
- Document every step with screenshots, HTTP request/response pairs

### Phase 5 — Reporting
**→ Read `references/23-report-writing.md` for full guidance**

---

## Vulnerability Quick Reference

### Injection Vulnerabilities
| Vulnerability | Key Test | Impact | Reference |
|---|---|---|---|
| XSS (Reflected) | Input reflected in HTML | Session hijacking, phishing | `02-xss.md` |
| XSS (Stored) | Input stored, output to all viewers | Mass session hijack, keylogging | `02-xss.md` |
| XSS (DOM) | `document.write(location.hash)` | Session hijacking | `02-xss.md` |
| XSS (Blind) | Fires in admin panel/logs | Admin account takeover | `02-xss.md` |
| SQLi | `'` triggers error/diff/time delay | DB dump, auth bypass, RCE | `07-sqli.md` |
| SSRF | Internal URL in param fetched by server | AWS metadata, internal services, RCE | `09-ssrf.md` |
| XXE | External entity in XML input | File read, SSRF, RCE | `11-xxe.md` |
| SSTI | `{{7*7}}` → `49` | RCE on server | `12-ssti.md` |
| Command Injection | `;id`, `$(id)`, backtick | Full OS RCE | `14-rce.md` |
| CRLF | `%0d%0a` in redirect param | Header injection, XSS | `22-html-injection.md` |
| HTTP Smuggling | CL vs TE header conflict | Cache poison, credential theft | `25-http-smuggling.md` |
| LDAP Injection | `)(uid=*))(|(uid=*` | Auth bypass, user enum | `22-html-injection.md` |
| XPath Injection | `' or '1'='1` | Auth bypass, data exfil | `22-html-injection.md` |

### Access Control / Logic Vulnerabilities
| Vulnerability | Key Test | Impact | Reference |
|---|---|---|---|
| IDOR | Change `user_id`, `doc_id` params | Data theft, account takeover | `06-idor.md` |
| CSRF | State-change without token/SameSite | Account takeover, fund transfer | `05-csrf.md` |
| Auth Bypass | Forced browsing, parameter tampering | Admin access | `13-logic-access.md` |
| Race Condition | Simultaneous requests | Double spend, limit bypass | `08-race-conditions.md` |
| Business Logic | Negative values, step skipping | Payment bypass, privilege escalation | `13-logic-access.md` |
| Mass Assignment | Extra JSON fields in registration | Role escalation, credit manipulation | `13-logic-access.md` |
| OAuth Flaw | Missing state, redirect_uri bypass | Account takeover | `16-sso-oauth.md` |
| JWT Attack | `alg:none`, JWK injection, RS256→HS256 | Auth bypass | `16-sso-oauth.md` |
| Deserialization | Tampered serialized object | RCE, auth bypass | `10-deserialization.md` |
| Prototype Pollution | `__proto__[x]=y` injection | XSS, auth bypass, RCE | `24-prototype-pollution.md` |
| HPP | Duplicate parameters | WAF bypass, OAuth token theft | `21-hpp.md` |

### Advanced / Infrastructure Vulnerabilities
| Vulnerability | Key Test | Impact | Reference |
|---|---|---|---|
| Subdomain Takeover | CNAME to unclaimed service | Phishing, XSS on victim origin | `29-subdomain-takeover.md` |
| Open Redirect | `?next=//evil.com` | Phishing, OAuth token theft | `03-open-redirect.md` |
| Clickjacking | Iframe victim page | CSRF, UI redressing | `04-clickjacking.md` |
| CORS Misconfiguration | Reflected Origin + credentials | Cross-site data theft | `15-sop-cors.md` |
| GraphQL | Introspection, batching, IDOR | Data leakage, injection | `19-api-hacking.md` |
| S3 Misconfiguration | List/write public bucket | Data theft, malware hosting | `17-info-disclosure.md` |
| HTML/Content Injection | `<h1>HACKED</h1>` renders | Phishing, defacement | `22-html-injection.md` |
| Info Disclosure | .git/.env/phpinfo exposure | Credential theft, source code | `17-info-disclosure.md` |

---

## Severity Escalation Chains

```
XSS → steal CSRF token → perform authenticated state-change (CSRF via XSS)
XSS → steal session cookie → account takeover
Open redirect → OAuth token theft → account takeover
SSRF → cloud metadata endpoint → IAM credential leak → AWS CLI RCE
SSRF → internal Redis/Elasticsearch → data exfiltration
SSRF → gopher:// → Redis FLUSHALL / SMTP relay
Info disclosure → CVE exploit → RCE
IDOR + blind info leak → escalate to full data exfiltration
CORS misconfiguration + credentials → user data theft
Subdomain takeover → OAuth redirect_uri → token theft
Prototype pollution → XSS gadget → account takeover
SSPP (server-side prototype pollution) → Node.js spawn → RCE
SAML signature bypass → admin impersonation
JWT alg=none → arbitrary user impersonation
JWT JWK header injection → forge any claim
LFI → log poisoning → RCE
File upload bypass → webshell → full server compromise
```

---

## Core HTTP & Browser Security Concepts

### Same-Origin Policy
- **Origin** = scheme + host + port (all three must match)
- JavaScript can SEND cross-origin requests but cannot READ responses without CORS
- `document.domain` relaxation: both parent and child must set it to share

### Cookie Security Model
- `domain=.example.com` — shared across all subdomains (subdomain XSS → parent cookie theft)
- `SameSite=Strict` — blocks CSRF in all cross-site contexts
- `SameSite=Lax` — allows top-level GET navigation, blocks cross-site POST
- `HttpOnly` — prevents JS access; `Secure` — HTTPS only

### URL Parsing Dangers
- `http://attacker.com@victim.com/` — authority vs. path confusion
- `%2F` in path may bypass WAF; `%00` null byte truncation
- IPv6 literal: `http://[::1]/` — can bypass IP allowlists
- IDN homograph attacks: Unicode lookalike domains
- Percent encoding double-decode: `%252F` → `%2F` → `/`

---

## OWASP Top 10 Mapping

- **A01 Broken Access Control** → IDOR, privilege escalation, forced browsing, CORS, path traversal
- **A02 Cryptographic Failures** → Sensitive data in URL, weak ciphers, improper TLS, insecure cookies
- **A03 Injection** → SQLi, XSS, SSTI, command injection, LDAP injection, XXE
- **A04 Insecure Design** → Business logic flaws, race conditions, workflow bypass
- **A05 Security Misconfiguration** → Default creds, open admin panels, unnecessary features, S3 public
- **A06 Vulnerable Components** → Known CVEs in libs/frameworks
- **A07 Auth Failures** → Credential stuffing, weak passwords, session fixation, insecure tokens
- **A08 Integrity Failures** → Insecure deserialization, supply chain, auto-update without verification
- **A09 Logging Failures** → Log injection, absence of audit logging
- **A10 SSRF** → Standalone category due to prevalence in modern cloud apps

---

## Essential Tools

### Proxy & Interception
- **Burp Suite Pro** — Scanner, Repeater, Intruder, Collaborator, extensions (Autorize, Turbo Intruder, HTTP Request Smuggler, Param Miner, ActiveScan++, SAML Raider, InQL, DOMInvader)
- **OWASP ZAP** — free alternative, active scanner, Ajax spider

### Recon & OSINT
- **Amass, Subfinder, Assetfinder, Findomain** — subdomain enumeration
- **httpx, httprobe** — live host detection
- **gau, waybackurls** — historical URL collection
- **LinkFinder, JSParser** — JS endpoint extraction
- **Shodan, Censys** — internet-facing asset discovery
- **ffuf, feroxbuster, dirsearch** — directory/content brute-force

### Exploitation
- **sqlmap** — automated SQLi
- **XSStrike, dalfox** — XSS detection/bypass
- **nuclei** — template-based vulnerability scanner
- **jwt_tool** — JWT analysis and attacks
- **ysoserial, PHPGGC** — Java/PHP deserialization gadget chains
- **testssl.sh** — comprehensive TLS testing

---

## CVSS Severity Reference

| Severity | CVSS Score | Typical Examples |
|---|---|---|
| **Critical** | 9.0–10.0 | Unauthenticated RCE, SQLi with OS access, auth bypass → admin, mass data breach |
| **High** | 7.0–8.9 | Authenticated RCE, SSRF to AWS metadata, stored XSS, IDOR account takeover |
| **Medium** | 4.0–6.9 | CSRF account modification, reflected XSS, IDOR data leak, race condition |
| **Low** | 0.1–3.9 | Self-XSS, open redirect (standalone), clickjacking on low-value page |
| **Informational** | N/A | Missing security headers, version disclosure, best practice violations |
