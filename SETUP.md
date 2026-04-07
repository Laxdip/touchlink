# TouchLink — Complete Setup Guide

## What You're Building
A private couple app where two users pair via a 6-character code and send
vibration "touches" to each other using Firebase Cloud Messaging.

---

## Prerequisites

| Tool | Install |
|------|---------|
| Flutter SDK ≥ 3.0 | https://docs.flutter.dev/get-started/install |
| Android Studio | https://developer.android.com/studio |
| Firebase account | https://console.firebase.google.com |
| Node.js ≥ 18 (for Firebase CLI) | https://nodejs.org |

---

## Step 1 — Create a Firebase Project

1. Go to https://console.firebase.google.com
2. Click **Add project** → name it `touchlink` → click Continue
3. Disable Google Analytics (not needed for MVP) → **Create project**

---

## Step 2 — Enable Firebase Services

### Authentication
1. Sidebar → **Authentication** → Get Started
2. **Sign-in method** tab → Enable **Anonymous** → Save

### Firestore Database
1. Sidebar → **Firestore Database** → Create database
2. Choose **Start in production mode** → pick a region → Done
3. Go to **Rules** tab → replace with contents of `firestore.rules`
4. Click **Publish**

### Cloud Messaging (FCM)
1. Sidebar → **Project Settings** (gear icon)
2. **Cloud Messaging** tab
3. Copy your **Server Key** (Legacy) — you'll need it in Step 6

---

## Step 3 — Add Android App to Firebase

1. In Firebase Console → **Project Overview** → **Add app** → Android icon
2. Android package name: `com.yourname.touchlink`
   (must match `applicationId` in `android/app/build.gradle`)
3. Download `google-services.json`
4. Place it at: `android/app/google-services.json`

---

## Step 4 — Configure FlutterFire (auto-generates firebase_options.dart)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# In your project root:
flutterfire configure
# → Select your Firebase project
# → Select android (and ios if needed)
# → This creates lib/firebase_options.dart automatically
```

> **If you skip FlutterFire CLI**, manually fill in the values in
> `lib/firebase_options.dart` from:
> Firebase Console → Project Settings → General → Your apps

---

## Step 5 — Update build.gradle Files

### android/build.gradle (project level)
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.1'
    }
}
```

### android/app/build.gradle (app level)
```gradle
plugins {
    id 'com.android.application'
    id 'kotlin-android'
    id 'com.google.gms.google-services'   // ← Add this line
}

android {
    compileSdk 34
    defaultConfig {
        applicationId "com.yourname.touchlink"   // ← Match Firebase
        minSdk 21
        targetSdk 34
    }
}
```

---

## Step 6 — Add Your FCM Server Key

Open `lib/services/notification_service.dart` and replace:

```dart
const String serverKey = 'YOUR_FCM_SERVER_KEY';
```

With your actual key from:
**Firebase Console → Project Settings → Cloud Messaging → Server Key (Legacy)**

> ⚠️ **Security Note for Production:**
> Calling FCM directly from the app exposes your server key.
> For a production app, move this call to a Firebase Cloud Function:
>
> ```javascript
> // functions/index.js
> const functions = require('firebase-functions');
> const admin = require('firebase-admin');
> admin.initializeApp();
>
> exports.sendTouch = functions.https.onCall(async (data, context) => {
>   if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '...');
>   await admin.messaging().send({
>     token: data.targetToken,
>     data: data.payload,
>     android: { priority: 'high' },
>   });
>   return { success: true };
> });
> ```

---

## Step 7 — Install Dependencies & Run

```bash
# From project root:
flutter pub get

# Run on connected Android device or emulator:
flutter run
```

---

## Step 8 — Test End-to-End

1. Install on **two devices** (or one device + one emulator)
2. **Device A**: Tap "✨ Create a Connection" → note the 6-char code
3. **Device B**: Tap "🔗 Join with a Code" → enter the code → Connect
4. Both devices land on **HomeScreen**
5. **Device A**: Tap the 💗 button → **Device B** vibrates!

### Touch types:
| Gesture | Result |
|---------|--------|
| Single tap | Short vibration (200ms) |
| Double tap (within 300ms) | Two short vibrations |
| Long press (hold) | Long vibration (800ms) |

---

## File Structure

```
touchlink/
├── lib/
│   ├── main.dart                    ← App entry, Firebase init, routing
│   ├── firebase_options.dart        ← Auto-generated Firebase config
│   ├── screens/
│   │   ├── pairing_screen.dart      ← Create / Join screen
│   │   └── home_screen.dart         ← Send Touch screen
│   ├── services/
│   │   ├── firebase_service.dart    ← Firestore + Auth logic
│   │   ├── notification_service.dart← FCM setup + send/receive
│   │   └── vibration_service.dart   ← Vibration patterns
│   ├── models/
│   │   └── user_model.dart          ← Data models
│   └── utils/
│       └── constants.dart           ← All app constants
├── android/
│   └── app/
│       ├── google-services.json     ← Download from Firebase
│       └── src/main/AndroidManifest.xml
├── pubspec.yaml                     ← Dependencies
├── firestore.rules                  ← Copy to Firebase Console
└── SETUP.md                         ← This file
```

---

## Firestore Data Structure

```
connections/               (collection)
  └── {CODE}/              (document, e.g. "AB3X7K")
        ├── code:          "AB3X7K"
        ├── userAId:       "firebase-uid-of-user-a"
        ├── userAToken:    "fcm-token-of-user-a"
        ├── userBId:       "firebase-uid-of-user-b"  ← empty until joined
        ├── userBToken:    "fcm-token-of-user-b"     ← empty until joined
        ├── active:        true/false
        └── createdAt:     "2024-01-01T00:00:00Z"
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `google-services.json not found` | Place it in `android/app/` not project root |
| Notification not delivered | Check FCM Server Key is correct |
| Vibration doesn't work on emulator | Emulators don't vibrate — test on real device |
| `firebase_options.dart` missing | Run `flutterfire configure` |
| Code not found when joining | Check Firestore Rules are published correctly |
| App crashes on launch | Ensure Firebase is initialized before `runApp()` |

---

## Anonymous Mode

When the toggle is **ON**:
- FCM data payload is sent **without** a `notification` field
- Partner's phone **only vibrates** — nothing appears in notification shade
- Perfect for a subtle "thinking of you" tap

When the toggle is **OFF**:
- Partner sees: **"💗 Touch received"** with a description in their notification
- Useful if partner's phone is on silent and they might miss the vibration

---

## Dependencies Used

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Anonymous authentication |
| `cloud_firestore` | Pairing + token storage |
| `firebase_messaging` | FCM push notifications |
| `flutter_local_notifications` | Foreground notification display |
| `vibration` | Custom vibration patterns |
| `shared_preferences` | Local persistence (connection code) |
| `http` | FCM HTTP API calls |
| `uuid` | Unique ID generation |
