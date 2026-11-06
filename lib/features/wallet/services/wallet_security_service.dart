import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';

class WalletSecurityService extends ChangeNotifier {
  static final WalletSecurityService _instance = WalletSecurityService._internal();
  factory WalletSecurityService() => _instance;
  WalletSecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Allowed wallet PIN lengths.
  static const int pinLengthFour = 4;
  static const int pinLengthSix = 6;
  static const List<int> allowedPinLengths = [pinLengthFour, pinLengthSix];
  
  String? _activeUserId;
  bool _isWalletLocked = false;
  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  String? _hashedPin;
  int _pinLength = pinLengthSix;
  DateTime? _lastUnlockTime;
  
  // Auto-lock timeout (in minutes)
  int _autoLockTimeout = 5;
  
  // Getters
  bool get isWalletLocked => _isWalletLocked;
  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isBiometricAvailable => _isBiometricAvailable;
  int get autoLockTimeout => _autoLockTimeout;
  DateTime? get lastUnlockTime => _lastUnlockTime;
  /// Preferred PIN length for this user (4 or 6). Defaults to 6.
  int get pinLength => _pinLength;

  // Storage keys
  static const String _keyPinHash = 'wallet_pin_hash';
  static const String _keyPinEnabled = 'wallet_pin_enabled';
  static const String _keyPinLength = 'wallet_pin_length';
  static const String _keyBiometricEnabled = 'wallet_biometric_enabled';
  static const String _keyAutoLockTimeout = 'wallet_auto_lock_timeout';
  static const String _keyLastUnlockTime = 'wallet_last_unlock_time';

  String? get activeUserId => _activeUserId;

  String _scopedKey(String base) =>
      _activeUserId == null ? base : '${base}_$_activeUserId';

  /// Called on login / session restore. Loads PIN lock state for [userId] only.
  Future<void> switchUser(String? userId) async {
    _activeUserId = userId?.trim().isEmpty == true ? null : userId?.trim();
    _resetInMemoryState();

    if (_activeUserId == null) {
      notifyListeners();
      return;
    }

    await _loadSecuritySettings();
    await _checkBiometricAvailability();
    _checkAutoLock();
    notifyListeners();
  }

  /// Align local lock flags with the authenticated user's server wallet PIN.
  Future<void> syncPinStateWithBackend() async {
    if (_activeUserId == null) return;

    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, const FlutterSecureStorage());
      final response = await api.get('/v1/wallet/security/status');
      final data = response.data;
      if (data is! Map) return;

      final map = Map<String, dynamic>.from(data);
      final hasPin = map['hasPin'] == true || map['pinSet'] == true;
      final prefs = await SharedPreferences.getInstance();

      if (!hasPin) {
        await prefs.setBool(_scopedKey(_keyPinEnabled), false);
        await prefs.remove(_scopedKey(_keyPinHash));
        _isPinEnabled = false;
        _hashedPin = null;
        _isWalletLocked = false;
      } else {
        await prefs.setBool(_scopedKey(_keyPinEnabled), true);
        _isPinEnabled = true;
        if (_lastUnlockTime == null) {
          _isWalletLocked = true;
        } else {
          _checkAutoLock();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('WalletSecurityService.syncPinStateWithBackend: $e');
      if (!_isPinEnabled && !_isBiometricEnabled) {
        _isWalletLocked = false;
        notifyListeners();
      }
    }
  }

  void _resetInMemoryState() {
    _isWalletLocked = false;
    _isPinEnabled = false;
    _isBiometricEnabled = false;
    _hashedPin = null;
    _pinLength = pinLengthSix;
    _lastUnlockTime = null;
    _autoLockTimeout = 5;
  }

  /// Initialize for the active user (call [switchUser] first when possible).
  Future<void> initialize() async {
    try {
      if (_activeUserId != null) {
        await _loadSecuritySettings();
      }
      await _checkBiometricAvailability();
      _checkAutoLock();
    } catch (e) {
      debugPrint('Error initializing WalletSecurityService: $e');
    }
  }

