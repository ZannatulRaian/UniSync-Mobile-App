═══════════════════════════════════════════════════════════════════════════════
                    UNISYNC - FIREBASE + APK BUILD READY
═══════════════════════════════════════════════════════════════════════════════

🎉 YOUR PROJECT IS READY TO BUILD!

What was updated:
✅ Firebase dependencies added to pubspec.yaml
✅ Firebase plugins added to Android Gradle files
✅ google-services.json template created

═══════════════════════════════════════════════════════════════════════════════
                              QUICK START (6 STEPS)
═══════════════════════════════════════════════════════════════════════════════

STEP 1: Download google-services.json from Firebase Console
────────────────────────────────────────────────────────────
1. Go to: https://console.firebase.google.com
2. Select your UniSync project
3. Click ⚙️ Settings → Project Settings
4. Go to "Your apps" section
5. Find Android app → Click download icon
6. Save google-services.json

⚠️  IMPORTANT: NOT the Service Account JSON - this is google-services.json!


STEP 2: Place google-services.json in Project
──────────────────────────────────────────────
Copy downloaded file to:
    unisync/android/app/google-services.json

(Copy the actual google-services.json file you downloaded, replacing the template)


STEP 3: Update .env File
─────────────────────────
Open: unisync/.env

Add:
    ONESIGNAL_APP_ID=your-app-id-from-onesignal

(Replace with your actual OneSignal App ID from OneSignal dashboard → Keys & IDs)


STEP 4: Clean & Get Dependencies
──────────────────────────────────
Open Terminal in project root and run:

    flutter clean
    flutter pub get

Wait for completion...


STEP 5: Build the APK
──────────────────────
Run in Terminal:

    dart run build_runner build --delete-conflicting-outputs
    flutter build apk --release

⏳ This takes 5-10 minutes. Be patient...

When done, you'll see:
    ✓ Built build/app/outputs/apk/release/app-release.apk


STEP 6: Test on Phone
──────────────────────
1. Copy APK to your phone
2. Tap to install (allow unknown sources if asked)
3. Launch UniSync app
4. Tap "Allow" for notifications
5. Login and create an announcement
6. Check if you get a push notification ✅

═══════════════════════════════════════════════════════════════════════════════
                              WHAT CHANGED
═══════════════════════════════════════════════════════════════════════════════

1. pubspec.yaml
   Added:
   - firebase_core: ^3.2.0
   - firebase_messaging: ^15.1.0

2. android/build.gradle
   Added:
   - id "com.google.gms.google-services" version "4.4.2"

3. android/app/build.gradle
   Added:
   - Firebase plugin: id "com.google.gms.google-services"
   - Firebase dependencies

4. android/app/google-services.json
   Created template file (you need to add your own from Firebase)

═══════════════════════════════════════════════════════════════════════════════
                           IMPORTANT NOTES
═══════════════════════════════════════════════════════════════════════════════

🔥 Why Firebase?
   OneSignal requires Firebase for Android push notifications
   Firebase provides FCM (Firebase Cloud Messaging) service

📝 Which JSON file?
   Service Account JSON (for backend/OneSignal): firebase-adminsdk-xxxxx.json
   google-services.json (for Android app): google-services.json ← YOU NEED THIS

🏠 Where to get google-services.json?
   Firebase Console → Project Settings → Your apps → Download

═══════════════════════════════════════════════════════════════════════════════
                           TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════════

❌ "Could not find google-services.json"
   ✓ Check: Is file at android/app/google-services.json?
   ✓ Run: flutter clean
   ✓ Run: flutter pub get
   ✓ Try build again

❌ Build is very slow
   ✓ First build takes 5-10 minutes (normal)
   ✓ Downloads dependencies
   ✓ Next builds are faster

❌ "Gradle build failed"
   ✓ Run: flutter clean
   ✓ Run: flutter pub get
   ✓ Run: dart run build_runner build --delete-conflicting-outputs
   ✓ Try: flutter build apk --release again

❌ Notifications not working after APK install
   ✓ Did you tap "Allow" for notification permission?
   ✓ Check OneSignal App ID is correct in .env
   ✓ Check Firebase is properly set up
   ✓ Try creating announcement in app

═══════════════════════════════════════════════════════════════════════════════
                          FILES IN THIS FOLDER
═══════════════════════════════════════════════════════════════════════════════

FIREBASE_AND_APK_BUILD_GUIDE.md
   Detailed markdown guide with all information

FIREBASE_APK_QUICK_START.html
   Visual HTML guide (open in browser for easy reading)

README.txt (this file)
   Quick reference

lib/
   Your Flutter source code

android/
   Android build files (Firebase configured)
   - google-services.json (template - replace with your own)

pubspec.yaml
   Project dependencies (Firebase added)

.env
   Environment variables (add your ONESIGNAL_APP_ID)

═══════════════════════════════════════════════════════════════════════════════
                              NEXT STEPS
═══════════════════════════════════════════════════════════════════════════════

1. Download google-services.json from Firebase Console
2. Place it at: android/app/google-services.json
3. Update .env with ONESIGNAL_APP_ID
4. Follow the 6 steps above
5. Build APK
6. Test on phone

═══════════════════════════════════════════════════════════════════════════════

For detailed help, open: FIREBASE_APK_QUICK_START.html in your browser

Good luck! 🚀
