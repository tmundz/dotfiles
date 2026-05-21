# Toolchain Reference — Setup and Usage for Every Tool

**All tools needed for Android mobile security testing**
**Every usage section tagged [ROOTED], [UNROOTED], or [BOTH]**

## Table of Contents
1. [Environment Setup](#setup)
2. [ADB](#adb)
3. [Android Emulator (AVD)](#avd)
4. [apktool](#apktool)
5. [JADX](#jadx)
6. [MobSF](#mobsf)
7. [Drozer](#drozer)
8. [Objection](#objection)
9. [Frida](#frida)
10. [Burp Suite](#burp)
11. [scrcpy](#scrcpy)
12. [semgrep](#semgrep)
13. [ripgrep / grep](#ripgrep)
14. [Ghidra / radare2](#ghidra)
15. [Python utilities](#python)

---

## 1. Environment Setup <a name="setup"></a>

```bash
# Install all tools (Ubuntu/Debian) [BOTH]
sudo apt update
sudo apt install -y adb apktool jadx python3-pip \
  openjdk-17-jdk zipalign apksigner scrcpy \
  nmap wireshark curl wget unzip

# Python tools
pip3 install frida-tools objection drozer mobsf semgrep

# Android debug keystore (for signing)
keytool -genkey -v \
  -keystore ~/.android/debug.keystore \
  -storepass android -alias androiddebugkey \
  -keypass android -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"

# ripgrep
sudo apt install ripgrep || cargo install ripgrep

# checksec
pip3 install checksec.py
# or: apt install checksec

# testssl.sh
git clone https://github.com/drwetter/testssl.sh.git
chmod +x testssl.sh/testssl.sh

# apk-mitm
npm install -g apk-mitm
```

---

## 2. ADB <a name="adb"></a>

```bash
# Verify [BOTH]
adb version
adb devices

# Full reference: references/adb-commands.md
```

---

## 3. Android Emulator (AVD) <a name="avd"></a>

```bash
# Create AVD with Google APIs (needed for Play Store, GSF) [ROOTED]
# Android Studio → AVD Manager → Create Virtual Device
# Select: Pixel 4 → System Image: API 30 Google APIs (x86_64) → Finish

# Create via cmdline [ROOTED]
sdkmanager "system-images;android-30;google_apis;x86_64"
avdmanager create avd -n "pentest_avd" \
  -k "system-images;android-30;google_apis;x86_64" \
  -d "pixel_4"

# Start emulator with writable system [ROOTED]
emulator -avd pentest_avd -writable-system -no-snapshot &

# Root the emulator [ROOTED]
adb root
adb remount  # makes /system writable

# Disable AVB verification [ROOTED]
adb shell avbctl disable-verification
adb reboot

# Set proxy in emulator [ROOTED]
emulator -avd pentest_avd -http-proxy [BURP_IP]:[BURP_PORT] &

# Or via ADB after start [BOTH]
adb shell settings put global http_proxy [BURP_IP]:[BURP_PORT]

# Install system CA cert [ROOTED]
HASH=$(openssl x509 -inform DER -subject_hash_old -in burp_ca.der | head -1)
adb push burp_ca.der /sdcard/
adb shell su -c "cp /sdcard/burp_ca.der /system/etc/security/cacerts/${HASH}.0"
adb shell su -c "chmod 644 /system/etc/security/cacerts/${HASH}.0"
adb reboot

# Snapshot management [ROOTED]
adb shell avd snapshot save clean_state
adb shell avd snapshot load clean_state
```

---

## 4. apktool <a name="apktool"></a>

```bash
# Install latest [BOTH]
wget https://github.com/iBotPeaches/Apktool/releases/latest/download/apktool_*.jar -O apktool.jar
sudo mv apktool.jar /usr/local/bin/
# Wrapper script: https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
sudo chmod +x /usr/local/bin/apktool

# Decode APK [BOTH]
apktool d [APK_PATH] -o [OUTPUT_DIR]
apktool d [APK_PATH] -o [OUTPUT_DIR] --no-res      # skip resources (faster)
apktool d [APK_PATH] -o [OUTPUT_DIR] --force        # overwrite existing
apktool d [APK_PATH] -o [OUTPUT_DIR] -p [FRAMEWORK] # custom framework

# Rebuild APK [BOTH]
apktool b [DECODED_DIR] -o [OUTPUT_APK]
apktool b [DECODED_DIR] -o [OUTPUT_APK] --use-aapt2  # Android 11+ resources

# Align and sign [BOTH]
zipalign -v 4 [OUTPUT_APK] [ALIGNED_APK]
apksigner sign --ks ~/.android/debug.keystore \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android \
  --key-pass pass:android \
  [ALIGNED_APK]

# Verify signature [BOTH]
apksigner verify [ALIGNED_APK]
apksigner verify --print-certs [ALIGNED_APK]

# Install patched APK [BOTH]
adb install -r [ALIGNED_APK]

# Smali patching workflow [UNROOTED]
# 1. Decode: apktool d app.apk -o app-decoded/
# 2. Find target method in app-decoded/smali/
# 3. Edit smali file (see smali syntax below)
# 4. Rebuild: apktool b app-decoded/ -o app-patched.apk
# 5. Align: zipalign -v 4 app-patched.apk app-aligned.apk
# 6. Sign: apksigner sign ...
# 7. Install: adb install -r app-aligned.apk
```

### Smali Quick Reference

```smali
# Return true (boolean)
const/4 v0, 0x1
return v0

# Return false
const/4 v0, 0x0
return v0

# Return-void (null return)
return-void

# Inject frida-gadget load
const-string v0, "frida-gadget"
invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V

# Log statement (for debugging)
const-string v0, "TAG"
const-string v1, "DEBUG MESSAGE"
invoke-static {v0, v1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

# Patch checkServerTrusted to be empty (SSL bypass)
# Find in smali, remove all code between .method and .end method
# Add only: return-void
.method public checkServerTrusted([Ljava/security/cert/X509Certificate;Ljava/lang/String;)V
    .registers 2
    return-void
.end method
```

---

## 5. JADX <a name="jadx"></a>

```bash
# Install [BOTH]
# Download: https://github.com/skylot/jadx/releases/latest
wget https://github.com/skylot/jadx/releases/latest/download/jadx-*.zip
unzip jadx-*.zip -d jadx/
sudo ln -s $(pwd)/jadx/bin/jadx /usr/local/bin/jadx
sudo ln -s $(pwd)/jadx/bin/jadx-gui /usr/local/bin/jadx-gui

# Decompile to Java source [BOTH]
jadx -d [OUTPUT_DIR] [APK_PATH]
jadx -d [OUTPUT_DIR] [APK_PATH] --show-bad-code  # include failed decompilation
jadx -d [OUTPUT_DIR] [APK_PATH] --no-res          # skip resources

# GUI [BOTH]
jadx-gui [APK_PATH]

# Search in JADX (grep-based) [BOTH]
rg -n 'pattern' [OUTPUT_DIR]/sources/ --type java

# JADX with deobfuscation [BOTH]
jadx -d [OUTPUT_DIR] [APK_PATH] --deobf --deobf-min 3 --deobf-max 64

# Export project as Gradle for IDE [BOTH]
jadx -d [OUTPUT_DIR] [APK_PATH] --export-gradle
```

---

## 6. MobSF <a name="mobsf"></a>

```bash
# Docker installation [BOTH]
docker pull opensecurity/mobile-security-framework-mobsf:latest
docker run -it --rm -p 8000:8000 \
  opensecurity/mobile-security-framework-mobsf:latest

# Access: http://localhost:8000
# Default API key: in Docker logs or settings

# Upload APK via REST API [BOTH]
curl -F "file=@[APK_PATH]" http://localhost:8000/api/v1/upload \
  -H "Authorization: [MOBSF_API_KEY]"
# Returns: {"hash": "[SCAN_HASH]", ...}

# Start scan [BOTH]
curl http://localhost:8000/api/v1/scan \
  -d "hash=[SCAN_HASH]&re_scan=0" \
  -H "Authorization: [MOBSF_API_KEY]"

# Get JSON report [BOTH]
curl http://localhost:8000/api/v1/report_json \
  -d "hash=[SCAN_HASH]" \
  -H "Authorization: [MOBSF_API_KEY]" | python3 -m json.tool

# Download PDF [BOTH]
curl http://localhost:8000/api/v1/download_pdf \
  -d "hash=[SCAN_HASH]" \
  -H "Authorization: [MOBSF_API_KEY]" \
  -o mobsf-report-[TARGET_PACKAGE].pdf

# Dynamic analysis: start dynamic scan [ROOTED]
# Requires emulator connected via ADB
curl http://localhost:8000/api/v1/dynamic/start_analysis \
  -d "hash=[SCAN_HASH]&identifier=[TARGET_PACKAGE]&activity=[MAIN_ACTIVITY]&...&re_scan=0" \
  -H "Authorization: [MOBSF_API_KEY]"

# Stop dynamic [ROOTED]
curl http://localhost:8000/api/v1/dynamic/stop_analysis \
  -d "hash=[SCAN_HASH]" \
  -H "Authorization: [MOBSF_API_KEY]"
```

---

## 7. Drozer <a name="drozer"></a>

```bash
# Install [BOTH]
pip3 install drozer
# Or: pip3 install https://github.com/WithSecureLabs/drozer/releases/latest/download/drozer.whl

# Install agent APK on device [BOTH]
# Download: https://github.com/WithSecureLabs/drozer/releases
adb install drozer-agent-[VERSION].apk
# Enable agent on device: open app → Embedded Server → On

# Connect [BOTH]
adb forward tcp:31415 tcp:31415
drozer console connect

# Full command reference (in drozer REPL):
dz> help
dz> list  # all available modules

# App analysis [BOTH]
dz> run app.package.list -f [KEYWORD]
dz> run app.package.info -a [TARGET_PACKAGE]
dz> run app.package.attacksurface [TARGET_PACKAGE]

# Activities [BOTH]
dz> run app.activity.info -a [TARGET_PACKAGE]
dz> run app.activity.forintent --action android.intent.action.VIEW
dz> run app.activity.start --component [TARGET_PACKAGE] [ACTIVITY]

# Services [BOTH]
dz> run app.service.info -a [TARGET_PACKAGE]
dz> run app.service.start --component [TARGET_PACKAGE] [SERVICE]

# Receivers [BOTH]
dz> run app.broadcast.info -a [TARGET_PACKAGE]
dz> run app.broadcast.send --component [TARGET_PACKAGE] [RECEIVER] --action [ACTION]

# Providers [BOTH]
dz> run app.provider.info -a [TARGET_PACKAGE]
dz> run scanner.provider.finduris -a [TARGET_PACKAGE]
dz> run app.provider.query content://[AUTHORITY]/[PATH]
dz> run scanner.provider.injection -a [TARGET_PACKAGE]
dz> run scanner.provider.traversal -a [TARGET_PACKAGE]

# File read via traversal [BOTH]
dz> run app.provider.read content://[AUTHORITY]/[PATH]
dz> run app.provider.download content://[AUTHORITY]/[TRAVERSAL_PATH] /tmp/output.txt
```

---

## 8. Objection <a name="objection"></a>

```bash
# Install [BOTH]
pip3 install objection

# Patch APK with gadget [UNROOTED]
objection patchapk --source [APK_PATH]
# Output: [APK_NAME].objection.apk
# Then sign and install (see apktool section)

# Connect to running process [ROOTED]
objection -g [TARGET_PACKAGE] explore

# Connect via gadget [UNROOTED]
objection -g Gadget explore

# Key REPL commands:
android sslpinning disable        # bypass SSL pinning
android root disable              # bypass root detection
android fingerprint bypass        # bypass biometric

android hooking list classes      # all classes
android hooking list class_methods [CLASS_NAME]
android hooking watch class_method [CLASS].[METHOD] \
  --dump-args --dump-return --dump-backtrace
android hooking watch class [CLASS] --dump-args --dump-return

android keystore list
android clipboard monitor
env                               # data directories
android file ls                   # /data/data/[pkg]/
android file download [path]

memory list modules
memory search "41 42 43" --string
memory list exports [MODULE]

ios sslpinning disable  # iOS equivalent
ios keychain dump
```

---

## 9. Frida <a name="frida"></a>

```bash
# Install [BOTH]
pip3 install frida-tools

# Full reference: subskills/frida/SKILL.md
# Quick commands:
frida --version
frida-ls-devices                         # list devices
frida-ps -U                              # processes on USB device
frida-ps -Ua                             # installed apps
frida -U -f [TARGET_PACKAGE] -l [SCRIPT] --no-pause  # spawn + inject
frida -U -n [PROCESS_NAME] -l [SCRIPT]  # attach to running
frida-trace -U -f [TARGET_PACKAGE] -j '*!*[KEYWORD]*'  # trace Java methods

# Server setup [ROOTED]
# Download matching frida-server binary for device ABI
FRIDA_VER=$(frida --version)
ABI=$(adb shell getprop ro.product.cpu.abi)
# arm64-v8a | armeabi-v7a | x86 | x86_64
wget "https://github.com/frida/frida/releases/download/${FRIDA_VER}/frida-server-${FRIDA_VER}-android-arm64.xz"
xz -d frida-server-${FRIDA_VER}-android-arm64.xz
adb push frida-server-${FRIDA_VER}-android-arm64 /data/local/tmp/frida-server
adb shell chmod 755 /data/local/tmp/frida-server
adb shell su -c "/data/local/tmp/frida-server &"
```

---

## 10. Burp Suite <a name="burp"></a>

```bash
# Community edition: free, sufficient for most tests
# Pro: needed for Intruder without rate limit, Scanner, BCHECK

# Setup: see references/network-analysis.md for full proxy setup

# Key Burp settings for mobile:
# Proxy → Options → Bind to: 0.0.0.0:[BURP_PORT]
# Proxy → Options → Certificate: Generate CA-signed per-host certificate

# Useful extensions [BOTH]
# - Logger++: comprehensive request/response logging with filter
# - Autorize: automated auth testing
# - JSON Web Tokens: JWT analysis and manipulation  
# - Hackvertor: encoding/decoding in requests
# - Param Miner: hidden parameter discovery

# Export CA cert for device install [BOTH]
# Proxy → Options → CA Certificate → Export → Certificate in DER format
openssl x509 -inform DER -in cacert.der -out cacert.pem
openssl x509 -inform DER -subject_hash_old -in cacert.der | head -1  # get filename hash

# Intruder for API fuzzing [BOTH]
# 1. Capture request → Send to Intruder
# 2. Positions tab → Add § around fuzz targets
# 3. Payloads → load wordlist or FUZZ_PAYLOAD list
# 4. Start Attack

# mitmproxy alternative [BOTH]
pip3 install mitmproxy
mitmproxy --listen-host 0.0.0.0 --listen-port [BURP_PORT]
mitmweb  # web UI version
```

---

## 11. scrcpy <a name="scrcpy"></a>

```bash
# Install [BOTH]
sudo apt install scrcpy
# or: brew install scrcpy

# Mirror device [BOTH]
scrcpy
scrcpy -s [DEVICE_ID]        # specific device
scrcpy --max-size 1024       # limit resolution
scrcpy --bit-rate 4M         # limit bitrate

# Record (critical for PoC evidence) [BOTH]
scrcpy --record evidence/poc-$(date +%Y%m%d-%H%M%S).mp4
scrcpy --no-display --record evidence/poc.mp4   # record only, no display

# Keyboard shortcuts in scrcpy:
# Ctrl+C: stop recording
# Ctrl+Shift+Z: toggle portrait/landscape
# Ctrl+Click: right click on device
```

---

## 12. semgrep <a name="semgrep"></a>

```bash
# Install [BOTH]
pip3 install semgrep

# Android rulesets [BOTH]
semgrep --config=p/android [TARGET_PACKAGE]-jadx/
semgrep --config=p/owasp-top-ten [TARGET_PACKAGE]-jadx/
semgrep --config=p/secrets [TARGET_PACKAGE]-jadx/
semgrep --config=p/java [TARGET_PACKAGE]-jadx/

# All configs at once [BOTH]
semgrep --config=p/android --config=p/secrets --config=p/owasp-top-ten \
  [TARGET_PACKAGE]-jadx/ --output results.json --json

# Custom rules [BOTH]
cat > custom-android.yaml << 'EOF'
rules:
  - id: android-hardcoded-key
    pattern: |
      new SecretKeySpec("...", $ALG)
    message: Hardcoded encryption key
    severity: ERROR
    languages: [java]

  - id: android-weak-algo
    pattern: |
      Cipher.getInstance("AES/ECB/...")
    message: ECB mode is insecure
    severity: ERROR
    languages: [java]
EOF
semgrep --config custom-android.yaml [TARGET_PACKAGE]-jadx/
```

---

## 13. ripgrep / grep <a name="ripgrep"></a>

```bash
# Install [BOTH]
sudo apt install ripgrep

# Key patterns for mobile security:
# Secrets [BOTH]
rg -i 'api[_-]?key|apikey|secret|password|token|bearer' \
  --type java [TARGET_PACKAGE]-jadx/

# Weak crypto [BOTH]
rg -in '"DES"\|"RC4"\|"MD5"\|"AES/ECB"\|new Random()' \
  --type java [TARGET_PACKAGE]-jadx/

# WebView sinks [BOTH]
rg -n 'loadUrl\|evaluateJavascript\|addJavascriptInterface' \
  --type java [TARGET_PACKAGE]-jadx/

# SQL injection patterns [BOTH]
rg -n 'rawQuery\|execSQL' --type java [TARGET_PACKAGE]-jadx/ | grep -v '?'

# Case-insensitive, with context [BOTH]
rg -in -B2 -A3 'PATTERN' [TARGET_PACKAGE]-jadx/

# Count matches per file [BOTH]
rg -c 'PATTERN' [TARGET_PACKAGE]-jadx/ | sort -t: -k2 -nr | head -20

# Only show filenames [BOTH]
rg -l 'PATTERN' [TARGET_PACKAGE]-jadx/
```

---

## 14. Ghidra / radare2 <a name="ghidra"></a>

```bash
# Ghidra (GUI) [BOTH]
# Download: https://github.com/NationalSecurityAgency/ghidra/releases
# Analyze: File → Import File → [LIB].so → Analyze

# radare2 [BOTH]
sudo apt install radare2
# or: pip3 install r2pipe

# Basic radare2 usage [BOTH]
r2 -A [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so
# In r2 REPL:
# aa   → analyze all
# afl  → list functions
# afl | grep ssl  → filter functions
# pdf @sym.SSL_write  → disassemble function
# iz   → strings
# iz | grep -i key  → search strings
# iE   → exports (symbols)
# iI   → binary info
# axt @sym.SSL_write  → cross-references to function

# r2frida (Frida + radare2) [BOTH]
r2 frida://[TARGET_PACKAGE]
# In r2 REPL:
# \i   → device info
# \is  → list imports
# \il  → list libraries
# \dm  → memory maps
# df   → attach to function

# strings extraction [BOTH]
strings [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so | \
  grep -iE 'key|secret|password|http|api|token' | head -30

# nm - symbol table [BOTH]
nm -D [TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so 2>/dev/null | head -50

# checksec [BOTH]
checksec --file=[TARGET_PACKAGE]-raw/lib/arm64-v8a/[LIB].so
# Look for: PIE (Position Independent Exec), NX (No-Execute), Stack Canary, RELRO
```

---

## 15. Python Utilities <a name="python"></a>

```bash
# APK backup converter [BOTH]
python3 -c "
import zlib, sys
data = open('backup.ab', 'rb').read()[24:]  # skip 24-byte header
sys.stdout.buffer.write(zlib.decompress(data))
" > backup.tar

# JWT decode [BOTH]
python3 << 'EOF'
import base64, json, sys
token = sys.argv[1] if len(sys.argv) > 1 else "[JWT_TOKEN]"
parts = token.split('.')
def decode(s):
    s += '=' * (4 - len(s) % 4)
    return json.loads(base64.b64decode(s).decode())
print("Header:", json.dumps(decode(parts[0]), indent=2))
print("Payload:", json.dumps(decode(parts[1]), indent=2))
EOF

# Decrypt AES-CBC from Frida dump [BOTH]
python3 << 'EOF'
from Crypto.Cipher import AES
key = bytes.fromhex('[KEY_HEX]')
iv = bytes.fromhex('[IV_HEX]')
ct = bytes.fromhex('[CT_HEX]')
cipher = AES.new(key, AES.MODE_CBC, iv)
print("Plaintext:", cipher.decrypt(ct))
EOF

# Burp traffic parser [BOTH]
python3 << 'EOF'
import base64
from xml.etree import ElementTree as ET
tree = ET.parse('burp-history.xml')
for item in tree.findall('.//item'):
    url = item.find('url').text or ''
    method = item.find('method').text or ''
    req = base64.b64decode(item.find('request').text or '').decode('utf-8', errors='ignore')
    if any(k in req.lower() for k in ['password','token','secret','auth']):
        print(f"\n[!] {method} {url}")
        print(req[:500])
EOF
```
