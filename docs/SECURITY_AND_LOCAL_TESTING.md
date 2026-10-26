# Security and local verification

## First administrator bootstrap

The first administrator must be provisioned from a trusted machine. Do not add a
special email bypass to callable authorization and do not expose a bootstrap
callable to the public app.

1. In Firebase Console for `future-youth-platform`, create the first admin's
   Authentication account and verify its email. Enable MFA for the account if
   your organization supports it.
2. On a trusted machine, install dependencies in `functions_fyp` and sign in
   with Google Application Default Credentials for an identity that has the
   required Firebase Authentication and Firestore IAM permissions:
   `gcloud auth application-default login`
3. In PowerShell, from `D:\future_youth_platform\functions_fyp`, set the email
   and run the one-time script:
   ```powershell
   $env:FYP_BOOTSTRAP_ADMIN_EMAIL = "your-verified-admin@example.com"
   npm run bootstrap:admin
   Remove-Item Env:FYP_BOOTSTRAP_ADMIN_EMAIL
   ```
4. The script refuses to run if a user profile with role `admin` already
   exists. After it completes, sign out and back in to refresh the role claim.
   Never run it from CI, a public client, or a shared/untrusted computer.

## Local checks (no production deployment)

From the repository root:

```powershell
cd functions_fyp
npm ci
npm test
npm run lint
cd ..
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

These checks must pass before merging. The Flutter analyzer flags are temporary
compatibility settings for existing analyzer debt; new warnings should still be
addressed rather than ignored.

## Firebase emulator checks

The configured Firebase emulators use Auth 9099, Firestore 8080, Functions
5001, Storage 9199. Start them with:

```powershell
firebase emulators:start --only auth,firestore,functions,storage
```

Do not deploy Firestore rules or functions to production as part of local
verification. The rules must be exercised against the emulator before release.

## Required credential response

The repository previously exposed a Firebase Admin service-account key for the
legacy `bbc-api-tool` project. Delete/revoke that exact key in Google Cloud
IAM. Removing the JSON from the current Git tree is not revocation and does not
remove historical copies. Rotate any other credentials that may have depended
on it. History rewriting is a separate operation to coordinate after revocation.
