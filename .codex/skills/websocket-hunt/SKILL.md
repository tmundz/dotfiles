---
name: websocket-hunt
description: >
  Full-lifecycle WebSocket security testing and exploitation for bug bounty hunters, penetration testers,
  and security researchers. Covers handshake hijacking, in-protocol fuzzing, sub-protocol abuse, and
  weaponized PoC generation. Use for WebSocket testing, CSWSH, WebSocket fuzzing, race conditions,
  Socket.IO hacking, STOMP exploitation, WebSocket CSRF/IDOR/injection, cross-site WebSocket hijacking,
  real-time app hacking, permessage-deflate attacks, WebSocket DoS, authorization bypass, WAMP audit,
  testing chat apps, trading platforms, live feeds, or any bidirectional connection security assessment.
---

# WebSocket Exploitation — Operational Playbook

You are acting as a Senior Security Researcher specialized in full-duplex protocol security.
Every test must be grounded in the RFC 6455 protocol model and real-world vulnerability patterns.
Work through phases in order, but skip phases that don't apply to the target topology.

---

## Phase 0 — Recon & Fingerprinting

Before touching the handshake, map the attack surface.

**Fingerprint the connection:**
```bash
# Capture upgrade request in Burp / Caido proxy first
wscat -c wss://target.com/ws --no-check   # raw connect
```

Check for:
- `Upgrade: websocket` + `Connection: Upgrade` in request
- `101 Switching Protocols` in response
- `Sec-WebSocket-Key` / `Sec-WebSocket-Accept` pair
- `Sec-WebSocket-Protocol` (sub-protocol declared)
- `Sec-WebSocket-Extensions` (compression negotiated)
- EIO query param → Socket.IO detected (EIO=4 = v4)
- STOMP CONNECT frame → Spring/ActiveMQ stack
- WAMP `Hello` message → WAMP router

**Tool stack to assemble:**
- Burp Suite Pro → WebSocket history tab (Proxy → WebSockets)
- WebSocket Turbo Intruder (BApp Store) → high-speed fuzzing
- wscat → CLI manual interaction
- Python `websockets` / `python-socketio` → custom exploits
- Caido → WebSocket replay/intercept alternative

---

## Phase 1 — Handshake Attack Surface

Read `references/handshake-attacks.md` for full detail on all vectors below.

### 1A — Cross-Site WebSocket Hijacking (CSWSH)

The WebSocket handshake is a plain HTTP upgrade — SOP does NOT protect it.
Browsers send cookies automatically. If the server trusts Origin-less or attacker-controlled origins, the connection is hijackable.

**Test sequence:**
1. Capture a legitimate upgrade request in Burp
2. Forward to Repeater. Remove the `Origin` header → check if server accepts
3. Change `Origin: https://attacker.com` → check if server accepts (403 or 101?)
4. Try: `Origin: null` (sandbox iframe bypass)
5. Try regex bypass: `Origin: https://victim.com.attacker.com`
6. Try: `Origin: https://victimcom.attacker.com`
7. Try: `Origin: https://attacker.comvictim.com` (suffix match bypass)
8. Try: `Origin: https://victim.com%60.attacker.com` (URL encoding tricks)

If any of the above returns `101`, CSWSH is confirmed. Build the PoC.

**Cookie-based auth check:**
- If auth is cookie-only (no CSRF token in WS handshake), CSWSH is exploitable with victim's active session
- Generate exploit page (see `references/poc-scripts.md` → CSWSH section)

### 1B — Protocol Smuggling / HTTP Tunneling

WebSocket upgrade can be used to bypass proxy/WAF rules or smuggle HTTP to internal services.

