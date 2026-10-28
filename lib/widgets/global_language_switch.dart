import 'package:flutter/material.dart';

import '../core/theme/brand_colors.dart';
import '../services/localization_service.dart';
import '../services/theme_service.dart';

class FloatingAppControlBar extends StatelessWidget {
  const FloatingAppControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;

        return ValueListenableBuilder<Locale>(
          valueListenable: AppLocalizations.localeNotifier,
          builder: (context, locale, child) {
            final isEn = locale.languageCode == 'en';
            final label = isEn ? 'العربية' : 'English';

            return Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? BrandColors.darkSurface : BrandColors.navy).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: ThemeService.toggleTheme,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: isDark ? Colors.amber : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    Container(
                      height: 16,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    InkWell(
                      onTap: AppLocalizations.toggleLocale,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class GlobalLanguageSwitch extends StatelessWidget {
  const GlobalLanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return const FloatingAppControlBar();
  }
}
