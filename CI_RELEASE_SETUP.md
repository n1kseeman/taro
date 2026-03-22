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

1. Add these GitHub repository secrets:
   - `ANDROID_UPLOAD_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_KEY_ALIAS`
2. The workflow already knows how to create `android/key.properties` when these secrets exist.
3. See `GITHUB_SECRETS_SETUP.md` for the exact format.

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
2. On `Spark`, deploy only Realtime Database rules and use realtime status updates without background push.
3. Keep Firebase Cloud Messaging configured only if you plan to move to `Blaze` later.
4. Upload APNs key for iOS only when you enable real push delivery.
5. Deploy the function from `functions/` only after upgrading to `Blaze`.

## GitHub secrets

See `GITHUB_SECRETS_SETUP.md`.

## Recommended next move

1. Put `taro` into Git.
2. Push to GitHub.
3. Run `Flutter CI`.
4. Run `Store Builds`.
5. After CI artifacts are stable, add signing and store-upload automation.
