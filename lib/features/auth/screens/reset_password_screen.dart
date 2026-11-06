import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../repository/auth_repository.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../utils/auth_errors.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final auth = AuthRepository(client.dio, client.storage);

      await auth.resetPassword(
        token: _codeController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      AppToast.success(context, 'Password reset successful. Please sign in.');
      GuardedNavigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, AuthErrors.resetPassword(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          _build3DContainer(
                            padding: const EdgeInsets.all(24),
                            radius: 100,
                            child: Icon(Icons.lock_reset, size: 48, color: primaryColor),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Reset Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the 6-digit code sent to ${widget.email} and choose a new password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          _build3DContainer(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                _buildTextField(
                                  label: 'Reset Code',
                                  hintText: 'Enter 6-digit code',
                                  controller: _codeController,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty) return 'Enter the code from your email';
                                    if (value.length < 4) return 'Enter the full code from your email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                _buildTextField(
                                  label: 'New Password',
                                  hintText: 'Enter new password',
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: scheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) return 'Enter a new password';
                                    if (value.length < 8) {
                                      return 'Use at least 8 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  label: 'Confirm Password',
                                  hintText: 'Re-enter new password',
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: scheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    onPressed: () {
                                      setState(() => _obscureConfirm = !_obscureConfirm);
                                    },
                                  ),
                                  validator: (v) {
                                    final value = v ?? '';
                                    if (value.isEmpty) return 'Confirm your new password';
                                    if (value != _passwordController.text) {
                                      return 'Passwords don\'t match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                _buildPrimaryButton(
                                  context: context,
                                  onTap: _isLoading ? null : _handleResetPassword,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Update Password',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ],
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
      ),
    );
  }

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
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.9),
            offset: const Offset(-2, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final btnColor = scheme.primary;

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
            BoxShadow(
              color: btnColor.withValues(alpha: 0.4),
              offset: const Offset(0, 8),
              blurRadius: 16,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(child: child),
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
