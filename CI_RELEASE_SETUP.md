# CI Release Setup

This project is prepared for a global backend in Firebase and CI-based builds for store delivery.

## What is included

- `/.github/workflows/flutter-ci.yml`
  - runs `flutter pub get`
  - runs `flutter analyze`
  - runs `flutter test`
- `/.github/workflows/store-builds.yml`
  - builds Android release `AAB`
  - builds iOS release with `--no-codesign`
  - uploads both artifacts

## What this solves

- Firebase stays global for all devices.
- iOS and Android builds stop depending on one local Mac.
- Release verification can run in a hosted CI environment before store submission.

## Before these workflows can run

1. Move the project into a real Git repository.
2. Push it to GitHub.
3. Keep the generated Firebase config files in the repository:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - `lib/firebase_options.dart`
4. Make sure `com.tarotea.app` is the final production identifier, or update Firebase again if it changes.

## For Android store submission

The current Gradle setup can still build in CI without a private keystore because it falls back to debug signing when `android/key.properties` is absent.

For actual Google Play release upload, add the real upload keystore and secrets:

1. Add the keystore file to your CI secret storage or artifact store.
2. Create `android/key.properties` in CI before the build.
3. Use the production keystore values:
   - `storePassword`
   - `keyPassword`
   - `keyAlias`
   - `storeFile`

## For iOS store submission

The included workflow intentionally uses `flutter build ios --release --no-codesign`.

That is enough for:

- CI validation
- catching dependency/build regressions
- producing a release artifact for inspection

For actual App Store delivery, you still need:

1. Apple Developer signing configured.
2. App Store Connect access.
3. An archive/export/signing step, usually through Xcode, Fastlane, or a dedicated signing workflow.

## Firebase requirements for production

1. Enable Firebase Realtime Database.
2. Keep Firebase Cloud Messaging configured.
3. Upload APNs key for iOS push.
4. Switch to `Blaze` if you need real background push delivery on order status changes.
5. Deploy the function from `functions/`.

## Recommended next move

1. Put `taro` into Git.
2. Push to GitHub.
3. Run `Flutter CI`.
4. Run `Store Builds`.
5. After CI artifacts are stable, add signing and store-upload automation.
