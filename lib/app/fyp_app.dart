import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/brand_colors.dart';
import '../core/theme/fyp_theme.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../services/localization_service.dart';
import '../services/platform_config.dart';
import '../services/theme_service.dart';
import 'fyp_router.dart';

/// Branded Material shell for the live Future Youth Platform skeleton.
class FypApp extends StatefulWidget {
  const FypApp({super.key});

  @override
  State<FypApp> createState() => _FypAppState();
}

class _FypAppState extends State<FypApp> {
  late final AuthController _authController;
  late final dynamic _router;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _router = createFypRouter(_authController);
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = PlatformConfig.current;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: AppLocalizations.localeNotifier,
          builder: (context, locale, child) {
            return MaterialApp.router(
              title: config.title,
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: FypTheme.light,
              darkTheme: FypTheme.dark,
              locale: locale,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en', ''),
                Locale('ar', ''),
              ],
              routerConfig: _router,
              builder: (context, child) {
                return Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    Positioned.directional(
                      textDirection: locale.languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      end: 18,
                      bottom: 70,
                      child: const GlobalLanguageSwitch(),
                    ),
                  ],
                );
              },
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
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocalizations.localeNotifier,
      builder: (context, locale, child) {
        final isEn = locale.languageCode == 'en';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: AppLocalizations.toggleLocale,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: BrandColors.navy.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(30),
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
                  const SizedBox(width: 8),
                  Text(
                    isEn ? 'العربية' : 'English',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
