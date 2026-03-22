# GitHub Secrets Setup

## Required for Firebase deploy

Repository secret:

- `FIREBASE_SERVICE_ACCOUNT_TARO_TEA`

Value:

- the full JSON content of the Firebase/Google service account key

Used by:

- `/.github/workflows/firebase-deploy.yml`

## Recommended for Android store builds

Repository secrets:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

What to put there:

1. Convert your upload keystore to base64:

```bash
base64 -i upload-keystore.jks | pbcopy
```

2. Paste that value into `ANDROID_UPLOAD_KEYSTORE_BASE64`.
3. Put the matching passwords and alias into the other three secrets.

Used by:

- `/.github/workflows/store-builds.yml`

## iOS signing

The current repository does not automate App Store signing yet.

That part still requires:

- Apple Developer certificates/profiles or App Store Connect API setup
- a separate signed archive/export workflow

Until then, the iOS workflow only produces a `--no-codesign` release artifact for verification.
