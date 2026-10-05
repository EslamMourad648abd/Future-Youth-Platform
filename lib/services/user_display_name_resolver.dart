import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolves a Firebase user UID into the best human-readable identity.
///
/// Platform-wide priority:
///
/// username
///     ↓
/// displayName
///     ↓
/// email
///     ↓
/// UID
///
/// The UID remains the permanent stored identity. This service only
/// controls how that identity is presented in the UI.
class UserDisplayNameResolver {
UserDisplayNameResolver({
FirebaseFirestore? firestore,
}) : _firestore =
firestore ?? FirebaseFirestore.instance;

final FirebaseFirestore _firestore;

final Map<String, Future<String>> _cache = {};

/// Resolves a UID using the platform-wide display-name priority.
Future<String> resolve(String uid) {
final normalizedUid = uid.trim();

if (normalizedUid.isEmpty) {
return Future.value('—');
}

final cached = _cache[normalizedUid];

if (cached != null) {
return cached;
}

final future = _load(normalizedUid);

_cache[normalizedUid] = future;

return future;
}

Future<String> _load(String uid) async {
try {
final snapshot = await _firestore
    .collection('users')
    .doc(uid)
    .get();

if (snapshot.exists) {
final data = snapshot.data();

if (data != null) {
// ============================================================
// 1. USERNAME
// ============================================================

final username =
_readString(data['username']);

if (username != null) {
return username;
}

// ============================================================
// 2. DISPLAY NAME
// ============================================================

final displayName =
_readString(data['displayName']);

if (displayName != null) {
return displayName;
}

// ============================================================
// 3. EMAIL
// ============================================================

final email =
_readString(data['email']);

if (email != null) {
return email;
}
}
}
} catch (_) {
// UID is intentionally used as the final fallback.
}

// ================================================================
// 4. UID FINAL FALLBACK
// ================================================================

return uid;
}

String? _readString(dynamic value) {
if (value == null) {
return null;
}

final result = value.toString().trim();

return result.isEmpty ? null : result;
}

/// Clears the cached identity for one user.
///
/// Useful after User Management changes username/displayName/email.
void invalidate(String uid) {
_cache.remove(uid.trim());
}

/// Clears the complete resolver cache.
void clearCache() {
_cache.clear();
}
}