  /// Load security settings from storage for [_activeUserId].
  Future<void> _loadSecuritySettings() async {
    if (_activeUserId == null) return;

    final prefs = await SharedPreferences.getInstance();

    _hashedPin = prefs.getString(_scopedKey(_keyPinHash));
    _isPinEnabled = prefs.getBool(_scopedKey(_keyPinEnabled)) ?? false;
    _isBiometricEnabled =
        prefs.getBool(_scopedKey(_keyBiometricEnabled)) ?? false;
    final storedLen = prefs.getInt(_scopedKey(_keyPinLength));
    _pinLength = (storedLen == pinLengthFour || storedLen == pinLengthSix)
        ? storedLen!
        : pinLengthSix;
    _autoLockTimeout =
        prefs.getInt(_scopedKey(_keyAutoLockTimeout)) ?? 5;

    final lastUnlockString = prefs.getString(_scopedKey(_keyLastUnlockTime));
    if (lastUnlockString != null) {
      _lastUnlockTime = DateTime.tryParse(lastUnlockString);
    }

    if (!_isPinEnabled && !_isBiometricEnabled) {
      _isWalletLocked = false;
    } else if (_lastUnlockTime == null) {
      _isWalletLocked = true;
    }

    notifyListeners();
  }

  static AuthenticationOptions get _unlockAuthOptions => AuthenticationOptions(
        // Android often classifies face unlock as "weak"; biometricOnly:true rejects it.
        biometricOnly: !Platform.isAndroid,
        stickyAuth: true,
        useErrorDialogs: true,
      );

  static const AuthenticationOptions _enableAuthOptions = AuthenticationOptions(
    biometricOnly: false,
    stickyAuth: true,
    useErrorDialogs: true,
  );

  /// Hides iOS "Enter Passcode" — wallet PIN is the app-level fallback.
  static const List<AuthMessages> _biometricAuthMessages = [
    IOSAuthMessages(
      localizedFallbackTitle: ' ',
      cancelButton: 'Cancel',
    ),
    AndroidAuthMessages(
      signInTitle: 'BYC wallet',
      cancelButton: 'Cancel',
      biometricHint: 'Verify your identity',
      biometricNotRecognized: 'Not recognized. Try again.',
      biometricSuccess: 'Success',
      biometricRequiredTitle: 'Biometric required',
      goToSettingsButton: 'Settings',
      goToSettingsDescription: 'Biometric setup is required on your device.',
      deviceCredentialsRequiredTitle: 'Device credentials required',
      deviceCredentialsSetupDescription: 'Set up screen lock in Settings.',
    ),
  ];

