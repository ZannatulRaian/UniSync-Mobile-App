# UniSync — Complete Setup & Build Guide

---

## PART 1 — Supabase Setup (already done ✅ except Step 2)

### Step 1 — Fill in your .env
Open `.env` in the project root and fill in your values:
```
SUPABASE_URL=https://yourproject.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
ONESIGNAL_APP_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Step 2 — Run Notifications SQL (NEW — do this once)
1. Go to Supabase Dashboard → SQL Editor
2. Open `NOTIFICATIONS_SETUP.sql` from the project root
3. Paste the contents and click **Run**

---

## PART 2 — OneSignal Setup (Push Notifications, no Firebase)

### Step 1 — Create OneSignal Account
1. Go to https://onesignal.com and sign up (free)
2. Click **New App/Website**
3. Name it `UniSync` → click **Next**

### Step 2 — Configure Android Platform
1. Select **Google Android (FCM)**  
   > ⚠️ OneSignal still uses FCM under the hood but YOU don't need a Firebase account.  
   > OneSignal provides a shared FCM sender ID for free — just click **"Use OneSignal's test credentials"** on that screen.
2. Click **Save & Continue**
3. Select **Flutter** as your SDK → click **Save & Continue**

### Step 3 — Get Your Keys
After setup you'll land on the app page:
1. Go to **Settings → Keys & IDs**
2. Copy **OneSignal App ID** → paste into `.env` as `ONESIGNAL_APP_ID`
3. Copy **REST API Key** → you'll need this for Supabase (next step)

### Step 4 — Add REST API Key to Supabase Edge Functions
1. Go to Supabase Dashboard → Edge Functions → **Secrets**
2. Add these two secrets:
   - Name: `ONESIGNAL_APP_ID` → Value: (your OneSignal App ID)
   - Name: `ONESIGNAL_REST_API_KEY` → Value: (your OneSignal REST API Key)

---

## PART 3 — Deploy Supabase Edge Function

### Step 1 — Install Supabase CLI
```powershell
npm install -g supabase
```

### Step 2 — Login and Link Project
```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```
Your project ref = Supabase Dashboard → Settings → General → **Reference ID**

### Step 3 — Deploy
```powershell
supabase functions deploy send-notification
```

---

## PART 4 — Run the App

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

On first launch the app will ask for notification permission — tap **Allow**.

---

## PART 5 — Build the APK

### Debug APK (for testing)
```powershell
flutter build apk --debug
```
File location: `build\app\outputs\flutter-apk\app-debug.apk`

### Release APK (for sharing / installing on phones)

**Step 1 — Create a keystore (do this ONCE, keep it safe)**
```powershell
keytool -genkey -v -keystore C:\Users\YourName\unisync-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias unisync
```
It will ask for a password. Remember it.

**Step 2 — Create `android/key.properties`**
Create this file (do NOT commit it to git):
```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=unisync
storeFile=C:\\Users\\YourName\\unisync-key.jks
```

**Step 3 — Update `android/app/build.gradle`**

At the very top, before the `plugins {` block, add:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Inside `android { }`, add this block before `defaultConfig`:
```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

Change `buildTypes > release` to:
```groovy
release {
    signingConfig signingConfigs.release
    minifyEnabled false
    shrinkResources false
}
```

**Step 4 — Build**
```powershell
flutter build apk --release
```
File: `build\app\outputs\flutter-apk\app-release.apk`

Send this APK file to anyone's phone. They can install it directly.

---

## How Notifications Work

| Action | Who gets notified |
|--------|------------------|
| New announcement posted | All users except poster |
| New event created | All users except organizer |
| New chat message sent | All users except sender |
| New resource uploaded | All users except uploader |

Notifications work even when the app is **closed** on the phone.

---

## Files Changed in This Update

| File | What changed |
|------|-------------|
| `pubspec.yaml` | Removed Firebase, added `onesignal_flutter` |
| `lib/main.dart` | Removed Firebase init, uses OneSignal |
| `lib/services/notification_service.dart` | Fully rewritten for OneSignal |
| `lib/services/announcement_service.dart` | Added notification on post |
| `lib/services/event_service.dart` | Added notification on create |
| `lib/services/chat_service.dart` | Added notification on send |
| `lib/services/resource_service.dart` | Added notification on upload |
| `android/app/src/main/AndroidManifest.xml` | Removed Firebase service |
| `supabase/functions/send-notification/index.ts` | Uses OneSignal API |
| `NOTIFICATIONS_SETUP.sql` | Table for OneSignal player IDs |
| `.env` | Added `ONESIGNAL_APP_ID` field |

---

## Troubleshooting

**Notifications not arriving**
- Make sure you tapped Allow on first launch
- Check `user_push_tokens` table in Supabase — there should be a row for your device
- Make sure the Edge Function is deployed and secrets are set

**`flutter pub get` fails**
- Run `flutter clean` then `flutter pub get` again

**Build fails after adding signing**
- Use double backslashes `\\` in `key.properties` for Windows paths
- Make sure `key.properties` is in the `android/` folder (not the root)
