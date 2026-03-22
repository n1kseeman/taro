# Firebase setup for `taro`

## What is already wired in code

- Flutter app can initialize Firebase without crashing if the project is not configured yet.
- Menu, addons, promo codes, and orders are mirrored to Firebase Realtime Database when Firebase is available.
- Orders still carry `notificationTokens`, but background push on status change is postponed while the project stays on `Spark`.
- Admin menu save writes directly to the shared cloud payload.
- Regular user devices subscribe only to their own cloud orders; the full order feed remains for admin mode.

## What still has to be done in Firebase Console

1. Create a Firebase project.
2. Enable Realtime Database in the Firebase Console.
3. Stay on `Spark` if you only need shared menu and shared orders.
4. Move to `Blaze` later only if you want real background push notifications on status changes.
4. Add Android and iOS apps for the final package identifiers.
5. For iOS push, upload an APNs key in Firebase.
6. Review `database.rules.json` before public launch.

## Local commands to finish wiring

From the project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then deploy the Realtime Database rules:

```bash
firebase deploy --only database
```

## Notes

- `Cloud Storage` is not required for the current menu sync flow.
- The app still uses local customer accounts; Firebase in this integration is responsible for shared menu and shared orders.
- On the free `Spark` plan, status changes still sync through Realtime Database, but push notifications are not sent in the background.
- The included Realtime Database rules are a baseline deployment config. For a stricter public production setup, move admin operations to Firebase Auth or a trusted backend.
- Before publishing to stores, replace the current placeholder app identifiers (`com.example.taro`) with your real package IDs and then run `flutterfire configure`.
