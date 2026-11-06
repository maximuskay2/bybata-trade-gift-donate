import 'package:flutter/material.dart';

import '../screens/wallet_pin_screen.dart';
import 'biometric_service.dart';
import 'wallet_api.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

typedef WalletAuthResult = ({String method, String credential});

/// Shared PIN / biometric gate for send, withdraw, and other outbound BYC actions.
///
/// Wallet security is optional. If the user has not set a wallet PIN, [request]
/// returns a NONE result and the API skips auth. Users who enabled a PIN must
/// authenticate; a successful PIN/biometric also refreshes their wallet session.
class WalletTransactionAuth {
  WalletTransactionAuth._();

  static Future<WalletAuthResult?> request(
    BuildContext context, {
    required String biometricReason,
  }) async {
    try {
      final api = await WalletApi.create();
      final status = await api.getSecurityStatus();
      final pinSet = status['pinSet'] == true || status['hasPin'] == true;
      final authRequired = status['transactionAuthRequired'] == true || pinSet;

      // Security not enabled — allow send/withdraw without PIN/biometric.
      if (!authRequired) {
        return (method: 'NONE', credential: 'none');
      }

      final biometricService = BiometricService();
      if (await biometricService.isAvailable()) {
        try {
          final token = await biometricService.authenticate(reason: biometricReason);
          if (token != null) {
            final tokenRes = await api.post('/v1/wallet/security/biometric/token');
            if (tokenRes['ok'] == true) {
              final cred = (tokenRes['token'] ?? token)?.toString();
              if (cred != null && cred.isNotEmpty) {
                return (method: 'BIOMETRIC', credential: cred);
              }
            }
          }
        } catch (_) {
          // Fall through to PIN
        }
      }

      if (!context.mounted) return null;

      final pin = await GuardedNavigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (ctx) => WalletPinScreen(
            isSetting: false,
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
      if (pin == null || pin.isEmpty) return null;
      return (method: 'PIN', credential: pin);
    } catch (_) {
      return null;
    }
  }

  static bool isSkipped(WalletAuthResult auth) =>
      auth.method == 'NONE' || auth.method.isEmpty;
}
