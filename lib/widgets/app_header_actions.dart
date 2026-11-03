import 'package:flutter/material.dart';

import '../services/localization_service.dart';
import '../services/theme_service.dart';

class AppHeaderActions extends StatelessWidget {
  const AppHeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        return ValueListenableBuilder<Locale>(
          valueListenable: AppLocalizations.localeNotifier,
          builder: (context, locale, _) {
            final isEn = locale.languageCode == 'en';

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isDark ? 'Light mode' : 'Dark mode',
                  onPressed: ThemeService.toggleTheme,
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: AppLocalizations.toggleLocale,
                  icon: const Icon(Icons.language, color: Colors.white, size: 18),
                  label: Text(
                    isEn ? 'العربية' : 'English',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            );
          },
        );
      },
    );
  }
}
