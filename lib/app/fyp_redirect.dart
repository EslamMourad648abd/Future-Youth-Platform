import '../core/constants/user_role.dart';
import 'fyp_routes.dart';

String? fypRedirect({
  required String location,
  required bool signedIn,
  required UserRole? role,
}) {
  final isRoleSelect = location == '/';
  final isLogin = location.startsWith('/login/');
  final isSignup = location.startsWith('/signup/');

  if (!signedIn) {
    if (isRoleSelect || isLogin) {
      return null;
    }
    if (isSignup) {
      if (location == FypRoutes.signupFor(UserRole.parent) ||
          location == FypRoutes.signupFor(UserRole.teacher)) {
        return null;
      }
      return '/';
    }
    return '/';
  }

  // Signed in without an assigned role
  if (role == null) {
    if (isRoleSelect) return null;
    return '/';
  }

  // Signed in user on auth pages -> redirect to role home
  if (isRoleSelect || isLogin || isSignup) {
    return FypRoutes.homeFor(role);
  }

  return null;
}
