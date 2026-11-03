# Firebase Admin service-account key rotation checklist

**Treat the service-account private key committed in historical Git history as compromised.** Deleting the file from the latest branch does not revoke the credential.

## Required owner/admin actions

1. Open the exposed JSON file from Git history in a secure local environment and read only its `project_id`, `client_email`, and `private_key_id` fields (never print or share `private_key`). Open Google Cloud Console for that `project_id` → **IAM & Admin → Service Accounts**. The filename suggests this may be the legacy BBC API Tool project, so do not assume it is `future-youth-platform`.
2. Identify the service account associated with `client_email` and locate the exact `private_key_id` in the service account's Keys tab. Do not paste the private key into issues or chat.
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
