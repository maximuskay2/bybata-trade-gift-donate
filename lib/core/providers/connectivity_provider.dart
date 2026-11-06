import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/network_utils.dart';

/// Provider to manage and monitor network connectivity state
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _isServerAvailable = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _checkTimer;

  bool get isOnline => _isOnline;
  bool get isServerAvailable => _isServerAvailable;
  bool get hasConnection => _isOnline && _isServerAvailable;

  ConnectivityProvider() {
    _initConnectivity();
    _listenToConnectivityChanges();
    _startPeriodicCheck();
  }

  /// Initialize connectivity state
  Future<void> _initConnectivity() async {
    try {
      final hasInternet = await NetworkUtils.hasInternetConnection();
      _isOnline = hasInternet;
      notifyListeners();
    } catch (e) {
      debugPrint('[ConnectivityProvider] Error initializing connectivity: $e');
      _isOnline = false;
      notifyListeners();
    }
  }

  /// Listen to connectivity changes
  void _listenToConnectivityChanges() {
    _connectivitySubscription = NetworkUtils.onConnectivityChanged.listen(
      (connectivityResults) async {
        debugPrint('[ConnectivityProvider] Connectivity changed: $connectivityResults');
        
        // Check actual internet connection
        final hasInternet = await NetworkUtils.hasInternetConnection();
        if (_isOnline != hasInternet) {
          _isOnline = hasInternet;
          debugPrint('[ConnectivityProvider] Internet status changed: $_isOnline');
          notifyListeners();
        }
      },
    );
  }

  /// Periodically check connection (every 30 seconds)
  void _startPeriodicCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final hasInternet = await NetworkUtils.hasInternetConnection();
      if (_isOnline != hasInternet) {
        _isOnline = hasInternet;
        debugPrint('[ConnectivityProvider] Periodic check - Internet status: $_isOnline');
        notifyListeners();
      }
    });
  }

  /// Manually check connectivity
  Future<void> checkConnectivity() async {
    try {
      final hasInternet = await NetworkUtils.hasInternetConnection();
      if (_isOnline != hasInternet) {
        _isOnline = hasInternet;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ConnectivityProvider] Error checking connectivity: $e');
    }
  }

  /// Set server availability status
  void setServerAvailability(bool isAvailable) {
    if (_isServerAvailable != isAvailable) {
      _isServerAvailable = isAvailable;
      debugPrint('[ConnectivityProvider] Server availability changed: $_isServerAvailable');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }
}