1. Test `Upgrade: websocket` + normal HTTP headers → does proxy strip security controls?
2. Test HTTP/1.1 upgrade to reach internal endpoints not exposed on HTTP routes
3. Probe: can you use the WS connection to reach services bound to localhost?
4. Check if WAF inspects WS frames (most don't — only the upgrade request)

### 1C — Header Injection

```
Sec-WebSocket-Protocol: chat, stomp\r\nInjected-Header: value
Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits\r\nEvil: header
```

Test for header injection in sub-protocol negotiation.
Also test forcing old protocol versions (Hixie-76, hybi-00) if server advertises backward compat.

---

## Phase 2 — In-Protocol Vulnerability Testing

Read `references/in-protocol-attacks.md` for payloads and scripts.

### 2A — Injection via Message Content

WebSocket messages bypass WAF inspection (WAF sees only the upgrade request).
Test every message field for:

| Injection Type | Payload Example |
|---|---|
| SQL injection | `{"id":"1 OR 1=1--"}` |
| XSS | `{"msg":"<img src=x onerror=alert(1)>"}` |
| SSTI | `{"name":"{{7*7}}"}` or `#{7*7}` |
| Command injection | `{"file":"../etc/passwd"}` or `;id;` |
| XXE | Binary/text frames with XML doctype |
| Prototype pollution | `{"__proto__":{"admin":true}}` |
| JSON deserialization | Crafted serialized objects |

Use WebSocket Turbo Intruder HTTP Middleware to pipe WS through Burp Scanner for automated payload injection.

### 2B — Authorization & State Confusion

The handshake establishes identity once. After that, no re-auth per message.

**Test vectors:**
1. Connect as user A, send messages that reference user B's resources (IDOR)
2. Remove/alter the session cookie after connection is established → does server re-validate?
3. Subscribe to channels/rooms meant for other users
4. Escalate: send admin-only actions as a low-privilege user
5. Test if session expiry closes the WS connection (it often doesn't — stale sessions live forever)
6. Logout → verify server closes the WS connection immediately

### 2C — Race Conditions

WebSocket enables concurrent state attacks that are harder via HTTP.
Read `references/in-protocol-attacks.md` → Race Conditions section.

Use WebSocket Turbo Intruder THREADED engine: each thread = its own connection.
Targets: coupon redemption, one-time token use, balance operations, rate limit bypasses.

### 2D — DoS Vectors

**Zlib bomb (permessage-deflate):**
If `Sec-WebSocket-Extensions: permessage-deflate` is negotiated, server must decompress frames.
Craft a highly compressed frame that decompresses to gigabytes.
Read `references/in-protocol-attacks.md` → Zlib Bomb section for the generator script.

**Ping of Death (malformed frame):**
Craft a WebSocket frame with `payload_length = 2147483647` (Integer.MAX_VALUE) in the header
but send zero bytes of actual payload. Java WS implementations allocate the full buffer → OOM crash.
PortSwigger Research documented this as a confirmed DoS pattern (2025).

**Connection exhaustion:**
Open thousands of connections, hold them open with periodic pings, exhaust thread pool or file descriptor limit.

---

## Phase 3 — Sub-Protocol Analysis

Read `references/sub-protocols.md` for protocol-specific test cases.

### 3A — Socket.IO (EIO=4)

Detection: upgrade URL has `?EIO=4` or `?EIO=3`.
Must send `"40"` handshake frame after connect before real messages flow.

**Prototype pollution:**
```json
{"__proto__": {"initialPacket": "Polluted"}}
{"__proto__": {"admin": true}}
{"constructor": {"prototype": {"role": "admin"}}}
```
Server-side prototype pollution confirmed if behavior changes (new greeting, role escalation, error message changes).
Refer to PortSwigger Research (Zakhar Fedotkin, 2025) + Gareth Heyes black-box detection technique.

**Socket.IO auth bypass:**
- Test without `auth` token in connect message
- Replay tokens across sessions
- Namespace enumeration: try `/admin`, `/internal`, `/debug`

### 3B — STOMP (Spring / ActiveMQ / RabbitMQ)

CVE-2018-1270 pattern: Spring Framework STOMP over WebSocket with SpEL injection.
```
SUBSCRIBE
destination:/topic/greetings
selector:T(java.lang.Runtime).getRuntime().exec('id')

^@
```
Also test: unauthenticated subscription to restricted topics, message routing bypass, unsubscribe forgery.

### 3C — WAMP (Web Application Messaging Protocol)

- Enumerate realm names (often leaked in HELLO message)
- Test unauthenticated topic subscription
- Cross-realm message injection
- Registration of procedures that shadow legitimate ones

---

## Phase 4 — Interception & Tooling

Read `references/tooling-and-interception.md` for setup instructions.

**Quick reference:**

| Tool | Use |
|---|---|
| Burp Suite Pro | WS history, Repeater, manual frame modification |
| WebSocket Turbo Intruder | High-speed fuzzing, THREADED race conditions, HTTP Middleware |
| wscat | CLI rapid manual testing |
| Caido | WS replay, alternative proxy |
| Python `websockets` | Custom listeners, replay harnesses |
| `websocat` | Unix-style WS client, piping |

**Routing through Burp (Python):**
```python
import asyncio, websockets

async def proxy():
    async with websockets.connect(
        "wss://target.com/ws",
        additional_headers={"Cookie": "session=VICTIM_TOKEN"}
    ) as ws:
        async for msg in ws:
            print(f"<-- {msg}")
            # Modify and replay
            await ws.send(msg)

asyncio.run(proxy())
```

---

## Phase 5 — PoC & Exploit Engineering

Read `references/poc-scripts.md` for complete, runnable Python scripts for each attack class.

**Available PoC templates:**
1. `cswsh_poc.html` — Browser-side CSWSH exploit page
2. `cswsh_listener.py` — Python exfil listener for CSWSH data
3. `async_fuzzer.py` — Async binary/text frame fuzzer with payload lists
4. `race_condition.py` — Concurrent connection race tester
5. `zlib_bomb.py` — permessage-deflate decompression bomb generator
6. `ping_of_death.py` — Malformed frame OOM DoS
7. `socketio_polluter.py` — Socket.IO prototype pollution tester
8. `stomp_exploit.py` — STOMP SpEL injection PoC
9. `message_replay.py` — Frame capture and replay with mutation

---

## Phase 6 — Reporting

For each confirmed finding, document:
- **Handshake request/response** (full headers)
- **Reproduction steps** (wscat or Python PoC command)
- **Impact** (CSWSH → account takeover / data exfil; race → financial loss; injection → SQLi/RCE)
- **Evidence** (server response showing exploitation)
- **Remediation** (Origin allowlist, per-message authz, rate limiting, connection limits)

---

## Quick Reference — What File to Read

| Need | File |
|---|---|
| CSWSH deep dive, Origin bypass tricks | `references/handshake-attacks.md` |
| Fuzzing payloads, race condition scripts | `references/in-protocol-attacks.md` |
| Socket.IO, STOMP, WAMP test cases | `references/sub-protocols.md` |
| Burp/Caido setup, Python proxy patterns | `references/tooling-and-interception.md` |
| Complete runnable exploit scripts | `references/poc-scripts.md` |
