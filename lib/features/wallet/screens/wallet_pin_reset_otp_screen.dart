import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_toast.dart' show AppToast, ToastType;

/// Screen for resetting wallet PIN via OTP sent to email.
class WalletPinResetOtpScreen extends StatefulWidget {
  const WalletPinResetOtpScreen({super.key});

  @override
  State<WalletPinResetOtpScreen> createState() => _WalletPinResetOtpScreenState();
}

class _WalletPinResetOtpScreenState extends State<WalletPinResetOtpScreen> {
  static const int _otpLength = 6;
  static const int _pinMinLength = 4;
  static const int _pinMaxLength = 6;

  // Step: 0 = request OTP, 1 = enter OTP + new PIN
  int _step = 0;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  String? _errorMessage;
  int _resendCountdown = 0;

  final List<String> _otpDigits = [];
  final List<String> _pinDigits = [];
  final List<String> _confirmDigits = [];
  // Which field is being edited: 'otp' | 'pin' | 'confirm'
  String _editingField = 'otp';

  @override
  void initState() {
    super.initState();
  }

  void _onOtpDigitTap(String digit) {
    if (_otpDigits.length < _otpLength) {
      setState(() {
        _otpDigits.add(digit);
        _errorMessage = null;
      });
    }
  }

  void _onPinDigitTap(String digit) {
    if (_pinDigits.length < _pinMaxLength) {
      setState(() {
        _pinDigits.add(digit);
        _errorMessage = null;
      });
    }
  }

  void _onConfirmDigitTap(String digit) {
    if (_confirmDigits.length < _pinMaxLength) {
      setState(() {
        _confirmDigits.add(digit);
        _errorMessage = null;
      });
    }
  }

  void _onBackspace() {
    setState(() {
      _errorMessage = null;
      if (_editingField == 'otp' && _otpDigits.isNotEmpty) {
        _otpDigits.removeLast();
      } else if (_editingField == 'pin' && _pinDigits.isNotEmpty) {
        _pinDigits.removeLast();
      } else if (_editingField == 'confirm' && _confirmDigits.isNotEmpty) {
        _confirmDigits.removeLast();
      }
    });
  }

  Future<void> _requestOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, const FlutterSecureStorage());
      await api.post('/v1/wallet/security/pin/reset/request');
      if (mounted) {
        setState(() {
          _step = 1;
          _isSendingOtp = false;
          _resendCountdown = 60;
        });
        _startResendCountdown();
        AppToast.show(context, 'Verification code sent to your email');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to send code. Please try again.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            msg = data['message'] as String;
          }
        }
        setState(() {
          _isSendingOtp = false;
          _errorMessage = msg;
        });
      }
    }
  }

  void _startResendCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendCountdown--;
        if (_resendCountdown < 0) _resendCountdown = 0;
      });
      return _resendCountdown > 0;
    });
  }

  Future<void> _submitReset() async {
    final otp = _otpDigits.join();
    final pin = _pinDigits.join();
    final confirm = _confirmDigits.join();

    if (otp.length != _otpLength) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your email');
      return;
    }
    if (pin.length < _pinMinLength || pin.length > _pinMaxLength) {
      setState(() => _errorMessage = 'PIN must be 4–6 digits');
      return;
    }
    if (pin != confirm) {
      setState(() {
        _errorMessage = 'PINs do not match';
        _confirmDigits.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, const FlutterSecureStorage());
      await api.post(
        '/v1/wallet/security/pin/reset/confirm',
        data: {'token': otp, 'newPin': pin},
      );
      if (mounted) {
        AppToast.show(context, 'PIN reset successfully', type: ToastType.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to reset PIN. Please try again.';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            msg = data['message'] as String;
          }
        }
        setState(() {
          _isLoading = false;
          _errorMessage = msg;
        });
      }
    }
  }

  Widget _buildDot(BuildContext context, bool filled, Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : context.dividerColor,
      ),
    );
  }

  Widget _buildNumberPad(
    BuildContext context, {
    required void Function(String) onDigit,
    VoidCallback? onBackspace,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumKey(context, '1', onDigit),
            const SizedBox(width: 16),
            _buildNumKey(context, '2', onDigit),
            const SizedBox(width: 16),
            _buildNumKey(context, '3', onDigit),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumKey(context, '4', onDigit),
            const SizedBox(width: 16),
            _buildNumKey(context, '5', onDigit),
            const SizedBox(width: 16),
            _buildNumKey(context, '6', onDigit),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumKey(context, '7', onDigit),
            const SizedBox(width: 16),
            _buildNumKey(context, '8', onDigit),
            const SizedBox(width: 16),
            _buildNumKey(context, '9', onDigit),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 56),
            _buildNumKey(context, '0', onDigit),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onBackspace,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.subtleFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.backspace_outlined, color: context.primaryText),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumKey(BuildContext context, String digit, void Function(String) onDigit) {
    return GestureDetector(
      onTap: () => onDigit(digit),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: context.cardSurface,
          shape: BoxShape.circle,
          border: Border.all(color: context.dividerColor),
          boxShadow: [BoxShadow(color: context.shadowColor, blurRadius: 4)],
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: context.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        title: Text(
          'Reset PIN with OTP',
          style: TextStyle(fontWeight: FontWeight.w900, color: context.primaryText),
        ),
        backgroundColor: context.pageBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _step == 0
            ? _buildRequestStep(context, primaryColor)
            : _buildConfirmStep(context, primaryColor),
      ),
    );
  }

  Widget _buildRequestStep(BuildContext context, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.email_outlined, size: 64, color: primaryColor),
        const SizedBox(height: 24),
        const Text(
          'Send verification code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ll send a 6-digit code to the email associated with your account. Use it to reset your wallet PIN.',
          style: TextStyle(fontSize: 14, color: context.secondaryText),
          textAlign: TextAlign.center,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSendingOtp ? null : _requestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSendingOtp
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Send verification code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _handleDigit(String digit) {
    setState(() {
      _errorMessage = null;
      if (_editingField == 'otp' && _otpDigits.length < _otpLength) {
        _otpDigits.add(digit);
        if (_otpDigits.length == _otpLength) _editingField = 'pin';
      } else if (_editingField == 'pin' && _pinDigits.length < _pinMaxLength) {
        _pinDigits.add(digit);
        if (_pinDigits.length == _pinMaxLength) _editingField = 'confirm';
      } else if (_editingField == 'confirm' && _confirmDigits.length < _pinMaxLength) {
        _confirmDigits.add(digit);
      }
    });
  }

  Widget _buildConfirmStep(BuildContext context, Color primaryColor) {
    final canSubmit = _otpDigits.length == _otpLength &&
        _pinDigits.length >= _pinMinLength &&
        _confirmDigits.length >= _pinMinLength &&
        _pinDigits.join() == _confirmDigits.join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the 6-digit code from your email and create a new PIN.',
          style: TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _editingField = 'otp'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verification code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _editingField == 'otp' ? primaryColor : Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _otpLength,
                  (i) => _buildDot(context, i < _otpDigits.length, primaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _editingField = 'pin'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New PIN (4–6 digits)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _editingField == 'pin' ? primaryColor : Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (i) => _buildDot(context, i < _pinDigits.length, primaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _editingField = 'confirm'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _editingField == 'confirm' ? primaryColor : Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (i) => _buildDot(context, i < _confirmDigits.length, primaryColor),
                ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _resendCountdown > 0 ? null : _requestOtp,
              child: Text(_resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend code'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildNumberPad(context, onDigit: _handleDigit, onBackspace: _onBackspace),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (canSubmit && !_isLoading) ? _submitReset : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Reset PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
