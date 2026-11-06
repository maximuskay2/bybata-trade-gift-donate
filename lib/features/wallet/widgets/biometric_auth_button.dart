import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/auth/auth_provider.dart';

/// Button widget for biometric authentication
class BiometricAuthButton extends StatefulWidget {
  final Function(String token)? onSuccess;
  final Function(String error)? onError;
  final String reason;
  final bool showLabel;

  const BiometricAuthButton({
    Key? key,
    required this.onSuccess,
    this.onError,
    this.reason = 'Authenticate to continue',
    this.showLabel = true,
  }) : super(key: key);

  @override
  State<BiometricAuthButton> createState() => _BiometricAuthButtonState();
}

class _BiometricAuthButtonState extends State<BiometricAuthButton> {
  final BiometricService _biometricService = BiometricService();
  bool _isAvailable = false;
  List<BiometricType> _availableTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available = await _biometricService.isAvailable();
    if (available) {
      final types = await _biometricService.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _isAvailable = available;
          _availableTypes = types;
        });
      }
    }
  }

  Future<void> _authenticate() async {
    if (!_isAvailable) {
      widget.onError?.call('Biometric authentication is not available');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _biometricService.authenticate(
        reason: widget.reason,
      );

      if (token != null) {
        // Get token from backend after local authentication
        try {
          final authProvider = context.read<AuthProvider>();
          final apiClient = ApiClient();
          
          final response = await apiClient.post(
            '/v1/wallet/security/biometric/token',
            data: {},
            token: authProvider.accessToken,
          );

          if (mounted && response['ok'] == true) {
            widget.onSuccess?.call(response['token'] ?? token);
          } else {
            widget.onError?.call('Failed to generate biometric token');
          }
        } catch (e) {
          // If backend call fails, use local token
          widget.onSuccess?.call(token);
        }
      } else {
        widget.onError?.call('Authentication cancelled');
      }
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAvailable) {
      return const SizedBox.shrink();
    }

    final icon = _biometricService.getBiometricIcon(_availableTypes);
    final label = _biometricService.getBiometricName(_availableTypes);

    return Column(
      children: [
        IconButton(
          onPressed: _isLoading ? null : _authenticate,
          icon: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 32),
          tooltip: label,
        ),
        if (widget.showLabel)
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

