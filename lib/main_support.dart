import 'main.dart';
import 'services/platform_config.dart';

Future<void> main() async {
  await runAppWithConfig(PlatformConfig.support);
}
