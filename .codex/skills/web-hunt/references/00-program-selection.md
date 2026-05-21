# Bug Bounty Program Selection & Setup

## Platform Comparison

| Platform | Best For | Notes |
|---|---|---|
| HackerOne | Large programs, public/private | Most programs, good triage |
| Bugcrowd | Managed programs | Strong for beginners |
| Intigriti | European programs | Less competition |
| Synack | Vetted researchers only | Higher payouts, harder to join |
| Cobalt | PTaaS model | Pentest-style engagements |
| Open Bug Bounty | Responsible disclosure | Free, no registration required |

## Choosing Your First Program (BBB Ch.1)

### Beginner Selection Criteria
1. **Has a "safe harbor" clause** — protects you from legal action
2. **Wide scope** — more endpoints = more bugs
3. **Clear scope definition** — know exactly what's in/out
4. **Active payout history** — check disclosed reports on HackerOne
5. **Responsive triage team** — look for avg time to first response < 2 days
6. **Low competition** — new programs or less-popular targets

### Red Flags to Avoid
- "No monetary reward" for critical bugs
- Vague scope ("all our assets")
- Programs with many "informational" or "not applicable" responses
- Programs that resolve issues as "won't fix" repeatedly

## Scope Management

### What's Typically In Scope
- Main domain and subdomains explicitly listed
- Mobile apps listed
- APIs listed
- Third-party services listed

### What's Typically Out of Scope
- Third-party services not listed
- Social engineering
- Physical attacks
- DoS/DDoS attacks
- Spam
- Issues requiring physical access
- Issues in software you don't own

### Safe Harbor Best Practices
- Always read the program policy before testing
- Never test production systems destructively
- Don't access data beyond what's needed to prove the bug
- Report immediately when you find sensitive data
- Don't download large amounts of data to prove access

## Recon for Program Selection

```bash
# Find all programs on HackerOne
curl https://hackerone.com/programs.json | jq '.data[].attributes | {name, url, offers_bounties}'

# Check program stats
curl https://api.hackerone.com/v1/programs/PROGRAM_HANDLE -u "username:token"
```

## Reading Disclosed Reports

HackerOne disclosed reports are gold mines:
- Go to hackerone.com/hacktivity
- Filter by program
- Sort by most recent or highest bounty
- Learn what types of bugs that program pays for
- Understand their triage mindset

## Building Your Methodology

### Focus Areas by Experience Level
**Beginner**: IDORs, open redirects, reflected XSS, info disclosure
**Intermediate**: Stored XSS, CSRF, SSRF, SQLi, logic errors
**Advanced**: Deserialization, RCE, auth bypass, complex chains

### Time Management
- 20% recon
- 60% active testing
- 20% documentation/reporting

## VDP vs Bug Bounty

| Type | Reward | Purpose |
|---|---|---|
| VDP (Vulnerability Disclosure Program) | Recognition only | Legal safe harbor for reporting |
| Bug Bounty | Cash payout | Financial incentive to find bugs |

Start with VDP programs to build portfolio; move to paid programs once you have experience.
