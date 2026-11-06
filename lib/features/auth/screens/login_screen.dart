import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../karma/providers/karma_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../widgets/auth_social_flow.dart';
import '../widgets/auth_social_section.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../utils/auth_errors.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

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
    _loadLastLoginIdentifier();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingVerification();
    });
  }

  Future<void> _loadLastLoginIdentifier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString('last_login_identifier');
      if (last != null && last.isNotEmpty && mounted) {
        setState(() => _emailController.text = last);
      }
    } catch (_) {}
  }

  Future<void> _checkPendingVerification() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pending = authProvider.pendingVerificationEmail;
      if (pending != null && pending.isNotEmpty && mounted) {
        try {
          await authProvider.resendVerification(pending);
        } catch (_) {}
        authProvider.clearPendingVerification();
        GuardedNavigator.pushReplacementNamed(context,
          '/email-verification',
          arguments: pending,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({
    required Widget child,
    Color? color,
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

  Widget _buildRecessedInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool compact = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = context.watch<ThemeProvider>().isGlassModeEnabled;
    
    // Simulate recessed depth with color
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
        SizedBox(height: compact ? 4 : 8),
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: isDark ? 0.05 : 0.02),
            ),
            // Inner shadow simulation via inset is hard in flutter standard, 
            // so we use a subtle border and background color shift.
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: icon != null
                  ? Icon(icon, color: scheme.onSurface.withValues(alpha: 0.6))
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 12 : 16),
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
            BoxShadow(
              color: btnColor.withValues(alpha: 0.4),
              offset: const Offset(0, 8),
              blurRadius: 16
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 4),
              blurRadius: 4
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // --- LOGIC PRESERVATION ---
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        if (mounted) {
          GuardedNavigator.pushReplacementNamed(context, '/main');
        }
      } else {
        if (mounted) {
          final pendingEmail = authProvider.pendingVerificationEmail;
          if (pendingEmail != null) {
            authProvider.clearPendingVerification();
            GuardedNavigator.pushReplacementNamed(context,
              '/email-verification',
              arguments: pendingEmail,
            );
          } else {
            _showErrorSnackBar(
              AuthErrors.sanitizeProviderMessage(
                authProvider.errorMessage,
                flow: AuthFlow.login,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(AuthErrors.login(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final success = await AuthSocialFlow.signInWithGoogle(context);
      if (!success && mounted) {
        _showErrorSnackBar(
          AuthSocialFlow.errorMessage(
            context,
            flow: AuthFlow.googleSignIn,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(AuthErrors.googleSignIn(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final success = await AuthSocialFlow.signInWithApple(context);
      if (!success && mounted) {
        _showErrorSnackBar(
          AuthSocialFlow.errorMessage(
            context,
            flow: AuthFlow.appleSignIn,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(AuthErrors.appleSignIn(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    AppToast.error(context, message);
  }

  void _showDailyLoginKarmaNotification() {
    AppToast.success(
      context,
      'Daily login bonus: +10 KARMA',
      title: 'KARMA earned',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 820;
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 16 : 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            const AuthScreenHeader(
                              title: 'Welcome back',
                              subtitle: 'Sign in to trade, gift, and connect',
                            ),
                            const SizedBox(height: 28),

                            _build3DContainer(
                              padding: EdgeInsets.all(compact ? 20 : 28),
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
                                      compact: compact,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Enter your email address';
                                        }
                                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                                          return 'Enter a valid email address';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: compact ? 16 : 24),
                                    _buildRecessedInput(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hint: 'Enter your password',
                                      icon: Icons.lock_outlined,
                                      obscureText: _obscurePassword,
                                      compact: compact,
                                      suffixIcon: GestureDetector(
                                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: scheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      validator: (value) => (value?.isEmpty ?? true)
                                          ? 'Enter your password'
                                          : null,
                                    ),
                                    SizedBox(height: compact ? 12 : 16),

                                    // Remember & Forgot
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                width: 24, height: 24,
                                                decoration: BoxDecoration(
                                                  color: _rememberMe ? primaryColor : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _rememberMe
                                                        ? primaryColor
                                                        : scheme.onSurface.withValues(alpha: 0.4),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: _rememberMe
                                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Remember me',
                                                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ),
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: () => GuardedNavigator.pushNamed(context, '/forgot-password'),
                                            child: Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: compact ? 24 : 32),

                                    // The Power Button
                                    _buildTactileButton(
                                      onTap: _isLoading ? null : _handleLogin,
                                      color: primaryColor,
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
                                              'Sign In',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 24),
                                    AuthSocialSection(
                                      isLoading: _isLoading,
                                      onGoogle: _handleGoogleLogin,
                                      onApple: _handleAppleLogin,
                                      showTopDivider: true,
                                      dividerLabel: 'or sign in with',
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Sign Up Link (Floating Chip)
                            GestureDetector(
                              onTap: () => GuardedNavigator.pushNamed(context, '/register'),
                              child: _build3DContainer(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                radius: 30,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Don't have an account?",
                                      style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Sign Up",
                                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
    // Fluid Gradient for Glass Mode
    final base = isDark
        ? [const Color(0xFF0F1017), const Color(0xFF151826), primary.withValues(alpha: 0.15)]
        : [const Color(0xFFF5F6FB), const Color(0xFFECE7FF), primary.withValues(alpha: 0.08)];
    
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: base,
      ),
    );
  }

}