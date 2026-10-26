import '../constants/user_role.dart';

/// What each role may do. UI and Cloud Functions should both consult this
/// so the matrix can grow without rewriting screens.
///
/// Source: handwritten notes + Roles, Permissions & Restrictions Matrix
/// (Oct 2026), with the owner's later decisions (docs/REQUIREMENTS.md).
abstract final class RolePermissions {
  static bool canSelfSignUp(UserRole role) => role.canSelfSignUp;

  /// Only a registered parent creates student accounts.
  static bool canCreateStudent(UserRole role) => role == UserRole.parent;

  static bool canCreateAdmin(UserRole role) => role == UserRole.admin;

  static bool canCreateTeacher(UserRole role) => role == UserRole.admin;

  static bool canCreateParent(UserRole role) => role == UserRole.admin;

  static bool canApproveTeachersAndContent(UserRole role) =>
      role == UserRole.admin;

  static bool canPay(UserRole role) => role == UserRole.parent;

  static bool canWatchAfterPayment(UserRole role) => role == UserRole.student;

  static bool canPreviewFreeVideo(UserRole role) =>
      role == UserRole.student ||
      role == UserRole.parent ||
      role == UserRole.teacher ||
      role == UserRole.admin;

  static bool canPublishWithoutReview(UserRole role) => role == UserRole.admin;

  static bool canSeeCourseAnalytics(UserRole role) =>
      role == UserRole.teacher || role == UserRole.admin;

  static bool canOpenAdminConsole(UserRole role) => role == UserRole.admin;

  /// Roles an [actor] is allowed to pass into the existing `createUser` call.
  static List<UserRole> creatableRoles(UserRole actor) {
    switch (actor) {
      case UserRole.parent:
        return const [UserRole.student];
      case UserRole.admin:
        return const [UserRole.admin, UserRole.teacher, UserRole.parent];
      case UserRole.teacher:
      case UserRole.student:
        return const [];
    }
  }
}
