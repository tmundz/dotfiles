# Android App Hacking & Cryptographic Testing
> Sources: WSTG v4.2, Real-World Bug Hunting (Yaworski), Bug Bounty Bootcamp (Li)

## Table of Contents
1. [Android App Hacking](#1-android-app-hacking)
2. [Cryptographic Testing](#2-cryptographic-testing)

---

## 1. Android App Hacking

### Setup & Required Tools
```bash
adb           # Android Debug Bridge
apktool       # Decompile APK to Smali
jadx          # Decompile APK to Java (more readable)
frida         # Dynamic instrumentation framework
objection     # Frida-based runtime exploration tool
MobSF         # Automated mobile security analysis
Burp Suite    # Intercept HTTPS traffic from device

# Basic workflow
adb devices                          # Verify device connected
adb install target.apk               # Install APK
adb shell                            # Shell on device
```

### Static Analysis

```bash
# Decompile APK
apktool d target.apk -o decompiled/

# Convert to Java source (more readable)
jadx -d output/ target.apk

# Search for secrets in Smali
grep -r "api_key\|apikey\|secret\|password\|token\|bearer\|aws" decompiled/ --include="*.smali"
grep -r "http\|https\|api\." decompiled/ | grep -v "android\|google\|schema"

# Check AndroidManifest.xml for security issues
cat decompiled/AndroidManifest.xml | grep -E "exported|debuggable|backup|scheme"

# Key flags to look for:
# exported=true → activity accessible from external apps without auth
# debuggable=true → attach debugger to running app
# allowBackup=true → extract app data via adb backup
# Custom URL schemes (deep links) → test for parameter injection
```

### Certificate Pinning Bypass

Certificate pinning prevents Burp Suite from intercepting HTTPS traffic. Bypass methods:

```bash
# Method 1: Frida script (recommended — works on non-rooted device sometimes)
frida -U -l bypass-cert-pinning.js -f com.target.app --no-pause
# Script from: https://github.com/httptoolkit/frida-android-unpinning

# Method 2: Objection (wraps Frida)
objection -g com.target.app explore
android sslpinning disable

# Method 3: Patch APK (no root required)
# 1. Decompile with apktool
# 2. Add network_security_config.xml that trusts user CAs
# 3. Recompile and sign
# 4. Install patched APK
```

### Dynamic Analysis with Frida

```javascript
// Hook a method to bypass authentication
Java.perform(function() {
  var TargetClass = Java.use("com.target.app.AuthClass");
  TargetClass.checkPin.implementation = function(pin) {
    console.log("[*] checkPin called with: " + pin);
    return true;  // Always return true (bypass)
  };
});

// List all loaded classes (find class names to hook)
Java.enumerateLoadedClasses({
    onMatch: function(name, handle) {
        if (name.includes("target")) console.log(name);
    },
    onComplete: function() {}
});

// Hook to log all methods of a class
Java.perform(function() {
  var TargetClass = Java.use("com.target.app.CryptoHelper");
  var methods = TargetClass.class.getDeclaredMethods();
  methods.forEach(function(method) {
    console.log("[*] Method: " + method.getName());
  });
});
```

### Deep Link / Intent Testing

```bash
# Launch exported activities directly
adb shell am start -n com.target.app/.AdminActivity
adb shell am start -n com.target.app/.WebViewActivity

# Test deep links for injection
adb shell am start -a android.intent.action.VIEW \
  -d "target://open?url=javascript:alert(document.cookie)"

# Test intent extras for injection
adb shell am start -n com.target.app/.SearchActivity \
  --es search_query "' OR 1=1--"
```

### Common Android Vulnerabilities

```
1. WebView with JavaScript enabled + remote URL loading → XSS, UXSS
2. WebView loading file:// URIs → access local files
3. Insecure data storage: SharedPreferences, SQLite, external storage in plaintext
4. Exported ContentProviders → SQL injection on internal DB
5. Exported Activities → bypass authentication
6. Hardcoded credentials/API keys in APK
7. Insecure deep links → parameter injection
8. Traffic over HTTP (not HTTPS)
9. Backup enabled → extract sensitive data
10. Logcat logging of sensitive data
```

```bash
# Check logcat for sensitive data while using app
adb logcat | grep -i "password\|token\|api_key\|secret"

# Check SharedPreferences (requires root or debuggable app)
adb shell run-as com.target.app cat /data/data/com.target.app/shared_prefs/*.xml

# Check SQLite databases
adb shell run-as com.target.app sqlite3 /data/data/com.target.app/databases/app.db .dump
```

### MobSF Automated Analysis

```bash
# Start MobSF (Docker)
docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest

# Upload APK at http://localhost:8000
# Key findings to look for:
# - Exported components
# - Hardcoded secrets
# - Insecure network config
# - Dangerous permissions
# - Known CVEs in libraries
```

---

## 2. Cryptographic Testing

### WSTG-CRYP Test Cases

**WSTG-CRYP-01: Weak Transport Layer Security**
```bash
# testssl.sh — comprehensive TLS audit
./testssl.sh --full https://target.com

# Check for these vulnerabilities:
# BEAST (TLS 1.0 CBC), CRIME (TLS compression), BREACH (HTTP compression)
# POODLE (SSLv3 CBC), SWEET32 (64-bit block ciphers)
# DROWN (SSLv2), LUCKY13, ROBOT (RSA padding oracle)
# Heartbleed (OpenSSL 1.0.1x)

# Check certificate issues:
# - Expired certificate
# - Self-signed certificate  
# - Wrong hostname
# - Weak signature algorithm (MD5, SHA1)
# - Short key (RSA < 2048 bits)
# - Missing intermediates

# sslscan for quick check
sslscan https://target.com

# sslyze for structured output
sslyze --regular target.com
```

**WSTG-CRYP-02: Padding Oracle**
```bash
# Detect: look for encrypted parameters in cookies or URL params
# Test by modifying last byte of ciphertext → different error message = oracle!

# PadBuster
python3 padbuster.py "https://target.com/page?token=ENCRYPTED_VALUE" "ENCRYPTED_VALUE" 8 -encoding 0

# Block size 8 = DES/3DES, block size 16 = AES

# Signs of padding oracle:
# - "Invalid padding" error vs. "Decryption failed" error (different responses)
# - Different HTTP status codes for padding vs. decryption errors
# - Response timing differences
```

**WSTG-CRYP-03: Sensitive Data in Plaintext**
```
# Check for PII/credentials transmitted over HTTP (not HTTPS)
# Check if passwords stored in plaintext in database:
# - If SQLi found: dump password column
# - If same password works with multiple hash algorithms → stored as hash
# - BCrypt hashes start with $2b$, $2y$, $2a$
# - MD5: 32 hex chars
# - SHA1: 40 hex chars
# - SHA256: 64 hex chars

# Plaintext indicators: registration email confirms exact password back to you
```

**WSTG-CRYP-04: Weak Encryption Algorithms**
```bash
# MD5/SHA1 for password hashing — crackable with GPU
# ECB mode — deterministic, shows patterns (classic ECB penguin image)
# Math.random() for security-sensitive values (tokens, session IDs)
# Hardcoded encryption keys in source code

# Check for weak crypto in source
grep -r "md5\|sha1\|des\|3des\|rc4" . -i | grep -v "comment\|#\|//"
grep -r "ECB\|MODE_ECB" .
grep -r "Math\.random()" . | grep -i "token\|session\|key\|nonce\|csrf"
grep -r "AES\|DES\|key\s*=" . | grep "=\s*[\"']" # Hardcoded keys

# ECB detection:
# Register two users with same password → if same hash returned → ECB or hash (not salted bcrypt)
# With AES-ECB: two identical 16-byte blocks in ciphertext = ECB mode
```

### Identifying Hash Algorithms in Responses

```
$2b$12$... or $2y$12$...     → bcrypt (good!)
$argon2...                   → Argon2 (good!)
$pbkdf2...                   → PBKDF2 (good!)
32 hex chars                 → MD5 (bad — crackable)
40 hex chars                 → SHA1 (bad)
64 hex chars                 → SHA256 (medium — fast to crack without salt)
[a-zA-Z0-9+/]{24}==         → Possibly base64-encoded binary hash

# Crack MD5/SHA1 hashes
hashcat -a 0 -m 0 hash.txt wordlist.txt     # MD5
hashcat -a 0 -m 100 hash.txt wordlist.txt   # SHA1
# Online: crackstation.net, hashes.com
```

### Testing TLS Configuration Manually

```bash
# Check supported protocols
openssl s_client -connect target.com:443 -ssl3 2>&1 | grep "SSL"
openssl s_client -connect target.com:443 -tls1 2>&1 | grep "TLS"

# Check cipher suite
openssl s_client -connect target.com:443 -cipher "NULL" 2>&1

# View certificate details
openssl s_client -connect target.com:443 < /dev/null 2>/dev/null | openssl x509 -text -noout

# Check HSTS header
curl -sI https://target.com | grep -i strict
```
