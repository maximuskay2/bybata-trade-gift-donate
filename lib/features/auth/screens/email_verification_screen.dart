import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../notifications/services/push_notifications_service.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../utils/auth_errors.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  
  const EmailVerificationScreen({
    super.key, 
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  String? _lastSentTo;
  bool _isLoading = false;
  bool _isVerified = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // For the invisible input

  late AnimationController _animationController;
  late AnimationController _successAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  Timer? _resendTimer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    
    // Listen to controller to update UI slots
    _codeController.addListener(() => setState(() {}));

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
    _startResendTimer();
    _startAutoCheckTimer();
    // Initial verification email is sent by the backend (e.g., on registration/login).
    // Users can explicitly request a resend if they don't see it.
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    _autoCheckTimer?.cancel();
    _animationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _startAutoCheckTimer() {
    // Auto-check removed for OTP flow; user enters code manually
  }

  Future<void> _sendVerification() async {
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final auth = AuthRepository(client.dio, client.storage);
      await auth.requestEmailVerification(widget.email);
      if (mounted) setState(() { _lastSentTo = widget.email; });
    } catch (e) {
      if (mounted) {
        _showFeedback(
          'We couldn\'t send a verification code right now. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _submitCode() async {
    setState(() => _isLoading = true);
    try {
      final code = _codeController.text.trim();
      if (code.length < 4) {
        throw Exception('Enter the 6-digit code from your email');
      }
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      await AuthRepository(client.dio, client.storage).confirmEmail(code);
      await _handleVerificationSuccess();
    } catch (e) {
      if (mounted) {
        _showFeedback(AuthErrors.emailVerification(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerificationSuccess() async {
    _autoCheckTimer?.cancel();
    setState(() => _isVerified = true);
    await _successAnimationController.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) {
          await authProvider.refreshUserData();
          // Now that the user is verified and profile refreshed, sync the
          // device's push token with the server.
          await PushNotificationsService.syncTokenWithServer();
        }
        authProvider.clearPendingVerification();
      } catch (_) {}
      GuardedNavigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isLoading = true);
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final auth = AuthRepository(client.dio, client.storage);
      await auth.requestEmailVerification(widget.email);

      if (mounted) {
        _showFeedback('A new verification code was sent to your email.');
        setState(() {
          _isLoading = false;
          _canResend = false;
          _resendCountdown = 60;
        });
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        _showFeedback(
          AuthErrors.emailVerification(e),
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeEmail() {
    GuardedNavigator.pushReplacementNamed(context, '/register');
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (isError) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({
    required Widget child,
    double radius = 24,
    EdgeInsets? padding,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = context.watch<ThemeProvider>().isGlassModeEnabled;

    if (isGlass) {
      return ByBataGlassContainer(
        padding: padding,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.16 : 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.9),
            offset: const Offset(-2, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = context.watch<ThemeProvider>().isGlassModeEnabled;
    final primaryColor = scheme.primary;

    return Scaffold(
      backgroundColor: scheme.background,
      body: Container(
        decoration: _buildBackgroundDecoration(
          isDark: isDark,
          isGlass: isGlass,
          primary: primaryColor,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Back Button (Floating Chip)
                    if (!_isVerified)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => GuardedNavigator.pushNamedAndRemoveUntil(context,
                            '/login',
                            (route) => false,
                          ),
                          child: _build3DContainer(
                            radius: 14,
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    if (!_isVerified) ...[
                      // 3D Mailbox Icon
                      _build3DContainer(
                        radius: 100,
                        padding: const EdgeInsets.all(30),
                        child: Icon(Icons.mark_email_unread_outlined, size: 60, color: primaryColor),
                      ),
                      const SizedBox(height: 32),

                      Text(
                        'Verify Your Email',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We\'ve sent a code to\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: scheme.onSurface.withValues(alpha: 0.6), height: 1.5),
                      ),
                      const SizedBox(height: 40),

                      // The Verification Slab
                      _build3DContainer(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text(
                              'Enter 6-digit Code',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),
                            
                            // Custom PIN Input System
                            _buildPinCodeInput(isDark, scheme),
                            
                            const SizedBox(height: 30),
                            
                            // Verify Button
                            GestureDetector(
                              onTap: _isLoading ? null : _submitCode,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Verify Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Resend & Change Email (Tactile Buttons)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: (_canResend && !_isLoading) ? _resendVerificationEmail : null,
                              child: _build3DContainer(
                                radius: 16,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    _canResend ? 'Resend Code' : 'Wait ${_resendCountdown}s',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _canResend ? primaryColor : scheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: _changeEmail,
                              child: _build3DContainer(
                                radius: 16,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'Change Email',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface.withValues(alpha: 0.7)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    ] else ...[
                      // Success State (Glowing Green Slab) centered vertically
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: _build3DContainer(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle, size: 60, color: Colors.green),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Verified!',
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scheme.onSurface),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Redirecting to ByBata...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: scheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                  const SizedBox(height: 30),
                                  const CircularProgressIndicator(strokeWidth: 3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Custom PIN Input: Invisible TextField overlaying 3D Boxes
  Widget _buildPinCodeInput(bool isDark, ColorScheme scheme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // The Visual Row (6 Slots)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final hasChar = _codeController.text.length > index;
            return Container(
              width: 44,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D26) : const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasChar 
                      ? scheme.primary 
                      : scheme.onSurface.withValues(alpha: isDark ? 0.1 : 0.05),
                  width: hasChar ? 1.5 : 1,
                ),
                boxShadow: hasChar ? [
                  BoxShadow(color: scheme.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))
                ] : null,
              ),
              child: Center(
                child: Text(
                  hasChar ? _codeController.text[index] : '',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ),
        // The Invisible Input
        Opacity(
          opacity: 0.0,
          child: TextField(
            controller: _codeController,
            focusNode: _focusNode,
            maxLength: 6,
            keyboardType: TextInputType.number,
            autofocus: true,
            showCursor: false,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
        // Tap detector to focus
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildBackgroundDecoration({
    required bool isDark,
    required bool isGlass,
    required Color primary,
  }) {
    if (!isGlass) {
      return BoxDecoration(color: Theme.of(context).colorScheme.background);
    }
    final colors = isDark
        ? [const Color(0xFF0F1017), const Color(0xFF171A26), primary.withValues(alpha: 0.12)]
        : [const Color(0xFFF7F6FF), const Color(0xFFEDE7FF), primary.withValues(alpha: 0.08)];
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
    );
  }
}