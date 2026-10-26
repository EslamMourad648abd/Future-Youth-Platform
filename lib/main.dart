import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/fyp_app.dart';
import 'firebase_options.dart';
import 'services/localization_service.dart';
import 'services/platform_config.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  await runAppWithConfig(PlatformConfig.futureYouth);
}

Future<void> runAppWithConfig(PlatformConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformConfig.current = config;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ThemeService.init();
  await AppLocalizations.init();

  runApp(const FypApp());
}
