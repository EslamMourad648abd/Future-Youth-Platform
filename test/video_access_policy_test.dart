import 'package:flutter_test/flutter_test.dart';
import 'package:future_youth_platform/features/future_youth/video_access_policy.dart';

void main() {
  group('VideoAccessPolicy', () {
    VideoAccessRequest request({
      bool authenticated = true,
      bool approved = true,
      bool preview = false,
      bool subscription = true,
      bool teacherSelected = true,
      int points = 1,
    }) => VideoAccessRequest(
      isAuthenticated: authenticated,
      isApproved: approved,
      isFreePreview: preview,
      hasActiveSubscription: subscription,
      hasConfirmedTeacherSelection: teacherSelected,
      availablePoints: points,
    );

    test('requires authentication even for a free preview', () {
      expect(
        VideoAccessPolicy.evaluate(request(authenticated: false, preview: true)),
        VideoAccessStatus.authenticationRequired,
      );
    });

    test('blocks content that has not been approved', () {
      expect(
        VideoAccessPolicy.evaluate(request(approved: false, preview: true)),
        VideoAccessStatus.contentPendingApproval,
      );
    });

    test('allows approved free preview without payment or points', () {
      expect(
        VideoAccessPolicy.evaluate(request(
          preview: true,
          subscription: false,
          teacherSelected: false,
          points: 0,
        )),
        VideoAccessStatus.allowed,
      );
    });

    test('requires teacher selection before paid content', () {
      expect(
        VideoAccessPolicy.evaluate(request(teacherSelected: false)),
        VideoAccessStatus.teacherSelectionRequired,
      );
    });

    test('requires active subscription for paid content', () {
      expect(
        VideoAccessPolicy.evaluate(request(subscription: false)),
        VideoAccessStatus.paymentRequired,
      );
    });

    test('requires points for paid content', () {
      expect(
        VideoAccessPolicy.evaluate(request(points: 0)),
        VideoAccessStatus.insufficientPoints,
      );
    });

    test('allows paid content when all checks pass', () {
      expect(
        VideoAccessPolicy.evaluate(request()),
        VideoAccessStatus.allowed,
      );
    });
  });
}
