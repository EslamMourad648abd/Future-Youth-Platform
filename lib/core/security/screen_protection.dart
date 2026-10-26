import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording while sensitive content is shown.
///
/// This is only the Dart side. It talks to native code over the
/// `fyp/screen_protection` channel:
/// - Android: set/clear `WindowManager.LayoutParams.FLAG_SECURE`.
/// - iOS: hide the player while `UIScreen.isCaptured` is true.
///
/// Until the native side exists (docs/AGENT_TASKS.md, task T14) every call is
/// a safe no-op. On the web it does nothing, because browsers cannot block
/// screen capture at all.
abstract final class ScreenProtection {
  static const MethodChannel _channel = MethodChannel('fyp/screen_protection');

  static Future<void> enable() => _set(true);

  static Future<void> disable() => _set(false);

  static Future<void> _set(bool enabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(enabled ? 'enable' : 'disable');
    } on MissingPluginException {
      debugPrint(
        'ScreenProtection: native side not installed yet (see T14).',
      );
    } on PlatformException catch (e) {
      debugPrint('ScreenProtection failed: ${e.message}');
    }
  }
}
