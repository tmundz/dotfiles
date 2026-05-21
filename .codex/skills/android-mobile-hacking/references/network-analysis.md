# Network Analysis Reference

**MASVS:** MASVS-NETWORK-1, MASVS-NETWORK-2
**MASTG Tests:** MASTG-TEST-0019 through MASTG-TEST-0023
**OWASP:** M5 (Insecure Communication)

## Table of Contents
1. [Burp Suite Setup — Rooted](#burp-rooted)
2. [Burp Suite Setup — Unrooted](#burp-unrooted)
3. [SSL Pinning Bypass Methods](#ssl-bypass)
4. [Traffic Analysis](#traffic)
5. [TLS Weakness Testing](#tls)
6. [Cleartext Detection](#cleartext)
7. [Certificate Pinning Detection](#pin-detection)
8. [API Endpoint Discovery](#api-discovery)

---

## 1. Burp Suite Setup — Rooted [ROOTED] <a name="burp-rooted"></a>

```bash
# 1. Start Burp on host, bind to 0.0.0.0:[BURP_PORT]

# 2. Configure proxy on device [ROOTED]
adb shell settings put global http_proxy [BURP_IP]:[BURP_PORT]
# Remove: adb shell settings put global http_proxy :0

# 3. Export and push Burp CA cert [ROOTED]
# In Burp: Proxy → Options → Export CA certificate → DER format
# Get OpenSSL hash for Android cert filename:
openssl x509 -inform DER -subject_hash_old -in cacert.der | head -1
# Output e.g.: 9a5ba575

# 4. Push as system CA [ROOTED]
adb push cacert.der /sdcard/
adb shell su -c "cp /sdcard/cacert.der /system/etc/security/cacerts/9a5ba575.0"
adb shell su -c "chmod 644 /system/etc/security/cacerts/9a5ba575.0"
adb shell su -c "chown root:root /system/etc/security/cacerts/9a5ba575.0"

# 5. For writable /system on emulator [ROOTED]
adb shell avbctl disable-verification
adb reboot
adb root
adb remount
adb push cacert.der /system/etc/security/cacerts/9a5ba575.0
adb shell chmod 644 /system/etc/security/cacerts/9a5ba575.0
adb reboot

# 6. Verify cert installed [ROOTED]
adb shell ls /system/etc/security/cacerts/ | grep 9a5ba575

# 7. ADB port forward (alternative to WiFi proxy) [ROOTED]
adb reverse tcp:[BURP_PORT] tcp:[BURP_PORT]
# Configure device WiFi proxy to 127.0.0.1:[BURP_PORT]
```

---

## 2. Burp Suite Setup — Unrooted [UNROOTED] <a name="burp-unrooted"></a>

### Method A: User Cert Store + NSC Override

```bash
# 1. Export Burp cert in DER format → rename to .cer
cp cacert.der cacert.cer

# 2. Install as user cert [UNROOTED]
adb push cacert.cer /sdcard/burp.cer
# On device: Settings → Security → Install Certificate → CA Certificate → burp.cer

# 3. Patch NSC to trust user certs [UNROOTED]
# Replace res/xml/network_security_config.xml:
cat > nsc_patch.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system"/>
            <certificates src="user"/>
        </trust-anchors>
    </base-config>
</network-security-config>
EOF

# Rebuild APK with patched NSC [UNROOTED]
apktool d [APK_PATH] -o [TARGET_PACKAGE]-decoded/
cp nsc_patch.xml [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml
# If no NSC exists, add to manifest:
# android:networkSecurityConfig="@xml/network_security_config"
apktool b [TARGET_PACKAGE]-decoded/ -o [TARGET_PACKAGE]-patched.apk
zipalign -v 4 [TARGET_PACKAGE]-patched.apk [TARGET_PACKAGE]-aligned.apk
apksigner sign --ks ~/.android/debug.keystore \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android \
  [TARGET_PACKAGE]-aligned.apk
adb install -r [TARGET_PACKAGE]-aligned.apk

# 4. Set WiFi proxy to Burp [UNROOTED]
# Manual: WiFi → Proxy → Manual → [BURP_IP]:[BURP_PORT]
# Via ADB:
adb shell settings put global http_proxy [BURP_IP]:[BURP_PORT]
```

### Method B: VPN-based Interception [UNROOTED]

```bash
# Use: ProxyDroid, Drony, or HTTP Toolkit on device
# Or: mitmproxy with transparent proxy mode + VPN app

# mitmproxy transparent (requires device VPN app)
mitmproxy --mode transparent --showhost
# On device: configure VPN pointing to mitmproxy host

# HTTP Toolkit (recommended for unrooted)
# Install HTTP Toolkit Android app → intercepts without root
```

### Method C: Frida Gadget + SSL bypass [UNROOTED]

```bash
# Most reliable for pinned apps — see subskills/frida/SKILL.md
# objection patchapk → install → connect → android sslpinning disable
```

---

## 3. SSL Pinning Bypass Methods <a name="ssl-bypass"></a>

### Cascade approach — try in order until one works:

**UNROOTED cascade (no frida-server possible):**
```bash
# Level 1: objection patchapk — repackages APK with gadget [UNROOTED]
objection patchapk --source [APK_PATH]
adb install -r [APK_BASENAME].objection.apk
# Connect: objection -g [TARGET_PACKAGE] explore
# Then: android sslpinning disable

# Level 2: Frida universal script via gadget [UNROOTED]
# (gadget must already be injected — see subskills/frida/SKILL.md gadget setup)
frida -U -n Gadget -l subskills/frida/scripts/universal-ssl-unpin.js

# Level 3: apk-mitm (auto-patches NSC + pinning) [UNROOTED]
npm install -g apk-mitm
apk-mitm [APK_PATH]
adb install -r [APK_NAME]-patched.apk

# Level 4: NSC cleartext override [UNROOTED]
# (see Method A above — patch res/xml/network_security_config.xml)

# Level 5: Manual smali patch [UNROOTED]
# In JADX: find SSL pinning class (OkHttpClient.Builder.certificatePinner)
# In smali: find corresponding method, replace body with return-void
# apktool b → zipalign → apksigner → adb install -r
```

**ROOTED cascade (frida-server running):**
```bash
# Level 1: objection explore [ROOTED]
objection -g [TARGET_PACKAGE] explore
# android sslpinning disable

# Level 2: Frida universal script [ROOTED]
frida -U -f [TARGET_PACKAGE] \
  -l subskills/frida/scripts/universal-ssl-unpin.js --no-pause

# Level 3: Hook specific library [ROOTED]
# If using Retrofit + OkHttp3:
rg -n 'certificatePinner\|CertificatePinner\|\.pinnedPublicKeys' [TARGET_PACKAGE]-jadx/
# Hook that specific class via custom Frida script

# Level 4: Native SSL bypass (libssl.so) [ROOTED]
frida -U -f [TARGET_PACKAGE] -l ssl-native-bypass.js --no-pause
```

```javascript
// ssl-native-bypass.js — hook native SSL verification
var SSL_CTX_set_verify = Module.getExportByName('libssl.so', 'SSL_CTX_set_verify');
if (SSL_CTX_set_verify) {
  Interceptor.attach(SSL_CTX_set_verify, {
    onEnter: function(args) {
      args[1] = ptr(0);  // SSL_VERIFY_NONE
      console.log('[*] SSL_CTX_set_verify → NONE');
    }
  });
}

var SSL_CTX_set_cert_verify_callback = Module.getExportByName('libssl.so', 'SSL_CTX_set_cert_verify_callback');
if (SSL_CTX_set_cert_verify_callback) {
  Interceptor.attach(SSL_CTX_set_cert_verify_callback, {
    onEnter: function(args) {
      args[1] = new NativeCallback(function() { return 1; }, 'int', ['pointer','pointer']);
    }
  });
}
```

---

## 4. Traffic Analysis <a name="traffic"></a>

```bash
# In Burp — key things to check for each request/response:
# 1. Authorization header format (Bearer, Basic, HMAC, JWT)
# 2. Custom auth headers
# 3. Session token entropy (length, character set, pattern)
# 4. Sensitive data in URL query params (logs to server access log)
# 5. Sensitive data in response (PII, internal IDs, stack traces)
# 6. CORS headers (Access-Control-Allow-Origin: *)
# 7. Security headers (missing HSTS, X-Frame-Options, etc.)
# 8. API versioning (v1 vs v2 — old versions may be unprotected)
# 9. Insecure cookies (missing Secure, HttpOnly, SameSite flags)

# Wireshark capture (parallel with Burp) [BOTH]
# On host — capture interface connected to device network:
wireshark -i en0 -f "host [DEVICE_IP]"

# Check for non-HTTP protocols [BOTH]
# WebSocket, MQTT, XMPP, custom TCP
adb shell ss -tunp  # show open connections from device

# Capture all traffic including non-HTTP [ROOTED]
adb shell su -c "tcpdump -i any -w /sdcard/capture.pcap"
adb pull /sdcard/capture.pcap ./
wireshark capture.pcap

# Burp logger++ extension for comprehensive logging
# Burp: Extensions → BApp Store → Logger++

# Export Burp traffic for analysis [BOTH]
# Proxy → HTTP history → right-click → Save items → XML
python3 << 'EOF'
import xml.etree.ElementTree as ET
tree = ET.parse('burp-traffic.xml')
for item in tree.findall('.//item'):
    url = item.find('url').text
    method = item.find('method').text
    req = item.find('request').text
    print(f"{method} {url}")
EOF
```

---

## 5. TLS Weakness Testing <a name="tls"></a>

```bash
# TLS version and cipher audit [BOTH]
testssl.sh [TARGET_HOST]
testssl.sh --full [TARGET_HOST]

# Nmap ssl enumeration [BOTH]
nmap --script ssl-enum-ciphers -p 443 [TARGET_HOST]
nmap --script ssl-cert -p 443 [TARGET_HOST]

# Check for weak protocols [BOTH]
nmap --script ssl-enum-ciphers -p 443 [TARGET_HOST] | \
  grep -E "TLSv1\.0|TLSv1\.1|SSLv3|SSLv2|RC4|DES|NULL|EXPORT|anon"

# sslscan [BOTH]
sslscan [TARGET_HOST]:443

# Check certificate validity [BOTH]
echo | openssl s_client -connect [TARGET_HOST]:443 2>/dev/null | openssl x509 -noout -dates

# Check for self-signed cert [BOTH]
echo | openssl s_client -connect [TARGET_HOST]:443 2>/dev/null | openssl x509 -noout -issuer -subject | \
  awk '{if ($0 ~ /issuer/) print; if ($0 ~ /subject/) print}'
# issuer == subject → self-signed

# HSTS check [BOTH]
curl -I https://[TARGET_HOST] | grep -i strict-transport-security

# Certificate transparency check [BOTH]
curl "https://crt.sh/?q=[TARGET_HOST]&output=json" | python3 -m json.tool | head -50
```

---

## 6. Cleartext Detection <a name="cleartext"></a>

```bash
# Static: check usesCleartextTraffic [BOTH]
grep -E 'usesCleartextTraffic|cleartextTrafficPermitted' \
  [TARGET_PACKAGE]-decoded/AndroidManifest.xml \
  [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml 2>/dev/null

# Static: find http:// URLs [BOTH]
rg -i 'http://' [TARGET_PACKAGE]-jadx/ | \
  grep -v '//android\|//java\|//www.w3\|//schemas\|//xmlns\|//com.google'

# Dynamic: tcpdump for HTTP [ROOTED]
adb shell su -c "tcpdump -i any port 80 -A" | grep -iE 'password|token|secret'

# Dynamic: mitmproxy transparent [BOTH]
mitmproxy --mode transparent --showhost

# Dynamic: check all non-443 traffic [ROOTED]
adb shell su -c "tcpdump -i any not port 443 -A -l" | tee cleartext-traffic.txt

# Check WebView cleartext [BOTH]
rg -n 'http://' [TARGET_PACKAGE]-jadx/ | grep -i 'loadUrl\|Uri'
```

---

## 7. Certificate Pinning Detection <a name="pin-detection"></a>

```bash
# Static detection [BOTH]
rg -n 'CertificatePinner\|certificatePinner\|pin(Sha\|sha256\|sha1' [TARGET_PACKAGE]-jadx/
rg -n 'TrustManagerImpl\|X509TrustManager\|checkServerTrusted' [TARGET_PACKAGE]-jadx/
rg -n 'SSLPeerUnverifiedException\|SSLException\|CertPathValidatorException' [TARGET_PACKAGE]-jadx/

# NSC pinning [BOTH]
grep -A5 '<pin-set' [TARGET_PACKAGE]-decoded/res/xml/network_security_config.xml

# TrustKit detection [BOTH]
rg -in 'trustkit\|TrustKit\|com.datatheorem.android.trustkit' [TARGET_PACKAGE]-jadx/

# OkHttp3 builder with pinner [BOTH]
rg -n 'OkHttpClient.Builder\(\)' [TARGET_PACKAGE]-jadx/ -A20 | grep -i 'pin\|cert'

# Custom TrustManager [BOTH]
rg -n 'implements.*X509TrustManager' [TARGET_PACKAGE]-jadx/
rg -n 'extends.*SSLSocketFactory' [TARGET_PACKAGE]-jadx/

# Dynamic detection: trigger SSL error → catch exception type [BOTH]
# If app crashes with SSLPeerUnverifiedException → pinning active
# If app hangs or shows error dialog → pinning active
# If traffic appears in Burp → no pinning (or already bypassed)
```

---

## 8. API Endpoint Discovery <a name="api-discovery"></a>

```bash
# Extract all URLs from decompiled code [BOTH]
rg -oE 'https?://[a-zA-Z0-9._/-]+' [TARGET_PACKAGE]-jadx/ | \
  grep -v '//android\|//java\|//schemas\|//xmlns' | sort -u

# Extract from strings.xml [BOTH]
grep -oE 'https?://[^"<]+' [TARGET_PACKAGE]-decoded/res/values/strings.xml

# Extract from assets [BOTH]
find [TARGET_PACKAGE]-raw/assets/ -type f | xargs grep -hoE 'https?://[^"<> ]+' 2>/dev/null | sort -u

# Endpoint discovery via Burp sitemap
# Exercise all app features, then:
# Target → Sitemap → right-click target → Engagement tools → Discover content

# API fuzzing via Burp Intruder [BOTH]
# Capture base request, send to Intruder
# Fuzz: path segments, parameters, headers
# Payloads: path traversal, IDOR IDs, verb tampering (GET→POST→PUT→DELETE)

# Check for dev/staging endpoints [BOTH]
rg -in 'staging\|dev\|test\|debug\|internal\|sandbox' [TARGET_PACKAGE]-jadx/ | \
  grep -iE 'url|host|endpoint|api|base'

# Check for hidden admin endpoints [BOTH]
# In Burp: try /admin, /internal, /debug, /v2, /api/admin
for path in /admin /internal /debug /v2/admin /api/admin /api/v1/admin /console; do
  curl -sk -o /dev/null -w "%{http_code} $path\n" \
    -H "Authorization: Bearer [TOKEN]" \
    https://[TARGET_HOST]$path
done
```
