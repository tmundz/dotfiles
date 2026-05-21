# Reconnaissance
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2 (OWASP)

## Table of Contents
1. [Scope Mapping & Asset Discovery](#1-scope-mapping--asset-discovery)
2. [Passive Recon](#2-passive-recon)
3. [Subdomain Enumeration](#3-subdomain-enumeration)
4. [Live Host & Service Discovery](#4-live-host--service-discovery)
5. [Content Discovery](#5-content-discovery)
6. [JavaScript Analysis](#6-javascript-analysis)
7. [Parameter Discovery](#7-parameter-discovery)
8. [Technology Fingerprinting](#8-technology-fingerprinting)
9. [Google Dorking](#9-google-dorking)
10. [GitHub Recon](#10-github-recon)
11. [Cloud Storage Discovery](#11-cloud-storage-discovery)
12. [Recon Automation Scripts](#12-recon-automation-scripts)
13. [WSTG Information Gathering Checklist](#13-wstg-information-gathering-checklist)

---

## 1. Scope Mapping & Asset Discovery

### Asset Discovery Checklist
- [ ] All subdomains of in-scope domains
- [ ] IP ranges (ASN lookup)
- [ ] Associated companies/acquisitions
- [ ] Mobile apps (iOS/Android)
- [ ] GitHub/GitLab repos
- [ ] S3 buckets, GCS buckets
- [ ] Cloud resources (AWS, GCP, Azure)

---

## 2. Passive Recon

### WHOIS & Reverse WHOIS
```bash
whois target.com
whois 1.2.3.4
# Reverse WHOIS: find all domains registered to same org
# Tools: viewdns.info/reversewhois, DomainTools, whoxy.com
# Look for: registrant email, phone, org name, address → sibling domains
```

### ASN & IP Range Discovery
```bash
# Find ASN by org name
curl https://api.bgpview.io/search?query_term=TargetCorp | jq
# Get IP ranges from ASN
whois -h whois.radb.net -- '-i origin AS12345' | grep route
# Shodan ASN search
shodan search 'asn:AS12345'
# BGP Toolkit: bgp.he.net → search company name → expand all prefixes

# Nmap/Masscan discovered ranges
nmap -sV -p 80,443,8080,8443 -iL ip_ranges.txt --open
masscan -p1-65535 --rate=10000 -iL ip_ranges.txt -oG masscan_results.txt
```

### Certificate Transparency Logs
```bash
# crt.sh — best passive subdomain source
curl "https://crt.sh/?q=%25.target.com&output=json" | jq '.[].name_value' | sort -u
# certspotter
curl "https://api.certspotter.com/v1/issuances?domain=target.com&include_subdomains=true&expand=dns_names"
```

### Wayback Machine & Historical Data
```bash
# Get all URLs ever indexed
gau target.com --threads 5 --subs | tee gau_output.txt
waybackurls target.com | tee wayback.txt
gauplus -t 5 -random-agent -subs target.com | tee gauplus.txt
# Combine and deduplicate
cat gau_output.txt wayback.txt gauplus.txt | sort -u > all_urls.txt
# Look for: old API endpoints, backup files, dev endpoints, parameter names
# Find old API versions:
cat all_urls.txt | grep "api/v"
# Find interesting historical endpoints:
cat all_urls.txt | grep -E "\.(php|asp|aspx|jsp)$"
cat all_urls.txt | grep "admin\|login\|upload\|config"
# Find params:
cat all_urls.txt | grep "=" > params.txt
```

### Shodan / Censys / FOFA
```bash
# Shodan
shodan search 'hostname:target.com'
shodan search 'org:"Target Corp" http.title:"Admin"'
shodan search 'ssl:"target.com" port:8443'
shodan search 'asn:AS12345 product:nginx'
shodan search "org:\"Target Corp\"" --fields ip_str,port,hostnames,product
shodan host <IP>
# Censys
censys search 'parsed.names: target.com' --index certificates
# FOFA (Chinese search engine — great for Asian targets)
# fofa.info query: domain="target.com"
```

### Paste Sites & Leak Databases
- **Pastebin, GitHub Gists, GitLab Snippets** — search company name, domain, email patterns
- **Have I Been Pwned, DeHashed** — check if org emails appear in breach data
- **Grep.app** — search GitHub for company/domain patterns
- **psbdmp.ws** — Pastebin search

### OSINT
```bash
# LinkedIn for employee names → email format
# hunter.io / emailformat.com for email discovery
# sherlock USERNAME  # social media handles
```

---

## 3. Subdomain Enumeration

### Passive (No DNS Brute-Force)
```bash
# Subfinder — queries 40+ passive sources
subfinder -d target.com -all -recursive -o subfinder.txt

# Amass passive mode
amass enum -passive -d target.com -o amass_passive.txt

# Assetfinder
assetfinder --subs-only target.com > assetfinder.txt

# Findomain
findomain -t target.com -u findomain.txt

# theHarvester
theHarvester -d target.com -b all -f theharvester.txt

# Sublist3r
sublist3r -d target.com -o sublist3r.txt

# Combine all results
cat subfinder.txt amass_passive.txt assetfinder.txt findomain.txt sublist3r.txt | sort -u > all_subs_passive.txt
```

### Active (DNS Brute-Force)
```bash
# Amass active with brute-force
amass enum -active -brute -d target.com \
  -w /usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt -o amass_active.txt

# puredns brute-force (fast, uses massdns)
puredns bruteforce /usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt \
  target.com -r resolvers.txt -o puredns.txt

# Gobuster DNS
gobuster dns -d target.com \
  -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o gobuster_dns.txt

# dnsx — resolve and filter
cat all_subs_passive.txt | dnsx -silent -a -resp -o resolved_subs.txt
```

### Permutation / Alteration
```bash
# altdns — generate permutations (dev, staging, api, etc.)
altdns -i resolved_subs.txt -o altdns_permutations.txt -w words.txt
puredns resolve altdns_permutations.txt -r resolvers.txt -o altdns_resolved.txt
```

### Virtual Host (VHost) Discovery
```bash
# ffuf vhost fuzzing
ffuf -w /path/to/subdomains.txt -u https://target.com \
  -H "Host: FUZZ.target.com" -mc 200,301,302,403 -o vhost_results.txt
# gobuster vhost
gobuster vhost -u https://target.com -w subdomains.txt
```

### Subdomain Wordlists (Priority Order)
1. `SecLists/Discovery/DNS/bitquark-subdomains-top100000.txt` — best all-purpose
2. `SecLists/Discovery/DNS/subdomains-top1million-5000.txt` — quick wins
3. Custom wordlist: dev, stage, api, admin, test, internal, beta, mobile, app, portal, dashboard, vpn, mail, login, sandbox, uat

---

## 4. Live Host & Service Discovery

### HTTP/HTTPS Probing
```bash
# httpx — fast HTTP probing with status codes, titles, tech detection
cat all_subs_passive.txt | httpx -silent -status-code -title -tech-detect \
  -follow-redirects -o httpx_results.txt

# httprobe — simple live detection
cat all_subs_passive.txt | httprobe -c 50 -t 3000 > live_hosts.txt

# Screenshot all live hosts
cat live_hosts.txt | aquatone -out aquatone_output/ -screenshot-timeout 30000
gowitness file -f live_hosts.txt -d screenshots/
eyewitness --web -f live_hosts.txt -d eyewitness_output/
```

### Port Scanning
```bash
# Nmap — targeted web ports
nmap -iL ips.txt -p 80,443,8080,8443,8000,8888,9200,9090,3000,5000,4443 -sV -oA nmap_web_ports

# Full port scan for interesting targets
nmap -p- --min-rate 5000 -sV target.com -oA nmap_fullport

# Masscan for speed
masscan -iL ips.txt -p 1-65535 --rate 100000 -oJ masscan_output.json
```

### Service-Specific Discovery
```bash
# Elasticsearch (common misconfiguration)
curl http://target.com:9200/_cat/indices
curl http://target.com:9200/_all/_search

# MongoDB (no auth)
mongo target.com:27017

# Redis
redis-cli -h target.com ping

# Jenkins (/script endpoint = Groovy console = RCE)
curl http://target.com:8080/script

# Kubernetes API
curl https://target.com:6443/api/v1/namespaces/default/pods
```

---

## 5. Content Discovery

### Directory & File Brute-Force
```bash
# ffuf — fastest option
ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-large-words.txt \
  -u https://target.com/FUZZ \
  -mc 200,201,204,301,302,307,401,403 \
  -ac -c -t 50 \
  -o ffuf_content.json -of json

# Extension fuzzing
ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-medium-files.txt \
  -u https://target.com/FUZZ \
  -e .php,.asp,.aspx,.jsp,.bak,.sql,.conf,.config,.log,.txt,.xml,.json \
  -mc 200,201,204 -ac

# feroxbuster — recursive
feroxbuster -u https://target.com \
  -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
  --depth 3 --auto-tune --extract-links -o feroxbuster.txt

# dirsearch
python3 dirsearch.py -u https://target.com -e php,asp,aspx,jsp,html,txt -r -t 50 -o dirsearch.txt

# gobuster
gobuster dir -u https://target.com \
  -w /opt/SecLists/Discovery/Web-Content/common.txt \
  -x php,asp,aspx,jsp,html,js,txt,bak -t 50 -o gobuster.txt
```

### Backup & Sensitive Files Checklist
```
/.git/HEAD                    # Git repo exposure
/.env                         # Environment variables
/config.php, /config.yml      # Config files
/backup.zip, /backup.tar.gz   # Backups
/robots.txt                   # May reveal hidden paths
/sitemap.xml                  # Full URL tree
/.htaccess, /.htpasswd        # Apache config/creds
/web.config                   # IIS config
/phpinfo.php                  # PHP info disclosure
/server-status                # Apache mod_status
/api-docs, /swagger.json      # API documentation
/actuator, /actuator/env      # Spring Boot actuator (credentials!)
/console                      # Rails/Grails console
/.DS_Store                    # macOS metadata
/crossdomain.xml              # Flash cross-domain policy
/security.txt                 # Security contacts
```

### API Endpoint Discovery
```bash
# Kiterunner — API route brute-force with real-world API routes
kr scan https://api.target.com -w routes-large.kite -o kr_results.txt

# Common API paths
/api/v1/, /api/v2/, /api/v3/
/rest/, /graphql, /graph
/admin/, /internal/, /private/
/health, /status, /ping, /metrics
/_debug, /_admin
```

---

## 6. JavaScript Analysis

### Endpoint & Secret Extraction
```bash
# LinkFinder — extract endpoints from JS files
python3 linkfinder.py -i https://target.com/app.js -o cli
python3 linkfinder.py -i https://target.com -d -o results.html  # crawl entire domain

# Download all JS files
gau target.com | grep '\.js$' | sort -u | xargs -I{} curl -s {} | tee all_js.txt
cat live_hosts.txt | getJS --complete --header "Cookie: session=xxx" > js_files.txt

# Extract secrets with grepping
grep -Ei "(api_key|apikey|secret|password|token|auth|bearer|private_key|access_key)" all_js.txt
grep -Ei "(aws_access|aws_secret|s3.amazonaws.com|firebase|mongodb|postgres|mysql)" all_js.txt
```

### Source Map Recovery
```bash
# If .js.map files are exposed, recover original source
node source-map-explorer bundle.js bundle.js.map
# Manually: curl https://target.com/static/main.chunk.js.map | jq .sources
```

### Webpack Bundle Analysis
```bash
# webpack-exploder — extract files from webpack bundle
python3 webpack-exploder.py https://target.com/static/js/main.chunk.js
# Check for: exposed internal URLs, dev endpoints, commented auth, API keys, internal IPs
```

### Track JS Changes Over Time
```bash
# Download JS periodically and diff
wget https://target.com/app.js -O app_$(date +%Y%m%d).js
diff app_yesterday.js app_today.js

# Monitor JS file changes (continuous monitoring script)
URL="https://target.com/app.js"
NEW_HASH=$(curl -s "$URL" | md5sum)
OLD_HASH=$(cat prev_hash.txt 2>/dev/null)
if [ "$NEW_HASH" != "$OLD_HASH" ]; then
    echo "JS changed!" | notify
    echo "$NEW_HASH" > prev_hash.txt
fi
```

---

## 7. Parameter Discovery

```bash
# Arjun — discovers HTTP parameters
python3 arjun.py -u https://target.com/api/users --get -t 10 -o arjun.json
python3 arjun.py -u https://target.com/api/users --post

# x8 — hidden parameter discovery
x8 -u "https://target.com/api?FUZZ=1" -w params.txt

# ParamSpider — mine params from Wayback Machine
python3 paramspider.py --domain target.com --output params.txt

# Burp Suite Param Miner extension
# Right-click request → Extensions → Param Miner → Guess params
# Guesses: query params, body params, JSON keys, header names
```

---

## 8. Technology Fingerprinting

### From HTTP Headers
```
Server: Apache/2.4.41 (Ubuntu)    → OS, web server version
X-Powered-By: PHP/7.4.3           → Language/version
X-Generator: Drupal 8             → CMS
X-AspNet-Version: 4.0.30319       → .NET version
Set-Cookie: PHPSESSID=            → PHP
Set-Cookie: JSESSIONID=           → Java/Tomcat
Set-Cookie: laravel_session=      → Laravel framework
Set-Cookie: _rails_session=       → Ruby on Rails
```

### From Response Bodies
```
<!-- WordPress: wp-content, wp-includes -->
<!-- Drupal: data-drupal-selector, /core/ paths -->
<!-- Joomla: /media/com_, index.php?option=com_ -->
<!-- Magento: /skin/frontend/, Mage.* JS -->
<!-- ASP.NET: __VIEWSTATE, __EVENTVALIDATION -->
<!-- Angular: ng-app, ng-version -->
```

### Tools
```bash
whatweb https://target.com -v -a 3
wappalyzer https://target.com  # browser extension / CLI
retire --path /path/to/js/files  # JS library CVE check
python3 cmsmap.py https://target.com

# Framework-specific fingerprinting
curl https://target.com/wp-login.php                    # WordPress
curl https://target.com/wp-json/wp/v2/users            # WordPress user enum
curl https://target.com/CHANGELOG.txt                  # Drupal version
curl https://target.com/actuator/env                   # Spring Boot
curl https://target.com/rails/info/properties          # Rails dev mode
```

---

## 9. Google Dorking

### Core Operators
```
site:target.com              # Restrict to domain
site:*.target.com            # All subdomains
inurl:admin                  # URL contains 'admin'
intitle:"index of"           # Directory listings
filetype:pdf                 # File type filter
ext:bak OR ext:old OR ext:backup  # Backup files
cache:target.com             # Google's cached version
```

### High-Value Dorks
```
site:target.com filetype:pdf confidential
site:target.com ext:sql OR ext:db OR ext:bak
site:target.com inurl:admin OR inurl:dashboard OR inurl:portal
site:target.com inurl:config OR inurl:settings
site:target.com "api_key" OR "apikey" OR "secret" OR "password"
site:target.com intitle:"index of" "passwords"
site:target.com "Internal Server Error"
site:target.com inurl:dev OR inurl:staging OR inurl:test OR inurl:beta
site:target.com ext:php inurl:id=
site:target.com wp-login.php
site:pastebin.com "target.com" password
site:github.com "target.com" apikey
"X-Jenkins" OR "Jenkins" site:target.com
```

### GitHub Dorks
```
org:TargetCorp password
org:TargetCorp secret
org:TargetCorp apikey
org:TargetCorp aws_access_key
org:TargetCorp mongodb://
org:TargetCorp "internal use only"
"target.com" extension:yaml password
"target.com" extension:json aws_secret
```

---

## 10. GitHub Recon

### Manual Searching
1. Search GitHub for: company name, domain, product names, engineer names
2. Look in: Issues, Pull Requests, **Commits**, **Code** (most important), Wikis
3. Review: `.env`, `config.yml`, `settings.py`, `database.yml`, `secrets.json`, `.npmrc`, `Dockerfile`
4. Check all **branches** and **commit history** — secrets may be removed but still in git history

### Automated Tools
```bash
# TruffleHog — find high-entropy strings
trufflehog github --org=TargetCorp
trufflehog git https://github.com/TargetCorp/repo.git
trufflehog --regex --entropy=True https://github.com/example/repo.git  # legacy

# Gitrob — scan org's GitHub repos
gitrob analyze TargetCorp --github-access-token <token>

# gitleaks — scan for secrets
gitleaks detect --source /path/to/cloned/repo

# Enumerate exposed .git directories
# If https://target.com/.git/HEAD returns "ref: refs/heads/master" → full source recovery!
git-dumper https://target.com/.git/ ./output/

# View all commits including deleted files
git log --all --full-history --oneline
git show <commit-hash>

# GitHub API search
curl "https://api.github.com/search/code?q=example.com+password&type=code" \
  -H "Authorization: token GITHUB_TOKEN"
```

---

## 11. Cloud Storage Discovery

```bash
# S3 bucket naming patterns to try:
# <company>-dev, <company>-prod, <company>-backup, <company>-assets
# <company>-uploads, <company>-static, <company>-media, <company>-data
# <company>-terraform, <company>-k8s, <company>-secrets

# Check S3 access
aws s3 ls s3://bucket-name --no-sign-request
aws s3 ls s3://bucket-name/ --no-sign-request --recursive | head -50
aws s3 cp /tmp/test.txt s3://bucket-name/test.txt --no-sign-request  # test write
curl https://bucket-name.s3.amazonaws.com/?list-type=2

# Generate and test bucket names
for word in dev staging prod backup assets images; do
  echo "example-$word"
  echo "$word-example"
done | s3scanner scan --buckets-file -

# lazys3 / s3scanner
lazys3 COMPANY
s3scanner scan --buckets-file bucket_names.txt

# Google Cloud Storage
curl https://storage.googleapis.com/bucket-name/

# Azure Blob Storage
https://accountname.blob.core.windows.net/containername/?restype=container&comp=list
```

---

## 12. Recon Automation Scripts

### Full Recon Script (Bash)
```bash
#!/bin/bash
TARGET=$1
OUTPUT_DIR="recon_${TARGET}_$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

echo "[*] Starting recon for $TARGET"

# Subdomain enumeration
echo "[*] Running subdomain enum..."
subfinder -d "$TARGET" -all -silent | tee "$OUTPUT_DIR/subfinder.txt"
assetfinder --subs-only "$TARGET" | tee "$OUTPUT_DIR/assetfinder.txt"
cat "$OUTPUT_DIR/subfinder.txt" "$OUTPUT_DIR/assetfinder.txt" | sort -u > "$OUTPUT_DIR/all_subs.txt"

# DNS resolution
echo "[*] Resolving subdomains..."
cat "$OUTPUT_DIR/all_subs.txt" | dnsx -silent -a -resp | tee "$OUTPUT_DIR/resolved.txt"

# HTTP probing
echo "[*] HTTP probing..."
cat "$OUTPUT_DIR/all_subs.txt" | httpx -silent -status-code -title -follow-redirects \
  | tee "$OUTPUT_DIR/httpx.txt"

# URL collection
echo "[*] Collecting URLs..."
gau "$TARGET" --subs --threads 10 | tee "$OUTPUT_DIR/gau_urls.txt"
waybackurls "$TARGET" | tee "$OUTPUT_DIR/wayback_urls.txt"
cat "$OUTPUT_DIR/gau_urls.txt" "$OUTPUT_DIR/wayback_urls.txt" | sort -u > "$OUTPUT_DIR/all_urls.txt"

# JS endpoint extraction
echo "[*] Extracting JS endpoints..."
cat "$OUTPUT_DIR/all_urls.txt" | grep '\.js$' | sort -u | while read url; do
    linkfinder -i "$url" -o cli 2>/dev/null
done | tee "$OUTPUT_DIR/js_endpoints.txt"

# Nuclei scanning
echo "[*] Running nuclei..."
cat "$OUTPUT_DIR/httpx.txt" | awk '{print $1}' | \
  nuclei -t ~/nuclei-templates/ -o "$OUTPUT_DIR/nuclei_results.txt" -severity medium,high,critical

echo "[+] Recon complete! Results in $OUTPUT_DIR/"
```

### Continuous Monitoring
```bash
# Monitor for new subdomains (run daily via cron)
NEW_SUBS=$(subfinder -d target.com -all -silent | anew already_seen_subs.txt)
if [ -n "$NEW_SUBS" ]; then
    echo "$NEW_SUBS" | notify -bulk  # Send to Slack/Discord
fi
```

---

## 13. WSTG Information Gathering Checklist

| ID | Test | Key Actions |
|---|---|---|
| WSTG-INFO-01 | Search Engine Discovery | Google/Bing/Shodan dorks, cached pages, sensitive file exposure |
| WSTG-INFO-02 | Fingerprint Web Server | Banner grabbing, response headers (`Server:`, `X-Powered-By:`), error pages |
| WSTG-INFO-03 | Review Webserver Metafiles | robots.txt, sitemap.xml, humans.txt, .well-known/ |
| WSTG-INFO-04 | Enumerate Applications | All ports, VHosts, non-default applications on same IP |
| WSTG-INFO-05 | Review Webpage Content | HTML comments, hidden fields, metadata in files, page source review |
| WSTG-INFO-06 | Identify Application Entry Points | All params (URL, body, headers, cookies), file uploads, WebSockets |
| WSTG-INFO-07 | Map Execution Paths | Spidering, flow mapping for all user roles (SPAs — use JS analysis) |
| WSTG-INFO-08 | Fingerprint Web Application Framework | Cookies (PHPSESSID→PHP, JSESSIONID→Java), URL structure, error pages |
| WSTG-INFO-09 | Fingerprint Web Application | Wappalyzer, WhatWeb, BuiltWith, version identification (for CVEs) |
| WSTG-INFO-10 | Map Application Architecture | Load balancers, WAFs, CDNs (Akamai/CloudFlare/Fastly), reverse proxies |
