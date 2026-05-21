#!/bin/bash
# burp_setup.sh — configure Burp proxy on device
# Usage: ./scripts/burp_setup.sh [BURP_IP] [BURP_PORT] [rooted|unrooted]

BURP_IP="${1:-192.168.1.100}"
BURP_PORT="${2:-8080}"
MODE="${3:-auto}"

# Auto-detect
IS_ROOTED=$(adb shell id 2>/dev/null | grep -c "uid=0" || echo "0")
if [ "$MODE" = "auto" ]; then
    if [ "$IS_ROOTED" = "1" ]; then MODE="rooted"; else MODE="unrooted"; fi
fi

echo "[*] Setting up Burp proxy: $BURP_IP:$BURP_PORT (mode: $MODE)"

# Configure proxy
adb shell settings put global http_proxy "$BURP_IP:$BURP_PORT"
echo "[+] WiFi proxy configured: $BURP_IP:$BURP_PORT"

# ADB reverse forward (if Burp on localhost)
adb reverse tcp:"$BURP_PORT" tcp:"$BURP_PORT" 2>/dev/null && \
    echo "[+] ADB reverse forward: device:$BURP_PORT → host:$BURP_PORT"

if [ "$MODE" = "rooted" ]; then
    echo "[*] Rooted mode — installing system CA cert..."
    if [ ! -f "burp_cacert.der" ]; then
        echo "[!] burp_cacert.der not found in current directory"
        echo "[!] Export from Burp: Proxy → Options → CA Certificate → DER format"
        echo "[!] Then re-run this script"
        exit 1
    fi

    HASH=$(openssl x509 -inform DER -subject_hash_old -in burp_cacert.der | head -1)
    echo "[*] Certificate hash: $HASH"

    adb root && adb remount
    adb push burp_cacert.der /sdcard/
    adb shell su -c "cp /sdcard/burp_cacert.der /system/etc/security/cacerts/${HASH}.0"
    adb shell su -c "chmod 644 /system/etc/security/cacerts/${HASH}.0"
    adb shell su -c "chown root:root /system/etc/security/cacerts/${HASH}.0"
    echo "[+] Burp CA installed as system cert: ${HASH}.0"
    echo "[+] Trust anchors include Burp CA — intercepting all apps"

else
    echo "[*] Unrooted mode — installing user CA cert..."
    if [ ! -f "burp_cacert.der" ]; then
        echo "[!] burp_cacert.der not found"
        echo "[!] Export from Burp: Proxy → Options → CA Certificate → DER format"
        exit 1
    fi

    # Push as user cert
    cp burp_cacert.der burp_cacert.cer
    adb push burp_cacert.cer /sdcard/burp_cacert.cer
    echo "[+] Cert pushed to /sdcard/burp_cacert.cer"
    echo "[!] Manual step: Settings → Security → Install certificate → CA Certificate → burp_cacert.cer"
    echo ""
    echo "[!] IMPORTANT for unrooted: NSC must be patched to trust user certs."
    echo "[!] If app doesn't use NSC or NSC doesn't trust user certs:"
    echo "[!]   Option 1: patch APK NSC (see references/network-analysis.md)"
    echo "[!]   Option 2: use frida SSL bypass (see subskills/frida/SKILL.md)"
    echo "[!]   Option 3: use objection: android sslpinning disable"
fi

echo ""
echo "[+] Burp setup complete"
echo "    Verify: start Burp → Proxy → Intercept → should see traffic from device"
echo ""
echo "[*] To remove proxy: adb shell settings put global http_proxy :0"
