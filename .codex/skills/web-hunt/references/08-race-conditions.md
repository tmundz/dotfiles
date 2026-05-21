# Race Conditions
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
A Time-of-Check to Time-of-Use (TOCTOU) vulnerability where the state of a resource changes between when it's checked and when it's used. Multiple concurrent requests exploit a window where checks haven't completed yet.

## Classic Scenarios

### Coupon/Discount Reuse
```
Normal flow: Apply coupon → check if used → mark as used → apply discount
Attack: Send 5 concurrent requests to apply same coupon
→ All 5 may pass the "is used?" check before any marks it as used
→ Coupon applied 5 times instead of once
```

### Account Balance Exploitation
```
Normal: Check balance ≥ amount → deduct → send
Attack: Concurrent withdrawals for balance check window
```

### Two-Factor Authentication Bypass
```
Normal: Submit OTP → server checks if valid → mark as used → proceed
Attack: Send same OTP rapidly in parallel before it's marked used
```

### File Upload Race
```
Normal: Upload → check for malware → delete if malicious → save if safe
Attack: Upload malicious file; race to access file URL before deletion
```

### Password Reset Token Reuse
```
Normal: Token used once → marked invalid → redirect to reset
Attack: Send same token twice simultaneously before marked invalid
```

---

## Where to Look for Race Conditions

1. **Purchase/checkout flows** — apply coupon, redeem gift card, complete order
2. **Points/rewards** — redeem points, use credits
3. **Voting/rating** — vote only once per user
4. **Password reset** — OTP/token single-use
5. **Registration** — username uniqueness check
6. **File operations** — upload + immediate access
7. **Invite system** — use same invite link twice for two accounts
8. **Subscription/trial limitations**

### Indicators of Vulnerability
- "You've already done X" error messages (suggests check before mark)
- Actions that should be idempotent but aren't
- Any "limit one per user" feature
- Any "first come first served" timing-dependent feature

---

## Tools and Techniques

### cURL Parallel Requests (Quick Test)
```bash
for i in {1..10}; do
  curl -s "https://target.com/apply-coupon" \
    -H "Cookie: session=YOUR_SESSION" \
    -d "coupon=DISCOUNT50" &
done
wait
```

### Python Concurrent Requests
```python
import concurrent.futures
import requests

session_cookie = "your_session_cookie"
target_url = "https://target.com/api/use-coupon"
num_requests = 10

def send_request(i):
    resp = requests.post(
        target_url,
        cookies={"session": session_cookie},
        data={"coupon_code": "ONCE123"}
    )
    return resp.status_code, resp.text[:200]

with concurrent.futures.ThreadPoolExecutor(max_workers=num_requests) as executor:
    futures = [executor.submit(send_request, i) for i in range(num_requests)]
    for f in concurrent.futures.as_completed(futures):
        print(f.result())
```

### Burp Suite Intruder (Null Payload)
1. Capture request in Burp
2. Send to Intruder
3. No payload positions needed (null payload)
4. Set 20 requests, null payload type
5. **Resource pool**: Create new pool with maximum concurrent requests = 20
6. Start attack

### Turbo Intruder (Burp Extension) — Best for Race Conditions
```python
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint,
                          concurrentConnections=20,
                          requestsPerConnection=1,
                          pipeline=False)
    
    for i in range(20):
        engine.queue(target.req, gate='race')
    
    engine.openGate('race')
    engine.complete(timeout=60)

def handleResponse(req, interesting):
    table.add(req)
```

### Single-Packet Attack (HTTP/2) — Most Reliable
HTTP/2 allows multiple requests in one TCP packet, eliminating network jitter:
1. Send requests to Burp Repeater
2. Group them (Ctrl+G → "Add to group")
3. Select **"Send group in parallel (last-byte sync)"**
4. All requests arrive at server simultaneously

---

## Reporting Race Conditions

Required for a good report:
1. **What the attack is**: describe TOCTOU clearly
2. **How to reproduce**: exact concurrent request script
3. **Proof**: screenshot showing multiple successful uses of a limited-use feature
4. **Impact**: quantify (e.g., "could discount unlimited purchases by sending 20 concurrent requests")

---

## Real-World Examples (Yaworski)
- **HackerOne** ($3,500): Race condition in team invitation — could add unlimited members
- **Keybase**: Race on invitation limits — use invite link more times than allowed
- **HackerOne payments**: Double-payout race condition in bounty payment system
- **Shopify Partners** ($1,500): Race condition allowed reading partner app data

## Severity
- **Low**: Minor logic bypass (vote twice)
- **Medium**: Free discount/coupon reuse
- **High**: Unlimited funds, payment bypass, privilege escalation
- **Critical**: Complete auth bypass, mass exploitation possible
