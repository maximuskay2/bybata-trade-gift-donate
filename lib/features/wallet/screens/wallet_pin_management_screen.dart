import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_toast.dart' show AppToast, ToastType;
import '../widgets/wallet_pin_reset_sheet.dart';
import 'wallet_pin_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// PIN management screen that checks status and routes to Set PIN or Reset PIN flow.
class WalletPinManagementScreen extends StatefulWidget {
  const WalletPinManagementScreen({super.key});

  @override
  State<WalletPinManagementScreen> createState() => _WalletPinManagementScreenState();
}

class _WalletPinManagementScreenState extends State<WalletPinManagementScreen> {
  bool _isLoading = true;
  bool? _hasPin;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, const FlutterSecureStorage());
      final response = await api.get('/v1/wallet/security/status');
      final data = response.data;
      if (mounted) {
        if (data != null && data is Map) {
          final map = data as Map<String, dynamic>;
          final pinSet = map['pinSet'];
          final hasPin = map['hasPin'];
          setState(() {
            _hasPin = hasPin == true || pinSet == true;
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _hasPin = false;
            _isLoading = false;
            _errorMessage = 'Could not load PIN status';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPin = null;
          _isLoading = false;
          _errorMessage = 'Failed to load. Please try again.';
        });
        AppToast.show(context, _errorMessage!, type: ToastType.error);
      }
    }
  }

  void _navigateToSetPin() {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => WalletPinScreen(isSetting: true, isChangingPin: false),
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _startPinReset() async {
    final success = await WalletPinResetFlow.start(context);
    if (mounted && success) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        title: Text(
          'Wallet PIN',
          style: TextStyle(fontWeight: FontWeight.w900, color: context.primaryText),
        ),
        backgroundColor: context.pageBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const BybataLoader()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w500),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadStatus,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _hasPin == true ? _buildResetSection(primaryColor) : _buildSetSection(primaryColor),
                ],
              ),
            ),
    );
  }

  Widget _buildSetSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.lock_outline,
          title: 'Set PIN',
          subtitle: 'Create a 4–6 digit PIN to protect your wallet and authorize transactions.',
          color: primaryColor,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _navigateToSetPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            child: const Text('Set PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildResetSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          icon: Icons.security,
          title: 'PIN is set',
          subtitle: 'Your wallet is protected. You can reset your PIN using one of the options below.',
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _startPinReset,
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text(
              'Reset PIN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.surfaceCardDecoration(radius: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.secondaryText),
          ),
        ],
      ),
    );
  }

}
