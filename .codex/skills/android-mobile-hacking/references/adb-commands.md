# ADB Commands Reference — Android Security Testing

**Full reference: every ADB command useful for mobile security testing**
**Every command tagged [ROOTED], [UNROOTED], or [BOTH]**

## Table of Contents
1. [Device Connection](#connection)
2. [Package Management](#packages)
3. [File Operations](#files)
4. [Shell Commands](#shell)
5. [Intent System](#intents)
6. [Content Providers](#providers)
7. [Logcat](#logcat)
8. [Port Forwarding](#port)
9. [Backup & Restore](#backup)
10. [Settings](#settings)
11. [Screen & Recording](#screen)
12. [Network](#network)
13. [App Lifecycle](#lifecycle)
14. [Security-Specific](#security)

---

## 1. Device Connection <a name="connection"></a>

```bash
# List connected devices [BOTH]
adb devices
adb devices -l  # with transport details

# Connect to specific device [BOTH]
adb -s [DEVICE_ID] shell

# Set default device env var [BOTH]
export ANDROID_SERIAL=[DEVICE_ID]

# Connect over TCP/IP [BOTH]
adb tcpip 5555
adb connect [DEVICE_IP]:5555

# Restart ADB server [BOTH]
adb kill-server
adb start-server

# Root ADB (emulator / eng builds) [ROOTED]
adb root
adb remount  # make /system writable

# Restart as non-root [BOTH]
adb unroot

# Get device properties [BOTH]
adb shell getprop
adb shell getprop ro.product.cpu.abi     # device ABI
adb shell getprop ro.build.version.sdk   # API level
adb shell getprop ro.build.version.release  # Android version
adb shell getprop ro.debuggable          # 1 = eng/userdebug build
adb shell getprop ro.product.model       # device model
adb shell getprop ro.serialno            # serial number
```

---

## 2. Package Management <a name="packages"></a>

```bash
# List all packages [BOTH]
adb shell pm list packages
adb shell pm list packages -3           # third-party only
adb shell pm list packages | grep [TARGET_PACKAGE]

# Get APK path [BOTH]
adb shell pm path [TARGET_PACKAGE]
# Output: package:/data/app/[TARGET_PACKAGE]-xxx/base.apk

# Pull APK from device [BOTH]
adb pull $(adb shell pm path [TARGET_PACKAGE] | cut -d: -f2) ./[TARGET_PACKAGE].apk

# Install APK [BOTH]
adb install [APK_PATH]
adb install -r [APK_PATH]               # replace existing
adb install -d [APK_PATH]               # allow version downgrade
adb install -g [APK_PATH]               # grant all permissions at install

# Uninstall [BOTH]
adb uninstall [TARGET_PACKAGE]
adb uninstall -k [TARGET_PACKAGE]       # keep data

# Get package info [BOTH]
adb shell dumpsys package [TARGET_PACKAGE]
adb shell pm dump [TARGET_PACKAGE]

# List package permissions [BOTH]
adb shell pm list permissions -g -d | grep -A5 [TARGET_PACKAGE]

# Grant/revoke permissions [BOTH]
adb shell pm grant [TARGET_PACKAGE] android.permission.READ_CONTACTS
adb shell pm revoke [TARGET_PACKAGE] android.permission.READ_CONTACTS

# Clear app data [BOTH]
adb shell pm clear [TARGET_PACKAGE]

# Disable/enable app [ROOTED]
adb shell pm disable [TARGET_PACKAGE]
adb shell pm enable [TARGET_PACKAGE]

# Force stop [BOTH]
adb shell am force-stop [TARGET_PACKAGE]

# Get app version [BOTH]
adb shell dumpsys package [TARGET_PACKAGE] | grep versionName

# List installed apps with version [BOTH]
adb shell pm list packages -3 | cut -d: -f2 | while read pkg; do
  ver=$(adb shell dumpsys package $pkg | grep versionName | head -1 | tr -d ' ')
  echo "$pkg $ver"
done
```

---

## 3. File Operations <a name="files"></a>

```bash
# Push file to device [BOTH]
adb push [LOCAL_FILE] [DEVICE_PATH]
adb push frida-server /data/local/tmp/frida-server

# Pull file from device [BOTH]
adb pull [DEVICE_PATH] [LOCAL_DEST]
adb pull /data/local/tmp/capture.pcap ./

# Pull directory [BOTH]
adb pull /sdcard/Android/data/[TARGET_PACKAGE]/ ./external-data/

# List files [BOTH]
adb shell ls -la [PATH]
adb shell ls -la /sdcard/Android/data/[TARGET_PACKAGE]/

# List app data (run-as for debuggable) [UNROOTED]
adb shell run-as [TARGET_PACKAGE] ls -la
adb shell run-as [TARGET_PACKAGE] ls -la shared_prefs/
adb shell run-as [TARGET_PACKAGE] cat shared_prefs/prefs.xml

# List app data (root) [ROOTED]
adb shell su -c "ls -la /data/data/[TARGET_PACKAGE]/"
adb shell su -c "find /data/data/[TARGET_PACKAGE]/ -type f"

# Read files (root) [ROOTED]
adb shell su -c "cat /data/data/[TARGET_PACKAGE]/shared_prefs/*.xml"
adb shell su -c "cat /data/data/[TARGET_PACKAGE]/files/[FILE]"

# Create directory [BOTH]
adb shell mkdir -p /data/local/tmp/frida/

# Delete file [BOTH]
adb shell rm /data/local/tmp/test.txt
adb shell rm -rf /sdcard/Android/data/[TARGET_PACKAGE]/cache/

# Set permissions [ROOTED]
adb shell su -c "chmod 755 /data/local/tmp/frida-server"
adb shell su -c "chmod 644 /system/etc/security/cacerts/9a5ba575.0"

# Check file permissions [BOTH]
adb shell ls -la /data/local/tmp/

# Find files by pattern [BOTH]
adb shell find /sdcard/ -name "*.db" -o -name "*.sqlite" 2>/dev/null
adb shell find /sdcard/ -name "*.json" 2>/dev/null
```

---

## 4. Shell Commands <a name="shell"></a>

```bash
# Interactive shell [BOTH]
adb shell

# Single command [BOTH]
adb shell [COMMAND]

# Root shell [ROOTED]
adb shell su -c "[COMMAND]"
adb shell su 0 [COMMAND]

# Process list [BOTH]
adb shell ps
adb shell ps | grep [TARGET_PACKAGE]
adb shell pidof [TARGET_PACKAGE]

# Process memory [ROOTED]
adb shell su -c "cat /proc/[PID]/maps"
adb shell su -c "cat /proc/[PID]/mem"  # requires special handling

# Network connections [BOTH]
adb shell ss -tunp
adb shell netstat -tunp  # older Android

# CPU/memory [BOTH]
adb shell top -n 1 | grep [TARGET_PACKAGE]
adb shell dumpsys meminfo [TARGET_PACKAGE]
adb shell dumpsys cpuinfo | grep [TARGET_PACKAGE]

# System info [BOTH]
adb shell uname -a
adb shell cat /proc/version
adb shell df -h

# Clipboard [BOTH]
adb shell am broadcast -a clipper.get  # requires Clipper app
# Or use: adb shell service call clipboard 2 ... (complex, use Frida instead)

# Run binary [BOTH]
adb shell /data/local/tmp/frida-server &
adb shell chmod 755 /data/local/tmp/[BINARY] && /data/local/tmp/[BINARY]
```

---

## 5. Intent System <a name="intents"></a>

```bash
# Start activity [BOTH]
adb shell am start -n [TARGET_PACKAGE]/[ACTIVITY_CLASSNAME]
adb shell am start -n [TARGET_PACKAGE]/com.example.MainActivity

# Start with action and data [BOTH]
adb shell am start -a android.intent.action.VIEW -d "https://example.com"
adb shell am start -a android.intent.action.VIEW -d "[SCHEME]://[HOST]/[PATH]"

# Start with extras [BOTH]
adb shell am start -n [TARGET_PACKAGE]/[ACTIVITY] \
  --es "key" "string_value" \
  --ei "intkey" 42 \
  --ez "boolkey" true \
  --ef "floatkey" 3.14 \
  --el "longkey" 9999999 \
  --eu "urikey" "https://example.com" \
  --esa "arraykey" "val1,val2"

# Start with deep link [BOTH]
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://[HOST]/[PATH]?[PARAMS]"

# Start service [BOTH]
adb shell am startservice -n [TARGET_PACKAGE]/[SERVICE_CLASSNAME]
adb shell am startservice -n [TARGET_PACKAGE]/[SERVICE] --es cmd "test"

# Stop service [BOTH]
adb shell am stopservice -n [TARGET_PACKAGE]/[SERVICE_CLASSNAME]

# Send broadcast [BOTH]
adb shell am broadcast -a [ACTION]
adb shell am broadcast -a com.example.ACTION --es data "value"
adb shell am broadcast -a android.intent.action.BOOT_COMPLETED
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true

# Force-stop app [BOTH]
adb shell am force-stop [TARGET_PACKAGE]

# Kill process [BOTH]
adb shell am kill [TARGET_PACKAGE]

# Activity manager info [BOTH]
adb shell am get-config
adb shell dumpsys activity [TARGET_PACKAGE]
adb shell dumpsys activity top  # currently visible activity

# Test deep link with URL encode [BOTH]
URL_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('[PAYLOAD]'))")
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://[HOST]?param=${URL_ENCODED}"
```

---

## 6. Content Providers <a name="providers"></a>

```bash
# Query provider [BOTH]
adb shell content query --uri content://[AUTHORITY]/[PATH]
adb shell content query --uri content://[AUTHORITY]/[PATH] \
  --projection "column1,column2" \
  --where "id=?" --arg "1" \
  --sort "id ASC"

# SQL injection test [BOTH]
adb shell content query \
  --uri content://[AUTHORITY]/users \
  --where "1=1 UNION SELECT name,sql,NULL FROM sqlite_master--"

# Insert row [BOTH]
adb shell content insert \
  --uri content://[AUTHORITY]/users \
  --bind username:s:"admin" \
  --bind password:s:"password123" \
  --bind role:s:"admin"

# Update row [BOTH]
adb shell content update \
  --uri content://[AUTHORITY]/users \
  --bind role:s:"admin" \
  --where "1=1"

# Delete rows [BOTH]
adb shell content delete \
  --uri content://[AUTHORITY]/users \
  --where "1=1"

# Read file from provider [BOTH]
adb shell content read \
  --uri content://[AUTHORITY]/files/secret.txt

# Call provider method [BOTH]
adb shell content call \
  --uri content://[AUTHORITY] \
  --method [METHOD_NAME] \
  --arg [ARG]

# List accessible providers (via drozer) [BOTH]
adb forward tcp:31415 tcp:31415
drozer console connect
dz> run scanner.provider.finduris -a [TARGET_PACKAGE]
dz> run scanner.provider.injection -a [TARGET_PACKAGE]
dz> run scanner.provider.traversal -a [TARGET_PACKAGE]
```

---

## 7. Logcat <a name="logcat"></a>

```bash
# All logcat [BOTH]
adb logcat

# Filter by app PID [BOTH]
adb logcat --pid=$(adb shell pidof [TARGET_PACKAGE])

# Filter by tag [BOTH]
adb logcat -s AndroidRuntime:E [TAG]:V

# Filter by priority [BOTH]
adb logcat "*:E"         # errors only
adb logcat "*:W"         # warnings and above

# Dump and clear [BOTH]
adb logcat -d > logcat.txt    # dump then exit
adb logcat -c                 # clear logcat buffer

# Format [BOTH]
adb logcat -v time            # with timestamps
adb logcat -v long            # full format
adb logcat -v threadtime      # with thread info

# Search for sensitive data [BOTH]
adb logcat | grep -iE 'password|token|secret|key|auth|credential|email'

# Native crashes [BOTH]
adb logcat | grep -E 'FATAL|tombstone|backtrace'

# Write to file [BOTH]
adb logcat -v time | tee braindump/session_log.md
```

---

## 8. Port Forwarding <a name="port"></a>

```bash
# Forward host port to device port [BOTH]
adb forward tcp:[HOST_PORT] tcp:[DEVICE_PORT]

# Forward for drozer [BOTH]
adb forward tcp:31415 tcp:31415

# Forward for frida-server [ROOTED]
adb forward tcp:27042 tcp:27042

# Reverse forward (device → host) [BOTH]
adb reverse tcp:[DEVICE_PORT] tcp:[HOST_PORT]

# Reverse for Burp (app → host:8080) [BOTH]
adb reverse tcp:[BURP_PORT] tcp:[BURP_PORT]

# List forwards [BOTH]
adb forward --list
adb reverse --list

# Remove forward [BOTH]
adb forward --remove tcp:[HOST_PORT]
adb forward --remove-all
```

---

## 9. Backup & Restore <a name="backup"></a>

```bash
# Full backup [BOTH]
adb backup -f [OUTPUT].ab -all -apk -shared

# App-only backup [BOTH]
adb backup -f backup.ab -noapk [TARGET_PACKAGE]

# Convert to tar [BOTH]
dd if=backup.ab bs=1 skip=24 | \
  python3 -c "import zlib,sys; sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read()))" \
  > backup.tar

# Extract [BOTH]
mkdir backup-extracted
tar xvf backup.tar -C backup-extracted/

# Restore backup [BOTH]
adb restore backup.ab
```

---

## 10. Settings <a name="settings"></a>

```bash
# Configure proxy [BOTH]
adb shell settings put global http_proxy [BURP_IP]:[BURP_PORT]
adb shell settings get global http_proxy
adb shell settings put global http_proxy :0  # remove proxy

# Screen lock [BOTH]
adb shell locksettings clear --old [PIN]
adb shell settings put secure lockscreen.password_type 0  # disable lock

# Check developer options [BOTH]
adb shell settings get global development_settings_enabled

# USB debugging check [BOTH]
adb shell settings get global adb_enabled

# Allow unknown sources [BOTH]
adb shell settings put global install_non_market_apps 1
adb shell settings put secure install_non_market_apps 1

# WiFi proxy via settings [BOTH]
# Use network settings ADB commands (complex, better done via UI)

# Airplane mode [BOTH]
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false

# Get all global settings [BOTH]
adb shell settings list global | grep -i proxy
adb shell settings list secure | grep -i lock
```

---

## 11. Screen & Recording <a name="screen"></a>

```bash
# Screenshot [BOTH]
adb exec-out screencap -p > screenshot.png
adb shell screencap -p /sdcard/screenshot.png && adb pull /sdcard/screenshot.png

# Screen record [BOTH]
adb shell screenrecord /sdcard/poc.mp4  # Ctrl+C to stop
adb shell screenrecord --time-limit 30 /sdcard/poc.mp4  # 30 second limit
adb pull /sdcard/poc.mp4 evidence/

# Mirror via scrcpy [BOTH]
scrcpy -s [DEVICE_ID]
scrcpy --record evidence/poc-$(date +%Y%m%d-%H%M%S).mp4
scrcpy --no-display --record evidence/poc.mp4  # record without display

# Dump UI hierarchy [BOTH]
adb shell uiautomator dump /sdcard/ui.xml
adb pull /sdcard/ui.xml
# Read XML to find UI element IDs for automation

# Swipe/tap [BOTH]
adb shell input tap 540 960          # tap at x,y
adb shell input swipe 500 1000 500 200  # swipe up
adb shell input text "password123"  # type text
adb shell input keyevent 82         # menu key
adb shell input keyevent 4          # back key
adb shell input keyevent 3          # home key
adb shell input keyevent 66         # enter
```

---

## 12. Network <a name="network"></a>

```bash
# Show device IP [BOTH]
adb shell ip addr show wlan0 | grep 'inet '
adb shell ifconfig wlan0

# Network connections [BOTH]
adb shell ss -tunp
adb shell cat /proc/net/tcp          # TCP connections (hex encoded)
adb shell cat /proc/net/tcp6

# DNS [BOTH]
adb shell getprop net.dns1
adb shell getprop net.dns2

# Ping from device [BOTH]
adb shell ping -c 4 8.8.8.8

# tcpdump (if installed or pushed) [ROOTED]
adb push tcpdump /data/local/tmp/
adb shell chmod 755 /data/local/tmp/tcpdump
adb shell su -c "/data/local/tmp/tcpdump -i any -w /sdcard/capture.pcap"
adb pull /sdcard/capture.pcap ./

# WiFi scan [BOTH]
adb shell cmd wifi status
adb shell dumpsys wifi | grep -E 'mNetworkInfo|SSID|BSSID'
```

---

## 13. App Lifecycle <a name="lifecycle"></a>

```bash
# Currently running activities [BOTH]
adb shell dumpsys activity top
adb shell dumpsys activity activities | grep -E 'Activity|mFocused'

# Recent tasks [BOTH]
adb shell dumpsys activity recents

# App state [BOTH]
adb shell dumpsys activity [TARGET_PACKAGE]

# Start/stop app [BOTH]
adb shell am start -n [TARGET_PACKAGE]/[MAIN_ACTIVITY]
adb shell am force-stop [TARGET_PACKAGE]
adb shell am kill [TARGET_PACKAGE]

# Clear app cache [BOTH]
adb shell pm clear [TARGET_PACKAGE]

# Check app running [BOTH]
adb shell pidof [TARGET_PACKAGE]
adb shell ps | grep [TARGET_PACKAGE]

# Watch activity stack [BOTH]
watch -n 1 'adb shell dumpsys activity top | head -30'

# Get current focused activity (useful during testing) [BOTH]
adb shell dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp'
```

---

## 14. Security-Specific <a name="security"></a>

```bash
# Check root [BOTH]
adb shell which su
adb shell test -f /system/bin/su && echo "rooted" || echo "not rooted"
adb shell id

# Check SELinux mode [BOTH]
adb shell getenforce  # Enforcing / Permissive

# Disable SELinux [ROOTED]
adb shell su -c "setenforce 0"

# Check device encryption [BOTH]
adb shell getprop ro.crypto.state    # encrypted / unencrypted
adb shell getprop ro.crypto.type     # file / block

# Check Verified Boot [BOTH]
adb shell getprop ro.boot.verifiedbootstate  # green / yellow / orange / red

# Disable Verified Boot (AVB) on emulator [ROOTED]
adb shell avbctl disable-verification
adb reboot

# Make /system writable (emulator) [ROOTED]
adb root
adb remount
# Or: adb shell "mount -o rw,remount /system"

# Install system CA cert [ROOTED]
HASH=$(openssl x509 -inform DER -subject_hash_old -in cacert.der | head -1)
adb push cacert.der /sdcard/
adb shell su -c "cp /sdcard/cacert.der /system/etc/security/cacerts/${HASH}.0"
adb shell su -c "chmod 644 /system/etc/security/cacerts/${HASH}.0"

# Check keystore entries [ROOTED]
adb shell su -c "ls /data/misc/keystore/"
adb shell su -c "ls /data/misc/keystore/user_0/"

# Dump Keystore (requires root) [ROOTED]
adb shell su -c "cat /data/misc/keystore/user_0/*" 2>/dev/null

# Device attestation check [BOTH]
adb shell getprop ro.boot.flash.locked   # 1 = locked bootloader

# Check if frida-server running [BOTH]
adb shell ps | grep frida-server

# Start frida-server [ROOTED]
adb shell su -c "/data/local/tmp/frida-server &"

# Check app signature [BOTH]
adb shell pm list packages --show-versioncode | grep [TARGET_PACKAGE]

# Trigger garbage collection (for memory analysis) [BOTH]
adb shell am dumpheap [TARGET_PACKAGE] /sdcard/heap.hprof
adb pull /sdcard/heap.hprof ./
# Analyze with: jhat, Android Studio Memory Profiler, Eclipse MAT
```
