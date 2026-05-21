# Code Review for Security

## Approach (BBB Ch.21)

### Two Strategies

**1. Dangerous Function First (grep-driven)**
- Find calls to dangerous functions
- Trace input from user-controlled sources
- Quick and scalable

**2. Feature-First (trace-driven)**
- Pick a high-value feature (authentication, payment)
- Trace all code paths
- Thorough but time-consuming

## Dangerous Functions by Language

### PHP
| Function | Vulnerability | Notes |
|---|---|---|
| `eval()` | Code injection | Immediate RCE if user-controlled |
| `assert()` | Code injection | String argument evaluated as PHP |
| `system()` | Command injection | |
| `exec()` | Command injection | |
| `shell_exec()` | Command injection | |
| `passthru()` | Command injection | |
| `popen()` | Command injection | |
| `proc_open()` | Command injection | |
| `` `...` `` | Command injection | Backtick operator |
| `include()` | LFI/RFI | User-controlled path |
| `require()` | LFI/RFI | User-controlled path |
| `include_once()` | LFI/RFI | |
| `require_once()` | LFI/RFI | |
| `unserialize()` | Deserialization | PHP object injection |
| `file_get_contents()` | SSRF/LFI | User-controlled URL |
| `fopen()` | SSRF/LFI | User-controlled path |
| `file_put_contents()` | Arbitrary write | |
| `mysqli_query()` | SQLi | String concatenation |
| `mysql_query()` | SQLi | Deprecated, often unparameterized |
| `header()` | Header injection | `\r\n` in value |
| `mail()` | Header injection | 5th arg to inject headers |
| `htmlspecialchars()` | Check if ENT_QUOTES used | Default misses quotes |
| `preg_replace()` with `/e` | Code injection | `/e` modifier evaluates replacement as PHP |

```bash
# PHP grep patterns
grep -r "eval\s*(" .
grep -r "system\s*(" .
grep -r "exec\s*(" .
grep -r "shell_exec\s*(" .
grep -r "unserialize\s*(" .
grep -r 'include\s*\($[' .  # User variable in include
grep -r "mysql_query\|mysqli_query" . | grep "\$"
grep -r "file_get_contents\s*(\$" .
grep -r "preg_replace.*\/e[^'\"]*\$" .
```

### Python
| Function | Vulnerability | Notes |
|---|---|---|
| `eval()` | Code injection | |
| `exec()` | Code injection | |
| `compile()` | Code injection | |
| `os.system()` | Command injection | |
| `subprocess.call(shell=True)` | Command injection | Only when shell=True |
| `subprocess.run(shell=True)` | Command injection | |
| `pickle.loads()` | Deserialization | |
| `yaml.load()` | Deserialization | Use yaml.safe_load() |
| `marshal.loads()` | Deserialization | |
| `__import__()` | Arbitrary import | |
| `open()` | File read/write | User-controlled path |
| `urllib.request.urlopen()` | SSRF | |
| `requests.get(url)` | SSRF | User-controlled URL |
| `Jinja2 Template(user_input)` | SSTI | |

```bash
# Python grep patterns
grep -r "eval(" .
grep -r "exec(" .
grep -r "os.system(" .
grep -r "shell=True" .
grep -r "pickle.load" .
grep -r "yaml.load(" .
grep -r "subprocess.call" . | grep "shell=True"
grep -r "Template(" . | grep "request\|user\|input"
```

### JavaScript/Node.js
| Function | Vulnerability | Notes |
|---|---|---|
| `eval()` | Code injection | |
| `Function()` | Code injection | New Function("code") |
| `setTimeout(string)` | Code injection | String form evaluated |
| `setInterval(string)` | Code injection | |
| `child_process.exec()` | Command injection | |
| `child_process.execSync()` | Command injection | |
| `child_process.spawn()` | Command injection | Shell: true |
| `JSON.parse()` | Safe (not inherently dangerous but prototype pollution possible) |
| `innerHTML =` | XSS | |
| `document.write()` | XSS | |
| `dangerouslySetInnerHTML` | XSS | React |
| `serialize()` (node-serialize) | Deserialization | |
| `deserialize()` (node-serialize) | Deserialization | |

```bash
# Node.js grep patterns
grep -r "eval(" .
grep -r "new Function(" .
grep -r "child_process.exec(" .
grep -r "innerHTML\s*=" .
grep -r "document.write(" .
grep -r "dangerouslySetInnerHTML" .
grep -r "serialize.unserialize(" .
```

