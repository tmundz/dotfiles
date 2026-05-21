#!/bin/bash
# setup_emulator.sh — configure rooted Android emulator for security testing
# Usage: ./setup_emulator.sh [AVD_NAME] [BURP_IP] [BURP_PORT]

set -e

AVD_NAME="${1:-pentest_avd}"
BURP_IP="${2:-192.168.1.100}"
BURP_PORT="${3:-8080}"

echo "[*] Starting emulator: $AVD_NAME"
emulator -avd "$AVD_NAME" -writable-system -no-snapshot &
EMULATOR_PID=$!

echo "[*] Waiting for boot..."
adb wait-for-device
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 2
done
echo "[+] Emulator booted"

echo "[*] Rooting ADB..."
adb root
adb remount

echo "[*] Disabling AVB verification..."
adb shell avbctl disable-verification 2>/dev/null || true
adb reboot
adb wait-for-device
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 2
done
adb root
adb remount

echo "[*] Setting Burp proxy: $BURP_IP:$BURP_PORT"
adb shell settings put global http_proxy "$BURP_IP:$BURP_PORT"

echo "[*] Installing Burp CA certificate..."
if [ -f "burp_cacert.der" ]; then
    HASH=$(openssl x509 -inform DER -subject_hash_old -in burp_cacert.der | head -1)
    adb push burp_cacert.der /sdcard/
    adb shell su -c "cp /sdcard/burp_cacert.der /system/etc/security/cacerts/${HASH}.0"
    adb shell su -c "chmod 644 /system/etc/security/cacerts/${HASH}.0"
    adb shell su -c "chown root:root /system/etc/security/cacerts/${HASH}.0"
    echo "[+] Burp CA installed with hash: $HASH"
else
    echo "[!] burp_cacert.der not found — install CA manually"
fi

echo "[*] Disabling SELinux (permissive mode)..."
adb shell su -c "setenforce 0" 2>/dev/null || true
echo "[+] SELinux: $(adb shell getenforce)"

echo "[*] Verifying setup..."
echo "    ADB user: $(adb shell id)"
echo "    SELinux: $(adb shell getenforce)"
echo "    Proxy: $(adb shell settings get global http_proxy)"
echo "    SDK: $(adb shell getprop ro.build.version.sdk)"
echo "    ABI: $(adb shell getprop ro.product.cpu.abi)"

echo "[+] Emulator ready for security testing"
echo "    Start Frida server with: ./scripts/frida_launcher.sh"
echo "    Set up Burp proxy and start testing"
