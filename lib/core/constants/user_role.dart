/// The four kinds of account on the platform.
///
/// The role is stored in two places and both are written ONLY by Cloud
/// Functions: the `role` custom claim on the Firebase Auth token (used by
/// security rules) and the `role` field on `users/{uid}` (used by the UI).
enum UserRole {
  student,
  parent,
  teacher,
  admin;

  /// Parses a stored role name. Returns null for anything unknown.
  static UserRole? tryParse(String? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }

  /// Only parents and teachers can sign themselves up.
  /// Students are created by a parent; admins are created by another admin.
  bool get canSelfSignUp => this == UserRole.parent || this == UserRole.teacher;
}
