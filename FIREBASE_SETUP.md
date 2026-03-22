# Firebase setup for `taro`

## What is already wired in code

- Flutter app can initialize Firebase without crashing if the project is not configured yet.
- Menu, addons, promo codes, and orders are mirrored to Firebase Realtime Database when Firebase is available.
- Orders now carry `notificationTokens`, and status changes are ready for a Cloud Function push trigger.
- Admin menu save writes directly to the shared cloud payload.
- Regular user devices subscribe only to their own cloud orders; the full order feed remains for admin mode.

## What still has to be done in Firebase Console

1. Create a Firebase project.
2. Enable Realtime Database in the Firebase Console.
3. If you need real push notifications when the app is closed, use the `Blaze` plan.
4. Add Android and iOS apps for the final package identifiers.
5. For iOS push, upload an APNs key in Firebase.
6. Review `database.rules.json` before public launch.

## Local commands to finish wiring

From the project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then deploy the Cloud Function:

```bash
cd functions
npm install
cd ..
firebase deploy --only database,functions
```

## Notes

- `Cloud Storage` is not required for the current menu sync flow.
- The app still uses local customer accounts; Firebase in this integration is responsible for shared menu, shared orders, and order-status push delivery.
- The included Realtime Database rules are a baseline deployment config. For a stricter public production setup, move admin operations to Firebase Auth or a trusted backend.
- Before publishing to stores, replace the current placeholder app identifiers (`com.example.taro`) with your real package IDs and then run `flutterfire configure`.
