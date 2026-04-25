# 🔥 Firebase Setup + APK Build Complete Guide

## Overview
You need Firebase to build the APK and use push notifications. This guide covers:
1. Getting google-services.json from Firebase
2. Placing it in the correct location
3. Building the APK

**Total Time: ~15-20 minutes**

---

## STEP 1: Get google-services.json from Firebase Console

### 1.1 Go to Firebase Console
```
https://console.firebase.google.com
```
Log in and select your UniSync project

### 1.2 Download google-services.json
1. Click the gear icon ⚙️ (Settings)
2. Click "Project Settings"
3. Go to "Your apps" section
4. You should see an Android app entry (if not, add one)
5. Click the download icon next to Android app
6. Download `google-services.json`

**IMPORTANT:** This is DIFFERENT from the Service Account JSON you used for OneSignal.
- Service Account JSON (for backend): firebase-adminsdk-xxxxx.json
- google-services.json (for Android app): google-services.json ← **YOU NEED THIS ONE**

### 1.3 Save the File
Keep the downloaded `google-services.json` file

---

## STEP 2: Place google-services.json in Project

### 2.1 Location
Copy the downloaded `google-services.json` to:
```
unisync/android/app/google-services.json
```

**Path Format:**
```
unisync/
├── android/
│   └── app/
│       └── google-services.json  ← PUT IT HERE
└── lib/
```

### 2.2 Verify
Open the file you put in `android/app/google-services.json` and check:
- Contains `"project_id"` field
- Contains `"package_name": "com.unisync.unisync"`
- Is valid JSON (no syntax errors)

---

## STEP 3: Update .env File

Open `.env` file in project root and add:

```
ONESIGNAL_APP_ID=your-app-id-from-onesignal
```

**Where to get:** OneSignal Dashboard → Settings → Keys & IDs → OneSignal App ID

---

## STEP 4: Build the APK

### 4.1 Open Terminal
Open Command Prompt or Terminal in your project root folder

### 4.2 Clean Build
```bash
flutter clean
```

### 4.3 Get Dependencies
```bash
flutter pub get
```

### 4.4 Run Build Runner (for Isar)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4.5 Build APK (Release)
```bash
flutter build apk --release
```

**Wait for build to complete...**

### 4.6 Find Your APK
If build succeeds, APK location:
```
build/app/outputs/apk/release/app-release.apk
```

**Success Message:**
```
✓ Built build/app/outputs/apk/release/app-release.apk (XX.X MB).
```

---

## STEP 5: Test the APK

### 5.1 Transfer to Phone
- Copy `app-release.apk` to your Android phone
- Or use ADB to install:
```bash
flutter install build/app/outputs/apk/release/app-release.apk
```

### 5.2 Install on Phone
- Open file manager on phone
- Find the APK file
- Tap to install
- Allow installation from unknown sources if prompted

### 5.3 Test the App
1. Launch UniSync app
2. Tap "Allow" for notifications
3. Login
4. Create an announcement
5. Check if you get a push notification

**✅ SUCCESS:** You should get a notification!

---

## Troubleshooting

### Problem: Build fails with "Could not find google-services.json"
**Solution:**
- Check file is at: `android/app/google-services.json` (exact path!)
- Run `flutter clean` again
- Rebuild

### Problem: "package_name mismatch" error
**Solution:**
- Check `android/app/google-services.json` has:
```
"package_name": "com.unisync.unisync"
```
- It should match your app package name

### Problem: "Firebase plugin not found"
**Solution:**
- Run: `flutter pub get`
- The pubspec.yaml was updated with Firebase dependencies
- Rebuild after running pub get

### Problem: Build hangs or is very slow
**Solution:**
- First build is always slow (downloads dependencies)
- Wait 5-10 minutes
- Or cancel and run: `flutter build apk --release -v` (verbose to see progress)

### Problem: "Gradle build failed"
**Solution:**
1. Run: `flutter clean`
2. Run: `flutter pub get`
3. Run: `dart run build_runner build --delete-conflicting-outputs`
4. Try: `flutter build apk --release` again

---

## Quick Reference Checklist

- [ ] Downloaded google-services.json from Firebase Console
- [ ] Placed it at: `unisync/android/app/google-services.json`
- [ ] Updated .env with ONESIGNAL_APP_ID
- [ ] Ran: `flutter clean`
- [ ] Ran: `flutter pub get`
- [ ] Ran: `dart run build_runner build --delete-conflicting-outputs`
- [ ] Ran: `flutter build apk --release`
- [ ] Found APK at: `build/app/outputs/apk/release/app-release.apk`
- [ ] Installed APK on phone
- [ ] Tested push notifications

---

## Important Notes

### What Changed in This Project
1. **pubspec.yaml** - Added Firebase dependencies:
   ```
   firebase_core: ^3.2.0
   firebase_messaging: ^15.1.0
   ```

2. **android/build.gradle** - Added Google Services plugin:
   ```
   id "com.google.gms.google-services" version "4.4.2"
   ```

3. **android/app/build.gradle** - Added Firebase plugin and dependencies

4. **android/app/google-services.json** - Template file (YOU NEED TO ADD YOUR OWN)

### Why Firebase?
- OneSignal requires Firebase for Android push notifications
- Firebase provides the FCM (Firebase Cloud Messaging) service
- OneSignal and Firebase work together for notifications

### Can I Use Just OneSignal?
- No, not for Android. Firebase is required.
- OneSignal is built on top of Firebase for Android
- For iOS, OneSignal can work independently

---

## Next Steps After APK Build

1. **Test on multiple devices** - Install on different Android phones
2. **Test notifications** - Create announcements and verify notifications arrive
3. **Create signing key** - For production release (ask if needed)
4. **Upload to Play Store** - When ready to launch (separate process)

---

## Still Having Issues?

Check these in order:
1. Is google-services.json at correct path? (`android/app/google-services.json`)
2. Did you run `flutter pub get` after extraction?
3. Did you run `flutter clean` before building?
4. Is your Firebase project properly set up with Android app?
5. Are you using the RIGHT google-services.json (from Firebase Console, not Service Account)?

---

**Good luck! 🚀 Your APK build should work now!**
