// ─────────────────────────────────────────────
// lib/screens/pairing_screen.dart
// Screen 1: Create or Join a connection
// ─────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _showJoinField = false;
  String? _generatedCode;
  String? _errorMessage;

  StreamSubscription<ConnectionModel?>? _connectionSub;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.95, end: 1.05).animate(_pulseController);
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _codeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Create a new pairing code ──
  Future<void> _createConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final code = await FirebaseService.createConnection();
      setState(() => _generatedCode = code);

      // Listen until partner joins (active == true)
      _connectionSub = FirebaseService.listenToConnection(code).listen((conn) {
        if (conn != null && conn.active) {
          _connectionSub?.cancel();
          _navigateToHome(code);
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not create connection: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Join using entered code ──
  Future<void> _joinConnection() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-character code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final error = await FirebaseService.joinConnection(code);
      if (error != null) {
        setState(() => _errorMessage = error);
        return;
      }
      _navigateToHome(code);
    } catch (e) {
      setState(() => _errorMessage = 'Could not join: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToHome(String code) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(connectionCode: code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ── App logo / title ──
              ScaleTransition(
                scale: _pulseAnimation,
                child: const Text('💗', style: TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 16),
              const Text(
                'TouchLink',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Feel closer, no matter the distance',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
              const SizedBox(height: 60),

              // ── If code was generated, show it waiting ──
              if (_generatedCode != null) ...[
                _WaitingCard(code: _generatedCode!),
              ] else ...[
                // ── Create button ──
                _ActionButton(
                  label: '✨  Create a Connection',
                  onTap: _isLoading ? null : _createConnection,
                  primary: true,
                ),
                const SizedBox(height: 16),

                // ── Join section ──
                if (!_showJoinField)
                  _ActionButton(
                    label: '🔗  Join with a Code',
                    onTap: () => setState(() => _showJoinField = true),
                    primary: false,
                  )
                else ...[
                  _JoinCodeField(controller: _codeController),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: _isLoading ? 'Connecting...' : '→  Connect',
                    onTap: _isLoading ? null : _joinConnection,
                    primary: true,
                  ),
                ],
              ],

              // ── Error message ──
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // ── Loading indicator ──
              if (_isLoading && _generatedCode == null) ...[
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Color(0xFFFF6B9D)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Waiting card shown after code is generated ──
class _WaitingCard extends StatelessWidget {
  final String code;
  const _WaitingCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'Share this code with your partner',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied!')),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6B9D)),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Color(0xFFFF6B9D),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Tap code to copy', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF6B9D),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Waiting for your partner…',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Join code input field ──
class _JoinCodeField extends StatelessWidget {
  final TextEditingController controller;
  const _JoinCodeField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 6,
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 6,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'XXXXXX',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 6),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6B9D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: const Color(0xFFFF6B9D).withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6B9D), width: 2),
        ),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
      ],
    );
  }
}

// ── Reusable action button ──
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              primary ? const Color(0xFFFF6B9D) : const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: primary
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFFF6B9D), width: 1.5),
          ),
          elevation: primary ? 4 : 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
