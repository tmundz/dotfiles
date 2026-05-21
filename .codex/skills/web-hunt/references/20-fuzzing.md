# Fuzzing

## What Is Fuzzing
Systematically testing inputs with semi-random, edge-case, or specially crafted payloads to discover unexpected behavior, crashes, or vulnerabilities.

## Tools Overview

| Tool | Best For |
|---|---|
| Burp Intruder | Focused parameter fuzzing, authenticated sessions |
| Turbo Intruder | High-speed fuzzing, race conditions |
| wfuzz | CLI fuzzing, flexible, scriptable |
| ffuf | Fast directory/parameter fuzzing |
| Nuclei | Template-based vulnerability scanning |
| radamsa | Mutation-based fuzzing |
| AFL | Binary fuzzing |

## Burp Suite Intruder (BBB Ch.23)

### Attack Types
| Type | Use Case |
|---|---|
| **Sniper** | One position, one payload list — basic fuzzing |
| **Battering Ram** | Same payload in all positions — testing same value across params |
| **Pitchfork** | Multiple positions, multiple lists — credential stuffing |
| **Cluster Bomb** | All combinations of multiple lists — brute force |

### Setting Up Intruder
1. Capture request in Proxy
2. Right-click → Send to Intruder
3. Mark positions with §position§
4. Choose attack type
5. Set payload list
6. Set options (threads, delay, follow redirects)
7. Start attack

### Useful Payload Lists
```
# SecLists - comprehensive wordlist collection
/opt/SecLists/Fuzzing/
/opt/SecLists/Discovery/Web-Content/
/opt/SecLists/Usernames/
/opt/SecLists/Passwords/
/opt/SecLists/Fuzzing/SQLi/
/opt/SecLists/Fuzzing/XSS/

# FuzzDB
/opt/fuzzdb/attack/
/opt/fuzzdb/attack/sql-injection/
/opt/fuzzdb/attack/xss/

# Big List of Naughty Strings (BLNS)
https://github.com/minimaxir/big-list-of-naughty-strings/blob/master/blns.txt
```

### Identifying Interesting Responses
In Intruder results, sort by:
- **Status code**: Look for 200 vs 403 vs 500
- **Response length**: Different length = different behavior
- **Response time**: Longer time may indicate SQLi or command injection

## wfuzz (BBB Ch.23)

```bash
# Basic directory fuzzing
wfuzz -w /opt/SecLists/Discovery/Web-Content/common.txt \
  https://target.com/FUZZ

# Fuzzing parameters
wfuzz -w ids.txt -u "https://target.com/user?id=FUZZ" \
  -H "Cookie: session=YOUR_SESSION"

# Post parameter fuzzing
wfuzz -w payloads.txt -d "username=FUZZ&password=test" \
  https://target.com/login

# Filter by response code (hide 404)
wfuzz -w wordlist.txt --hc 404 https://target.com/FUZZ

# Filter by response length (hide default-length responses)
wfuzz -w wordlist.txt --hl 50 https://target.com/FUZZ  # hide 50-line responses

# Multiple positions (pitchfork)
wfuzz -w users.txt -w passwords.txt \
  -d "user=FUZ&pass=FUZ2Z" https://target.com/login

# Recursive fuzzing
wfuzz -w wordlist.txt -R 1 https://target.com/FUZZ

# With proxy
wfuzz -w wordlist.txt -p 127.0.0.1:8080:HTTP https://target.com/FUZZ
```

## ffuf

```bash
# Directory fuzzing
ffuf -w /opt/SecLists/Discovery/Web-Content/common.txt \
  -u https://target.com/FUZZ -mc 200,301,302,403

# Extension fuzzing
ffuf -w /opt/SecLists/Discovery/Web-Content/common.txt \
  -u https://target.com/FUZZ.php -mc 200

# Parameter name fuzzing
ffuf -w /opt/SecLists/Discovery/Web-Content/burp-parameter-names.txt \
  -u "https://target.com/page?FUZZ=value" -mc 200

# Parameter value fuzzing
ffuf -w /opt/SecLists/Fuzzing/special-chars.txt \
  -u "https://target.com/page?id=FUZZ" -mc all -fc 200  # find non-200

# POST parameter
ffuf -w values.txt \
  -u https://target.com/api/endpoint \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"param":"FUZZ"}' \
  -H "Cookie: session=ABC"

# Subdomain fuzzing
ffuf -w /opt/SecLists/Discovery/DNS/subdomains-top1million-5000.txt \
  -u https://FUZZ.target.com \
  -H "Host: FUZZ.target.com" \
  -mc 200,301,302
```

