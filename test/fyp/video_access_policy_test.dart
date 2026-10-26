import 'package:flutter_test/flutter_test.dart';
import 'package:future_youth_platform/core/constants/user_role.dart';
import 'package:future_youth_platform/core/permissions/role_permissions.dart';
import 'package:future_youth_platform/features/points/domain/points_policy.dart';
import 'package:future_youth_platform/features/video/domain/video_access_policy.dart';

VideoAccess _decide({
  UserRole role = UserRole.student,
  bool free = false,
  bool subscribed = true,
  int points = 5,
}) {
  return decideVideoAccess(
    viewerRole: role,
    isFreeVideo: free,
    subscriptionActive: subscribed,
    pointsBalance: points,
  );
}

void main() {
  group('student', () {
    test('unpaid student can watch the free video (FR-05, D-1)', () {
      expect(_decide(subscribed: false, free: true), VideoAccess.allowed);
    });

    test('unpaid student is locked out of paid videos (FR-10)', () {
      expect(_decide(subscribed: false), VideoAccess.paymentRequired);
    });

    test('subscribed student can watch the free video with zero points (FR-05)',
        () {
      expect(_decide(free: true, points: 0), VideoAccess.allowed);
    });

    test('subscribed student with points can watch a paid video', () {
      expect(_decide(points: 1), VideoAccess.allowed);
    });

    test('subscribed student with no points is stopped (FR-06)', () {
      expect(_decide(points: 0), VideoAccess.noPoints);
    });
  });

  group('parent', () {
    test('can preview the free video without a subscription (A-1)', () {
      expect(_decide(role: UserRole.parent, free: true, subscribed: false),
          VideoAccess.allowed);
    });

    test('is asked to subscribe for any other video', () {
      expect(_decide(role: UserRole.parent, subscribed: false),
          VideoAccess.paymentRequired);
    });
  });

  group('staff', () {
    test('teacher and admin are never blocked', () {
      for (final role in [UserRole.teacher, UserRole.admin]) {
        expect(_decide(role: role, subscribed: false, points: 0),
            VideoAccess.allowed);
      }
    });
  });

  group('PointsPolicy', () {
    test('subscription grants videoCount x months points (A-3)', () {
      expect(PointsPolicy.pointsForSubscription(videoCount: 12, months: 3), 36);
      expect(PointsPolicy.pointsForSubscription(videoCount: 0, months: 3), 0);
    });

    test('negative input is rejected', () {
      expect(
        () => PointsPolicy.pointsForSubscription(videoCount: -1, months: 1),
        throwsArgumentError,
      );
    });

    test('one point is enough to start a video', () {
      expect(PointsPolicy.canAfford(1), isTrue);
      expect(PointsPolicy.canAfford(0), isFalse);
    });
  });

  group('UserRole', () {
    test('only parent and teacher can sign themselves up (FR-02)', () {
      expect(UserRole.parent.canSelfSignUp, isTrue);
      expect(UserRole.teacher.canSelfSignUp, isTrue);
      expect(UserRole.student.canSelfSignUp, isFalse);
      expect(UserRole.admin.canSelfSignUp, isFalse);
    });

    test('only a parent can create a student account', () {
      expect(RolePermissions.canCreateStudent(UserRole.parent), isTrue);
      expect(RolePermissions.canCreateStudent(UserRole.admin), isFalse);
      expect(RolePermissions.creatableRoles(UserRole.admin),
          isNot(contains(UserRole.student)));
    });

    test('tryParse returns null for unknown names', () {
      expect(UserRole.tryParse('teacher'), UserRole.teacher);
      expect(UserRole.tryParse('superadmin'), isNull);
      expect(UserRole.tryParse(null), isNull);
    });
  });
}
