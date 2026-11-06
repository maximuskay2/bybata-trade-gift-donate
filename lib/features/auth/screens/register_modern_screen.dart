import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bybata/core/theme/app_theme.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/config/web_links_config.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../karma/providers/karma_provider.dart';
import '../../auth/repository/auth_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/currency_constants.dart';
import '../../../core/models/locale_hints.dart';
import '../../../core/services/locale_currency_detector.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/theme/theme_provider.dart';
import '../widgets/auth_social_flow.dart';
import '../widgets/auth_social_section.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../utils/auth_errors.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class RegisterModernScreen extends StatefulWidget {
  const RegisterModernScreen({super.key});

  @override
  State<RegisterModernScreen> createState() => _RegisterModernScreenState();
}

class _RegisterModernScreenState extends State<RegisterModernScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  String? _pendingReferralCode;
  final _referralCodeController = TextEditingController();
  late String _signupCurrency;
  String? _signupCountryCode;
  
  // Password Strength State
  double _passwordStrength = 0.0;
  Color _strengthColor = Colors.grey;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final hints = LocaleCurrencyDetector.detectFromDevice();
    _signupCurrency = hints.preferredFiatCurrency ?? LocaleCurrencyDetector.defaultCurrency;
    _signupCountryCode = hints.countryCode;
    _passwordController.addListener(_updatePasswordStrength);
    _loadPendingReferralCode();
    
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('pending_invite_code');
      if (code != null && code.trim().isNotEmpty && mounted) {
        setState(() {
          _pendingReferralCode = code.trim();
          _referralCodeController.text = code.trim();
        });
      }
    } catch (_) {}
  }

  void _updatePasswordStrength() {
    final pass = _passwordController.text;
    double strength = 0;
    if (pass.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(pass)) strength += 0.25;
    if (RegExp(r'[a-z]').hasMatch(pass)) strength += 0.25;
    if (RegExp(r'\d').hasMatch(pass)) strength += 0.25;

    setState(() {
      _passwordStrength = strength;
      if (strength <= 0.25) _strengthColor = Colors.red;
      else if (strength <= 0.5) _strengthColor = Colors.orange;
      else if (strength <= 0.75) _strengthColor = AppColors.primary;
      else _strengthColor = Colors.green;
    });
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({
    required Widget child,
    double radius = 30,
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
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    bool obscureText = false,
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

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.05 : 0.02),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: icon != null ? Icon(icon, color: scheme.onSurface.withValues(alpha: 0.6), size: 20) : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTactileButton({required VoidCallback? onTap, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = scheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildCurrencyRow(Color primaryColor, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    final option = CurrencyConstants.optionFor(_signupCurrency);
    final flag = _flagForCurrency(_signupCurrency);
    final regionHint = _signupCountryCode != null
        ? 'Suggested for your region · $_signupCountryCode'
        : 'Used for wallet funding and listing prices';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.currency_exchange_rounded, size: 18, color: primaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your currency',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    regionHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showSignupCurrencyPicker(isDark, primaryColor),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          primaryColor.withValues(alpha: 0.18),
                          primaryColor.withValues(alpha: 0.08),
                        ]
                      : [
                          primaryColor.withValues(alpha: 0.08),
                          primaryColor.withValues(alpha: 0.03),
                        ],
                ),
                border: Border.all(
                  color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: isDark ? 0.55 : 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 22)),
                          Text(
                            option?.symbol ?? _signupCurrency,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option?.code ?? _signupCurrency,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option?.name ?? 'Select a currency',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface.withValues(alpha: 0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: isDark ? 0.7 : 0.95),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 16, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
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
      ],
    );
  }

  void _showSignupCurrencyPicker(bool isDark, Color primaryColor) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14121C) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                    child: Column(
                      children: [
                        Text(
                          'Choose your currency',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pick the money you use day to day. You can change this later in settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: CurrencyConstants.displayCurrencies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final opt = CurrencyConstants.displayCurrencies[index];
                        final selected = opt.code == _signupCurrency;
                        final flag = _flagForCurrency(opt.code);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _signupCurrency = opt.code;
                                _signupCountryCode ??= _countryForCurrency(opt.code);
                              });
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.08)
                                    : scheme.surfaceContainerHighest.withValues(
                                        alpha: isDark ? 0.35 : 0.55,
                                      ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? primaryColor.withValues(alpha: 0.55)
                                      : scheme.outlineVariant.withValues(alpha: 0.35),
                                  width: selected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: scheme.surface.withValues(
                                        alpha: isDark ? 0.65 : 0.95,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(flag, style: const TextStyle(fontSize: 20)),
                                        Text(
                                          opt.symbol,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          opt.code,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          opt.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurface.withValues(alpha: 0.58),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected ? primaryColor : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? primaryColor
                                            : scheme.onSurface.withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _flagForCurrency(String code) {
    const flags = {
      'NGN': '🇳🇬',
      'USD': '🇺🇸',
      'GBP': '🇬🇧',
      'EUR': '🇪🇺',
      'GHS': '🇬🇭',
      'KES': '🇰🇪',
      'ZAR': '🇿🇦',
      'JPY': '🇯🇵',
      'CAD': '🇨🇦',
    };
    return flags[code.toUpperCase()] ?? '💱';
  }

  String? _countryForCurrency(String code) {
    const map = {
      'NGN': 'NG',
      'USD': 'US',
      'GBP': 'GB',
      'EUR': 'DE',
      'GHS': 'GH',
      'KES': 'KE',
      'ZAR': 'ZA',
      'JPY': 'JP',
      'CAD': 'CA',
    };
    return map[code.toUpperCase()];
  }

  // --- LOGIC PRESERVATION ---
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _showError('Please accept the Terms and Conditions to create your account.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final authRepo = AuthRepository(client.dio, client.storage);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final username = _usernameController.text.trim();
      final available = await authRepo.isUsernameAvailable(username);
      if (!available) {
        _showError('This username is already taken. Please choose another one.');
        return;
      }
      final displayName = username.isNotEmpty ? username : _emailController.text.trim();
      final referralCode = _referralCodeController.text.trim().isNotEmpty
          ? _referralCodeController.text.trim()
          : _pendingReferralCode;
      final success = await authProvider.signUpWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: displayName,
        username: username.isEmpty ? _emailController.text.trim().split('@').first : username,
        referralCode: referralCode,
        localeHints: LocaleHints(
          countryCode: _signupCountryCode,
          preferredFiatCurrency: _signupCurrency,
          timezone: LocaleCurrencyDetector.detectFromDevice().timezone,
        ),
      );
      if (success && (referralCode != null && referralCode.isNotEmpty)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_invite_code');
      }
      if (!success) {
        _showError(
          AuthErrors.sanitizeProviderMessage(
            authProvider.errorMessage,
            flow: AuthFlow.signUp,
          ),
        );
        return;
      }

      if (mounted) {
        final karma = Provider.of<KarmaProvider>(context, listen: false);
        await karma.addTransaction(100, 'welcome_bonus', 'Welcome bonus');
      }

      if (mounted) {
        GuardedNavigator.pushNamed(context, '/email-verification', arguments: _emailController.text.trim());
      }
    } catch (e) {
      _showError(AuthErrors.signUp(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (!_acceptTerms) {
      _showError('Please accept the Terms of Service and Privacy Policy to continue.');
      return;
    }
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final success = await AuthSocialFlow.signInWithGoogle(context);
      if (!success && mounted) {
        _showError(AuthSocialFlow.errorMessage(context, flow: AuthFlow.googleSignIn));
      }
    } catch (e) {
      if (mounted) _showError(AuthErrors.googleSignIn(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignUp() async {
    if (!_acceptTerms) {
      _showError('Please accept the Terms of Service and Privacy Policy to continue.');
      return;
    }
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final success = await AuthSocialFlow.signInWithApple(context);
      if (!success && mounted) {
        _showError(AuthSocialFlow.errorMessage(context, flow: AuthFlow.appleSignIn));
      }
    } catch (e) {
      if (mounted) _showError(AuthErrors.appleSignIn(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    AppToast.error(context, msg);
  }

  Future<void> _openLegalDocument(String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        _showError('Couldn\'t open that link. Please try again later.');
      }
    } catch (_) {
      if (mounted) _showError('Could not open link');
    }
  }

  Widget _buildTermsAcceptanceRow(Color primaryColor, ColorScheme scheme) {
    final bodyStyle = TextStyle(
      fontSize: 12,
      height: 1.45,
      color: scheme.onSurface.withValues(alpha: 0.65),
    );
    final linkStyle = TextStyle(
      fontSize: 12,
      height: 1.45,
      color: primaryColor,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: primaryColor.withValues(alpha: 0.45),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _acceptTerms = !_acceptTerms),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _acceptTerms ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _acceptTerms
                    ? primaryColor
                    : scheme.onSurface.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: _acceptTerms
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('I agree to the ', style: bodyStyle),
              GestureDetector(
                onTap: () => _openLegalDocument(WebLinksConfig.termsUrl),
                child: Text('Terms of Service', style: linkStyle),
              ),
              Text(' and ', style: bodyStyle),
              GestureDetector(
                onTap: () => _openLegalDocument(WebLinksConfig.privacyUrl),
                child: Text('Privacy Policy', style: linkStyle),
              ),
              Text('.', style: bodyStyle),
            ],
          ),
        ),
      ],
    );
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
      body: Container(
        decoration: _buildBackgroundDecoration(
          isDark: isDark,
          isGlass: isGlass,
          primary: primaryColor,
          secondary: scheme.secondary,
        ),
        child: Stack(
          children: [
            // Background Blobs (The "Fluid" part)
            if (!isGlass) ...[ // Simple blobs if solid background
               Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.secondary.withValues(alpha: isDark ? 0.08 : 0.05),
                  ),
                ),
              ),
            ],
            
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AuthScreenHeader(
                            title: 'Create account',
                            subtitle: 'Join ByBata to trade, gift, and grow your karma',
                          ),
                          const SizedBox(height: 24),
                          _build3DContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildTermsAcceptanceRow(primaryColor, scheme),
                                  const SizedBox(height: 16),
                                  AuthSocialSection(
                                    isLoading: _isLoading,
                                    onGoogle: _handleGoogleSignUp,
                                    onApple: _handleAppleSignUp,
                                  ),
                                  const AuthOrDivider(label: 'or sign up with email'),
                                  const SizedBox(height: 20),

                                  // Email sign-up fields
                                  _buildRecessedInput(
                                    controller: _usernameController,
                                    hint: 'Username',
                                    icon: Icons.person_outline,
                                    validator: (v) => (v?.trim().isEmpty ?? true)
                                        ? 'Choose a username'
                                        : (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(v!)
                                            ? 'Use 3–20 letters, numbers, or underscores'
                                            : null),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildRecessedInput(
                                    controller: _emailController,
                                    hint: 'Email Address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => (v?.trim().isEmpty ?? true)
                                        ? 'Enter your email address'
                                        : (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)
                                            ? 'Enter a valid email address'
                                            : null),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildRecessedInput(
                                    controller: _referralCodeController,
                                    hint: 'Referral code (optional)',
                                    icon: Icons.person_add_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildCurrencyRow(primaryColor, isDark),
                                  const SizedBox(height: 16),
                                  _buildRecessedInput(
                                    controller: _passwordController,
                                    hint: 'Password',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscurePassword,
                                    suffixIcon: GestureDetector(onTap: () => setState(() => _obscurePassword = !_obscurePassword), child: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20)),
                                    validator: (v) {
                                      final t = v ?? '';
                                      if (!(t.length >= 8 && RegExp(r'[A-Z]').hasMatch(t) && RegExp(r'[a-z]').hasMatch(t) && RegExp(r'\d').hasMatch(t))) {
                                        return 'Use at least 8 characters with upper, lower, and a number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // HUD Style Password Meter
                                  _buildPasswordStrengthBar(),
                                  
                                  const SizedBox(height: 16),
                                  _buildRecessedInput(
                                    controller: _confirmPasswordController,
                                    hint: 'Confirm Password',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscureConfirm,
                                    suffixIcon: GestureDetector(onTap: () => setState(() => _obscureConfirm = !_obscureConfirm), child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20)),
                                    validator: (v) => (v != _passwordController.text)
                                        ? 'Passwords don\'t match'
                                        : null,
                                  ),
                                  
                                  const SizedBox(height: 22),
                                  _buildTactileButton(
                                    onTap: _isLoading ? null : _handleRegister,
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
                                            'Create account',
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
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Floating Footer Chip
                          GestureDetector(
                            onTap: () => GuardedNavigator.pushNamed(context, '/login'),
                            child: _build3DContainer(
                              radius: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: RichText(
                                text: TextSpan(
                                  text: "Already a member? ",
                                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
                                  children: [
                                    TextSpan(text: "Sign In", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                                  ],
                                ),
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
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration({
    required bool isDark,
    required bool isGlass,
    required Color primary,
    required Color secondary,
  }) {
    if (!isGlass) {
      return BoxDecoration(color: Theme.of(context).colorScheme.background);
    }
    final colors = isDark
        ? [const Color(0xFF0F1017), const Color(0xFF171A26), primary.withValues(alpha: 0.12)]
        : [const Color(0xFFF7F6FF), const Color(0xFFEDE7FF), secondary.withValues(alpha: 0.08)];
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
    );
  }

  Widget _buildPasswordStrengthBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: _passwordStrength > 0 ? _strengthColor : Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
            Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: _passwordStrength > 0.25 ? _strengthColor : Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
            Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: _passwordStrength > 0.5 ? _strengthColor : Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
            Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength > 0.75 ? _strengthColor : Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _passwordStrength == 0 ? "Enter password" : _passwordStrength <= 0.25 ? "Weak" : _passwordStrength <= 0.5 ? "Fair" : _passwordStrength <= 0.75 ? "Good" : "Strong",
          style: TextStyle(color: _strengthColor, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

}