// ─────────────────────────────────────────────
// lib/models/user_model.dart
// Represents a paired user stored in Firestore
// ─────────────────────────────────────────────

class UserModel {
  final String userId;      // Firebase anonymous UID
  final String fcmToken;    // Device FCM token for push notifications
  final String connectionCode; // 6-char pairing code

  UserModel({
    required this.userId,
    required this.fcmToken,
    required this.connectionCode,
  });

  /// Convert to Firestore document map
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'fcmToken': fcmToken,
    'connectionCode': connectionCode,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  /// Build from Firestore document snapshot
  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    userId: map['userId'] ?? '',
    fcmToken: map['fcmToken'] ?? '',
    connectionCode: map['connectionCode'] ?? '',
  );
}


// ─────────────────────────────────────────────
// Connection model – one document per pair
// ─────────────────────────────────────────────

class ConnectionModel {
  final String code;         // 6-char unique code (document ID)
  final String userAId;      // UID of user who created
  final String userBId;      // UID of user who joined (empty until joined)
  final String userAToken;   // FCM token of User A
  final String userBToken;   // FCM token of User B (empty until joined)
  final bool active;         // True once both users are paired

  ConnectionModel({
    required this.code,
    required this.userAId,
    this.userBId = '',
    required this.userAToken,
    this.userBToken = '',
    this.active = false,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'userAId': userAId,
    'userBId': userBId,
    'userAToken': userAToken,
    'userBToken': userBToken,
    'active': active,
    'createdAt': DateTime.now().toIso8601String(),
  };

  factory ConnectionModel.fromMap(Map<String, dynamic> map) => ConnectionModel(
    code: map['code'] ?? '',
    userAId: map['userAId'] ?? '',
    userBId: map['userBId'] ?? '',
    userAToken: map['userAToken'] ?? '',
    userBToken: map['userBToken'] ?? '',
    active: map['active'] ?? false,
  );
}
