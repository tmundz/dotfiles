# MASVS Checklist — Every Control Mapped to Test + Command

**Source:** OWASP Mobile Application Security Verification Standard (MASVS) v2.x
**Format:** CONTROL-ID | Description | Test Command | [TAG]

## Table of Contents
- [MASVS-STORAGE](#storage) — Data Storage
- [MASVS-CRYPTO](#crypto) — Cryptography
- [MASVS-AUTH](#auth) — Authentication
- [MASVS-NETWORK](#network) — Network Communication
- [MASVS-PLATFORM](#platform) — Platform Interaction
- [MASVS-CODE](#code) — Code Quality
- [MASVS-RESILIENCE](#resilience) — Anti-Tampering & Reverse Engineering

---

## MASVS-STORAGE <a name="storage"></a>

### MASVS-STORAGE-1: Sensitive data not stored locally unless necessary

```bash
# [BOTH] Static: search for storage APIs with sensitive data
rg -n 'SharedPreferences\|SQLiteDatabase\|openFileOutput\|openOrCreateDatabase' \
  [TARGET_PACKAGE]-jadx/ | grep -i 'password\|token\|key\|secret\|auth'

# [ROOTED] Dynamic: enumerate all files in app data dir
adb shell su -c "find /data/data/[TARGET_PACKAGE]/ -type f" | sort
adb shell su -c "cat /data/data/[TARGET_PACKAGE]/shared_prefs/*.xml"
```

### MASVS-STORAGE-2: Sensitive data encrypted using platform-recommended APIs

```bash
# [BOTH] Check for EncryptedSharedPreferences usage
rg -n 'EncryptedSharedPreferences\|EncryptedFile\|MasterKey' [TARGET_PACKAGE]-jadx/
# If absent → plaintext storage → finding

# [BOTH] Check for Android Keystore usage
rg -n 'KeyStore\|KeyGenParameterSpec\|KeyGenerator.*AES\|KeyPairGenerator' [TARGET_PACKAGE]-jadx/

# [ROOTED] Read plaintext SharedPreferences
adb shell su -c "cat /data/data/[TARGET_PACKAGE]/shared_prefs/*.xml"

# [ROOTED] Inspect SQLite for plaintext secrets
adb pull /data/data/[TARGET_PACKAGE]/databases/ ./dbs/
sqlite3 dbs/[DB_NAME].db ".tables"
sqlite3 dbs/[DB_NAME].db "SELECT * FROM users;"
```

### MASVS-STORAGE-3: No sensitive data written to logs

```bash
# [BOTH] Static: find Log calls with sensitive data
rg -n 'Log\.[dvwie]\(' [TARGET_PACKAGE]-jadx/ -A1 | \
  grep -iE 'password|token|secret|key|auth|email|credit'

# [BOTH] Dynamic: monitor logcat during app use
adb logcat | tee logcat.txt
grep -iE 'password|token|secret|key' logcat.txt
```

### MASVS-STORAGE-4: No sensitive data shared with third parties

```bash
# [BOTH] Check third-party SDK integrations
rg -in 'firebase\|amplitude\|mixpanel\|appsflyer\|adjust\|sentry\|crashlytics' \
  [TARGET_PACKAGE]-jadx/

# [BOTH] Network: observe what data is sent to third-party domains in Burp
# Flag: PII (email, phone, device ID) sent to analytics domains
```

### MASVS-STORAGE-5: No sensitive data exposed via keyboard cache

```bash
# [BOTH] Check inputType on sensitive fields
rg -n 'inputType\|TYPE_TEXT_VARIATION_PASSWORD\|TYPE_CLASS_TEXT' [TARGET_PACKAGE]-jadx/
# Must include: TYPE_TEXT_VARIATION_PASSWORD for password fields
```

### MASVS-STORAGE-6: No sensitive data exposed via IPC (Intents)

```bash
# [BOTH] Check for PII in Intents
rg -n 'putExtra\|getStringExtra' [TARGET_PACKAGE]-jadx/ | \
  grep -i 'password\|token\|secret'

# [BOTH] Test exported activities can't receive sensitive intent extras
adb shell am start -n [TARGET_PACKAGE]/[EXPORTED_ACTIVITY] \
  --es "token" "leaked_token"
```

### MASVS-STORAGE-7: No sensitive data exposed via screenshot

```bash
# [BOTH] Check for FLAG_SECURE
rg -n 'FLAG_SECURE\|WindowManager.LayoutParams.FLAG_SECURE' [TARGET_PACKAGE]-jadx/
# If missing on sensitive screens → screenshotable
adb exec-out screencap -p > test-screenshot.png
```

### MASVS-STORAGE-8: No sensitive data in cloud backups

```bash
# [BOTH] Manifest check
grep -E 'android:allowBackup|android:fullBackupContent|android:dataExtractionRules' \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# [BOTH] Extract and inspect backup
adb backup -f backup.ab -noapk [TARGET_PACKAGE]
dd if=backup.ab bs=1 skip=24 | python3 -c \
  "import zlib,sys; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read()))" \
  | tar xv -C backup-extracted/
grep -r 'password\|token\|secret' backup-extracted/ 2>/dev/null
```

---

## MASVS-CRYPTO <a name="crypto"></a>

### MASVS-CRYPTO-1: Strong cryptography algorithms with appropriate key lengths

```bash
# [BOTH] Find weak algorithms
rg -in '"DES"\|"3DES"\|"RC4"\|"Blowfish"\|"AES/ECB"\|"MD5"\|"SHA1"\|"SHA-1"' \
  [TARGET_PACKAGE]-jadx/

# [BOTH] Dynamic: Frida crypto intercept
frida -U -f [TARGET_PACKAGE] -l scripts/frida/crypto-dump.js --no-pause

# [BOTH] Check key lengths
rg -n 'KeyGenParameterSpec\|KeyGenerator.getInstance' [TARGET_PACKAGE]-jadx/ -A5 | \
  grep -E 'keySize|KEY_SIZE'
# AES must be 256, RSA must be 2048+
```

### MASVS-CRYPTO-2: Cryptographic keys not hardcoded or poorly managed

```bash
# [BOTH] Find hardcoded keys
rg -n 'SecretKeySpec\|IvParameterSpec' [TARGET_PACKAGE]-jadx/ -A2 | \
  grep -E '"[0-9a-fA-F]{32,}"\|"[A-Za-z0-9+/]{32,}"'

# [BOTH] Find hardcoded IV
rg -n 'new byte\[\]\s*{' [TARGET_PACKAGE]-jadx/ -A1

# [BOTH] Check SecureRandom vs Random
rg -n 'new Random()\|java\.util\.Random' [TARGET_PACKAGE]-jadx/
# Must use SecureRandom for crypto operations
```

---

## MASVS-AUTH <a name="auth"></a>

### MASVS-AUTH-1: Remote endpoints use secure authentication

```bash
# [BOTH] Test: remove Authorization header in Burp, check if endpoint still responds
# [BOTH] JWT analysis
python3 << 'EOF'
import base64, json
token = "[JWT_TOKEN]"
parts = token.split('.')
header = json.loads(base64.b64decode(parts[0]+'==').decode())
payload = json.loads(base64.b64decode(parts[1]+'==').decode())
print("Header:", header)
print("Payload:", payload)
EOF

# [BOTH] Test alg=none
# Encode header with alg:none, remove signature, replay
```

### MASVS-AUTH-2: Session management — tokens expire, invalidate on logout

```bash
# [BOTH] Capture token, logout, replay old token → should get 401
curl -H "Authorization: Bearer [OLD_TOKEN]" https://[TARGET_HOST]/api/profile

# [BOTH] Check token expiry claim in JWT
# exp field: is it reasonable? (not years in future)
# [BOTH] Check refresh token rotation
```

### MASVS-AUTH-3: Biometric uses OS-provided cryptographic primitives

```bash
# [BOTH] Static: check BiometricPrompt usage
rg -n 'BiometricPrompt\|BiometricManager\|FingerprintManager' [TARGET_PACKAGE]-jadx/
# Must use CryptoObject-based approach, not just auth callback

# [BOTH] Frida: bypass biometric auth
# Hook BiometricPrompt.AuthenticationCallback.onAuthenticationSucceeded
```

---

## MASVS-NETWORK <a name="network"></a>

### MASVS-NETWORK-1: All network traffic uses TLS

```bash
# [BOTH] Static: find http:// URLs
rg -i 'http://' [TARGET_PACKAGE]-jadx/ | grep -v '//android\|//java\|//schemas'

# [BOTH] NSC cleartext check
grep 'cleartextTrafficPermitted\|usesCleartextTraffic' \
  [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml

# [BOTH] Dynamic: Burp intercept all traffic, flag non-HTTPS
# [ROOTED] tcpdump -i any port 80 to catch cleartext
```

### MASVS-NETWORK-2: TLS settings align with best practices

```bash
# [BOTH] TLS cipher/version audit
testssl.sh [TARGET_HOST]
nmap --script ssl-enum-ciphers -p 443 [TARGET_HOST]
# Flag: TLS < 1.2, RC4, 3DES, NULL, EXPORT, anon ciphers
```

---

## MASVS-PLATFORM <a name="platform"></a>

### MASVS-PLATFORM-1: Exported components use permissions or require caller validation

```bash
# [BOTH] Find unprotected exported components
grep -E 'android:exported="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
# Cross-check: no android:permission attribute on exported components

# [BOTH] Drozer: attempt direct launch of all exported activities
dz> run app.activity.start --component [TARGET_PACKAGE] [EACH_EXPORTED_ACTIVITY]

# [BOTH] ADB: start all exported activities directly
adb shell am start -n [TARGET_PACKAGE]/[ACTIVITY]
```

### MASVS-PLATFORM-2: Sensitive data not exposed via deep links without validation

```bash
# [BOTH] Extract deep link schemes
grep 'android:scheme' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# [BOTH] Fuzz deep link parameters
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://host/path?param=FUZZ_PAYLOAD"

# [BOTH] Check for path traversal in deep link file access
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://open?file=../../../data/data/[TARGET_PACKAGE]/databases/main.db"
```

### MASVS-PLATFORM-3: No JavaScript interfaces without explicit safe allowlisting

```bash
# [BOTH] Find addJavascriptInterface
rg -n 'addJavascriptInterface' [TARGET_PACKAGE]-jadx/
# Check: what methods are exposed? Can they read files?

# [BOTH] Test via WebView URL
# If app loads attacker-controlled URL with JS interface:
# window.[INTERFACE_NAME].dangerousMethod()
```

### MASVS-PLATFORM-4: WebViewClient validates navigation properly

```bash
# [BOTH] Check shouldOverrideUrlLoading
rg -n 'shouldOverrideUrlLoading\|shouldInterceptRequest' [TARGET_PACKAGE]-jadx/

# [BOTH] Test open redirect
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://auth/callback?redirect=http://evil.com"
```

---

## MASVS-CODE <a name="code"></a>

### MASVS-CODE-1: App signed with valid cert (not debug key) and targetSdkVersion >= 28

```bash
# [BOTH] Verify signature
apksigner verify --print-certs [APK_PATH] | grep -E 'Signer|Common Name|Issued By'
# Debug key: CN=Android Debug, O=Android → finding for production apps

# [BOTH] Check targetSdkVersion
grep 'android:targetSdkVersion' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
# < 28 = missing modern protections
```

### MASVS-CODE-2: App not debuggable in production

```bash
# [BOTH]
grep 'android:debuggable="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
# Present = HIGH SIGNAL finding

# [BOTH] ADB debug attach
adb shell am attach-agent [TARGET_PACKAGE] /data/local/tmp/agent.so
# Only works if debuggable=true
```

### MASVS-CODE-3: Third-party libraries free of known vulnerabilities

```bash
# [BOTH] MobSF library version check (automated)
# [BOTH] OWASP Dependency Check
# [BOTH] Search for CVE-known versions
rg -rn 'okhttp3.*3\.[0-7]\.\|retrofit.*2\.[0-5]\.' [TARGET_PACKAGE]-jadx/ 2>/dev/null
```

### MASVS-CODE-4: No free security functions (proper input validation everywhere)

```bash
# [BOTH] SQLi pattern
rg -n 'rawQuery\|execSQL' [TARGET_PACKAGE]-jadx/ | grep -v '?'  # no parameterization

# [BOTH] XSS pattern
rg -n 'loadData\|loadDataWithBaseURL' [TARGET_PACKAGE]-jadx/ -A2 | grep -v 'text/plain'
```

---

## MASVS-RESILIENCE <a name="resilience"></a>

### MASVS-RESILIENCE-1: App detects and prevents tampering

```bash
# [BOTH] Check for signature/integrity verification
rg -n 'getSignatures\|getPackageInfo.*GET_SIGNATURES\|PackageManager.GET_SIGNATURES' \
  [TARGET_PACKAGE]-jadx/

# [BOTH] Test: repackage APK with debug key, install, observe behavior
apktool d [APK_PATH] -o test/ && apktool b test/ -o repacked.apk
apksigner sign --ks ~/.android/debug.keystore --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android repacked.apk
adb install repacked.apk
# If runs normally → no integrity check → finding
```

### MASVS-RESILIENCE-2: App detects emulator/jailbreak/root

```bash
# [BOTH] Check for root detection
rg -in 'isRooted\|checkRoot\|RootBeer\|/su\|/sbin/su\|buildTags\|test-keys' \
  [TARGET_PACKAGE]-jadx/

# [BOTH] Frida bypass root detection (see subskills/frida/SKILL.md)
frida -U -f [TARGET_PACKAGE] -l scripts/frida/root-bypass.js --no-pause

# [BOTH] Test on rooted device/emulator to verify detection works
```

### MASVS-RESILIENCE-3: App detects and responds to debugging

```bash
# [BOTH] Check for anti-debug
rg -n 'isDebuggerConnected\|ptrace\|Debug.isDebuggerConnected' [TARGET_PACKAGE]-jadx/

# [BOTH] Frida anti-debug bypass
frida -U -f [TARGET_PACKAGE] -l scripts/frida/anti-debug-bypass.js --no-pause
```

### MASVS-RESILIENCE-4: App obfuscated to prevent reverse engineering

```bash
# [BOTH] JADX decompile — check for meaningful class/method names
jadx -d [TARGET_PACKAGE]-jadx/ [APK_PATH]
ls [TARGET_PACKAGE]-jadx/sources/
# com/example/LoginManager.java → no obfuscation
# a/b/c.java → R8/ProGuard applied

# [BOTH] Check for proguard-rules.pro / R8 configuration
find [TARGET_PACKAGE]-raw/ -name "proguard*" -o -name "*.pro" 2>/dev/null
```

---

## Quick MASVS Scan Script

```bash
#!/bin/bash
# Quick MASVS static scan
PKG=$1
DECODED="${PKG}-decoded"
JADX="${PKG}-jadx"

echo "=== MASVS Quick Scan: $PKG ==="
echo ""
echo "[STORAGE-1] Shared prefs with sensitive data:"
rg -l 'password|token|secret' $JADX --type java 2>/dev/null | grep -i 'pref\|storage\|data' | head -5

echo "[CRYPTO-1] Weak algorithms:"
rg -in '"DES"\|"RC4"\|"MD5"\|"AES/ECB"\|"SHA-1"' $JADX --type java 2>/dev/null | head -10

echo "[PLATFORM-1] Exported components:"
grep -E 'android:exported="true"' $DECODED/AndroidManifest.xml

echo "[CODE-1] Debug key:"
apksigner verify --print-certs *.apk 2>/dev/null | grep 'Common Name' | head -3

echo "[CODE-2] Debuggable:"
grep 'android:debuggable' $DECODED/AndroidManifest.xml

echo "[STORAGE-8] Backup:"
grep 'android:allowBackup' $DECODED/AndroidManifest.xml

echo "[NETWORK-1] HTTP URLs:"
rg -c 'http://' $JADX --type java 2>/dev/null | grep -v '0$' | head -5

echo "[RESILIENCE-1] Integrity checks:"
rg -n 'getSignatures\|PackageManager.GET_SIGNATURES' $JADX --type java 2>/dev/null | head -5
```
