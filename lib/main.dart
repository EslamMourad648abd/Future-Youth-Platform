import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/localization_service.dart';
import 'services/theme_service.dart';
import 'services/platform_config.dart';

Future<void> main() async {
  await runAppWithConfig(PlatformConfig.master);
}

Future<void> runAppWithConfig(PlatformConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  PlatformConfig.current = config;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ThemeService.init();
  await AppLocalizations.init();

  runApp(const ApiTesterApp());
}

class ApiTesterApp extends StatelessWidget {
  const ApiTesterApp({super.key});

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
              
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: config.primaryColor,
                  brightness: Brightness.light,
                  surface: const Color(0xffF5F8FC),
                ),
                cardTheme: CardThemeData(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xffE2E8EF)),
                  ),
                ),
                dividerColor: const Color(0xffE2E8EF),
              ),

              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: config.primaryColor,
                  brightness: Brightness.dark,
                  surface: const Color(0xff0F172A),
                  onSurface: Colors.white,
                  primary: config.primaryColor,
                  secondary: const Color(0xff818CF8),
                ),
                scaffoldBackgroundColor: const Color(0xff0F172A),
                cardTheme: CardThemeData(
                  color: const Color(0xff1E293B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                dividerColor: Colors.white.withValues(alpha: 0.1),
              ),

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
              routerConfig: AppRouter.router,
              builder: (context, child) {
                return Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    const Positioned(
                      right: 18,
                      bottom: 10,
                      child: AppWatermark(),
                    ),
                    Positioned.directional(
                      textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: AppLocalizations.toggleLocale,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.blueGrey.shade800 : const Color(0xff003366)).withValues(alpha: 0.9),
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

class AppWatermark extends StatelessWidget {
  const AppWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Opacity(
        opacity: 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (isDark ? Colors.blueGrey.shade900 : Colors.white).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
          ),
          child: Text(
            'Powered by Eng. Eslam Mourad',
            style: TextStyle(
              fontSize: isSmall ? 12 : 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : const Color(0xff6B7280),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
