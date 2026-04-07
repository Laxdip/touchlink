// ─────────────────────────────────────────────
// lib/services/vibration_service.dart
// Handles all vibration pattern triggers
// ─────────────────────────────────────────────

import 'package:vibration/vibration.dart';
import '../utils/constants.dart';

class VibrationService {
  /// Check if device supports vibration
  static Future<bool> hasVibrator() async {
    return await Vibration.hasVibrator() ?? false;
  }

  /// Single tap → short 200ms vibration
  static Future<void> singleTap() async {
    if (!await hasVibrator()) return;
    Vibration.vibrate(pattern: AppConstants.vibrationSingle);
  }

  /// Double tap → two 200ms vibrations with 150ms gap
  static Future<void> doubleTap() async {
    if (!await hasVibrator()) return;
    Vibration.vibrate(pattern: AppConstants.vibrationDouble);
  }

  /// Long press → one long 800ms vibration
  static Future<void> longPress() async {
    if (!await hasVibrator()) return;
    Vibration.vibrate(pattern: AppConstants.vibrationLong);
  }

  /// Trigger correct pattern based on touch type string
  static Future<void> triggerFromType(String type) async {
    switch (type) {
      case AppConstants.touchSingle:
        await singleTap();
        break;
      case AppConstants.touchDouble:
        await doubleTap();
        break;
      case AppConstants.touchLong:
        await longPress();
        break;
      default:
        await singleTap(); // fallback
    }
  }
}
