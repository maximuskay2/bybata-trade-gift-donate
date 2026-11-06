import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../../karma/providers/karma_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../auth/repository/auth_repository.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../utils/auth_errors.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  int _currentStep = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _countries = [
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'Nigeria',
    'South Africa',
    'India',
    'Brazil',
    // Add more countries as needed
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _showErrorSnackBar('Please accept the Terms and Conditions to create your account.');
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
        _showErrorSnackBar('This username is already taken. Please choose another one.');
        return;
      }
      final displayNameCandidate =
          (_firstNameController.text.trim() + ' ' + _lastNameController.text.trim()).trim();
      final displayName = (username.isNotEmpty
              ? username
              : displayNameCandidate.isEmpty
                  ? _emailController.text.trim()
                  : displayNameCandidate);
      final success = await authProvider.signUpWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: displayName.isEmpty
            ? _emailController.text.trim()
            : displayName,
        username: username.isEmpty ? _emailController.text.trim().split('@').first : username,
      );
      if (!success) {
        _showErrorSnackBar(
          AuthErrors.sanitizeProviderMessage(
            authProvider.errorMessage,
            flow: AuthFlow.signUp,
          ),
        );
        return;
      }

      if (mounted) {
        final karmaProvider = Provider.of<KarmaProvider>(
          context,
          listen: false,
        );
        await karmaProvider.addTransaction(
          100,
          'welcome_bonus',
          'Welcome to BYBATA! Here\'s your starting KARMA bonus',
        );
      }

      GuardedNavigator.pushNamed(context,
        '/email-verification',
        arguments: _emailController.text.trim(),
      );
      _showWelcomeKarmaNotification();
    } catch (e) {
      _showErrorSnackBar(AuthErrors.signUp(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    AppToast.error(context, message);
  }

  void _showWelcomeKarmaNotification() {
    AppToast.success(
      context,
      'You\'ve earned 100 KARMA points',
      title: 'Welcome!',
    );
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _animationController.reset();
      _animationController.forward();
    } else {
      _handleRegister();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F7FF), Color(0xFFE8E1FF), Color(0xFFD4C4FF)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final w = constraints.maxWidth;
                  final compact = h < 820 || w < 380;
                  final ultraCompact = h < 700 || w < 340;
                  final titleSize = compact ? 22.0 : 42.0;
                  final subtitleSize = compact ? 12.0 : 16.0;
                  final topSpace = compact ? 4.0 : 48.0;
                  final betweenSpace = compact ? 6.0 : 20.0;
                  final postFormSpace = compact ? 6.0 : 24.0;
                  // Safe-area and keyboard-aware bottom padding for the button
                  final double viewPaddingBottom = MediaQuery.of(context).viewPadding.bottom;
                  final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
                  final double minPad = compact ? 14.0 : 20.0;
                  final double basePad = viewPaddingBottom > minPad ? viewPaddingBottom : minPad;
                  final double buttonBottomPad = keyboardInset > 0
                      ? basePad + (compact ? 12.0 : 16.0)
                      : basePad;
                  return Padding(
                    padding: EdgeInsets.all(compact ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: topSpace),
                        // Logo
                        Center(
                          child: Container(
                            width: compact ? 80 : 160,
                            height: compact ? 80 : 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF7F2E9),
                            ),
                            alignment: Alignment.center,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/animations/logo_small.png',
                                width: compact ? 52 : 90,
                                height: compact ? 52 : 90,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: betweenSpace),
                        // Title
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        // Subtitle
                        Text(
                          'Sign up to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: Colors.black.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: betweenSpace),
                        // Step indicator for improved navigation
                        _buildStepIndicator(compact),
                        SizedBox(height: betweenSpace),
                        // Centered content card
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(compact ? 12 : 24),
                                  child: SingleChildScrollView(
                                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                    child: Form(
                                      key: _formKey,
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      child: _buildCurrentStep(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: postFormSpace),
                        // Bottom Button (safe-area wrapped and lifted above system bar)
                        SafeArea(
                          bottom: true,
                          minimum: EdgeInsets.only(bottom: buttonBottomPad),
                          child: SizedBox(
                            width: double.infinity,
                            height: compact ? 42 : 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _nextStep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
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
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool compact) {
    final steps = const [
      ('Personal', Icons.person_outline),
      ('Location', Icons.location_on_outlined),
      ('Account', Icons.lock_outline),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final (label, icon) = steps[i];
        final selected = i == _currentStep;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GestureDetector(
            onTap: () {
              setState(() => _currentStep = i);
              _animationController.reset();
              _animationController.forward();
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: compact ? 34 : 40,
                  height: compact ? 34 : 40,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: compact ? 18 : 20, color: selected ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.black : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildAccountStep();
      default:
        return _buildPersonalInfoStep();
    }
  }

  Widget _buildPersonalInfoStep() {
    final compact = MediaQuery.of(context).size.height < 820;
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        ShadowCard(
          shadowIntensity: ShadowIntensity.medium,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 24),
            child: Column(
              children: [
                Column(
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      hintText: 'Enter your first name',
                      prefixIcon: Icons.person_outline,
                      compact: compact,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hintText: 'Enter your last name',
                      compact: compact,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 20),
                if (!compact) ...[
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hintText: 'Enter your email address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    compact: compact,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Email is required';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value!)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hintText: 'Enter your phone number',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    compact: compact,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Phone number is required';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        // Social sign-up removed per request
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    final compact = MediaQuery.of(context).size.height < 820;
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        ShadowCard(
          shadowIntensity: ShadowIntensity.medium,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 24),
            child: Column(
              children: [
                _buildDropdownField(
                  controller: _countryController,
                  label: 'Country',
                  hintText: 'Select your country',
                  prefixIcon: Icons.public,
                  items: _countries,
                  compact: compact,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Country is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: compact ? 8 : 20),
                _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  hintText: 'Enter your city',
                  prefixIcon: Icons.location_city_outlined,
                  compact: compact,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
                SizedBox(height: compact ? 8 : 20),
                if (!compact)
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address (Optional)',
                    hintText: 'Enter your address',
                    prefixIcon: Icons.home_outlined,
                    maxLines: 2,
                    compact: compact,
                  ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildAccountStep() {
    final compact = MediaQuery.of(context).size.height < 820;
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        ShadowCard(
          shadowIntensity: ShadowIntensity.medium,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 24),
            child: Column(
              children: [
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hintText: 'Choose a username',
                  prefixIcon: Icons.alternate_email,
                  compact: compact,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Username is required';
                    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(v)) {
                      return '3–20 chars, letters, digits, or _';
                    }
                    return null;
                  },
                ),
                SizedBox(height: compact ? 12 : 20),
                if (compact) ...[
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hintText: 'Enter your email address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    compact: compact,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Email is required';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value!)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: compact ? 12 : 20),
                ],
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Create a password',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outlined,
                  compact: compact,
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey[600],
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Password is required';
                    }
                    final v = value!;
                    final lengthOk = v.length >= 8;
                    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
                    final hasLower = RegExp(r'[a-z]').hasMatch(v);
                    final hasDigit = RegExp(r'\d').hasMatch(v);
                    final hasSymbol = RegExp(r'[!@#\$%\^&*(),.?":{}|<>_-]').hasMatch(v);
                    if (!(lengthOk && hasUpper && hasLower && hasDigit)) {
                      return 'Min 8 chars, include upper, lower, digit';
                    }
                    return null;
                  },
                ),
                SizedBox(height: compact ? 8 : 12),
                _buildPasswordHints(compact),
                SizedBox(height: compact ? 12 : 20),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: 'Confirm your password',
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: Icons.lock_outlined,
                  compact: compact,
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    child: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey[600],
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: compact ? 12 : 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: compact ? 8 : 12),
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: TextStyle(
                              fontSize: compact ? 13 : 14,
                              color: Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: 'Terms and Conditions',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 32),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                GestureDetector(
                  onTap: () { GuardedNavigator.pushNamed(context, '/login'); },
                  child: Text(
                    'Sign In',
                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool compact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
          enableInteractiveSelection: true,
          decoration: InputDecoration(
            isDense: compact,
            hintText: hintText,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 20)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 6 : 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordHints(bool compact) {
    final baseStyle = TextStyle(
      fontSize: compact ? 12 : 13,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 6),
          Text('Minimum 8 characters', style: baseStyle),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 6),
          Text('Include uppercase and lowercase letters', style: baseStyle),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 6),
          Text('Include at least one digit', style: baseStyle),
        ]),
      ],
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required List<String> items,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    bool compact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
          validator: validator,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: compact ? 16 : 20,
            color: Colors.grey[700],
          ),
          decoration: InputDecoration(
            isDense: compact,
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey[600], size: 20)
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 6 : 16,
            ),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            if (value != null) {
              controller.text = value;
            }
          },
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    String title,
    String iconPath,
    Color backgroundColor,
    Color textColor,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Since we don't have actual icons, using Flutter icons as placeholders
            Icon(
              title == 'Google' ? Icons.g_mobiledata : Icons.apple,
              size: 20,
              color: textColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Simulate Google Sign In
      await Future.delayed(const Duration(seconds: 2));

      // In real implementation, you'd use google_sign_in package
      // GoogleSignInAccount? account = await GoogleSignIn().signIn();

      AppToast.show(context, 'Google Sign In - Coming Soon!');
    } catch (e) {
      _showErrorSnackBar(AuthErrors.googleSignIn(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Simulate Apple Sign In
      await Future.delayed(const Duration(seconds: 2));

      // In real implementation, you'd use sign_in_with_apple package
      // AuthorizationCredentialAppleID credential = await SignInWithApple.getAppleIDCredential();

      AppToast.show(context, 'Apple Sign In - Coming Soon!');
    } catch (e) {
      _showErrorSnackBar(AuthErrors.appleSignIn(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
