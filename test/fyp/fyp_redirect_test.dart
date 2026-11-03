import 'package:flutter_test/flutter_test.dart';
import 'package:future_youth_platform/app/fyp_redirect.dart';
import 'package:future_youth_platform/app/fyp_routes.dart';
import 'package:future_youth_platform/core/constants/user_role.dart';

void main() {
  group('fypRedirect role boundaries', () {
    test('signed-out users cannot open protected portals', () {
      expect(fypRedirect(location: FypRoutes.admin, signedIn: false, role: null), '/');
      expect(fypRedirect(location: FypRoutes.parent, signedIn: false, role: null), '/');
      expect(fypRedirect(location: FypRoutes.student, signedIn: false, role: null), '/');
      expect(fypRedirect(location: FypRoutes.teacher, signedIn: false, role: null), '/');
    });

    test('each role is redirected away from another role portal', () {
      expect(
        fypRedirect(location: FypRoutes.admin, signedIn: true, role: UserRole.student),
        FypRoutes.student,
      );
      expect(
        fypRedirect(location: FypRoutes.teacherCourseEditorFor('course-1'), signedIn: true, role: UserRole.parent),
        FypRoutes.parent,
      );
      expect(
        fypRedirect(location: FypRoutes.parentSubscriptions, signedIn: true, role: UserRole.teacher),
        FypRoutes.teacher,
      );
    });

    test('users can navigate within their own portal', () {
      expect(fypRedirect(location: FypRoutes.student, signedIn: true, role: UserRole.student), isNull);
      expect(fypRedirect(location: FypRoutes.teacherCourseEditorFor('course-1'), signedIn: true, role: UserRole.teacher), isNull);
      expect(fypRedirect(location: FypRoutes.adminCreateAdmin, signedIn: true, role: UserRole.admin), isNull);
    });
  });
}
