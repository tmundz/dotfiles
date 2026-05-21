# Android Security-Relevant API Reference

**Focus: APIs that matter for security testing — attack surfaces, data storage, crypto, platform**
**Source: Android developer.android.com/reference + MASTG**

## Table of Contents
1. [Manifest Security Attributes](#manifest)
2. [Storage APIs](#storage)
3. [Cryptography APIs](#crypto)
4. [Network APIs](#network)
5. [Platform Interaction APIs](#platform)
6. [Authentication APIs](#auth)
7. [IPC APIs](#ipc)
8. [WebView APIs](#webview)
9. [Content Provider APIs](#provider)
10. [Security APIs](#security-apis)

---

## 1. Manifest Security Attributes <a name="manifest"></a>

### High-Risk Attributes

| Attribute | Risk | Test |
|-----------|------|------|
| `android:debuggable="true"` | Debug access in prod | grep manifest |
| `android:allowBackup="true"` | ADB backup data theft | grep manifest |
| `android:exported="true"` (no permission) | Component hijacking | drozer/am start |
| `android:networkSecurityConfig` | TLS configuration | check xml |
| `android:usesCleartextTraffic="true"` | HTTP allowed | grep manifest |
| `android:sharedUserId` | Shared Linux UID | privilege escalation |
| `android:permission` (absent on exported) | Missing access control | drozer |
| `android:grantUriPermissions="true"` | URI grant abuse | content provider |
| `android:authorities` | Provider access point | content query |
| `android:launchMode="singleTask"` + taskAffinity | StrandHogg | task hijack |

### Permission Security

```bash
# Dangerous permissions (require runtime grant) [BOTH]
android.permission.READ_CONTACTS
android.permission.WRITE_CONTACTS
android.permission.READ_CALL_LOG
android.permission.CAMERA
android.permission.RECORD_AUDIO
android.permission.ACCESS_FINE_LOCATION
android.permission.ACCESS_COARSE_LOCATION
android.permission.READ_EXTERNAL_STORAGE
android.permission.WRITE_EXTERNAL_STORAGE
android.permission.READ_SMS
android.permission.SEND_SMS
android.permission.CALL_PHONE
android.permission.GET_ACCOUNTS

# Over-privileged check [BOTH]
grep 'uses-permission' [TARGET_PACKAGE]-decoded/AndroidManifest.xml | \
  grep -E 'CAMERA|CONTACTS|LOCATION|SMS|CALL|READ_EXTERNAL|WRITE_EXTERNAL' | \
  wc -l
# High number = likely over-privileged
```

---

## 2. Storage APIs <a name="storage"></a>

### SharedPreferences

```java
// INSECURE — plaintext storage
SharedPreferences prefs = context.getSharedPreferences("app", MODE_PRIVATE);
prefs.edit().putString("token", token).apply();

// MODE_WORLD_READABLE — DEPRECATED but still found in old apps
SharedPreferences prefs = context.getSharedPreferences("app", MODE_WORLD_READABLE);
// → readable by any app [CRITICAL finding]

// SECURE — EncryptedSharedPreferences (Jetpack Security)
MasterKey masterKey = new MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build();
SharedPreferences securePrefs = EncryptedSharedPreferences.create(
    context, "secure_prefs", masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM);
```

```bash
# Test grep [BOTH]
rg -n 'getSharedPreferences\|SharedPreferences' decoded/ --type java | \
  grep -v 'EncryptedSharedPreferences'
# All non-encrypted prefs = potential finding

# Test dynamic [ROOTED]
adb shell su -c "cat /data/data/[TARGET_PACKAGE]/shared_prefs/*.xml"
```

### SQLite

```java
// INSECURE — plaintext SQLite
SQLiteDatabase db = context.openOrCreateDatabase("app.db", MODE_PRIVATE, null);

// INSECURE — SQL injection via rawQuery
db.rawQuery("SELECT * FROM users WHERE id='" + userId + "'", null);

// SECURE — parameterized query
db.rawQuery("SELECT * FROM users WHERE id=?", new String[]{userId});

// SECURE — SQLCipher (encrypted)
import net.sqlcipher.database.SQLiteDatabase;
SQLiteDatabase.loadLibs(context);
SQLiteDatabase db = SQLiteDatabase.openOrCreateDatabase(dbFile, password, null);
```

### File Storage

```java
// INSECURE — external storage (world-readable)
File file = new File(Environment.getExternalStorageDirectory(), "data.txt");

// INSECURE — world-readable (deprecated)
FileOutputStream fos = openFileOutput("creds.txt", MODE_WORLD_READABLE);

// SECURE — internal storage
FileOutputStream fos = openFileOutput("creds.txt", MODE_PRIVATE);

// SECURE — EncryptedFile
MasterKey masterKey = ...;
EncryptedFile encFile = new EncryptedFile.Builder(
    context, file, masterKey,
    EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB).build();
```

---

## 3. Cryptography APIs <a name="crypto"></a>

### Cipher

```java
// INSECURE — ECB mode
Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");

// INSECURE — CBC with static IV
byte[] staticIV = "1234567890123456".getBytes();
Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
cipher.init(Cipher.ENCRYPT_MODE, key, new IvParameterSpec(staticIV));

// SECURE — AES-GCM with random IV
SecureRandom sr = new SecureRandom();
byte[] iv = new byte[12];
sr.nextBytes(iv);
Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(128, iv));
byte[] ciphertext = cipher.doFinal(plaintext);
// Store IV with ciphertext

// Detect via Frida: crypto-dump.js logs all Cipher.init calls
```

### MessageDigest

```java
// INSECURE — MD5, SHA-1
MessageDigest md = MessageDigest.getInstance("MD5");
MessageDigest md = MessageDigest.getInstance("SHA-1");

// SECURE — SHA-256, SHA-3
MessageDigest md = MessageDigest.getInstance("SHA-256");
MessageDigest md = MessageDigest.getInstance("SHA3-256");

// INSECURE — unsalted password hash
byte[] hash = md.digest(password.getBytes());

// SECURE — PBKDF2 for passwords
SecretKeyFactory skf = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
PBEKeySpec spec = new PBEKeySpec(password, salt, 100000, 256);
byte[] hash = skf.generateSecret(spec).getEncoded();
```

### Android Keystore

```java
// SECURE — generate key in Android Keystore
KeyGenerator keyGen = KeyGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
keyGen.init(new KeyGenParameterSpec.Builder("my_key",
    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setUserAuthenticationRequired(true)  // requires biometric/PIN
    .build());
SecretKey key = keyGen.generateKey();

// Key operations
KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
ks.load(null);
SecretKey key = (SecretKey) ks.getKey("my_key", null);
```

```bash
# Test: is Keystore used? [BOTH]
rg -n 'KeyStore\|KeyGenParameterSpec\|AndroidKeyStore' decoded/ --type java

# Test: does key require auth? [BOTH]
rg -n 'setUserAuthenticationRequired' decoded/ --type java
# Missing = key accessible without user auth
```

---

## 4. Network APIs <a name="network"></a>

### HttpsURLConnection / OkHttp

```java
// INSECURE — disabled hostname verification
HttpsURLConnection.setDefaultHostnameVerifier(
    (hostname, session) -> true);

// INSECURE — trust all certs
TrustManager[] trustAll = new TrustManager[]{
    new X509TrustManager() {
        public void checkServerTrusted(X509Certificate[] c, String a) {}
        public void checkClientTrusted(X509Certificate[] c, String a) {}
        public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
    }
};
SSLContext sc = SSLContext.getInstance("TLS");
sc.init(null, trustAll, new SecureRandom());

// INSECURE — WebView SSL bypass
webView.setWebViewClient(new WebViewClient() {
    @Override
    public void onReceivedSslError(WebView v, SslErrorHandler h, SslError e) {
        h.proceed();  // NEVER do this in production
    }
});

// SECURE — OkHttp with pinning
CertificatePinner pinner = new CertificatePinner.Builder()
    .add("api.example.com", "sha256/[BASE64_HASH]")
    .build();
OkHttpClient client = new OkHttpClient.Builder()
    .certificatePinner(pinner)
    .build();
```

### Network Security Configuration

```xml
<!-- SECURE — network_security_config.xml -->
<network-security-config>
    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2026-12-31">
            <pin digest="SHA-256">base64encodedHash=</pin>
            <pin digest="SHA-256">backupHash=</pin>
        </pin-set>
    </domain-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system"/>
            <!-- NOT user: prevents user CA trust -->
        </trust-anchors>
    </base-config>
</network-security-config>
```

---

## 5. Platform Interaction APIs <a name="platform"></a>

### Intent

```java
// SECURE — explicit intent (only specific component receives)
Intent intent = new Intent(context, TargetActivity.class);
intent.putExtra("data", data);
startActivity(intent);

// INSECURE — implicit intent with sensitive data
Intent intent = new Intent("com.example.ACTION_SECRET");
intent.putExtra("token", authToken);
sendBroadcast(intent);  // Any app can receive this!

// INSECURE — starting activity from intent data without validation
Uri uri = getIntent().getData();
String url = uri.getQueryParameter("url");
webView.loadUrl(url);  // Open redirect / XSS

// SECURE — validate URL scheme
if (url != null && (url.startsWith("https://api.example.com"))) {
    webView.loadUrl(url);
}

// PendingIntent — INSECURE (mutable, can be hijacked)
PendingIntent pi = PendingIntent.getActivity(context, 0, intent, 0);
// SECURE:
PendingIntent pi = PendingIntent.getActivity(context, 0, intent,
    PendingIntent.FLAG_IMMUTABLE);
```

### Clipboard

```java
// SENSITIVE — clipboard is accessible to all apps
ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
ClipData clip = ClipData.newPlainText("password", password);
cm.setPrimaryClip(clip);  // Any app can read this
```

---

## 6. Authentication APIs <a name="auth"></a>

### BiometricPrompt (Android 9+)

```java
// INSECURE — auth without cryptographic binding
BiometricPrompt.AuthenticationCallback callback = new BiometricPrompt.AuthenticationCallback() {
    @Override
    public void onAuthenticationSucceeded(AuthenticationResult result) {
        unlockApp();  // Only checks if finger matched, no crypto binding
    }
};

// SECURE — auth with CryptoObject binding
Signature signature = ...; // from Keystore key
BiometricPrompt.CryptoObject cryptoObj = new BiometricPrompt.CryptoObject(signature);
biometricPrompt.authenticate(cryptoObj, cancellationSignal, executor, callback);
// Key operation only possible after biometric success
```

---

## 7. IPC APIs <a name="ipc"></a>

### ContentProvider

```java
// INSECURE — exported without permission
// Manifest: android:exported="true" and no android:permission

// INSECURE — wildcard path in FileProvider
// file_paths.xml: <root-path name="root" path="/"/>

// SECURE — restrictive FileProvider paths
// <files-path name="files" path="documents/"/>

// INSECURE — SQL injection in query
@Override
public Cursor query(Uri uri, String[] projection, String selection,
                    String[] selectionArgs, String sortOrder) {
    return db.rawQuery("SELECT * FROM data WHERE " + selection, null);
    // Should use parameterized queries!
}

// SECURE
return db.query("data", projection, selection, selectionArgs, null, null, sortOrder);
```

### BroadcastReceiver

```java
// INSECURE — exported receiver, no permission
// Manifest: android:exported="true"

// INSECURE — sending broadcast with sensitive data
Intent intent = new Intent("TOKEN_REFRESH");
intent.putExtra("token", newToken);
sendBroadcast(intent);  // Any receiver can intercept

// SECURE — local broadcast (in-process only)
LocalBroadcastManager.getInstance(this).sendBroadcast(intent);

// SECURE — with permission requirement
sendBroadcast(intent, "com.example.RECEIVE_TOKEN");

// SECURE — explicit intent to specific component
intent.setComponent(new ComponentName("com.example", "com.example.TokenReceiver"));
sendBroadcast(intent);
```

---

## 8. WebView APIs <a name="webview"></a>

```java
// HIGH RISK SETTINGS
webView.getSettings().setJavaScriptEnabled(true);  // enables JS execution
webView.getSettings().setAllowFileAccess(true);     // access file:// URIs
webView.getSettings().setAllowUniversalAccessFromFileURLs(true);  // [CRITICAL]
webView.getSettings().setAllowFileAccessFromFileURLs(true);       // [HIGH]

// INSECURE — addJavascriptInterface
// Attacker-controlled HTML can call Java methods!
webView.addJavascriptInterface(new JsInterface(), "Android");

// INSECURE — loadUrl from untrusted source
String url = getIntent().getData().getQueryParameter("url");
webView.loadUrl(url);  // XSS / open redirect

// INSECURE — loadData from untrusted data
webView.loadData(userInput, "text/html", "UTF-8");

// SECURE — validate scheme
if (Uri.parse(url).getScheme().equals("https") &&
    url.startsWith("https://example.com")) {
    webView.loadUrl(url);
}
```

```bash
# Test grep [BOTH]
rg -n 'addJavascriptInterface\|setAllowFileAccess\|setAllowUniversalAccess\|loadUrl' \
  decoded/ --type java -A2

# Dynamic test [BOTH]
# Hook loadUrl via Frida to see all URLs loaded
frida -U -f [TARGET_PACKAGE] -l scripts/frida/webview-hooks.js --no-pause
```

---

## 9. Content Provider APIs <a name="provider"></a>

```java
// ContentResolver — client side
ContentResolver cr = getContentResolver();

// Query
Cursor c = cr.query(
    Uri.parse("content://[AUTHORITY]/[PATH]"),
    null,           // projection (null = all columns)
    "id=?",         // selection
    new String[]{"1"}, // selectionArgs
    null            // sort order
);

// Insert
ContentValues cv = new ContentValues();
cv.put("username", "admin");
Uri newUri = cr.insert(Uri.parse("content://[AUTHORITY]/users"), cv);

// Update
int rows = cr.update(
    Uri.parse("content://[AUTHORITY]/users"),
    cv, "id=?", new String[]{"1"});

// Delete
int deleted = cr.delete(
    Uri.parse("content://[AUTHORITY]/users"),
    "1=1", null);  // delete all

// File read via FileProvider
InputStream is = cr.openInputStream(fileUri);
```

---

## 10. Security APIs <a name="security-apis"></a>

### PackageManager

```java
// Signature check (integrity)
PackageInfo pi = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES);
Signature[] sigs = pi.signingInfo.getApkContentsSigners();
// Compare against known-good signature bytes

// Check if package installed
pm.getApplicationInfo("com.evil.app", 0);  // throws NameNotFoundException if absent
```

### SafetyNet / Play Integrity

```java
// SafetyNet Attestation (deprecated, use Play Integrity)
SafetyNet.getClient(context).attest(nonce, API_KEY)
    .addOnSuccessListener(response -> {
        // Validate JWS response server-side
        String jws = response.getJwsResult();
    });

// Play Integrity API (current)
IntegrityManager integrityManager = IntegrityManagerFactory.create(context);
IntegrityTokenRequest request = IntegrityTokenRequest.builder()
    .setNonce(nonce).build();
integrityManager.requestIntegrityToken(request)
    .addOnSuccessListener(response -> {
        String token = response.token();
        // Send to server for validation
    });
```

```bash
# Detect SafetyNet/Play Integrity [BOTH]
rg -in 'SafetyNet\|SafetyNetApi\|attest\|PlayIntegrity\|IntegrityManager\|IntegrityToken' \
  decoded/ --type java

# Bypass via Frida [BOTH]
# Hook SafetyNet result callback, return mocked pass response
```

### KeyguardManager

```java
// Device security state check
KeyguardManager km = (KeyguardManager) getSystemService(KEYGUARD_SERVICE);
boolean isDeviceSecure = km.isDeviceSecure();  // true if PIN/pattern/password set
boolean isLocked = km.isKeyguardLocked();
```

### FLAG_SECURE

```java
// Prevent screenshots of sensitive screens
getWindow().setFlags(
    WindowManager.LayoutParams.FLAG_SECURE,
    WindowManager.LayoutParams.FLAG_SECURE
);
```

```bash
# Test: can you screenshot this screen? [BOTH]
adb exec-out screencap -p > test.png
# If test.png is black → FLAG_SECURE active
# If test.png shows content → FLAG_SECURE missing
```
