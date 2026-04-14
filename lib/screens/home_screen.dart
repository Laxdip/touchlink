// ─────────────────────────────────────────────
// lib/screens/home_screen.dar
// Screen 2: The main "Send Touch" interface
//   • Big tap button (single, double, long)
//   • Anonymous mode toggle
//   • Connection status indicator
// ─────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/vibration_service.dart';
import '../utils/constants.dart';
import 'pairing_screen.dart';

class HomeScreen extends StatefulWidget {
  final String connectionCode;
  const HomeScreen({super.key, required this.connectionCode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  bool _anonymousMode = false;
  bool _isSending = false;
  String _statusMessage = '';
  String _lastTouchLabel = '';

  // Button press tracking for double-tap detection
  int _tapCount = 0;
  Timer? _tapTimer;

  // Ripple animation
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  // Glow animation on button press
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _setupAnimations();
    _refreshToken();

    // Listen for incoming FCM messages to show feedback in UI
    // (VibrationService is already triggered in notification_service)
  }

  void _setupAnimations() {
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rippleAnimation =
        Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(_glowController);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _anonymousMode = prefs.getBool(AppConstants.prefAnonymousMode) ?? false;
    });
  }

  Future<void> _saveAnonymousMode(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefAnonymousMode, val);
  }

  /// Keep FCM token fresh in Firestore
  Future<void> _refreshToken() async {
    await FirebaseService.refreshFcmToken(widget.connectionCode);
  }

  // ──────────────────────────────────────────
  // Handle tap: detect single vs double
  // ──────────────────────────────────────────
  void _onTap() {
    _tapCount++;
    _tapTimer?.cancel();

    // Wait 300ms to distinguish single vs double tap
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      final count = _tapCount;
      _tapCount = 0;
      if (count == 1) {
        _sendTouch(AppConstants.touchSingle);
      } else {
        _sendTouch(AppConstants.touchDouble);
      }
    });
  }

  // Handle long press
  void _onLongPress() {
    _tapTimer?.cancel();
    _tapCount = 0;
    _sendTouch(AppConstants.touchLong);
  }

  // ──────────────────────────────────────────
  // Send touch notification to partner
  // ──────────────────────────────────────────
  Future<void> _sendTouch(String type) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _statusMessage = '';
    });

    // Animate button
    _rippleController.forward(from: 0);
    _glowController.forward(from: 0).then((_) => _glowController.reverse());

    // Also vibrate sender's phone as confirmation
    await VibrationService.triggerFromType(type);

    try {
      final partnerToken =
          await FirebaseService.getPartnerToken(widget.connectionCode);

      if (partnerToken == null || partnerToken.isEmpty) {
        _showStatus('Partner not connected yet', isError: true);
        return;
      }

      await NotificationService.sendTouchNotification(
        targetFcmToken: partnerToken,
        touchType: type,
        anonymous: _anonymousMode,
        senderId: FirebaseService.currentUserId,
      );

      final label = _touchLabel(type);
      _showStatus('$label sent 💗');
      setState(() => _lastTouchLabel = label);
    } catch (e) {
      _showStatus('Failed to send: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showStatus(String msg, {bool isError = false}) {
    setState(() => _statusMessage = isError ? '⚠️ $msg' : msg);
    Future.delayed(
      const Duration(seconds: 3),
      () => mounted ? setState(() => _statusMessage = '') : null,
    );
  }

  String _touchLabel(String type) {
    switch (type) {
      case AppConstants.touchDouble:
        return 'Double tap';
      case AppConstants.touchLong:
        return 'Long hug';
      default:
        return 'Single tap';
    }
  }

  // ── Disconnect and go back to pairing ──
  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Disconnect?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will end your connection. You\'ll need to pair again.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.disconnect(widget.connectionCode);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PairingScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'TouchLink',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Connection code pill
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B9D).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6B9D).withOpacity(0.4),
              ),
            ),
            child: Text(
              widget.connectionCode,
              style: const TextStyle(
                color: Color(0xFFFF6B9D),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.link_off, color: Colors.white38),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // ── Status message ──
            AnimatedOpacity(
              opacity: _statusMessage.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const Spacer(flex: 1),

            // ── Touch instructions ──
            Text(
              'Tap · Double Tap · Hold',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // ── THE BIG TOUCH BUTTON ──
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple ring
                  AnimatedBuilder(
                    animation: _rippleAnimation,
                    builder: (_, __) => Transform.scale(
                      scale: _rippleAnimation.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF6B9D)
                                .withOpacity(1.0 - (_rippleAnimation.value - 1.0) / 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Glow
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (_, child) => Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B9D)
                                .withOpacity(0.4 * _glowAnimation.value),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: GestureDetector(
                      onTap: _onTap,
                      onLongPress: _onLongPress,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFc94b7b)],
                            center: Alignment(-0.3, -0.3),
                          ),
                        ),
                        child: Center(
                          child: _isSending
                              ? const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3)
                              : const Text('💗',
                                  style: TextStyle(fontSize: 64)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Last touch label ──
            if (_lastTouchLabel.isNotEmpty)
              Text(
                'Last: $_lastTouchLabel',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
              ),

            const Spacer(flex: 2),

            // ── Anonymous mode toggle ──
            _AnonymousToggle(
              value: _anonymousMode,
              onChanged: (val) {
                setState(() => _anonymousMode = val);
                _saveAnonymousMode(val);
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Anonymous mode toggle card ──
class _AnonymousToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AnonymousToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value
              ? const Color(0xFFFF6B9D).withOpacity(0.6)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          const Text('🥷', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anonymous Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'Silent vibration only — no notification text'
                      : 'Partner sees a notification message',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF6B9D),
          ),
        ],
      ),
    );
  }
}
