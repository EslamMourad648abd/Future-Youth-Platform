import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          body: Center(child: _ThemeSwitchHarness()),
        ),
      ),
    );

    expect(find.text('Dark theme'), findsOneWidget);
    await tester.tap(find.text('Dark theme'));
    await tester.pumpAndSettle();
    expect(ThemeService.themeNotifier.value, ThemeMode.dark);
    expect(find.text('Light theme'), findsOneWidget);
  });
}

class _ThemeSwitchHarness extends StatelessWidget {
  const _ThemeSwitchHarness();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return TextButton(
          onPressed: ThemeService.toggleTheme,
          child: Text(isDark ? 'Light theme' : 'Dark theme'),
        );
      },
    );
  }
}
