// ─────────────────────────────────────────────
// lib/services/firebase_service.dart
// Handles: anonymous auth, pairing code
// generation/joining, FCM token storage.
// ─────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Current user UID (set after signIn) ──
  static String? _currentUserId;
  static String get currentUserId => _currentUserId ?? '';

  // ──────────────────────────────────────────
  // 1. Anonymous sign-in
  // ──────────────────────────────────────────
  static Future<void> signInAnonymously() async {
    // If already signed in, reuse session
    if (_auth.currentUser != null) {
      _currentUserId = _auth.currentUser!.uid;
      return;
    }
    final credential = await _auth.signInAnonymously();
    _currentUserId = credential.user?.uid;
  }

  // ──────────────────────────────────────────
  // 2. Generate a unique 6-character code
  //    and create a connection document in Firestore
  // ──────────────────────────────────────────
  static Future<String> createConnection() async {
    final token = await NotificationService.getToken() ?? '';
    final code = _generateCode();

    final connection = ConnectionModel(
      code: code,
      userAId: currentUserId,
      userAToken: token,
    );

    // Use the code as document ID for easy lookup
    await _db
        .collection(AppConstants.connectionsCollection)
        .doc(code)
        .set(connection.toMap());

    // Persist locally so we know which connection we belong to
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefConnectionCode, code);
    await prefs.setString(AppConstants.prefUserId, currentUserId);
    await prefs.setBool(AppConstants.prefIsUserA, true);

    return code;
  }

  // ──────────────────────────────────────────
  // 3. Join an existing connection using a code
  //    Returns error string or null on success
  // ──────────────────────────────────────────
  static Future<String?> joinConnection(String code) async {
    final docRef = _db
        .collection(AppConstants.connectionsCollection)
        .doc(code.toUpperCase());

    final snap = await docRef.get();

    // Code does not exist
    if (!snap.exists) return 'Invalid code. Please check and try again.';

    final data = snap.data()!;

    // Connection already has 2 users
    if (data['userBId'] != null && (data['userBId'] as String).isNotEmpty) {
      return 'This code is already in use by another pair.';
    }

    // Cannot pair with yourself
    if (data['userAId'] == currentUserId) {
      return 'You cannot pair with yourself!';
    }

    final token = await NotificationService.getToken() ?? '';

    // Update Firestore: add User B details and mark active
    await docRef.update({
      'userBId': currentUserId,
      'userBToken': token,
      'active': true,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefConnectionCode, code.toUpperCase());
    await prefs.setString(AppConstants.prefUserId, currentUserId);
    await prefs.setBool(AppConstants.prefIsUserA, false);

    return null; // success
  }

  // ──────────────────────────────────────────
  // 4. Listen for connection becoming active
  //    (User A waits for User B to join)
  // ──────────────────────────────────────────
  static Stream<ConnectionModel?> listenToConnection(String code) {
    return _db
        .collection(AppConstants.connectionsCollection)
        .doc(code)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return ConnectionModel.fromMap(snap.data()!);
    });
  }

  // ──────────────────────────────────────────
  // 5. Get partner's FCM token
  //    (so we know where to send the notification)
  // ──────────────────────────────────────────
  static Future<String?> getPartnerToken(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final isUserA = prefs.getBool(AppConstants.prefIsUserA) ?? true;

    final snap = await _db
        .collection(AppConstants.connectionsCollection)
        .doc(code)
        .get();

    if (!snap.exists) return null;
    final data = snap.data()!;

    // If I am User A → partner is User B, and vice-versa
    return isUserA
        ? data['userBToken'] as String?
        : data['userAToken'] as String?;
  }

  // ──────────────────────────────────────────
  // 6. Update FCM token in Firestore
  //    (token can refresh — keep it up to date)
  // ──────────────────────────────────────────
  static Future<void> refreshFcmToken(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final isUserA = prefs.getBool(AppConstants.prefIsUserA) ?? true;
    final token = await NotificationService.getToken() ?? '';

    final field = isUserA ? 'userAToken' : 'userBToken';
    await _db
        .collection(AppConstants.connectionsCollection)
        .doc(code)
        .update({field: token});
  }

  // ──────────────────────────────────────────
  // 7. Disconnect / leave connection
  // ──────────────────────────────────────────
  static Future<void> disconnect(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefConnectionCode);
    await prefs.remove(AppConstants.prefUserId);
    await prefs.remove(AppConstants.prefIsUserA);

    // Mark connection inactive in Firestore
    await _db
        .collection(AppConstants.connectionsCollection)
        .doc(code)
        .update({'active': false});
  }

  // ──────────────────────────────────────────
  // Helper: generate 6-char alphanumeric code
  // ──────────────────────────────────────────
  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous I/O/1/0
    final rand = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    int seed = rand;
    for (int i = 0; i < 6; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      code += chars[seed % chars.length];
    }
    return code;
  }
}
