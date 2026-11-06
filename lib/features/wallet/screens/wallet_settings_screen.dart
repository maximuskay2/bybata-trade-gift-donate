import 'package:flutter/material.dart';
import '../../../core/constants/currency_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../features/settings/widgets/settings_ui.dart';
import '../../../core/config/env_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/app_toast.dart' show AppToast, ToastType;
import '../services/wallet_api.dart';
import '../services/wallet_service.dart';
import '../services/wallet_security_service.dart';
import '../services/transaction_export_service.dart';
import '../screens/transaction_history_screen.dart';
import '../screens/wallet_pin_screen.dart';
import '../screens/wallet_pin_management_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class WalletSettingsScreen extends StatefulWidget {
  const WalletSettingsScreen({super.key});

  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;

  // Settings state
  bool _notificationsEnabled = true;
  bool _transactionAlertsEnabled = true;
  bool _lowBalanceAlertsEnabled = true;
  bool _promotionAlertsEnabled = true;
  double _lowBalanceThreshold = 10.0;
  String _defaultCurrency = 'USD';
  bool _showFiatEquivalents = true;
  bool _autoLockEnabled = true;
  int _autoLockMinutes = 5;
  bool? _hasPin;
  bool? _biometricEnabled;
  bool _sessionExpired = false;
  bool _biometricLoading = false;
  String? _biometricTypeName;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // --- LOGIC PRESERVATION ---
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('wallet_notifications_enabled') ?? true;
      _transactionAlertsEnabled = prefs.getBool('wallet_transaction_alerts') ?? true;
      _lowBalanceAlertsEnabled = prefs.getBool('wallet_low_balance_alerts') ?? true;
      _promotionAlertsEnabled = prefs.getBool('wallet_promotion_alerts') ?? true;
      _lowBalanceThreshold = prefs.getDouble('wallet_low_balance_threshold') ?? 10.0;
      final savedCurrency = prefs.getString('wallet_default_currency') ?? 'USD';
      _defaultCurrency = CurrencyConstants.displayCurrencyCodes.contains(savedCurrency)
          ? savedCurrency
          : 'USD';
      _showFiatEquivalents = prefs.getBool('wallet_show_fiat_equivalents') ?? true;
      _autoLockEnabled = prefs.getBool('wallet_auto_lock_enabled') ?? true;
      _autoLockMinutes = prefs.getInt('wallet_auto_lock_minutes') ?? 5;
      final auth = context.read<AuthProvider>();
      final security = WalletSecurityService();
      await security.switchUser(auth.currentUser?.id);
      if (auth.currentUser?.id != null) {
        await security.syncPinStateWithBackend();
      }
      _biometricEnabled = security.isBiometricEnabled;
      _biometricTypeName = await security.getBiometricTypeName();
      await _loadSecurityStatus();
      if (mounted && _hasPin == true) {
        await security.setPinEnabled(true);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to load settings: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSecurityStatus() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, const FlutterSecureStorage());
      final response = await api.get('/v1/wallet/security/status');
      final data = response.data;
      if (data == null || data is! Map) {
        if (mounted) setState(() { _hasPin = null; });
        return;
      }
      final map = data as Map<String, dynamic>;
      final pinSet = map['pinSet'];
      final hasPin = map['hasPin'];
      final sessionExp = map['sessionExpired'];
      if (mounted) {
        setState(() {
          _hasPin = hasPin == true || pinSet == true;
          _sessionExpired = sessionExp == true;
        });
        final security = WalletSecurityService();
        if (_hasPin == true) {
          await security.setPinEnabled(true);
        } else {
          await security.setPinEnabled(false);
        }
        if (_sessionExpired) {
          _refreshWalletSession(api);
        }
      }
    } catch (e) {
      if (mounted) setState(() { _hasPin = null; _sessionExpired = false; });
    }
  }

  Future<void> _refreshWalletSession(ApiClient api) async {
    try {
      await api.get('/v1/wallet/balance');
      if (mounted) {
        setState(() => _sessionExpired = false);
      }
    } catch (e) {
      if (mounted && _sessionExpired) {
        AppToast.show(context, 'Wallet session expired. Some operations may require re-authentication.', type: ToastType.warning);
      }
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      AppToast.show(context, 'Please sign in again', type: ToastType.error);
      return;
    }

    final security = WalletSecurityService();
    await security.switchUser(userId);

    if (_hasPin != true && !security.isPinEnabled) {
      AppToast.show(
        context,
        'Set a wallet PIN first',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _biometricLoading = true);

    try {
      if (enabled) {
        if (!await security.hasEnrolledBiometrics()) {
          if (!mounted) return;
          AppToast.show(
            context,
            'No fingerprint or face enrolled on this device. Add one in system Settings.',
            type: ToastType.error,
          );
          return;
        }

        _biometricTypeName ??= await security.getBiometricTypeName();
        if (!mounted) return;

        final verified = await GuardedNavigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const WalletPinScreen(isSetting: false),
          ),
          force: true,
        );
        if (!mounted) return;
        if (verified == null || verified.isEmpty) {
          return;
        }

        final pinSaved = await security.setupPin(verified, length: verified.length);
        if (!pinSaved) {
          if (!mounted) return;
          AppToast.show(
            context,
            'Could not save PIN for biometric unlock. Try again.',
            type: ToastType.error,
          );
          return;
        }

        // Wait for PIN route to fully dismiss before BiometricPrompt (Android).
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        final result = await security.enableBiometricWithDetails();
        if (!mounted) return;
        if (result.success) {
          setState(() => _biometricEnabled = true);
          AppToast.show(
            context,
            '${_biometricTypeName ?? 'Biometric'} enabled',
          );
        } else {
          setState(() => _biometricEnabled = false);
          AppToast.show(
            context,
            result.errorMessage ?? 'Could not enable biometrics',
            type: ToastType.error,
          );
        }
      } else {
        final verified = await GuardedNavigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const WalletPinScreen(isSetting: false),
          ),
          force: true,
        );
        if (!mounted) return;
        if (verified == null || verified.isEmpty) {
          return;
        }

        final disabled = await security.disableBiometric();
        if (!mounted) return;
        if (disabled) {
          setState(() => _biometricEnabled = false);
          AppToast.show(context, 'Biometric disabled');
        } else {
          setState(() => _biometricEnabled = security.isBiometricEnabled);
          AppToast.show(
            context,
            'Could not disable biometrics. Try again.',
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _biometricEnabled = security.isBiometricEnabled);
        AppToast.show(context, 'Biometric update failed. Try again.', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wallet_notifications_enabled', _notificationsEnabled);
      await prefs.setBool('wallet_transaction_alerts', _transactionAlertsEnabled);
      await prefs.setBool('wallet_low_balance_alerts', _lowBalanceAlertsEnabled);
      await prefs.setBool('wallet_promotion_alerts', _promotionAlertsEnabled);
      await prefs.setDouble('wallet_low_balance_threshold', _lowBalanceThreshold);
      await prefs.setString('wallet_default_currency', _defaultCurrency);
      await prefs.setBool('wallet_show_fiat_equivalents', _showFiatEquivalents);
      await prefs.setBool('wallet_auto_lock_enabled', _autoLockEnabled);
      await prefs.setInt('wallet_auto_lock_minutes', _autoLockMinutes);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to save: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _exportTransactions() async {
    try {
      final walletService = WalletService();
      final transactions = walletService.allTransactions;
      if (transactions.isEmpty) { AppToast.show(context, 'No transactions', type: ToastType.error); return; }

      final format = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Export Format", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text("CSV", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)), onTap: () => Navigator.pop(c, 'csv')),
            ListTile(title: Text("JSON", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)), onTap: () => Navigator.pop(c, 'json')),
          ]),
        ),
      );

      if (format == null || !mounted) return;

      String content;
      String filename;

      if (format == 'csv') {
        content = await TransactionExportService.exportToCSV(transactions);
        filename = 'wallet_transactions_${DateTime.now().toIso8601String().split('T')[0]}.csv';
      } else {
        content = await TransactionExportService.exportToJSON(transactions);
        filename = 'wallet_transactions_${DateTime.now().toIso8601String().split('T')[0]}.json';
      }

      final file = await TransactionExportService.saveToFile(content, filename);
      if (mounted) {
        AppToast.show(context, 'Exported: ${file.path}');
        showDialog(
          context: context, 
          builder: (c) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Export Complete", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)), 
            content: Text("Saved to:\n${file.path}", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.black87)), 
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]
          )
        );
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Export failed: $e', type: ToastType.error);
    }
  }

  String get _pinStatusSubtitle {
    if (_hasPin == null) return 'Checking PIN status…';
    if (_hasPin == true) return 'PIN is active';
    return 'No PIN set — tap to create one';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: SettingsUi.pageBackground(context),
        body: const BybataLoader(),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return SettingsPageScaffold(
      title: 'Wallet settings',
      body: ListView(
        padding: SettingsUi.screenPadding,
        children: [
          SettingsGroupCard(
            title: 'Notifications',
            children: [
              SettingsSwitchTile(
                title: 'Wallet notifications',
                subtitle: 'Alerts for wallet activity',
                value: _notificationsEnabled,
                onChanged: (v) {
                  setState(() => _notificationsEnabled = v);
                  _saveSettings();
                },
              ),
              if (_notificationsEnabled) ...[
                const SettingsSwitchDivider(),
                SettingsSwitchTile(
                  title: 'Transactions',
                  subtitle: 'Notify on sends and receives',
                  value: _transactionAlertsEnabled,
                  onChanged: (v) {
                    setState(() => _transactionAlertsEnabled = v);
                    _saveSettings();
                  },
                ),
                const SettingsSwitchDivider(),
                SettingsSwitchTile(
                  title: 'Low balance',
                  subtitle: 'Warn when BYC is below threshold',
                  value: _lowBalanceAlertsEnabled,
                  onChanged: (v) {
                    setState(() => _lowBalanceAlertsEnabled = v);
                    _saveSettings();
                  },
                ),
                if (_lowBalanceAlertsEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Threshold: ${_lowBalanceThreshold.toStringAsFixed(0)} BYC',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _lowBalanceThreshold,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) {
                      setState(() => _lowBalanceThreshold = v);
                      _saveSettings();
                    },
                  ),
                ],
                const SettingsSwitchDivider(),
                SettingsSwitchTile(
                  title: 'Promotions',
                  subtitle: 'Bonuses and special offers',
                  value: _promotionAlertsEnabled,
                  onChanged: (v) {
                    setState(() => _promotionAlertsEnabled = v);
                    _saveSettings();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroupCard(
            title: 'Display',
            children: [
              SettingsSwitchTile(
                title: 'Show fiat value',
                subtitle: 'Display BYC equivalent in currency',
                value: _showFiatEquivalents,
                onChanged: (v) {
                  setState(() => _showFiatEquivalents = v);
                  _saveSettings();
                },
              ),
              const SettingsNavDivider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Currency',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                trailing: DropdownButton<String>(
                  value: CurrencyConstants.displayCurrencyCodes.contains(_defaultCurrency)
                      ? _defaultCurrency
                      : 'USD',
                  underline: const SizedBox.shrink(),
                  items: CurrencyConstants.displayCurrencyCodes
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(CurrencyConstants.labelFor(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _defaultCurrency = v);
                    _saveSettings();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroupCard(
            title: 'Security',
            children: [
              SettingsNavTile(
                icon: Icons.lock_outline_rounded,
                title: 'Wallet PIN',
                subtitle: _pinStatusSubtitle,
                onTap: () => GuardedNavigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => const WalletPinManagementScreen(),
                  ),
                ).then((_) => _loadSecurityStatus()),
              ),
              const SettingsNavDivider(),
              SettingsSwitchTile(
                title: 'Biometrics',
                subtitle: _biometricLoading
                    ? 'Verifying…'
                    : (_biometricTypeName != null
                        ? 'Unlock with $_biometricTypeName'
                        : 'Fingerprint or face unlock'),
                value: _biometricEnabled == true,
                onChanged: _biometricLoading
                    ? null
                    : (value) {
                        if (_hasPin != true) {
                          AppToast.show(
                            context,
                            'Set a wallet PIN first',
                            type: ToastType.error,
                          );
                          setState(() {}); // keep switch in sync
                          return;
                        }
                        _toggleBiometric(value);
                      },
              ),
              const SettingsSwitchDivider(),
              SettingsSwitchTile(
                title: 'Auto-lock',
                subtitle: 'Lock wallet after inactivity',
                value: _autoLockEnabled,
                onChanged: (v) {
                  setState(() => _autoLockEnabled = v);
                  _saveSettings();
                },
              ),
              if (_autoLockEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lock after $_autoLockMinutes min',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _autoLockMinutes > 1
                              ? () {
                                  setState(() => _autoLockMinutes--);
                                  _saveSettings();
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _autoLockMinutes < 30
                              ? () {
                                  setState(() => _autoLockMinutes++);
                                  _saveSettings();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroupCard(
            title: 'Data',
            children: [
              SettingsNavTile(
                icon: Icons.history_rounded,
                title: 'Transaction history',
                subtitle: 'View all wallet activity',
                onTap: () => GuardedNavigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: WalletService(),
                      child: const TransactionHistoryScreen(),
                    ),
                  ),
                ),
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.download_rounded,
                title: 'Export transactions',
                subtitle: 'Save as CSV or JSON',
                onTap: _exportTransactions,
              ),
            ],
          ),
        ],
      ),
    );
  }
}