  /// Device has enrolled fingerprint / Face ID (not just hardware support).
  Future<bool> hasEnrolledBiometrics() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      // canCheckBiometrics is more reliable than types alone on some Androids.
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        final types = await _localAuth.getAvailableBiometrics();
        return types.isNotEmpty;
      }
      final types = await _localAuth.getAvailableBiometrics();
      return canCheck || types.isNotEmpty;
    } catch (e) {
      debugPrint('hasEnrolledBiometrics: $e');
      return false;
    }
  }

  Future<bool> _authenticateBiometric({
    required String reason,
    required AuthenticationOptions options,
  }) async {
    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}
    // Let the previous route finish dismissing (critical after PIN screen).
    await Future<void>.delayed(const Duration(milliseconds: 450));

    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        authMessages: _biometricAuthMessages,
        options: options,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authenticate failed (${e.code}): ${e.message}');
      // Retry once with the more permissive enable options.
      if (e.code == 'NotAvailable' ||
          e.code == 'Other' ||
          e.code == 'auth_in_progress' ||
          e.code == 'LockedOut') {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        try {
          await _localAuth.stopAuthentication();
        } catch (_) {}
        return await _localAuth.authenticate(
          localizedReason: reason,
          authMessages: _biometricAuthMessages,
          options: _enableAuthOptions,
        );
      }
      rethrow;
    }
  }

  /// Check if biometric authentication is available
  Future<void> _checkBiometricAvailability() async {
    try {
      _isBiometricAvailable = await hasEnrolledBiometrics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      _isBiometricAvailable = false;
    }
  }

  /// Check if wallet should be auto-locked
  void _checkAutoLock() {
    if (_lastUnlockTime != null && (_isPinEnabled || _isBiometricEnabled)) {
      final timeSinceUnlock = DateTime.now().difference(_lastUnlockTime!);
      if (timeSinceUnlock.inMinutes >= _autoLockTimeout) {
        _isWalletLocked = true;
        notifyListeners();
      }
    }
  }

  /// Mark PIN as enabled (e.g. when backend has PIN but we don't store local hash).
  Future<void> setPinEnabled(bool value) async {
    if (_activeUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_keyPinEnabled), value);
    _isPinEnabled = value;
    if (!value && !_isBiometricEnabled) {
      _isWalletLocked = false;
    }
    notifyListeners();
  }

  /// Unlock the wallet (e.g. after successful API PIN verification).
  Future<void> unlock() async {
    _isWalletLocked = false;
    _lastUnlockTime = DateTime.now();
    await _saveLastUnlockTime();
    notifyListeners();
  }

  /// Persist preferred PIN length (4 or 6).
  Future<void> setPinLength(int length) async {
    if (!allowedPinLengths.contains(length)) {
      throw ArgumentError('PIN length must be 4 or 6');
    }
    _pinLength = length;
    if (_activeUserId == null) {
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scopedKey(_keyPinLength), length);
    notifyListeners();
  }

  /// Set up PIN for wallet security (exactly 4 or 6 digits).
  Future<bool> setupPin(String pin, {int? length}) async {
    try {
      final expected = length ?? pin.length;
      if (!allowedPinLengths.contains(expected) ||
          pin.length != expected ||
          int.tryParse(pin) == null) {
        throw ArgumentError('PIN must be exactly 4 or 6 digits');
      }

      final hashedPin = _hashPin(pin);
      if (_activeUserId == null) return false;

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_scopedKey(_keyPinHash), hashedPin);
      await prefs.setBool(_scopedKey(_keyPinEnabled), true);
      await prefs.setInt(_scopedKey(_keyPinLength), expected);

      _hashedPin = hashedPin;
      _isPinEnabled = true;
      _pinLength = expected;
      _isWalletLocked = false;
      _lastUnlockTime = DateTime.now();

      await _saveLastUnlockTime();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error setting up PIN: $e');
      return false;
    }
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    try {
      if (!_isPinEnabled || _hashedPin == null) {
        return false;
      }

      final hashedInputPin = _hashPin(pin);
      final isValid = hashedInputPin == _hashedPin;
      
      if (isValid) {
        _isWalletLocked = false;
        _lastUnlockTime = DateTime.now();
        await _saveLastUnlockTime();
        notifyListeners();
      }
      
      return isValid;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  /// Change PIN
  Future<bool> changePin(String currentPin, String newPin) async {
    try {
      if (!await verifyPin(currentPin)) {
        return false;
      }
      
      return await setupPin(newPin);
    } catch (e) {
      debugPrint('Error changing PIN: $e');
      return false;
    }
  }

  /// Disable PIN
  Future<bool> disablePin(String currentPin) async {
    try {
      if (!await verifyPin(currentPin)) {
        return false;
      }

      if (_activeUserId == null) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scopedKey(_keyPinHash));
      await prefs.setBool(_scopedKey(_keyPinEnabled), false);
      
      _hashedPin = null;
      _isPinEnabled = false;
      
      // If biometric is also disabled, unlock wallet
      if (!_isBiometricEnabled) {
        _isWalletLocked = false;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error disabling PIN: $e');
      return false;
    }
  }

  /// Get user-friendly biometric type name (Fingerprint, Face ID, etc.)
  Future<String> getBiometricTypeName() async {
    try {
      final types = await _localAuth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        return Platform.isIOS ? 'Face ID' : 'Face Recognition';
      }
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.iris)) return 'Iris';
      return 'Biometric';
    } catch (_) {
      return 'Biometric';
    }
  }

  /// Test biometric authentication (for activation flow).
  Future<({bool success, String? errorMessage})> testBiometricAuthWithDetails() async {
    try {
      if (!await hasEnrolledBiometrics()) {
        return (
          success: false,
          errorMessage:
              'No biometrics enrolled. Add fingerprint or face in device settings.',
        );
      }

      final typeName = await getBiometricTypeName();
      final ok = await _authenticateBiometric(
        reason: 'Verify your identity with $typeName to enable wallet unlock',
        options: _enableAuthOptions,
      );
      if (ok) return (success: true, errorMessage: null);
      return (
        success: false,
        errorMessage: 'Verification cancelled. Try again.',
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric test PlatformException: ${e.code} ${e.message}');
      return (success: false, errorMessage: _biometricErrorFromCode(e.code));
    } catch (e) {
      debugPrint('Biometric test error: $e');
      return (
        success: false,
        errorMessage: 'Biometric verification failed. Please try again.',
      );
    }
  }

  String _biometricErrorFromCode(String? code) {
    switch (code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
      case 'noBiometricsEnrolled':
        return 'No biometrics enrolled. Add fingerprint or face in device settings.';
      case 'LockedOut':
      case 'temporaryLockout':
        return 'Too many attempts. Wait a moment and try again.';
      case 'PermanentlyLockedOut':
        return 'Biometric locked. Use your wallet PIN or try again later.';
      case 'PasscodeNotSet':
      case 'noCredentialsSet':
        return 'Set up device lock and biometrics in Settings, or use your wallet PIN.';
      case 'Other':
        return 'Biometric verification failed. Use your wallet PIN.';
      default:
        return 'Biometric verification failed. Use your wallet PIN.';
    }
  }

  /// Test biometric authentication (for activation flow - does not require _isBiometricEnabled).
  Future<bool> testBiometricAuth() async {
    final result = await testBiometricAuthWithDetails();
    return result.success;
  }

  /// Enable biometric authentication. Requires PIN to be set first. Verifies biometric works before enabling.
  /// Returns (success, errorMessage).
  Future<({bool success, String? errorMessage})> enableBiometricWithDetails() async {
    try {
      if (_activeUserId == null) {
        return (success: false, errorMessage: 'Not signed in');
      }
      if (!_isPinEnabled) {
        return (success: false, errorMessage: 'PIN must be set first');
      }
      if (!await hasEnrolledBiometrics()) {
        return (
          success: false,
          errorMessage:
              'No biometrics enrolled. Add fingerprint or face in device settings.',
        );
      }

      final testResult = await testBiometricAuthWithDetails();
      if (!testResult.success) return testResult;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_scopedKey(_keyBiometricEnabled), true);

      _isBiometricEnabled = true;
      notifyListeners();

      return (success: true, errorMessage: null);
    } catch (e) {
      debugPrint('Error enabling biometric: $e');
      return (success: false, errorMessage: 'Failed to enable biometrics. Try again.');
    }
  }

  /// Enable biometric (legacy API).
  Future<bool> enableBiometric() async {
    final result = await enableBiometricWithDetails();
    return result.success;
  }

  /// Disable biometric authentication
  Future<bool> disableBiometric() async {
    try {
      if (_activeUserId == null) {
        debugPrint('disableBiometric: no active user');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_scopedKey(_keyBiometricEnabled), false);

      _isBiometricEnabled = false;

      if (!_isPinEnabled) {
        _isWalletLocked = false;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error disabling biometric: $e');
      return false;
    }
  }

  /// Authenticate with Face ID / fingerprint.
  /// On failure or cancel, caller should fall back to wallet PIN entry.
  Future<({bool success, bool cancelled, String? errorMessage})>
      authenticateWithBiometricWithDetails() async {
    try {
      if (!_isBiometricEnabled) {
        return (success: false, cancelled: false, errorMessage: null);
      }
      if (!await hasEnrolledBiometrics()) {
        return (
          success: false,
          cancelled: false,
          errorMessage:
              'Biometrics not set up on this device. Use your wallet PIN.',
        );
      }

      final typeName = await getBiometricTypeName();
      final isAuthenticated = await _authenticateBiometric(
        reason: 'Use $typeName to unlock your BYC wallet',
        options: _unlockAuthOptions,
      );

      if (isAuthenticated) {
        _isWalletLocked = false;
        _lastUnlockTime = DateTime.now();
        await _saveLastUnlockTime();
        notifyListeners();
        return (success: true, cancelled: false, errorMessage: null);
      }

      return (
        success: false,
        cancelled: true,
        errorMessage: 'Use your wallet PIN to continue.',
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: ${e.code} ${e.message}');
      final cancelled = _isUserCancelledBiometric(e.code);
      return (
        success: false,
        cancelled: cancelled,
        errorMessage: cancelled
            ? 'Use your wallet PIN to continue.'
            : _biometricErrorFromCode(e.code),
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return (
        success: false,
        cancelled: false,
        errorMessage: 'Biometric failed. Use your wallet PIN.',
      );
    }
  }

  bool _isUserCancelledBiometric(String? code) {
    switch (code) {
      case 'UserCanceled':
      case 'Canceled':
      case 'canceled':
      case 'auth_in_progress':
        return true;
      default:
        return false;
    }
  }

  /// Authenticate with biometric
  Future<bool> authenticateWithBiometric() async {
    final result = await authenticateWithBiometricWithDetails();
    return result.success;
  }

  /// Lock the wallet manually
  Future<void> lockWallet() async {
    _isWalletLocked = true;
    notifyListeners();
  }

  /// Set auto-lock timeout
  Future<bool> setAutoLockTimeout(int minutes) async {
    try {
      if (_activeUserId == null) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_scopedKey(_keyAutoLockTimeout), minutes);
      
      _autoLockTimeout = minutes;
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error setting auto-lock timeout: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Hash PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + 'byc_wallet_salt'); // Add salt for security
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save last unlock time
  Future<void> _saveLastUnlockTime() async {
    try {
      if (_activeUserId == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _scopedKey(_keyLastUnlockTime),
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving last unlock time: $e');
    }
  }

  /// Check if any security method is enabled
  bool get hasSecurityEnabled => _isPinEnabled || _isBiometricEnabled;

  /// Get security status summary
  Map<String, dynamic> get securityStatus => {
    'isLocked': _isWalletLocked,
    'pinEnabled': _isPinEnabled,
    'biometricEnabled': _isBiometricEnabled,
    'biometricAvailable': _isBiometricAvailable,
    'autoLockTimeout': _autoLockTimeout,
    'lastUnlockTime': _lastUnlockTime?.toIso8601String(),
  };

  /// Reset security settings for the active user only.
  Future<void> resetSecurity() async {
    try {
      if (_activeUserId == null) {
        _resetInMemoryState();
        notifyListeners();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scopedKey(_keyPinHash));
      await prefs.remove(_scopedKey(_keyPinEnabled));
      await prefs.remove(_scopedKey(_keyPinLength));
      await prefs.remove(_scopedKey(_keyBiometricEnabled));
      await prefs.remove(_scopedKey(_keyAutoLockTimeout));
      await prefs.remove(_scopedKey(_keyLastUnlockTime));

      _resetInMemoryState();
      notifyListeners();
    } catch (e) {
      debugPrint('Error resetting security: $e');
    }
  }

  /// Validate PIN format (exactly 4 or 6 digits)
  static bool isValidPin(String pin, {int? length}) {
    final expected = length ?? pin.length;
    return allowedPinLengths.contains(expected) &&
        pin.length == expected &&
        int.tryParse(pin) != null;
  }

  /// Check if PIN is weak (common patterns)
  static bool isWeakPin(String pin) {
    if (pin.length != 4 && pin.length != 6) return true;

    const weakFour = [
      '0000', '1111', '2222', '3333', '4444',
      '5555', '6666', '7777', '8888', '9999',
      '1234', '4321', '1122', '2211',
      '0123', '3210', '1010', '0101',
    ];
    const weakSix = [
      '000000', '111111', '222222', '333333', '444444',
      '555555', '666666', '777777', '888888', '999999',
      '123456', '654321', '112233', '121212',
    ];

    return weakFour.contains(pin) || weakSix.contains(pin);
  }
}
