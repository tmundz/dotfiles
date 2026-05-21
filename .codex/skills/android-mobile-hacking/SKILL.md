---
name: android-mobile-hacking
description: Expert Android mobile security testing, bug bounty hunting, and penetration testing. Covers static analysis, dynamic analysis, network interception, Frida instrumentation, and vulnerability exploitation. Use when testing Android app security, mobile pentesting, APK analysis, bug bounty on Android, SSL pinning bypass, Frida hooking, ADB exploitation, content provider testing, deep link fuzzing, intent injection, Android reversing, OWASP Mobile Top 10, MASVS/MASTG testing, drozer, objection, apktool, JADX, MobSF, or any Android security task. Also use for APK analysis, root detection bypass, intercepting Android traffic, or Android CTF challenges.
---

# Android Mobile Hacking — Master Orchestrator

## Session Start Protocol (MANDATORY)

Before ANY work, run this sequence every session:

### Step 1: Detect Device Context

```bash
adb devices -l
adb shell whoami 2>/dev/null || echo "no-shell"
adb shell id 2>/dev/null | grep -c "root" || echo "0"
```

**Context A — Rooted Emulator/Device:** `id` returns uid=0 or `whoami` returns root
**Context B — Unrooted Live Device:** non-root uid, restricted shell

Announce detected context to user. Every technique in this skill is tagged:
- `[ROOTED]` — requires root/emulator
- `[UNROOTED]` — works without root
- `[BOTH]` — works in both contexts

### Step 2: Load BrainDump State

```bash
mkdir -p braindump
```

Read ALL of these files if they exist (they are the source of truth for the engagement):
- `braindump/session_log.md` — full action history
- `braindump/methodology_state.md` — current phase, tried techniques, dead ends
- `braindump/findings_map.md` — attack surface map with test statuses
- `braindump/high_signal.md` — prioritized targets from last session
- `braindump/poc_log.md` — all PoC attempts and results

After reading, announce: "Resuming engagement. Last phase: [X]. High signal targets: [Y]."
If files don't exist, initialize them (see BrainDump Maintenance below).

### Step 3: Initialize BrainDump (first session only)

Create all braindump files with headers. Then proceed to Attack Surface Mapping.

---

## Attack Surface Mapping (Phase 1)

When given a new APK or package, run full surface mapping before testing:

```bash
# Pull APK from device [BOTH]
adb shell pm list packages | grep [TARGET_PACKAGE]
adb shell pm path [TARGET_PACKAGE]
adb pull [APK_PATH_FROM_DEVICE] ./[TARGET_PACKAGE].apk

# Decode APK [BOTH]
apktool d [APK_PATH] -o [TARGET_PACKAGE]-decoded/
jadx -d [TARGET_PACKAGE]-jadx/ [APK_PATH]

# Extract manifest [BOTH]
cat [TARGET_PACKAGE]-decoded/AndroidManifest.xml
```

Parse and log to `braindump/findings_map.md`:
- `android:exported="true"` components (Activities, Services, Receivers, Providers)
- `android:debuggable="true"` flag
- `android:allowBackup="true"` flag
- `android:networkSecurityConfig` reference
- Deep link schemes (`<data android:scheme=...>`)
- Permissions declared and requested
- `<provider android:authorities=...>` URIs

**Flag all exported components as [HIGH SIGNAL] immediately.**

---

## Testing Phases

### Phase 1: Static Analysis
Read `references/static-analysis.md` for full methodology.
Key: JADX source search, secret hunting with ripgrep, smali analysis.

### Phase 2: Dynamic Analysis
Read `references/dynamic-analysis.md` for full methodology.
Key: ADB intent fuzzing, content provider exploitation, backup extraction, logcat monitoring.

### Phase 3: Network Analysis
Read `references/network-analysis.md` for full methodology.
Key: Burp proxy setup, SSL pinning bypass, traffic capture and analysis.

### Phase 4: Frida Instrumentation
Read `references/mastg-techniques.md` for Frida-based MASTG techniques.
Key: Runtime hooking, SSL/root bypass, crypto key extraction, memory scanning.
Scripts: `scripts/frida_launcher.sh` for quick Frida setup.

