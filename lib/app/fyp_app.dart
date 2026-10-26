import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../widgets/global_language_switch.dart';
import '../core/theme/fyp_theme.dart';
import '../widgets/global_theme_switch.dart';
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
                      bottom: MediaQuery.of(context).padding.bottom + 70,
                      child: const GlobalLanguageSwitch(),
                    ),
                    Positioned.directional(
                      textDirection: locale.languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      end: 18,
                      bottom: MediaQuery.of(context).padding.bottom + 18,
                      child: const GlobalThemeSwitch(),
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