## Fuzzing for Specific Vulnerabilities

### SQL Injection Fuzzing
```bash
# Using SQLi payload list
wfuzz -w /opt/SecLists/Fuzzing/SQLi/quick-SQLi.txt \
  -u "https://target.com/search?q=FUZZ" \
  -H "Cookie: session=ABC" \
  --hl 50  # hide normal responses

# Look for:
# HTTP 500 (server error → SQL error)
# Different response length (data returned)
# Response with SQL error messages
```

### XSS Fuzzing
```bash
# Using XSS payload list
wfuzz -w /opt/SecLists/Fuzzing/XSS/XSS-Jhaddix.txt \
  -u "https://target.com/search?q=FUZZ" \
  --hc 404 \
  -H "Cookie: session=ABC"

# Look for:
# Reflected payloads in response body (grep for <script, onerror)
# HTTP 500 (WAF block → might be exploitable)
```

### Directory/File Discovery
```bash
# Comprehensive directory scan
ffuf -w /opt/SecLists/Discovery/Web-Content/raft-large-directories.txt \
  -u https://target.com/FUZZ/ \
  -mc 200,301,302,403 \
  -t 50 \
  -o dirs.json

# Find backup/config files
ffuf -w /opt/SecLists/Discovery/Web-Content/raft-large-files.txt \
  -u https://target.com/FUZZ \
  -mc 200 \
  -t 30

# Find PHP files
ffuf -w /opt/SecLists/Discovery/Web-Content/big.txt \
  -u https://target.com/FUZZ.php \
  -mc 200
```

### API Endpoint Fuzzing
```bash
# REST API path fuzzing
ffuf -w /opt/SecLists/Discovery/Web-Content/api/api-endpoints.txt \
  -u https://api.target.com/FUZZ \
  -mc all -fc 404 \
  -H "Authorization: Bearer YOUR_TOKEN"

# API version fuzzing
ffuf -w versions.txt \
  -u https://api.target.com/FUZZ/users \
  -mc all -fc 404
# versions.txt: v1, v2, v3, v4, api, beta, test, internal, dev, 1, 2, 3
```

### Parameter Fuzzing
```bash
# Find hidden parameters
ffuf -w /opt/SecLists/Discovery/Web-Content/burp-parameter-names.txt \
  -u "https://target.com/page?FUZZ=1" \
  -mc all -fc 200 \
  -fs SIZE_OF_NORMAL_RESPONSE

# Fuzz parameter values
ffuf -w /opt/SecLists/Fuzzing/special-chars.txt \
  -u "https://target.com/page?id=FUZZ"
```

## Nuclei Templates

```bash
# Install nuclei
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# Scan with all templates
nuclei -u https://target.com -t /opt/nuclei-templates/

# Specific categories
nuclei -u https://target.com -t /opt/nuclei-templates/vulnerabilities/
nuclei -u https://target.com -t /opt/nuclei-templates/exposures/
nuclei -u https://target.com -t /opt/nuclei-templates/cves/

# Scan multiple targets
nuclei -l targets.txt -t /opt/nuclei-templates/ -o results.txt

# Severity filter
nuclei -u https://target.com -severity high,critical

# Rate limiting
nuclei -u https://target.com -rate-limit 10 -timeout 5
```

## Custom Payload Lists

### Special Characters for Injection Testing
```
'
"
<
>
&
;
|
`
$
(
)
{
}
\
/
../
%00
\r\n
\n
```

### BLNS (Big List of Naughty Strings)
Tests edge cases: null bytes, Unicode, emoji, SQL, XSS, LDAP injection, XML injection, etc.
```bash
# Download
wget https://raw.githubusercontent.com/minimaxir/big-list-of-naughty-strings/master/blns.txt

# Use with wfuzz
wfuzz -w blns.txt "https://target.com/api?input=FUZZ"
```

## Fuzzing Strategy for Bug Bounty

1. **Start broad**: Directory fuzzing to find attack surface
2. **Go deep**: Parameter fuzzing on interesting endpoints
3. **Test for known vulns**: SQL, XSS, SSRF payloads
4. **Monitor responses**: Length, status, time differences
5. **Investigate anomalies**: Any different response = investigate manually

## Rate Limiting Considerations

- Be respectful: don't DoS the target
- Start with 10-50 req/s
- Check program rules for allowed rate
- Use `-t 10` in ffuf to limit threads
- Add delays: `-p 0.1` in wfuzz
- Route through Burp to log everything
