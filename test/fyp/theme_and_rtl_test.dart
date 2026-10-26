import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:future_youth_platform/core/theme/fyp_theme.dart';
import 'package:future_youth_platform/services/localization_service.dart';

void main() {
  test('light and dark themes expose readable foreground/background pairs', () {
    for (final theme in [FypTheme.light, FypTheme.dark]) {
      final scheme = theme.colorScheme;
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSecondary, scheme.secondary), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('Arabic locale sets RTL text direction', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Text(
            Directionality.of(context) == TextDirection.rtl ? 'RTL' : 'LTR',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('RTL'), findsOneWidget);
  });

  testWidgets('Arabic locale translates learning interface labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Text(
            fypTranslate(context, 'course_editor', 'Course editor'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('محرر الدورة'), findsOneWidget);
  });
}

double _contrast(Color foreground, Color background) {
  final l1 = _luminance(foreground);
  final l2 = _luminance(background);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color color) {
  double channel(int value) {
    final normalized = value / 255.0;
    return normalized <= 0.04045
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.red) +
      0.7152 * channel(color.green) +
      0.0722 * channel(color.blue);
}

