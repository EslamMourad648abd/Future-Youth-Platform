import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../services/localization_service.dart';

/// Persistent global light/dark switch. Kept separate from the language control
/// so both preferences remain available on every portal and route.
class GlobalThemeSwitch extends StatelessWidget {
  const GlobalThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            label: fypTranslate(
              context,
              'theme_switch_hint',
              'Switch between light and dark themes',
            ),
            child: InkWell(
              onTap: ThemeService.toggleTheme,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    if (MediaQuery.sizeOf(context).width >= 380) ...[
                      const SizedBox(width: 8),
                      Text(
                        fypTranslate(context, isDark ? 'theme_light' : 'theme_dark', isDark ? 'Light theme' : 'Dark theme'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