### Phase 5: PoC Development & Reporting
Read `references/poc-app-creation.md` for PoC templates.
Read `references/reporting.md` for finding templates and submission guidance.

---

## MASVS/MASTG Coverage

Every test maps to MASVS controls and MASTG test cases.
See `references/masvs-checklist.md` for complete control-to-command mapping.
See `references/mastg-techniques.md` for every MASTG test procedure.

---

## Tool Quick Reference

| Tool | Purpose | Context |
|------|---------|---------|
| adb | Device bridge, all shell commands | [BOTH] |
| apktool | Decode/rebuild APK, smali | [BOTH] |
| jadx | Java decompilation | [BOTH] |
| MobSF | Automated static+dynamic scan | [BOTH] |
| drozer | Component exploitation | [BOTH] (agent APK) |
| objection | Runtime patching, SSL bypass | [BOTH] (gadget on unrooted) |
| frida/frida-gadget | Dynamic instrumentation | [ROOTED]/[UNROOTED] via gadget |
| Burp Suite | Traffic interception | [BOTH] |
| semgrep | Static pattern analysis | [BOTH] |
| ripgrep | Secret/sink hunting | [BOTH] |
| scrcpy | Screen mirror + PoC recording | [BOTH] |
| Ghidra/r2 | Native .so analysis | [BOTH] |

Full tool setup: `references/toolchain.md`
Full ADB reference: `references/adb-commands.md`

---

## BrainDump Maintenance (CRITICAL — update continuously)

**ALL tool output MUST go to `braindump/session_log.md`**

Append every action result:
```bash
echo "[$(date -u)] [ACTION] [RESULT]" >> braindump/session_log.md
```

For long-running tools, pipe directly:
```bash
frida -U -f [PKG] -l script.js --no-pause 2>&1 | tee -a braindump/session_log.md
logcat -d 2>&1 | tee -a braindump/session_log.md
```

After every finding or failed technique, update `braindump/methodology_state.md`.

Mark HIGH SIGNAL items: `[HIGH SIGNAL]` — exported components, world-readable files, cleartext traffic, hardcoded secrets, deprecated crypto.

Log every PoC to `braindump/poc_log.md`:
```
## PoC: [name] [TIMESTAMP]
**Command:** [exact command]
**Result:** [SUCCESS/FAIL]
**Evidence:** [logcat snippet / screenshot path / capture path]
```

---

## Unrooted Device Fallbacks [UNROOTED]

When Context B detected, automatically use:
- **Frida:** gadget injection (repackage APK)
- **SSL pinning bypass:** smali patch or network_security_config override
- **Burp cert:** user cert store + NSC override or smali patch
- **Drozer:** sideload agent APK, connect via ADB forward
- **Objection:** launch via frida-gadget
- **Root detection:** patch smali or use gadget + Frida hook

---

## OWASP Mobile Top 10 Quick Map

| ID | Risk | Primary Ref |
|----|------|------------|
| M1 | Improper Credential Usage | `references/owasp-mobile-top10.md` |
| M2 | Inadequate Supply Chain Security | `references/owasp-mobile-top10.md` |
| M3 | Insecure Authentication/Authorization | `references/owasp-mobile-top10.md` |
| M4 | Insufficient Input/Output Validation | `references/owasp-mobile-top10.md` |
| M5 | Insecure Communication | `references/owasp-mobile-top10.md` |
| M6 | Inadequate Privacy Controls | `references/owasp-mobile-top10.md` |
| M7 | Insufficient Binary Protections | `references/owasp-mobile-top10.md` |
| M8 | Security Misconfiguration | `references/owasp-mobile-top10.md` |
| M9 | Insecure Data Storage | `references/owasp-mobile-top10.md` |
| M10 | Insufficient Cryptography | `references/owasp-mobile-top10.md` |

## Scripts

- `scripts/setup_emulator.sh` — set up Android emulator for testing
- `scripts/burp_setup.sh` — configure Burp Suite proxy with Android
- `scripts/apk_extract.sh` — extract and decode APK files
- `scripts/frida_launcher.sh` — launch Frida server and attach to process
