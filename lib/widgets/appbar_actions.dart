import 'package:flutter/material.dart';

import '../services/localization_service.dart';
import '../services/theme_service.dart';

class GlobalAppBarActions extends StatelessWidget {
  final Color? iconColor;

  const GlobalAppBarActions({
    super.key,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = iconColor ?? theme.colorScheme.onSurface;

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocalizations.localeNotifier,
      builder: (context, locale, _) {
        final isEn = locale.languageCode == 'en';

        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeNotifier,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: AppLocalizations.toggleLocale,
                    borderRadius: BorderRadius.circular(20),
                    child: Tooltip(
                      message: isEn ? 'العربية' : 'English',
                      child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 18, color: activeColor),
                          if (MediaQuery.sizeOf(context).width >= 380) ...[
                            const SizedBox(width: 6),
                            Text(
                              isEn ? 'العربية' : 'English',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: activeColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: ThemeService.toggleTheme,
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: activeColor,
                    size: 20,
                  ),
                  tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                ),
                const SizedBox(width: 4),
              ],
            );
          },
        );
      },
    );
  }
}
