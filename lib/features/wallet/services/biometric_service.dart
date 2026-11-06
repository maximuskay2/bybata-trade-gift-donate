import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';

/// Service for handling biometric authentication
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Authenticate using biometrics
  /// Returns the biometric token to send to backend
  Future<String?> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        // Generate a token (in production, this should be generated on backend)
        // For now, we'll use a timestamp-based token
        return DateTime.now().millisecondsSinceEpoch.toString();
      }
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') {
        throw Exception('Biometric authentication is not available');
      } else if (e.code == 'NotEnrolled') {
        throw Exception('No biometrics enrolled. Please set up biometrics in device settings.');
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        throw Exception('Biometric authentication is locked out. Please use PIN.');
      }
      throw Exception('Biometric authentication failed: ${e.message}');
    } catch (e) {
      throw Exception('Biometric authentication failed: $e');
    }
  }

  /// Stop authentication (cancel ongoing biometric prompt)
  Future<bool> stopAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } catch (e) {
      return false;
    }
  }

  /// Get biometric icon based on available type
  IconData getBiometricIcon(List<BiometricType> availableTypes) {
    if (Platform.isIOS) {
      if (availableTypes.contains(BiometricType.face)) {
        return Icons.face;
      } else if (availableTypes.contains(BiometricType.fingerprint)) {
        return Icons.fingerprint;
      }
    } else if (Platform.isAndroid) {
      if (availableTypes.contains(BiometricType.fingerprint)) {
        return Icons.fingerprint;
      } else if (availableTypes.contains(BiometricType.face)) {
        return Icons.face;
      }
    }
    return Icons.lock;
  }

  /// Get biometric name for display
  String getBiometricName(List<BiometricType> availableTypes) {
    if (availableTypes.contains(BiometricType.face)) {
      return Platform.isIOS ? 'Face ID' : 'Face Recognition';
    } else if (availableTypes.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    return 'Biometric';
  }
}

