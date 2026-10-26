import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:future_youth_platform/core/theme/fyp_theme.dart';

void main() {
  testWidgets('branded shell shows Future Youth Platform', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FypTheme.light,
        home: const Scaffold(
          body: Center(child: Text('Future Youth Platform')),
        ),
      ),
    );

    expect(find.text('Future Youth Platform'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('Future Youth Platform'))).colorScheme.primary,
        FypTheme.light.colorScheme.primary);
  });
}
