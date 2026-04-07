// ─────────────────────────────────────────────
// lib/utils/constants.dart
// App-wide constants used across services & UI
// ─────────────────────────────────────────────

class AppConstants {
  // Firestore collection names
  static const String connectionsCollection = 'connections';
  static const String usersCollection = 'users';

  // SharedPreferences keys
  static const String prefConnectionCode = 'connection_code';
  static const String prefUserId = 'user_id';
  static const String prefAnonymousMode = 'anonymous_mode';
  static const String prefIsUserA = 'is_user_a'; // true = created, false = joined

  // FCM notification data keys
  static const String notifKeyType = 'touch_type';
  static const String notifKeySenderId = 'sender_id';
  static const String notifKeyAnonymous = 'anonymous';

  // Touch types (sent as FCM data payload)
  static const String touchSingle = 'single';
  static const String touchDouble = 'double';
  static const String touchLong = 'long';

  // Vibration patterns in milliseconds
  // Format: [wait, vibrate, wait, vibrate ...]
  static const List<int> vibrationSingle = [0, 200];
  static const List<int> vibrationDouble = [0, 200, 150, 200];
  static const List<int> vibrationLong   = [0, 800];

  // FCM high-priority channel
  static const String notifChannelId   = 'touchlink_channel';
  static const String notifChannelName = 'TouchLink';
  static const String notifChannelDesc = 'Touch notifications from your partner';
}
