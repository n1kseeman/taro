# Store Release Checklist

## Already prepared in the project

- Firebase is configured for the current package identifiers.
- CI workflows are prepared for GitHub Actions in `/.github/workflows/`.
- Android has `INTERNET` and `POST_NOTIFICATIONS` permissions.
- iOS now declares photo library usage text for image picking.
- Android release signing supports `android/key.properties`.
- App name is aligned to `Taro Tea` in Flutter, Android, and iOS.

## Must be done before App Store / Google Play submission

1. Verify the chosen identifiers still match your brand/legal setup:
   - Android package: `com.tarotea.app`
   - iOS bundle ID: `com.tarotea.app`
   - macOS bundle ID: `com.tarotea.app`
2. Re-run `flutterfire configure` any time identifiers change again.
3. Create Android upload keystore and fill `android/key.properties`.
4. Configure Apple signing in Xcode with the final bundle ID.
5. Upload APNs key/certificate in Firebase for iOS push notifications.
6. Stay on `Spark` if realtime sync is enough for now; switch to `Blaze` only if you later need real background push on order status changes.
7. Deploy Realtime Database rules first; deploy Cloud Functions from `functions/` only after moving to `Blaze`.
8. Prepare store assets:
   - final app icon
   - screenshots
   - privacy policy URL
   - support URL/contact
   - age rating/content questionnaire
9. Verify release builds:
   - `flutter build appbundle --release`
   - `flutter build ios --release --no-codesign`
10. Put the project in Git and connect CI before store submission.
11. Review `CI_RELEASE_SETUP.md` and wire GitHub Actions.
12. Add repository secrets from `GITHUB_SECRETS_SETUP.md` before relying on CI release builds.

## Recommended package IDs

Use your real brand domain if you have one. Good patterns:

- `by.tarotea.app`
- `com.tarotea.app`

Do not submit with placeholder identifiers like `com.example.*`.
