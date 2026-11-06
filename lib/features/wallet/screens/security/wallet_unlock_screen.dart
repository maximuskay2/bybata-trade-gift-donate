import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_toast.dart' show AppToast, ToastType;
import '../../../../core/widgets/pin_entry_layout.dart';
import '../../../settings/widgets/settings_ui.dart';
import '../../services/wallet_security_service.dart';
import '../../widgets/wallet_pin_reset_sheet.dart';

class WalletUnlockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  
  const WalletUnlockScreen({
    super.key,
    this.onUnlocked,
  });

  @override
  State<WalletUnlockScreen> createState() => _WalletUnlockScreenState();
}

class _WalletUnlockScreenState extends State<WalletUnlockScreen>
    with TickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  
  String _enteredPin = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  bool _isLocked = false;
  DateTime? _lockUntil;
  bool _biometricFailed = false;
  String? _biometricLabel;
  IconData _biometricIcon = Icons.fingerprint_rounded;
  bool _canUseBiometric = false;
  /// Optional override when stored length is wrong (e.g. legacy 6 default).
  int? _lengthOverride;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareBiometricUnlock();
    });
  }

  Future<void> _prepareBiometricUnlock() async {
    final securityService =
        Provider.of<WalletSecurityService>(context, listen: false);
    if (!securityService.isBiometricEnabled) return;

    final enrolled = await securityService.hasEnrolledBiometrics();
    final label = await securityService.getBiometricTypeName();
    final types = await securityService.getAvailableBiometrics();
    if (!mounted) return;

    setState(() {
      _canUseBiometric = enrolled;
      _biometricLabel = label;
      _biometricIcon = _iconForBiometricTypes(types);
    });

    if (enrolled) {
      await _attemptBiometricUnlock();
    }
  }

  IconData _iconForBiometricTypes(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return Icons.face_rounded;
    }
    if (types.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint_rounded;
    }
    if (types.contains(BiometricType.iris)) {
      return Icons.remove_red_eye_outlined;
    }
    return Icons.fingerprint_rounded;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // --- LOGIC PRESERVATION ---

  Future<void> _attemptBiometricUnlock() async {
    final securityService =
        Provider.of<WalletSecurityService>(context, listen: false);

    if (!securityService.isBiometricEnabled || !_canUseBiometric) return;

    final result = await securityService.authenticateWithBiometricWithDetails();
    if (!mounted) return;

    if (result.success) {
      _handleSuccessfulUnlock();
    } else {
      setState(() {
        _biometricFailed = true;
        if (result.errorMessage != null && !result.cancelled) {
          _errorMessage = result.errorMessage;
        }
      });
    }
  }

  void _handleBack() {
    Navigator.of(context).pop(false);
  }

  int _pinLengthFor(WalletSecurityService security) {
    final override = _lengthOverride;
    if (override == WalletSecurityService.pinLengthFour ||
        override == WalletSecurityService.pinLengthSix) {
      return override!;
    }
    final stored = security.pinLength;
    if (stored == WalletSecurityService.pinLengthFour ||
        stored == WalletSecurityService.pinLengthSix) {
      return stored;
    }
    return WalletSecurityService.pinLengthSix;
  }

  void _addNumber(String number) {
    if (_isLoading) return;
    final securityService =
        Provider.of<WalletSecurityService>(context, listen: false);
    final length = _pinLengthFor(securityService);
    if (_enteredPin.length >= length) return;

    setState(() {
      _enteredPin += number;
      _errorMessage = null;
    });
    if (_enteredPin.length == length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verifyPin();
      });
    }
  }

  void _deleteLast() {
    if (_enteredPin.isNotEmpty && !_isLoading) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _togglePinLength(WalletSecurityService security) {
    if (_isLoading) return;
    final current = _pinLengthFor(security);
    setState(() {
      _lengthOverride = current == WalletSecurityService.pinLengthSix
          ? WalletSecurityService.pinLengthFour
          : WalletSecurityService.pinLengthSix;
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    final securityService =
        Provider.of<WalletSecurityService>(context, listen: false);
    final length = _pinLengthFor(securityService);
    if (_enteredPin.length != length) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool success = await securityService.verifyPin(_enteredPin);

    if (!success) {
      try {
        final baseUrl = await EnvConfig.getBaseUrl();
        final api = ApiClient(baseUrl, const FlutterSecureStorage());
        final response = await api.post(
          '/v1/wallet/security/pin/verify',
          data: {'pin': _enteredPin},
        );
        final data = response.data;
        if (data is Map && (data['ok'] == true || data['success'] == true)) {
          await securityService.unlock();
          success = true;
        }
      } on DioException catch (_) {
        // API verify failed, fall through to _handleFailedAttempt
      } catch (_) {}
    }

    if (mounted) {
      if (success) {
        // Persist the length that actually worked (fixes stale 6-digit default).
        await securityService.setPinLength(_enteredPin.length);
        if (!mounted) return;
        _handleSuccessfulUnlock();
      } else {
        _handleFailedAttempt();
      }
    }
  }

  Future<void> _useBiometric(WalletSecurityService securityService) async {
    if (!_canUseBiometric) {
      setState(() {
        _biometricFailed = true;
        _errorMessage =
            'Biometrics unavailable. Enter your wallet PIN below.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await securityService.authenticateWithBiometricWithDetails();

    if (mounted) {
      setState(() => _isLoading = false);
      if (result.success) {
        _handleSuccessfulUnlock();
      } else {
        setState(() {
          _biometricFailed = true;
          _errorMessage = result.errorMessage ??
              'Biometric failed. Enter your wallet PIN.';
        });
      }
    }
  }

  void _handleSuccessfulUnlock() {
    setState(() {
      _isLoading = false;
      _failedAttempts = 0;
      _isLocked = false;
    });
    
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _handleFailedAttempt() {
    setState(() {
      _isLoading = false;
      _failedAttempts++;
      _enteredPin = '';
      _errorMessage = 'Incorrect PIN';
    });

    _shakeController.forward().then((_) {
      _shakeController.reset();
    });

    if (_failedAttempts >= 5) {
      setState(() {
        _isLocked = true;
        _lockUntil = DateTime.now().add(const Duration(minutes: 5));
      });
      _startLockTimer();
    }
  }

  void _startLockTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isLocked && _lockUntil != null) {
        final now = DateTime.now();
        if (now.isBefore(_lockUntil!)) {
          setState(() {}); 
          _startLockTimer(); 
        } else {
          setState(() {
            _isLocked = false;
            _lockUntil = null;
            _failedAttempts = 0;
          });
        }
      }
    });
  }

  Future<void> _onForgotPin() async {
    final reset = await WalletPinResetFlow.start(context);
    if (!mounted || !reset) return;

    setState(() {
      _failedAttempts = 0;
      _isLocked = false;
      _lockUntil = null;
      _enteredPin = '';
      _errorMessage = null;
      _biometricFailed = false;
    });

    AppToast.show(
      context,
      'PIN updated. Enter your new PIN to unlock.',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Consumer<WalletSecurityService>(
        builder: (context, securityService, _) {
          if (_isLocked && _lockUntil != null) {
            return _buildLockedScaffold(context);
          }

          final pinLength = _pinLengthFor(securityService);
          final subtitle = _biometricFailed
              ? 'Biometric unavailable or cancelled. Enter your $pinLength-digit PIN.'
              : _canUseBiometric && securityService.isBiometricEnabled
                  ? 'Use $_biometricLabel or enter your $pinLength-digit PIN'
                  : 'Enter your $pinLength-digit wallet PIN to continue';

          return PinEntryLayout(
            title: 'Unlock wallet',
            subtitle: subtitle,
            pinLength: pinLength,
            filledCount: _enteredPin.length,
            errorMessage: _errorMessage,
            isLoading: _isLoading,
            onBack: _handleBack,
            onDigit: _addNumber,
            onBackspace: _deleteLast,
            footer: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (securityService.isBiometricEnabled && _canUseBiometric)
                  TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _useBiometric(securityService),
                    icon: Icon(_biometricIcon),
                    label: Text('Use ${_biometricLabel ?? 'biometrics'}'),
                  ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => _togglePinLength(securityService),
                  child: Text(
                    pinLength == WalletSecurityService.pinLengthSix
                        ? 'Use 4-digit PIN instead'
                        : 'Use 6-digit PIN instead',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _onForgotPin,
                  child: const Text('Forgot PIN?'),
                ),
                if (_failedAttempts > 0)
                  Text(
                    'Attempts: $_failedAttempts/5',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _failedAttempts > 3
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLockedScaffold(BuildContext context) {
    final remaining = _lockUntil!.difference(DateTime.now());
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SettingsUi.pageBackground(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 56, color: AppColors.warning),
              const SizedBox(height: 24),
              Text(
                'Wallet locked',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Too many failed attempts. Try again in '
                '${minutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _handleBack,
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}