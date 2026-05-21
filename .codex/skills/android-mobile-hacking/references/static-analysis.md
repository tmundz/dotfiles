# Static Analysis Reference

**MASVS:** MASVS-CODE, MASVS-STORAGE, MASVS-CRYPTO, MASVS-RESILIENCE
**MASTG Tests:** MASTG-TEST-0001 through MASTG-TEST-0030 (Android Static)
**OWASP:** M7 (Binary Protections), M9 (Data Storage), M10 (Cryptography), M1 (Credentials)

## Table of Contents
1. [APK Acquisition](#apk)
2. [APK Decode & Decompile](#decode)
3. [Manifest Analysis](#manifest)
4. [Secret Hunting](#secrets)
5. [Source Code Sink/Source Analysis](#sinks)
6. [Crypto Analysis](#crypto)
7. [Network Security Config Analysis](#nsc)
8. [Binary Protection Checks](#binary)
9. [Automated Scan (MobSF)](#mobsf)
10. [Semgrep Static Analysis](#semgrep)

---

## 1. APK Acquisition <a name="apk"></a>

```bash
# From device via ADB [BOTH]
adb shell pm list packages | grep [TARGET_PACKAGE]
adb shell pm path [TARGET_PACKAGE]
# Output: package:/data/app/[TARGET_PACKAGE]-xxx/base.apk
adb pull /data/app/[TARGET_PACKAGE]-xxx/base.apk ./[TARGET_PACKAGE].apk

# Pull split APKs too [BOTH]
adb shell pm path [TARGET_PACKAGE]  # may list multiple paths
adb pull [SPLIT_APK_PATH]

# From Google Play (external tool) [BOTH]
# Use: https://apkpure.com or gplaydl
# Or pull from emulator after install via Play Store [ROOTED]
```

---

## 2. APK Decode & Decompile <a name="decode"></a>

```bash
# apktool: decode resources + smali [BOTH]
apktool d [APK_PATH] -o [TARGET_PACKAGE]-decoded/
apktool d [APK_PATH] -o [TARGET_PACKAGE]-decoded/ --no-res  # skip resources (faster)

# JADX: decompile to Java [BOTH]
jadx -d [TARGET_PACKAGE]-jadx/ [APK_PATH]
jadx -d [TARGET_PACKAGE]-jadx/ [APK_PATH] --show-bad-code  # include deobfuscation attempts

# JADX GUI (interactive) [BOTH]
jadx-gui [APK_PATH]

# Extract raw APK contents [BOTH]
unzip [APK_PATH] -d [TARGET_PACKAGE]-raw/

# Verify APK signature [BOTH]
apksigner verify --print-certs [APK_PATH]
keytool -printcert -jarfile [APK_PATH]
```

---

## 3. Manifest Analysis <a name="manifest"></a>

**MASVS-PLATFORM-1, MASVS-PLATFORM-2 | OWASP M8**

```bash
# Read decoded manifest [BOTH]
cat [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Critical flags to check:
grep -E "android:debuggable|android:allowBackup|android:networkSecurityConfig" \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Exported components (HIGH SIGNAL) [BOTH]
grep -E 'android:exported="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
grep -B5 -A5 'android:exported="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Activities with intent-filters are implicitly exported [BOTH]
grep -B2 -A10 '<intent-filter>' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Deep link schemes [BOTH]
grep -E 'android:scheme' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Content provider authorities [BOTH]
grep -E 'android:authorities' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Dangerous permissions [BOTH]
grep -E 'uses-permission' [TARGET_PACKAGE]-decoded/AndroidManifest.xml | \
  grep -E "CAMERA|CONTACTS|LOCATION|MICROPHONE|READ_EXTERNAL|WRITE_EXTERNAL|SMS|CALL"

# Custom permissions [BOTH]
grep '<permission ' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# minSdkVersion / targetSdkVersion [BOTH]
grep -E 'android:minSdkVersion|android:targetSdkVersion' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
```

### Manifest Risk Matrix

| Flag | Risk | MASVS |
|------|------|-------|
| `debuggable="true"` | Debug access in prod | MASVS-RESILIENCE-4 |
| `allowBackup="true"` | ADB backup data theft | MASVS-STORAGE-8 |
| `exported="true"` (no permission) | Component hijacking | MASVS-PLATFORM-1 |
| `android:scheme` without validation | Deep link injection | MASVS-PLATFORM-3 |
| cleartext traffic allowed | MITM | MASVS-NETWORK-1 |
| targetSdkVersion < 28 | Missing modern protections | MASVS-CODE-1 |

---

## 4. Secret Hunting <a name="secrets"></a>

**MASVS-STORAGE-2, MASVS-CRYPTO-1 | OWASP M1, M9**

```bash
# Hardcoded API keys, tokens, passwords [BOTH]
rg -i 'api[_-]?key|apikey|secret|password|passwd|token|bearer|auth' \
  --type java [TARGET_PACKAGE]-jadx/ 2>/dev/null

# AWS / cloud credentials [BOTH]
rg -i 'AKIA[0-9A-Z]{16}|aws_access|aws_secret' [TARGET_PACKAGE]-jadx/
rg -i 'AIza[0-9A-Za-z_-]{35}' [TARGET_PACKAGE]-jadx/  # Google API key pattern
rg -i 'sk-[a-zA-Z0-9]{40}' [TARGET_PACKAGE]-jadx/  # OpenAI key

# Private keys and certs [BOTH]
rg '-----BEGIN (RSA |EC |PRIVATE KEY)' [TARGET_PACKAGE]-jadx/
rg '-----BEGIN CERTIFICATE' [TARGET_PACKAGE]-jadx/

# Base64-encoded secrets [BOTH]
rg -i 'base64|Base64.decode' [TARGET_PACKAGE]-jadx/
grep -r '[A-Za-z0-9+/=]\{40,\}' [TARGET_PACKAGE]-decoded/res/ 2>/dev/null

# SharedPreferences with sensitive data [BOTH]
rg -i 'getSharedPreferences|putString|putInt|apply\(\)' [TARGET_PACKAGE]-jadx/ | \
  grep -i 'password\|token\|key\|secret\|auth'

# Firebase / Firestore [BOTH]
cat [TARGET_PACKAGE]-decoded/res/values/strings.xml | grep -i 'firebase\|google_app_id'
cat [TARGET_PACKAGE]-raw/google-services.json 2>/dev/null

# SQLite database paths [BOTH]
rg -i 'openOrCreateDatabase\|SQLiteOpenHelper\|getWritableDatabase\|getReadableDatabase' \
  [TARGET_PACKAGE]-jadx/

# Hardcoded URLs and endpoints [BOTH]
rg -iE 'https?://[a-zA-Z0-9._/-]+' [TARGET_PACKAGE]-jadx/ | \
  grep -v '//android\|//java\|//com.google'

# Package strings.xml [BOTH]
cat [TARGET_PACKAGE]-decoded/res/values/strings.xml | grep -iE 'key|secret|token|api|url|endpoint'

# Assets directory [BOTH]
ls [TARGET_PACKAGE]-raw/assets/
find [TARGET_PACKAGE]-raw/assets/ -type f | xargs grep -li 'password\|secret\|token' 2>/dev/null

# Certificates in assets/raw [BOTH]
find [TARGET_PACKAGE]-raw/ -name "*.bks" -o -name "*.p12" -o -name "*.pfx" \
  -o -name "*.keystore" -o -name "*.jks" 2>/dev/null
```

---

## 5. Source Code Sink/Source Analysis <a name="sinks"></a>

**MASVS-CODE-4, MASVS-PLATFORM | OWASP M4**

```bash
# WebView sinks (XSS, code injection) [BOTH]
rg -n 'loadUrl\|loadData\|evaluateJavascript\|addJavascriptInterface\|setJavaScriptEnabled' \
  [TARGET_PACKAGE]-jadx/

# JavaScript enabled without safe URL check [BOTH]
rg -A3 'setJavaScriptEnabled\(true\)' [TARGET_PACKAGE]-jadx/

# SQL injection risks [BOTH]
rg -n 'rawQuery\|execSQL\|query(' [TARGET_PACKAGE]-jadx/ | grep -v '?'  # queries without parameterization

# Intent/component exposure [BOTH]
rg -n 'getIntent\(\)\|getAction\(\)\|getStringExtra\|getParcelableExtra' [TARGET_PACKAGE]-jadx/
rg -n 'startActivity\|startService\|sendBroadcast\|startActivityForResult' [TARGET_PACKAGE]-jadx/

# Exported receiver/provider/service usage [BOTH]
rg -n 'onReceive\|ContentProvider\|query\|insert\|update\|delete' [TARGET_PACKAGE]-jadx/

# Logging sensitive data [BOTH]
rg -n 'Log\.[dvwie]\|System\.out\.print\|printStackTrace' [TARGET_PACKAGE]-jadx/ | \
  grep -i 'password\|token\|key\|secret\|user'

# Reflection (dynamic code loading) [BOTH]
rg -n 'Class\.forName\|getDeclaredMethod\|getDeclaredField\|invoke\(' [TARGET_PACKAGE]-jadx/
rg -n 'DexClassLoader\|PathClassLoader\|loadClass' [TARGET_PACKAGE]-jadx/

# Native library loading [BOTH]
rg -n 'System\.loadLibrary\|Runtime\.load\|dlopen' [TARGET_PACKAGE]-jadx/

# Clipboard sensitive data [BOTH]
rg -n 'ClipboardManager\|setPrimaryClip\|getPrimaryClip' [TARGET_PACKAGE]-jadx/

# Deep link parameter handling (injection surface) [BOTH]
rg -n 'getIntent\(\).*getData\|Uri\.parse\|getQueryParameter' [TARGET_PACKAGE]-jadx/

# Broadcast intent with sensitive data [BOTH]
rg -n 'sendBroadcast\|sendOrderedBroadcast' [TARGET_PACKAGE]-jadx/
```

---

## 6. Crypto Analysis <a name="crypto"></a>

**MASVS-CRYPTO-1, MASVS-CRYPTO-2 | OWASP M10**

```bash
# Weak algorithms [BOTH]
rg -in 'DES\b|3DES|RC4|MD5|SHA-1|SHA1|ECB|AES/ECB' [TARGET_PACKAGE]-jadx/

# Hardcoded IV/salt [BOTH]
rg -n 'IvParameterSpec\|PBEKeySpec\|SecretKeySpec' [TARGET_PACKAGE]-jadx/
rg -n '"[0-9a-fA-F]{32,}"' [TARGET_PACKAGE]-jadx/  # hex-encoded keys

# Insecure random [BOTH]
rg -n 'new Random\(\)\|Math\.random\|java\.util\.Random' [TARGET_PACKAGE]-jadx/

# KeyStore usage (good pattern — note what's stored) [BOTH]
rg -n 'KeyStore\|KeyGenerator\|KeyPairGenerator\|KeyGenParameterSpec' [TARGET_PACKAGE]-jadx/

# Custom encryption [BOTH]
rg -in 'encrypt\|decrypt\|cipher\|obfuscat' [TARGET_PACKAGE]-jadx/ | head -50
```

---

## 7. Network Security Config Analysis <a name="nsc"></a>

**MASVS-NETWORK-1, MASVS-NETWORK-2 | OWASP M5**

```bash
# Find NSC file [BOTH]
cat [TARGET_PACKAGE]-decoded/AndroidManifest.xml | grep networkSecurityConfig
find [TARGET_PACKAGE]-decoded/res/xml/ -name "network_security_config.xml"
cat [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml

# Check for cleartext allowed [BOTH]
grep -i 'cleartextTrafficPermitted\|usesCleartextTraffic' \
  [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml

# Certificate pins (note domains + hashes for bypass) [BOTH]
grep -A5 '<pin-set>' [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml

# User CA trust (useful for Burp) [BOTH]
grep 'user' [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml
```

### NSC Bypass Patch [UNROOTED]

```xml
<!-- Replace res/xml/network_security_config.xml with: -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system"/>
            <certificates src="user"/>
        </trust-anchors>
    </base-config>
</network-security-config>
```

```bash
# Apply patch, rebuild, sign [UNROOTED]
cp burp_nsc.xml [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml
apktool b [TARGET_PACKAGE]-decoded/ -o [TARGET_PACKAGE]-patched.apk
zipalign -v 4 [TARGET_PACKAGE]-patched.apk [TARGET_PACKAGE]-aligned.apk
apksigner sign --ks ~/.android/debug.keystore \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android \
  [TARGET_PACKAGE]-aligned.apk
adb install -r [TARGET_PACKAGE]-aligned.apk
```

---

## 8. Binary Protection Checks <a name="binary"></a>

**MASVS-RESILIENCE-1 through RESILIENCE-4 | OWASP M7**

```bash
# Obfuscation check [BOTH]
# Look for meaningful class/method names in JADX
# ProGuard → single-letter class names (a.b.c pattern)
# R8 → similar
# No obfuscation → plain names like LoginActivity, SecretManager

# Check for ProGuard mapping [BOTH]
find [TARGET_PACKAGE]-raw/ -name "*.map" -o -name "mapping.txt" 2>/dev/null

# Native library analysis [BOTH]
find [TARGET_PACKAGE]-raw/lib/ -name "*.so"
file [TARGET_PACKAGE]-raw/lib/arm64-v8a/*.so
nm -D [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so 2>/dev/null | head -50  # exported symbols
strings [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so | grep -iE 'password|secret|key|http|api'

# Debuggable flag [BOTH]
grep 'android:debuggable' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Anti-tampering / integrity checks [BOTH]
rg -n 'getPackageInfo\|getSignatures\|Signature\|digest\|checksum\|hash' [TARGET_PACKAGE]-jadx/ | \
  grep -v '//.*'

# SafetyNet / Play Integrity [BOTH]
rg -n 'SafetyNet\|SafetyNetApi\|attest\|PlayIntegrity\|IntegrityManager' [TARGET_PACKAGE]-jadx/

# Frida/Xposed detection [BOTH]
rg -in 'frida\|xposed\|substrate\|magisk\|hook' [TARGET_PACKAGE]-jadx/

# Debug symbols in .so [BOTH]
readelf -S [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so | grep -E 'debug|DWARF'

# Stack canary / PIE / NX [BOTH]
# Use checksec on .so files
checksec --file=[TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so
```

---

## 9. Automated Scan (MobSF) <a name="mobsf"></a>

**[BOTH]**

```bash
# Start MobSF [BOTH]
docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest

# Upload APK via CLI [BOTH]
curl -F "file=@[APK_PATH]" http://localhost:8000/api/v1/upload \
  -H "Authorization: [MOBSF_API_KEY]"

# Get scan results [BOTH]
curl "http://localhost:8000/api/v1/report_json" \
  -d "hash=[SCAN_HASH]" \
  -H "Authorization: [MOBSF_API_KEY]" | python3 -m json.tool

# Download PDF report [BOTH]
curl "http://localhost:8000/api/v1/download_pdf" \
  -d "hash=[SCAN_HASH]" \
  -H "Authorization: [MOBSF_API_KEY]" \
  -o mobsf-report.pdf
```

---

## 10. Semgrep Static Analysis <a name="semgrep"></a>

**[BOTH]**

```bash
# Install semgrep
pip install semgrep

# Run mobile rulesets [BOTH]
semgrep --config=p/android [TARGET_PACKAGE]-jadx/
semgrep --config=p/owasp-top-ten [TARGET_PACKAGE]-jadx/
semgrep --config=p/secrets [TARGET_PACKAGE]-jadx/

# Custom rules for common vulns [BOTH]
semgrep --config=auto [TARGET_PACKAGE]-jadx/ --output semgrep-results.json --json

# Specific patterns
semgrep -e 'new Random()' --lang java [TARGET_PACKAGE]-jadx/
semgrep -e 'Log.$A($B)' --lang java [TARGET_PACKAGE]-jadx/
```

---

## Findings Map Template

After static analysis, log all findings to `braindump/findings_map.md`:

```markdown
## Exported Components
- [HIGH SIGNAL] com.example.DeepLinkActivity — exported, no permission, scheme=myapp://
- [HIGH SIGNAL] com.example.FileProvider — exported authority=com.example.provider
- com.example.MainActivity — exported (has intent-filter), UNTESTED

## Secrets Found
- [HIGH SIGNAL] API key: AIzaSy... in strings.xml line 42
- Token hardcoded in LoginManager.java line 89

## Crypto Issues
- MD5 used in PasswordUtils.java line 23
- ECB mode in CryptoHelper.java line 67

## NSC Issues
- cleartext permitted for *.example.com
- No certificate pinning configured
```
