# Firebase Setup (one-time)

The app is **offline-first**: it runs fully without Firebase. Auth + cloud sync stay
dormant until you connect a Firebase project. `initFirebaseSafely()` swallows the
"not configured" error, so nothing breaks before you do this.

## 1. Create a Firebase project
- Go to the [Firebase console](https://console.firebase.google.com/), create a project.
- In **Authentication → Sign-in method**, enable **Email/Password** and **Anonymous**.
- In **Firestore Database**, create a database (production mode is fine).

## 2. Generate the platform config
From `flutter_app/`:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Select your project and the iOS + macOS apps. This generates:
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart` (optional — the app calls `Firebase.initializeApp()` with
  no args and reads the native plist, so this file isn't strictly required, but
  flutterfire writes it anyway).

> If you prefer the native-only path, just drop the `GoogleService-Info.plist` files
> into the Runner targets in Xcode — `initFirebaseSafely()` will pick them up.

## 3. iOS / macOS pods
```bash
cd ios && pod install && cd ..
cd macos && pod install && cd ..
```
Deployment target is already iOS 13 (Firebase 5.x requires ≥ 13).

## 4. Firestore security rules
Lock the per-user document so users only read/write their own contacts:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## 5. Run
```bash
flutter run
```
Open the overflow menu (⋮) → **Sign in to sync**. After signing in, the local contact
list reconciles with `users/{uid}.contacts` (last-write-wins by each contact's
`updatedAt`) and every later change is pushed automatically.

## Data model in Firestore
- Document path: `users/{uid}`
- Field `contacts`: array of `Contact.toJson()` objects
- Field `updatedAt`: server timestamp of the last push

## Notes
- Conflict resolution is **last-write-wins per contact by `updatedAt`** (see
  `reconcileByUpdatedAt` in `cloud_sync_service.dart`, unit-tested).
- Local notifications request permission at runtime on first launch; no extra
  Info.plist keys are required for local (non-push) notifications.
