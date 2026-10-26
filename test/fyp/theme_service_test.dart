import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/app/fyp_app.dart';
import '../../lib/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeService.themeNotifier.value = ThemeMode.light;
  });

  test('theme preference defaults to light and persists dark mode', () async {
    await ThemeService.init();
    expect(ThemeService.themeNotifier.value, ThemeMode.light);

    await ThemeService.toggleTheme();
    expect(ThemeService.themeNotifier.value, ThemeMode.dark);

    // Re-initialization simulates a fresh app start.
    ThemeService.themeNotifier.value = ThemeMode.light;
    await ThemeService.init();
    expect(ThemeService.themeNotifier.value, ThemeMode.dark);
  });

  testWidgets('global theme switch toggles the theme mode', (tester) async {
    await ThemeService.init();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: GlobalThemeSwitch()),
        ),
      ),
    );

    expect(find.text('Dark theme'), findsOneWidget);
    await tester.tap(find.text('Dark theme'));
    await tester.pumpAndSettle();
    expect(ThemeService.themeNotifier.value, ThemeMode.dark);
    expect(find.text('Light theme'), findsOneWidget);
  });
