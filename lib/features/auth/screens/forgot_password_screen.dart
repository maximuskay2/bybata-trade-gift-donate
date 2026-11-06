import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../auth/repository/auth_repository.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../utils/auth_errors.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEmailSent = false;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({
    required Widget child,
    double radius = 24,
    EdgeInsets? padding,
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
        color: scheme.surface,
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

  Widget _buildRecessedInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = context.watch<ThemeProvider>().isGlassModeEnabled;

    // Simulate recessed depth
    final fillColor = isGlass
        ? scheme.surface.withValues(alpha: isDark ? 0.25 : 0.7)
        : (isDark ? const Color(0xFF1A1D26) : const Color(0xFFF2F4F8));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: isDark ? 0.05 : 0.02),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: icon != null ? Icon(icon, color: scheme.onSurface.withValues(alpha: 0.6)) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              hintStyle: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTactileButton({required VoidCallback? onTap, required Widget child, Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final btnColor = color ?? scheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [btnColor, btnColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: btnColor.withValues(alpha: 0.4), offset: const Offset(0, 8), blurRadius: 16),
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), offset: const Offset(0, 4), blurRadius: 4),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // --- LOGIC ---
  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final auth = AuthRepository(client.dio, client.storage);
      
      await auth.forgotPassword(_emailController.text.trim());
      
      if (mounted) {
        final email = _emailController.text.trim();
        setState(() => _isEmailSent = true);
        AppToast.success(context, 'Reset code sent! Check your email.');
        // Navigate to the password reset screen where the user can enter the
        // OTP code and choose a new password.
        GuardedNavigator.pushNamed(context,
          '/password-reset',
          arguments: email,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, AuthErrors.forgotPassword(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = scheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = context.watch<ThemeProvider>().isGlassModeEnabled;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: _build3DContainer(
              radius: 12, 
              padding: const EdgeInsets.all(0),
              child: Icon(Icons.arrow_back_ios_new, size: 20, color: scheme.onSurface),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: _buildBackgroundDecoration(
          isDark: isDark,
          isGlass: isGlass,
          primary: primaryColor,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        
                        // Hero Icon Pedestal
                        _build3DContainer(
                          padding: const EdgeInsets.all(24),
                          radius: 100,
                          child: Icon(
                            _isEmailSent ? Icons.mark_email_read : Icons.lock_reset,
                            size: 48,
                            color: primaryColor,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        Text(
                          _isEmailSent ? 'Check your mail' : 'Forgot Password?',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isEmailSent 
                              ? 'We have sent password recovery instructions to your email.' 
                              : 'Enter your registered email below to receive password reset instructions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 40),

                        // The Recovery Monolith
                        if (!_isEmailSent)
                          _build3DContainer(
                            padding: const EdgeInsets.all(32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildRecessedInput(
                                    controller: _emailController,
                                    label: 'Email Address',
                                    hint: 'Enter your email',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Enter your email address';
                                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                  _buildTactileButton(
                                    onTap: _isLoading ? null : _handlePasswordReset,
                                    child: _isLoading 
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text("Send Reset Link", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          _buildTactileButton(
                            onTap: () => Navigator.pop(context),
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black87,
                            child: const Text("Back to Sign In", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          
                        const SizedBox(height: 32),
                        
                        if (!_isEmailSent)
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: RichText(
                              text: TextSpan(
                                text: "Remember password? ",
                                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
                                children: [
                                  TextSpan(text: "Sign In", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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