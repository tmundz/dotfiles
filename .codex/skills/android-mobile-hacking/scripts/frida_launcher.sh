#!/bin/bash
# frida_launcher.sh — start frida-server or connect via gadget
# Usage: ./scripts/frida_launcher.sh [TARGET_PACKAGE] [SCRIPT_PATH] [rooted|gadget]

TARGET_PACKAGE="${1}"
FRIDA_SCRIPT="${2:-subskills/frida/scripts/universal-ssl-unpin.js}"
MODE="${3:-auto}"

# Auto-detect device context
IS_ROOTED=$(adb shell id 2>/dev/null | grep -c "uid=0" || echo "0")

if [ "$MODE" = "auto" ]; then
    if [ "$IS_ROOTED" = "1" ]; then
        MODE="rooted"
    else
        MODE="gadget"
    fi
fi

echo "[*] Device context: $MODE"
echo "[*] Target: $TARGET_PACKAGE"
echo "[*] Script: $FRIDA_SCRIPT"

if [ "$MODE" = "rooted" ]; then
    # Check if frida-server running
    RUNNING=$(adb shell ps 2>/dev/null | grep -c frida-server || echo "0")
    if [ "$RUNNING" = "0" ]; then
        echo "[*] Starting frida-server..."
        FRIDA_VER=$(frida --version 2>/dev/null)
        ABI=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
        SERVER_BIN="frida-server-${FRIDA_VER}-android-${ABI}"

        if adb shell ls /data/local/tmp/frida-server > /dev/null 2>&1; then
            adb shell su -c "/data/local/tmp/frida-server &" &
            sleep 2
            echo "[+] frida-server started"
        else
            echo "[!] frida-server not found at /data/local/tmp/frida-server"
            echo "[!] Download: https://github.com/frida/frida/releases/download/${FRIDA_VER}/${SERVER_BIN}.xz"
            echo "[!] Then: xz -d ${SERVER_BIN}.xz && adb push ${SERVER_BIN} /data/local/tmp/frida-server && adb shell chmod 755 /data/local/tmp/frida-server"
            exit 1
        fi
    else
        echo "[+] frida-server already running"
    fi

    if [ -z "$TARGET_PACKAGE" ]; then
        echo "[+] frida-server running. Usage:"
        echo "    frida-ps -U            # list processes"
        echo "    frida -U -f $TARGET_PACKAGE -l [SCRIPT] --no-pause"
        exit 0
    fi

    echo "[*] Launching: frida -U -f $TARGET_PACKAGE -l $FRIDA_SCRIPT --no-pause"
    frida -U -f "$TARGET_PACKAGE" -l "$FRIDA_SCRIPT" --no-pause 2>&1 | \
        tee -a braindump/session_log.md

elif [ "$MODE" = "gadget" ]; then
    echo "[*] Gadget mode — connecting to Gadget process..."

    if [ -z "$TARGET_PACKAGE" ]; then
        echo "[!] Launch the repackaged app first, then run this script"
        echo "    Usage: $0 [TARGET_PACKAGE] [SCRIPT] gadget"
        exit 1
    fi

    echo "[*] Waiting for gadget to appear..."
    sleep 2

    echo "[*] Connecting: frida -U -n Gadget -l $FRIDA_SCRIPT"
    frida -U -n Gadget -l "$FRIDA_SCRIPT" 2>&1 | \
        tee -a braindump/session_log.md
fi
