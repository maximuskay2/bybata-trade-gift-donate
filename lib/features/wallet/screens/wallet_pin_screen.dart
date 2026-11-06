import 'package:flutter/material.dart';
import '../../../core/widgets/pin_entry_layout.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/config/env_config.dart';
import 'package:bybata/core/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../../../core/theme/app_theme.dart';
import '../services/wallet_security_service.dart';

/// Screen for setting, verifying, or changing wallet PIN.
/// Users choose 4-digit or 6-digit length when creating/changing a PIN.
class WalletPinScreen extends StatefulWidget {
  final bool isSetting;
  final bool isChangingPin;
  final Function(String)? onVerified;
  final Function()? onCancel;
  /// When set, forces this length (4 or 6). Otherwise loaded from prefs / chosen by user.
  final int? pinLength;

  const WalletPinScreen({
    Key? key,
    this.isSetting = false,
    this.isChangingPin = false,
    this.onVerified,
    this.onCancel,
    this.pinLength,
  }) : super(key: key);

  @override
  State<WalletPinScreen> createState() => _WalletPinScreenState();
}

class _WalletPinScreenState extends State<WalletPinScreen> {
  final List<String> _pinDigits = [];
  bool _isLoading = false;
  bool _booting = true;
  String? _errorMessage;

  /// null = still choosing length (set / change-new only)
  int? _selectedLength;

  // Change PIN: 0=current, 1=new, 2=confirm
  // Set PIN: 0=new, 1=confirm
  int _changeStep = 0;
  String? _newPin;

  bool get _choosingLength =>
      widget.isSetting &&
      _selectedLength == null &&
      ((widget.isChangingPin && _changeStep == 1) ||
          (!widget.isChangingPin && _changeStep == 0 && _newPin == null));

  int get _pinLength =>
      _selectedLength ??
      widget.pinLength ??
      WalletSecurityService.pinLengthSix;

  bool get _canSubmit =>
      _pinDigits.length == _pinLength && !_isLoading && !_choosingLength;

  @override
  void initState() {
    super.initState();
    _bootstrapLength();
  }

  Future<void> _bootstrapLength() async {
    final security = WalletSecurityService();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await security.switchUser(auth.currentUser?.id);

    if (widget.pinLength == 4 || widget.pinLength == 6) {
      _selectedLength = widget.pinLength;
    } else if (!widget.isSetting) {
      // Verify existing PIN — use stored preference (default 6).
      _selectedLength = security.pinLength;
    } else if (widget.isChangingPin) {
      // Verify current with stored length; choose new length after.
      _selectedLength = security.pinLength;
    }
    // First-time set: leave _selectedLength null so user picks.

    if (mounted) setState(() => _booting = false);
  }