### Ruby
| Function | Vulnerability | Notes |
|---|---|---|
| `eval()` | Code injection | |
| `instance_eval()` | Code injection | |
| `class_eval()` | Code injection | |
| `` `cmd` `` | Command injection | Backtick operator |
| `system()` | Command injection | |
| `exec()` | Command injection | |
| `Open3.popen*` | Command injection | |
| `Marshal.load()` | Deserialization | |
| `YAML.load()` | Deserialization | Use YAML.safe_load |
| `send()` with user input | Method injection | |

```bash
# Ruby grep patterns
grep -r "eval(" .
grep -r "Marshal.load(" .
grep -r "YAML.load(" . | grep -v "safe_load"
grep -r "\.send(" . | grep "params\|user_input"
grep -r "system(" . | grep "params\|@"
```

### Java
| Pattern | Vulnerability |
|---|---|
| `Runtime.exec()` | Command injection |
| `ProcessBuilder` | Command injection |
| `ObjectInputStream.readObject()` | Deserialization |
| `XMLDecoder.readObject()` | Deserialization/XXE |
| `Statement.execute()` (JDBC) | SQLi |
| `PreparedStatement` with concat | SQLi |
| `DocumentBuilderFactory` (no disableExternalEntities) | XXE |
| `SAXParserFactory` (no secure) | XXE |
| `ScriptEngine.eval()` | Code injection |
| `JNDI lookup` | Log4Shell/SSRF |

```bash
# Java grep patterns
grep -r "Runtime.exec\|ProcessBuilder" . --include="*.java"
grep -r "ObjectInputStream" . --include="*.java"
grep -r "XMLDecoder" . --include="*.java"
grep -r "ScriptEngine" . --include="*.java"
grep -r "execute\|executeQuery\|executeUpdate" . --include="*.java" | grep '"+\|request\.'
```

## Input/Output Tracking Methodology

### Step 1: Identify Sources (User-Controlled Input)
```
HTTP Parameters: $_GET, $_POST, $_REQUEST, request.args, request.form, req.query, req.body
HTTP Headers: $_SERVER['HTTP_USER_AGENT'], request.headers
Cookies: $_COOKIE, request.cookies
Files: $_FILES
URL path: Flask @app.route('<var>'), Express req.params
Environment: $_ENV, process.env (if from external config)
```

### Step 2: Find Where Input Flows (Data Flow)
```bash
# After identifying source variable (e.g., $username):
# Search for where it's used
grep -r "\$username" .

# Trace through functions
grep -r "function.*\$username" .
```

### Step 3: Check if Input Reaches Dangerous Sink
```
Source: $id = $_GET['id']
Flow:   $id → $query = "SELECT * FROM users WHERE id=$id"
Sink:   mysql_query($query)  ← SQL Injection!
```

## Cryptographic Review

### Weak Algorithms to Flag
```
MD5 for passwords → bcrypt, scrypt, or Argon2 required
SHA1 for passwords → too fast, brute-forceable
DES/3DES → use AES-256
ECB mode → use GCM or CBC with random IV
Predictable IVs → IVs must be cryptographically random
Random seed from time → use CSPRNG
```

```bash
# Grep for weak crypto
grep -r "md5\|sha1\|des\|3des\|rc4" . -i | grep -v "comment\|#"
grep -r "random()\|rand()\|srand(" . | grep "session\|token\|password"
grep -r "ECB\|MODE_ECB" .
```

## Authentication Review

```bash
# Check password hashing
grep -r "password_hash\|bcrypt\|scrypt\|argon2\|pbkdf2" .
grep -r "md5.*password\|sha1.*password" . -i  # Bad!

# Check session management
grep -r "session_id\|sessionid" .
grep -r "token\|csrf" .

# Check password comparison
grep -r "strcmp.*password\|===.*password" .
# Should use: password_verify() in PHP, bcrypt.compare() in Node
```

## Authorization Review

```bash
# Find places where access decisions are made
grep -r "is_admin\|isAdmin\|role\|permission\|authorize" .

# Find places where user input determines object access
grep -r "WHERE id=\$\|WHERE id=" .
grep -r "find.*params\[:id\]\|findById.*req.params" .

# Check if every sensitive route has auth middleware
grep -r "app.get\|app.post\|router.get\|router.post" . | head -50
# Compare with middleware usage
```

## Third-Party Libraries

```bash
# Check for vulnerable dependencies
npm audit
pip-audit
bundle audit
mvn dependency-check:check
safety check
```

## Testing Checklist
- [ ] Run grep patterns for all dangerous functions
- [ ] Trace user input from sources to sinks
- [ ] Check SQL queries for string concatenation
- [ ] Check file operations for path traversal
- [ ] Check command execution for injection
- [ ] Check deserialization of untrusted data
- [ ] Check cryptographic implementations
- [ ] Check authentication and authorization logic
- [ ] Review third-party dependencies for known CVEs
