import 'package:flutter/material.dart';

import '../core/theme/brand_colors.dart';
import '../services/localization_service.dart';

class GlobalLanguageSwitch extends StatelessWidget {
  const GlobalLanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocalizations.localeNotifier,
      builder: (context, locale, child) {
        final isEn = locale.languageCode == 'en';
        final compact = MediaQuery.sizeOf(context).width < 380;
        final label = isEn ? 'العربية' : 'English';
        final hint =
            isEn ? 'Switch language to Arabic' : 'Switch language to English';

        return Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            label: hint,
            child: InkWell(
              onTap: AppLocalizations.toggleLocale,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: BrandColors.navy.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, color: Colors.white, size: 18),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
