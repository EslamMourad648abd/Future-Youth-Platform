import '../../../core/constants/user_role.dart';

class AuthSession {
  final String? uid;
  final UserRole? role;
  final String? displayName;
  final String? email;

  const AuthSession({
    this.uid,
    this.role,
    this.displayName,
    this.email,
  });

  bool get signedIn => uid != null && uid!.isNotEmpty;

  static const AuthSession empty = AuthSession();
}

class RoleMismatchException implements Exception {
  final UserRole expectedRole;
  final UserRole actualRole;

  const RoleMismatchException({
    required this.expectedRole,
    required this.actualRole,
  });

  @override
  String toString() =>
      'This account is a ${actualRole.name} account. Use the ${actualRole.name} login.';
}
