#!/bin/bash
# apk_extract.sh — pull, decode, and decompile APK from device
# Usage: ./scripts/apk_extract.sh com.target.package

set -e

TARGET_PACKAGE="${1}"
if [ -z "$TARGET_PACKAGE" ]; then
    echo "Usage: $0 com.target.package"
    exit 1
fi

echo "[*] Target: $TARGET_PACKAGE"
mkdir -p evidence

# Get APK path
echo "[*] Finding APK on device..."
APK_PATH=$(adb shell pm path "$TARGET_PACKAGE" 2>/dev/null | head -1 | cut -d: -f2 | tr -d '\r')
if [ -z "$APK_PATH" ]; then
    echo "[!] Package not found: $TARGET_PACKAGE"
    exit 1
fi
echo "[+] APK path: $APK_PATH"

# Pull APK
echo "[*] Pulling APK..."
adb pull "$APK_PATH" "./${TARGET_PACKAGE}.apk"
echo "[+] APK saved: ./${TARGET_PACKAGE}.apk"

# Get version info
VERSION=$(adb shell dumpsys package "$TARGET_PACKAGE" | grep versionName | head -1 | sed 's/.*versionName=//' | tr -d ' \r')
echo "[+] Version: $VERSION"

# Verify signature
echo "[*] Verifying signature..."
apksigner verify --print-certs "./${TARGET_PACKAGE}.apk" 2>/dev/null | \
    grep -E 'Signer|Common Name' | head -5

# Decode with apktool
echo "[*] Decoding with apktool..."
apktool d "./${TARGET_PACKAGE}.apk" -o "./${TARGET_PACKAGE}-decoded/" --force
echo "[+] Decoded to: ./${TARGET_PACKAGE}-decoded/"

# Decompile with JADX
echo "[*] Decompiling with JADX..."
jadx -d "./${TARGET_PACKAGE}-jadx/" "./${TARGET_PACKAGE}.apk" 2>/dev/null
echo "[+] Decompiled to: ./${TARGET_PACKAGE}-jadx/"

# Extract raw
echo "[*] Extracting raw APK contents..."
mkdir -p "./${TARGET_PACKAGE}-raw"
unzip -q "./${TARGET_PACKAGE}.apk" -d "./${TARGET_PACKAGE}-raw/"
echo "[+] Extracted to: ./${TARGET_PACKAGE}-raw/"

# Quick manifest analysis
echo ""
echo "=== MANIFEST QUICK SCAN ==="
echo "[exported components]"
grep -E 'android:exported="true"' "./${TARGET_PACKAGE}-decoded/AndroidManifest.xml" 2>/dev/null || echo "  none found"
echo "[debuggable]"
grep 'android:debuggable' "./${TARGET_PACKAGE}-decoded/AndroidManifest.xml" 2>/dev/null || echo "  not set"
echo "[allowBackup]"
grep 'android:allowBackup' "./${TARGET_PACKAGE}-decoded/AndroidManifest.xml" 2>/dev/null || echo "  not set"
echo "[deep link schemes]"
grep 'android:scheme' "./${TARGET_PACKAGE}-decoded/AndroidManifest.xml" 2>/dev/null || echo "  none"
echo "[providers]"
grep 'android:authorities' "./${TARGET_PACKAGE}-decoded/AndroidManifest.xml" 2>/dev/null || echo "  none"
echo "[NSC]"
grep 'networkSecurityConfig' "./${TARGET_PACKAGE}-decoded/AndroidManifest.xml" 2>/dev/null || echo "  not configured"

# Quick secret scan
echo ""
echo "=== QUICK SECRET SCAN ==="
echo "[hardcoded credentials]"
rg -il 'api[_-]?key|apikey|secret|password|token|bearer' \
    "./${TARGET_PACKAGE}-jadx/" --type java 2>/dev/null | head -10 || echo "  none found"

echo ""
echo "[+] Extraction complete!"
echo "    Decoded: ./${TARGET_PACKAGE}-decoded/"
echo "    JADX:    ./${TARGET_PACKAGE}-jadx/"
echo "    Raw:     ./${TARGET_PACKAGE}-raw/"
echo ""
echo "[*] Next: run full static analysis with references/static-analysis.md"
