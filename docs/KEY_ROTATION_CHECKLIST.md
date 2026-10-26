# Firebase Admin service-account key rotation checklist

**Treat the service-account private key committed in historical Git history as compromised.** Deleting the file from the latest branch does not revoke the credential.

## Required owner/admin actions

1. Open Google Cloud Console for project `future-youth-platform` → **IAM & Admin → Service Accounts**.
2. Identify the service account associated with the historical file `functions/bbc-api-tool-firebase-adminsdk-fbsvc-344ab63826.json`. Confirm its email and key ID from the exposed JSON/file history; do not paste the private key into issues or chat.
3. Create a replacement key only if a long-lived key is genuinely required. Prefer Application Default Credentials / the Cloud Functions runtime service account instead of downloaded JSON keys.
4. **Disable/delete the exposed key ID** in the service account's **Keys** tab. Do not delete the whole service account unless you have verified it is unused.
5. Check Cloud Audit Logs for use of the exposed key after the earliest known exposure and review IAM bindings for unnecessary privileges.
6. Check repository secrets, CI variables, local developer machines, and deployment environments for copies of the exposed key. Replace or remove them.
7. Only after revocation and confirming no needed history references remain, consider rewriting Git history with `git-filter-repo` to remove the JSON file. Coordinate this with all collaborators because rewriting history requires a force-push and fresh clones.
8. Verify the deployed Functions use their attached runtime identity and that required APIs still work without the old key.

## What this repository change can and cannot do

- The credential file is not intended to be present in the current branch.
- Repository access does not grant access to Google Cloud IAM, so this checklist does **not** mean the key has been revoked.
- Do not publish, upload, or paste the private key while investigating it.
