# Subdomain Takeover
> Sources: WSTG v4.2, Real-World Bug Hunting (Yaworski), Bug Bounty Bootcamp (Li)

## How Subdomain Takeover Works

1. `sub.victim.com` has a CNAME record pointing to `victim.github.io` (or another external service)
2. The GitHub Pages site (or other service) was deleted or never configured
3. Attacker claims `victim.github.io` on their own account
4. Attacker now controls all content served at `sub.victim.com`

The attacker's page runs in the victim's subdomain origin — same as a full XSS on that subdomain.
If the parent domain uses `domain=.victim.com` cookies, the attacker can steal them.

## Detection

```bash
# Step 1: Collect all subdomains
subfinder -d target.com -all -o all_subs.txt
amass enum -passive -d target.com >> all_subs.txt
sort -u all_subs.txt -o all_subs.txt

# Step 2: Find CNAMEs pointing to external services
cat all_subs.txt | dnsx -silent -cname -resp | tee cname_records.txt

# Step 3: Check each CNAME target for vulnerability
# Manually: curl -H "Host: sub.victim.com" https://cname-target.com
# Look for service-specific "not found" fingerprints

# Automated scanning
subjack -w all_subs.txt -t 100 -timeout 30 -ssl -c ~/fingerprints.json -o takeover_candidates.txt
nuclei -l all_subs.txt -t takeovers/ -o nuclei_takeovers.txt
# Reference: https://github.com/EdOverflow/can-i-take-over-xyz
```

## Vulnerable Services & Fingerprints

| Service | CNAME Pattern | Fingerprint |
|---|---|---|
| GitHub Pages | `*.github.io` | "There isn't a GitHub Pages site here" |
| AWS S3 | `*.s3-website-*.amazonaws.com` | "NoSuchBucket" |
| AWS CloudFront | `*.cloudfront.net` | "Bad Request" / "ERROR: The request could not be satisfied" |
| Heroku | `*.herokudns.com` | "No such app" |
| Zendesk | `*.zendesk.com` | "Help Center Closed" |
| Fastly | `*.fastly.net` | "Fastly error: unknown domain" |
| Surge.sh | `*.surge.sh` | "project not found" |
| SendGrid | `*.sendgrid.net` | "The domain you are attempting to view is either not configured..." |
| HubSpot | `*.hs-sites.com` | "Domain not found" |
| Shopify | `*.myshopify.com` | "Sorry, this shop is currently unavailable" |
| Ghost | `*.ghost.io` | "The thing you were looking for is no longer here" |
| Cargo Collective | `*.cargocollective.com` | "404 Not Found" |
| WordPress | `*.wordpress.com` | "Do you want to register *.wordpress.com?" |
| Pantheon | `*.pantheonsite.io` | "404 error unknown site!" |
| Tumblr | `*.tumblr.com` | "Whatever you were looking for doesn't currently exist at this address" |
| Squarespace | `*.squarespace.com` | "No Such Account" |
| Azure Web Apps | `*.azurewebsites.net` | "404 Web Site not found" |
| BitBucket Pages | `*.bitbucket.io` | "Repository not found" |
| Unbounce | `*.unbounce.com` | "The requested URL /page was not found" |
| Freshdesk | `*.freshdesk.com` | "May be this is still fresh!" |
| Agile CRM | `*.agilecrm.com` | "Sorry, this page is no longer available" |

## Exploitation

```bash
# GitHub Pages example:
# 1. Create GitHub account (or use existing)
# 2. Create repo named to match CNAME target: e.g., "victim" for victim.github.io
# 3. Enable GitHub Pages for this repo (Settings → Pages → Deploy from branch)
# 4. Create index.html with your PoC
# 5. sub.victim.com now serves your content

# AWS S3 example:
# 1. Create S3 bucket with EXACT matching name (must match the CNAME target)
# 2. Enable static website hosting
# 3. Set bucket policy to public read
# 4. Upload index.html with your PoC
aws s3 mb s3://exact-bucket-name-from-cname
aws s3 website s3://exact-bucket-name-from-cname --index-document index.html
echo '<h1>Subdomain Takeover PoC</h1>' > index.html
aws s3 cp index.html s3://exact-bucket-name-from-cname

# Heroku example:
# 1. Create a Heroku app
# 2. heroku domains:add sub.victim.com
# 3. Deploy a simple app as PoC
```

## Assessing Impact

- **Standard**: Attacker controls content served at `sub.victim.com`
- **Phishing**: Create fake login page matching parent domain's style
- **XSS escalation**: If `sub.victim.com` XSS, JavaScript runs in that origin
- **Cookie theft**: If parent sets `Set-Cookie: session=x; Domain=.victim.com`, the subdomain can read that cookie
- **OAuth redirect_uri**: If OAuth allows any `*.victim.com` redirect, attacker's subdomain receives auth codes
- **CORS origin trust**: If `api.victim.com` trusts any `*.victim.com` origin in CORS policy

## Subdomain Takeover for OAuth Token Theft

```
Step 1: Find subdomain takeover on sub.victim.com
Step 2: Check if OAuth server allows redirect_uri matching *.victim.com
Step 3: Craft OAuth authorization URL:
  /oauth/authorize?client_id=app&redirect_uri=https://sub.victim.com/callback&...
Step 4: Victim clicks link → auth code delivered to attacker's subdomain
Step 5: Exchange auth code for access token → full account takeover
```

## Real-World Examples

- **Ubiquiti** ($1,000): `status.ubnt.com` → unclaimed S3 bucket → attacker hosted fake content
- **Zendesk** ($100+): Multiple companies had Zendesk CNAME pointing to unclaimed instances
- **Shopify Windsor** ($500): Shopify CDN subdomain not configured — takeover possible
- **Snapchat** (Fastly): Subdomain pointing to Fastly CDN origin not configured
- **Legal Robot** (Heroku): CNAME to Heroku → "No such app" → takeover demonstrated
- **Uber SendGrid**: Email subdomain pointing to unclaimed SendGrid instance

## Monitoring for New Subdomain Takeover Opportunities

```bash
# Run daily via cron — monitor for new CNAME targets that become vulnerable
#!/bin/bash
NEW_SUBS=$(subfinder -d target.com -all -silent | anew already_seen_subs.txt)
if [ -n "$NEW_SUBS" ]; then
  echo "$NEW_SUBS" | subjack -t 50 -ssl -c fingerprints.json | notify -bulk
fi
```

## WSTG-CONF-10: Checklist
- [ ] Enumerate all subdomains (passive + active)
- [ ] Find all CNAME records
- [ ] Check each CNAME target against fingerprint database
- [ ] Test NS record delegation for orphaned zones
- [ ] Test A records pointing to cloud IPs that may have been released
- [ ] Document takeover-vulnerable subdomains with evidence
- [ ] Assess impact (XSS, phishing, cookie theft, OAuth)
- [ ] Claim the subdomain for PoC (don't leave it open for others)
