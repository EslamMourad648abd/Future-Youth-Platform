import 'package:flutter_test/flutter_test.dart';
import 'package:future_youth_platform/services/platform_config.dart';

void main() {
  group('Future Youth platform configuration', () {
    test('uses the Future Youth landing route', () {
      expect(PlatformConfig.futureYouth.landingRoute, '/future-youth');
    });

    test('uses the approved brand navy', () {
      expect(PlatformConfig.futureYouth.primaryColor.value, 0xFF263778);
    });

    test('allows the four product roles', () {
      expect(
        PlatformConfig.futureYouth.allowedRoles,
        containsAll(['admin', 'teacher', 'parent', 'student']),
      );
    });
  });
}
