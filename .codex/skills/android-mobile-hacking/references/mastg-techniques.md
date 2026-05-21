# MASTG Techniques Reference

**Source:** OWASP Mobile Application Security Testing Guide (MASTG)
**Format:** Test ID | Description | Static + Dynamic procedure | Tools | MASVS cross-ref

## Table of Contents
- [Data Storage Tests](#storage)
- [Cryptography Tests](#crypto)
- [Authentication Tests](#auth)
- [Network Communication Tests](#network)
- [Platform Interaction Tests](#platform)
- [Code Quality Tests](#code)
- [Resilience Tests](#resilience)

---

## Data Storage Tests <a name="storage"></a>

### MASTG-TEST-0001: Testing Local Data Storage for Sensitive Data

**MASVS:** MASVS-STORAGE-1 | **OWASP:** M9

```bash
# Static [BOTH]
jadx -d decoded/ [APK_PATH]
rg -n 'SharedPreferences\|SQLiteDatabase\|openFileOutput\|getExternalFilesDir' \
  decoded/ --type java | grep -i 'password\|token\|key\|secret'

# Dynamic [ROOTED]
adb shell su -c "find /data/data/[TARGET_PACKAGE]/ -type f"
adb shell su -c "cat /data/data/[TARGET_PACKAGE]/shared_prefs/*.xml"
sqlite3 <(adb shell su -c "cat /data/data/[TARGET_PACKAGE]/databases/main.db") ".tables"

# Dynamic [UNROOTED - debuggable]
adb shell run-as [TARGET_PACKAGE] find . -type f
adb shell run-as [TARGET_PACKAGE] cat shared_prefs/prefs.xml

# Objection [BOTH]
objection -g [TARGET_PACKAGE] explore
android file ls
```

### MASTG-TEST-0002: Testing SharedPreferences for Sensitive Data

**MASVS:** MASVS-STORAGE-1 | **OWASP:** M9

```bash
# Static [BOTH]
rg -n 'getSharedPreferences\|putString\|putInt\|putBoolean' decoded/ --type java | \
  grep -i 'password\|token\|auth\|secret'

# Dynamic [ROOTED]
adb shell su -c "ls /data/data/[TARGET_PACKAGE]/shared_prefs/"
adb shell su -c "cat /data/data/[TARGET_PACKAGE]/shared_prefs/*.xml"

# Check EncryptedSharedPreferences [BOTH]
rg -n 'EncryptedSharedPreferences\|MasterKey' decoded/ --type java
# Absent = plaintext storage
```

### MASTG-TEST-0003: Testing SQLite Databases for Sensitive Data

**MASVS:** MASVS-STORAGE-1 | **OWASP:** M9

```bash
# Static [BOTH]
rg -n 'SQLiteOpenHelper\|openOrCreateDatabase\|getWritableDatabase\|getReadableDatabase' \
  decoded/ --type java

# Dynamic [ROOTED]
adb pull /data/data/[TARGET_PACKAGE]/databases/ ./dbs/
for db in dbs/*.db; do
  echo "=== $db ==="
  sqlite3 "$db" ".tables"
  sqlite3 "$db" "SELECT * FROM sqlite_master WHERE type='table';"
done
# Inspect tables for sensitive data
sqlite3 dbs/main.db "SELECT * FROM users LIMIT 10;"

# Check encryption [BOTH]
# SQLCipher: encrypted DB starts with "SQLite format 3" but body is binary
file dbs/*.db
xxd dbs/main.db | head -4  # unencrypted shows "SQLite format 3\000"
```

### MASTG-TEST-0004: Testing External Storage for Sensitive Data

**MASVS:** MASVS-STORAGE-1 | **OWASP:** M9

```bash
# Static [BOTH]
rg -n 'getExternalFilesDir\|getExternalStorageDirectory\|Environment.getExternalStorageDirectory' \
  decoded/ --type java

# Dynamic [BOTH]
adb shell ls -la /sdcard/Android/data/[TARGET_PACKAGE]/
adb pull /sdcard/Android/data/[TARGET_PACKAGE]/ ./external-data/
find external-data/ -type f | xargs grep -li 'password\|token\|secret' 2>/dev/null
```

### MASTG-TEST-0005: Testing Logs for Sensitive Data

**MASVS:** MASVS-STORAGE-3 | **OWASP:** M6

```bash
# Static [BOTH]
rg -n 'Log\.[dvwie]\(' decoded/ --type java | \
  grep -i 'password\|token\|key\|secret\|auth\|email'

# Dynamic [BOTH]
adb logcat -c
# [trigger login, registration, purchase flows]
adb logcat -d | grep -iE 'password|token|secret|key|email|credit'
adb logcat --pid=$(adb shell pidof [TARGET_PACKAGE]) -d | tee logcat.txt
```

### MASTG-TEST-0006: Testing Backups for Sensitive Data

**MASVS:** MASVS-STORAGE-8 | **OWASP:** M9

```bash
# Static [BOTH]
grep -E 'android:allowBackup|android:fullBackupContent|android:dataExtractionRules' \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Dynamic [BOTH]
adb backup -f backup.ab -noapk [TARGET_PACKAGE]
dd if=backup.ab bs=1 skip=24 | \
  python3 -c "import zlib,sys; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read()))" \
  | tar xv -C backup-extracted/
grep -r 'password\|token\|secret' backup-extracted/ 2>/dev/null
```

---

## Cryptography Tests <a name="crypto"></a>

### MASTG-TEST-0013: Testing for Weak Cryptography

**MASVS:** MASVS-CRYPTO-1 | **OWASP:** M10

```bash
# Static [BOTH]
rg -in '"DES"\|"3DES"\|"RC4"\|"AES/ECB"\|"MD5"\|"SHA-1"\|new Random()' \
  decoded/ --type java

# Dynamic [BOTH]
frida -U -f [TARGET_PACKAGE] -l scripts/frida/crypto-dump.js --no-pause
# Observe: algorithm, mode, key material, IV
```

### MASTG-TEST-0014: Testing for Hardcoded Cryptographic Keys

**MASVS:** MASVS-CRYPTO-2 | **OWASP:** M10

```bash
# Static [BOTH]
rg -n 'new SecretKeySpec\|IvParameterSpec\|PBEKeySpec' decoded/ --type java -A2
# Look for byte[] literals, hex string constants

# Check for base64-encoded keys [BOTH]
rg -n '"[A-Za-z0-9+/]{24,}={0,2}"' decoded/ --type java | head -20
# Decode candidates:
echo "[B64_STRING]" | base64 -d | xxd | head -3

# Dynamic [BOTH]
frida -U -f [TARGET_PACKAGE] -l scripts/frida/crypto-dump.js --no-pause
# SecretKeySpec.$init hook reveals raw key bytes
```

---

## Authentication Tests <a name="auth"></a>

### MASTG-TEST-0015: Testing Biometric Authentication

**MASVS:** MASVS-AUTH-3 | **OWASP:** M3

```bash
# Static [BOTH]
rg -n 'BiometricPrompt\|BiometricManager\|FingerprintManager\|KeyguardManager' \
  decoded/ --type java -A10

# Dynamic [BOTH]
# Hook BiometricPrompt auth callback
frida -U -f [TARGET_PACKAGE] -l scripts/frida/biometric-bypass.js --no-pause
# Or via objection: android fingerprint bypass
objection -g [TARGET_PACKAGE] explore
android fingerprint bypass
```

### MASTG-TEST-0016: Testing Local Authentication

**MASVS:** MASVS-AUTH-1 | **OWASP:** M3

```bash
# Static [BOTH]
rg -n 'checkSelfPermission\|isAuthenticated\|verifyPin\|checkPassword' \
  decoded/ --type java

# Dynamic [BOTH]
# Hook auth method, force return true
frida -U -f [TARGET_PACKAGE] -l scripts/frida/auth-bypass.js --no-pause
# Test airplane mode: does app enforce re-auth?
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
```

---

## Network Communication Tests <a name="network"></a>

### MASTG-TEST-0019: Testing Endpoint Identify Verification (SSL)

**MASVS:** MASVS-NETWORK-1 | **OWASP:** M5

```bash
# Static [BOTH]
rg -n 'AllowAllHostnameVerifier\|ALLOW_ALL_HOSTNAME_VERIFIER\|setHostnameVerifier' \
  decoded/ --type java
rg -n 'checkServerTrusted' decoded/ --type java -A5
rg -n 'onReceivedSslError.*proceed' decoded/ --type java

# Dynamic [BOTH]
# Set up Burp proxy with self-signed cert
# If app works → hostname verification disabled → finding
```

### MASTG-TEST-0020: Testing Custom Certificate Stores and Certificate Pinning

**MASVS:** MASVS-NETWORK-2 | **OWASP:** M5

```bash
# Static [BOTH]
rg -n 'CertificatePinner\|checkServerTrusted\|TrustManager' decoded/ --type java
cat [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml | grep -A5 'pin-set'

# Dynamic [BOTH]
# Test if Burp works without pinning bypass → if fails, pinning exists
# Then apply bypass:
frida -U -f [TARGET_PACKAGE] -l subskills/frida/scripts/universal-ssl-unpin.js --no-pause
# If bypass needed to see traffic → pinning confirmed → document both states
```

### MASTG-TEST-0021: Testing Cleartext Traffic

**MASVS:** MASVS-NETWORK-1 | **OWASP:** M5

```bash
# Static [BOTH]
grep 'cleartextTrafficPermitted\|usesCleartextTraffic' \
  [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml
rg -i 'http://' decoded/ --type java | grep -v '//android\|//schemas\|//java'

# Dynamic [ROOTED]
adb shell su -c "tcpdump -i any port 80 -A" | grep -i 'password\|token'
```

---

## Platform Interaction Tests <a name="platform"></a>

### MASTG-TEST-0024: Testing for Injected Intent Arguments

**MASVS:** MASVS-PLATFORM-1 | **OWASP:** M4, M8

```bash
# Static [BOTH]
grep -E 'android:exported="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
rg -n 'getIntent\(\)\.getStringExtra\|getIntExtra\|getBundleExtra' decoded/ --type java

# Dynamic [BOTH]
adb shell am start -n [TARGET_PACKAGE]/[EXPORTED_ACTIVITY] \
  --es "key" "injected_value" \
  --ez "isAdmin" true
```

### MASTG-TEST-0025: Testing Deep Links

**MASVS:** MASVS-PLATFORM-2 | **OWASP:** M4, M8

```bash
# Static [BOTH]
grep -E 'android:scheme\|android:host\|android:pathPrefix' \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Dynamic fuzz [BOTH]
for payload in "' OR 1=1--" "<script>alert(1)</script>" "http://evil.com" \
  "../../../data/data/[TARGET_PACKAGE]/databases/main.db"; do
  adb shell am start -a android.intent.action.VIEW \
    -d "[SCHEME]://[HOST]/[PATH]?param=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))")"
  sleep 1
done
```

### MASTG-TEST-0026: Testing WebViews for Dangerous Functionality

**MASVS:** MASVS-PLATFORM-3 | **OWASP:** M4

```bash
# Static [BOTH]
rg -n 'setJavaScriptEnabled\(true\)\|addJavascriptInterface\|loadUrl\|evaluateJavascript' \
  decoded/ --type java -A3

# Dynamic [BOTH]
# Frida hook WebView
frida -U -f [TARGET_PACKAGE] -l scripts/frida/webview-hooks.js --no-pause
# Then navigate to WebView and observe JS execution
```

---

## Code Quality Tests <a name="code"></a>

### MASTG-TEST-0038: Testing for Debuggable Apps

**MASVS:** MASVS-CODE-2 | **OWASP:** M7, M8

```bash
# Static [BOTH]
grep 'android:debuggable' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Dynamic [BOTH]
adb shell run-as [TARGET_PACKAGE] id  # only works if debuggable
adb jdwp  # list debuggable processes
```

### MASTG-TEST-0039: Testing for Weak Signature Algorithm

**MASVS:** MASVS-CODE-1 | **OWASP:** M7

```bash
# [BOTH]
apksigner verify --print-certs [APK_PATH]
keytool -printcert -jarfile [APK_PATH]
# Check: MD5withRSA or SHA1withRSA = weak signing
# Should be: SHA256withRSA
```

---

## Resilience Tests <a name="resilience"></a>

### MASTG-TEST-0041: Testing for Rooting Detection

**MASVS:** MASVS-RESILIENCE-1 | **OWASP:** M7

```bash
# Static [BOTH]
rg -in 'isRooted\|checkRoot\|RootBeer\|/sbin/su\|/system/bin/su\|/system/xbin/su' \
  decoded/ --type java

# Dynamic [ROOTED]
# Test on rooted device: does app detect root?
# Then bypass:
frida -U -f [TARGET_PACKAGE] -l scripts/frida/root-bypass.js --no-pause
# Or: objection android root disable
```

### MASTG-TEST-0042: Testing for Anti-Debugging

**MASVS:** MASVS-RESILIENCE-2 | **OWASP:** M7

```bash
# Static [BOTH]
rg -n 'Debug.isDebuggerConnected\|ptrace\|TracerPid\|isBeingDebugged' decoded/ --type java

# Dynamic [BOTH]
frida -U -f [TARGET_PACKAGE] -l scripts/frida/anti-debug-bypass.js --no-pause
# Attach debugger and observe if app crashes/exits
adb jdwp | head -5
```

### MASTG-TEST-0043: Testing for Code Obfuscation

**MASVS:** MASVS-RESILIENCE-4 | **OWASP:** M7

```bash
# [BOTH]
jadx -d decoded/ [APK_PATH]
ls decoded/sources/
# Meaningful names → no obfuscation → finding
# Single-letter names (a/, b/, c/) → ProGuard/R8 applied

# Check obfuscation quality
wc -l decoded/sources/**/*.java | sort -n | tail -20
# Very small files often = aggressively obfuscated
```

### MASTG-TEST-0044: Testing for Anti-Tampering

**MASVS:** MASVS-RESILIENCE-1 | **OWASP:** M7

```bash
# Static [BOTH]
rg -n 'getSignatures\|PackageManager.GET_SIGNATURES\|getPackageInfo' decoded/ --type java

# Dynamic: repack test [BOTH]
apktool d [APK_PATH] -o repack-test/
# Trivial change (add comment in smali)
apktool b repack-test/ -o repacked.apk
apksigner sign --ks ~/.android/debug.keystore \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android repacked.apk
adb install repacked.apk
# Launch app — if runs normally = no integrity check = finding
```