  void _onDigitTap(String digit) {
    if (_isLoading || _choosingLength) return;
    if (_pinDigits.length >= _pinLength) return;
    setState(() {
      _pinDigits.add(digit);
      _errorMessage = null;
    });
    if (_pinDigits.length == _pinLength) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canSubmit) _submitPin();
      });
    }
  }

  void _onBackspace() {
    if (_isLoading || _choosingLength) return;
    if (_pinDigits.isNotEmpty) {
      setState(() {
        _pinDigits.removeLast();
        _errorMessage = null;
      });
    }
  }

  void _dismiss({Object? result}) {
    if (widget.onCancel != null && result == null) {
      widget.onCancel!();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }

  void _chooseLength(int length) {
    setState(() {
      _selectedLength = length;
      _pinDigits.clear();
      _errorMessage = null;
    });
  }

  String _getTitle() {
    if (_choosingLength) return 'PIN length';
    if (widget.isChangingPin) {
      if (_changeStep == 0) return 'Current PIN';
      if (_changeStep == 1) return 'New PIN';
      return 'Confirm PIN';
    }
    if (widget.isSetting) {
      return _changeStep == 0 ? 'Create PIN' : 'Confirm PIN';
    }
    return 'Verify PIN';
  }

  String _getSubtitle() {
    if (_choosingLength) {
      return 'Choose a 4-digit or 6-digit wallet PIN';
    }
    final n = _pinLength;
    if (widget.isChangingPin) {
      if (_changeStep == 0) return 'Enter your current $n-digit PIN';
      if (_changeStep == 1) return 'Create your new $n-digit PIN';
      return 'Re-enter your new $n-digit PIN';
    }
    if (widget.isSetting) {
      return _changeStep == 0
          ? 'Enter a secure $n-digit PIN'
          : 'Re-enter your $n-digit PIN to confirm';
    }
    return 'Enter your $n-digit wallet PIN';
  }

  String _getButtonLabel() {
    if (widget.isChangingPin) {
      if (_changeStep == 0) return 'Verify';
      if (_changeStep == 1) return 'Next';
      return 'Change PIN';
    }
    if (widget.isSetting) {
      return _changeStep == 0 ? 'Next' : 'Set PIN';
    }
    return 'Verify';
  }

  Future<void> _submitPin() async {
    if (_isLoading || _choosingLength) return;
    if (_pinDigits.length != _pinLength) {
      setState(() {
        _errorMessage = 'Enter all $_pinLength digits';
      });
      return;
    }

    final pin = _pinDigits.join();

    if (widget.isSetting && !widget.isChangingPin) {
      if (_changeStep == 0) {
        setState(() {
          _newPin = pin;
          _pinDigits.clear();
          _changeStep = 1;
          _errorMessage = null;
        });
        return;
      }
      if (_changeStep == 1) {
        if (pin != _newPin) {
          setState(() {
            _errorMessage = 'PINs do not match. Try again.';
            _pinDigits.clear();
          });
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final secureStorage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, secureStorage);
      final security = WalletSecurityService();

      if (widget.isSetting && widget.isChangingPin) {
        if (_changeStep == 0) {
          final response = await apiClient.post(
            '/v1/wallet/security/pin/verify',
            data: {'pin': pin},
          );
          final data = response.data;
          final ok =
              data is Map && (data['ok'] == true || data['success'] == true);
          if (!mounted) return;
          if (ok) {
            setState(() {
              _changeStep = 1;
              _pinDigits.clear();
              // Let user pick length for the new PIN.
              _selectedLength = null;
              _isLoading = false;
            });
          } else {
            setState(() {
              _errorMessage = 'Current PIN is incorrect';
              _pinDigits.clear();
              _isLoading = false;
            });
          }
          return;
        }
        if (_changeStep == 1) {
          if (mounted) {
            setState(() {
              _newPin = pin;
              _pinDigits.clear();
              _changeStep = 2;
              _isLoading = false;
            });
          }
          return;
        }
        if (_changeStep == 2) {
          if (pin != _newPin) {
            if (mounted) {
              setState(() {
                _errorMessage = 'PINs do not match';
                _pinDigits.clear();
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      if (widget.isSetting) {
        final response = await apiClient.post(
          '/v1/wallet/security/pin/set',
          data: {'pin': pin},
        );
        final statusCode = response.statusCode;
        final responseData = response.data;

        if (!mounted) return;
        if (statusCode != null && statusCode >= 200 && statusCode < 300) {
          await security.setupPin(pin, length: _pinLength);
          final message =
              (responseData is Map && responseData['message'] != null)
                  ? responseData['message'] as String
                  : (widget.isChangingPin
                      ? 'PIN changed successfully'
                      : 'PIN set successfully');
          AppToast.success(context, message);
          _dismiss(result: true);
        } else {
          final errorMsg =
              (responseData is Map && responseData['message'] != null)
                  ? responseData['message'] as String
                  : 'Failed to set PIN. Please try again.';
          throw Exception(errorMsg);
        }
      } else {
        final response = await apiClient.post(
          '/v1/wallet/security/pin/verify',
          data: {'pin': pin},
        );
        final data = response.data;
        final ok =
            data is Map && (data['ok'] == true || data['success'] == true);

        if (!mounted) return;
        if (ok) {
          // Persist length if this verify revealed it (legacy users).
          await security.setPinLength(_pinLength);
          widget.onVerified?.call(pin);
          _dismiss(result: pin);
        } else {
          setState(() {
            _errorMessage = 'Invalid PIN';
            _pinDigits.clear();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      String errorMsg =
          'Failed to ${widget.isSetting ? 'set' : 'verify'} PIN';

      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        if (responseData is Map) {
          final message = responseData['message'] ?? responseData['error'];
          if (message is String && message.isNotEmpty) {
            errorMsg = message;
          } else if (message is List && message.isNotEmpty) {
            errorMsg = message.first.toString();
          }
        }

        if (statusCode == 401) {
          errorMsg = 'Session expired. Please log in again.';
        } else if (statusCode == 400 && errorMsg.startsWith('Failed')) {
          errorMsg = 'Invalid PIN. Check the digits and try again.';
        } else if (statusCode == 403) {
          errorMsg = 'Permission denied. Please try again.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          errorMsg = 'Request timed out. Check your connection.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMsg = 'Network error. Check your connection.';
        }
      }

      setState(() {
        _errorMessage = errorMsg;
        _pinDigits.clear();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLengthChooser(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option({
      required int length,
      required String title,
      required String subtitle,
    }) {
      return Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _chooseLength(length),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$length',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          option(
            length: 6,
            title: '6-digit PIN',
            subtitle: 'More secure — recommended',
          ),
          const SizedBox(height: 12),
          option(
            length: 4,
            title: '4-digit PIN',
            subtitle: 'Faster to enter',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return PopScope(
      canPop: true,
      child: PinEntryLayout(
        title: _getTitle(),
        subtitle: _getSubtitle(),
        pinLength: _choosingLength ? 0 : _pinLength,
        filledCount: _choosingLength ? 0 : _pinDigits.length,
        errorMessage: _errorMessage,
        isLoading: _isLoading,
        hideKeypad: _choosingLength,
        allowBackWhileLoading: true,
        backIcon: (widget.isSetting &&
                    ((_changeStep > 0 && !_choosingLength) ||
                        (_choosingLength && widget.isChangingPin))) ||
                (!_choosingLength &&
                    widget.isSetting &&
                    !widget.isChangingPin &&
                    _selectedLength != null &&
                    _changeStep == 0)
            ? Icons.arrow_back_ios_new_rounded
            : Icons.close_rounded,
        onBack: () {
          if (_isLoading) {
            _dismiss();
            return;
          }
          // Back from length choice during change → return to current-PIN done? stay on length
          if (_choosingLength && widget.isChangingPin) {
            // Can't go back to re-verify easily; just close
            _dismiss();
            return;
          }
          // Back from enter PIN after choosing length (first set)
          if (widget.isSetting &&
              !widget.isChangingPin &&
              _changeStep == 0 &&
              _selectedLength != null &&
              _newPin == null) {
            setState(() {
              _selectedLength = null;
              _pinDigits.clear();
              _errorMessage = null;
            });
            return;
          }
          if (widget.isSetting && _changeStep > 0 && !_choosingLength) {
            setState(() {
              _changeStep--;
              _pinDigits.clear();
              _newPin = null;
              _errorMessage = null;
              if (widget.isChangingPin && _changeStep == 1) {
                _selectedLength = null; // re-pick length
              }
            });
            return;
          }
          _dismiss();
        },
        onDigit: _onDigitTap,
        onBackspace: _onBackspace,
        belowKeypad: _choosingLength
            ? _buildLengthChooser(context)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canSubmit)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _submitPin,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _getButtonLabel(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!widget.isSetting) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _selectedLength = _pinLength == 6 ? 4 : 6;
                                _pinDigits.clear();
                                _errorMessage = null;
                              });
                            },
                      child: Text(
                        _pinLength == 6
                            ? 'Use 4-digit PIN instead'
                            : 'Use 6-digit PIN instead',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
