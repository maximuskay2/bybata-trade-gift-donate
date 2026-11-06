import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/network_error_message.dart';
import '../../../features/common/widgets/state_components.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import '../services/wallet_security_service.dart';
import '../screens/transfer_byc_screen.dart';
import '../screens/receive_byc_screen.dart';
import '../screens/wallet_settings_screen.dart';
import '../screens/wallet_notifications_screen.dart';
import '../screens/withdrawals_screen.dart';
import '../screens/withdrawal_request_screen.dart';
import '../screens/transaction_history_screen.dart';
import '../screens/subscription_screen.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/promotion_opportunities.dart';
import '../widgets/recent_promotions_list.dart';
import '../widgets/conversion_rates_widget.dart';
import '../navigation/wallet_navigator.dart';
import '../services/wallet_api.dart';
import 'security/wallet_unlock_screen.dart';
import 'wallet_pin_screen.dart';
import '../../karma/providers/karma_provider.dart';
import '../../karma/screens/karma_screen.dart';
import 'package:bybata/core/navigation/app_drawer_opener.dart';
import 'package:bybata/core/providers/auth_provider.dart';
import 'package:bybata/core/widgets/hub_screen_top_bar.dart';
import 'package:bybata/core/widgets/app_side_drawer.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/widgets/bybata_glass_container.dart';
import 'package:bybata/features/settings/widgets/settings_ui.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WalletService _walletService = WalletService();
  final WalletSecurityService _securityService = WalletSecurityService();
  bool _isSecurityChecked = false;
  /// True when wallet PIN/biometric is required but unlock was cancelled.
  bool _awaitingUnlock = false;
  
  // Track index locally for instant fluid animation
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize controller for 5 tabs
    _tabController = TabController(length: 5, vsync: this);
    
    // Listener to sync the fluid UI when swiping the content
    _tabController.addListener(() {
      // Only update if the index actually changed to prevent jitter
      if (_tabController.index != _currentTabIndex && !_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    
    _initializeServices();
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({required Widget child, Color? color, double radius = 24}) {
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(radius),
      child: color == null
          ? child
          : Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: child,
            ),
    );
  }

  // --- LOGIC PRESERVATION ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    final loadedUserId = _walletService.currentBalance?.userId;
    if (currentUserId != null && currentUserId != loadedUserId && _isSecurityChecked) {
      _initializeServices();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    await _securityService.switchUser(uid);
    if (uid != null) {
      await _securityService.syncPinStateWithBackend();
    }
    if (_securityService.hasSecurityEnabled && _securityService.isWalletLocked) {
      final unlocked = await _showUnlockScreen();
      if (!unlocked && mounted) {
        // Never auto-pop the wallet route — that looked like "tapping Wallet
        // sends me home" when unlock was blocked by navigation debounce.
        setState(() {
          _isSecurityChecked = true;
          _awaitingUnlock = true;
        });
        return;
      }
    }
    _awaitingUnlock = false;
    _isSecurityChecked = true;
    if (uid == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      await _walletService.initializeWallet(uid);
    } catch (e) {
      debugPrint('Wallet init failed: $e');
    }
    if (mounted) setState(() {});
  }

  Future<bool> _showUnlockScreen() async {
    // force: true — unlock must open even if we just navigated to /wallet
    // (NavigationTapGuard would otherwise return null and bounce the user).
    final result = await GuardedNavigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [ChangeNotifierProvider.value(value: _securityService)],
          child: const WalletUnlockScreen(),
        ),
        fullscreenDialog: true,
      ),
      force: true,
    );
    return result ?? false;
  }

  Future<void> _retryUnlock() async {
    setState(() {
      _isSecurityChecked = false;
      _awaitingUnlock = false;
    });
    await _initializeServices();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _walletService),
        ChangeNotifierProvider.value(value: _securityService),
      ],
      child: Scaffold(
        backgroundColor: SettingsUi.pageBackground(context),
        drawer: const AppSideDrawer(),
        body: Consumer<WalletService>(
          builder: (context, walletService, child) {
            if (!_isSecurityChecked) return const BybataLoader();
            if (_awaitingUnlock) return _buildLockedState();
            if (walletService.isLoading && walletService.currentBalance == null) {
              return const BybataLoader();
            }
            if (walletService.error != null && walletService.currentBalance == null) {
              return _buildErrorState(walletService.error!);
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HubScreenTopBar(
                  title: 'Wallet',
                  onOpenDrawer: () => AppDrawerOpener.open(context),
                  trailingActions: [
                    HubTopBarIconButton(
                      icon: Icons.settings_outlined,
                      onTap: _showWalletSettings,
                      isDark: isDark,
                      iconColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => await _initializeServices(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWalletBalanceCard(),
                    const SizedBox(height: 20),
                    _buildReceivedDonationsCard(),
                    const SizedBox(height: 24),
                    _buildModernQuickActions(context),
                    const SizedBox(height: 12),
                    _buildWithdrawalsLink(context),
                    const SizedBox(height: 32),

                    // FLUID 3D TAB SWITCHER
                    _buildFluidTabSwitcher(),
                    
                    const SizedBox(height: 20),

                    // Tab Content
                    SizedBox(
                      height: 500, // Fixed height area for tab content
                      child: TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(), // Better feel for swipes
                        children: [
                          // Recent Transactions (5 items + View All)
                          RecentTransactionsList(
                            limit: 5,
                            onViewAll: () => GuardedNavigator.push(context,
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: _walletService,
                                  child: const TransactionHistoryScreen(),
                                ),
                              ),
                            ),
                          ),

                          // KARMA History
                          _buildKarmaHistoryTab(),

                          // Promotion Opportunities
                          Column(
                            children: [
                              PromotionOpportunities(
                                onCreatePromotion: () => _navigateToPromotions(),
                              ),
                              const SizedBox(height: 12),
                              const RecentPromotionsList(),
                            ],
                          ),

                          // Conversion Rates
                          ConversionRatesWidget(
                            onViewAll: () => _navigateToConversion(),
                          ),

                          // Analytics & Insights
                          _buildAnalyticsTab(),
                        ],
                      ),
                    ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- FIXED FLUID TAB SWITCHER ---
  Widget _buildFluidTabSwitcher() {
    // Labels corresponding to length: 5
    final List<String> labels = ['Activity', 'Karma', 'Promo', 'Rates', 'Stats'];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // The Fluid Background "Pill"
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut, // The "Sweet" bounce effect
            alignment: Alignment(
              // Logic to map index 0..4 to alignment -1.0..1.0
              -1.0 + (_currentTabIndex * (2.0 / (labels.length - 1))), 
              0
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.onSurface.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The Clickable Labels
          Row(
            children: List.generate(labels.length, (index) {
              final isSelected = _currentTabIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // 1. Update visual state IMMEDIATELY for responsiveness
                    setState(() {
                      _currentTabIndex = index;
                    });
                    // 2. Animate the TabView content
                    _tabController.animateTo(index);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBalanceCard() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? 'unknown';
    
    return Consumer<WalletService>(
      key: ValueKey('wallet_balance_$userId'),
      builder: (context, walletService, child) {
        final bal = walletService.currentBalance?.availableBalance ?? 0.0;
        final scheme = Theme.of(context).colorScheme;
        return _build3DContainer(
          color: scheme.surface,
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available balance',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${bal.toStringAsFixed(2)} BYC',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _navigateToFundFlow(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add funds'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToSendFlow(context),
                        icon: const Icon(Icons.arrow_outward, size: 18),
                        label: const Text('Send'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDarkAction(String label, IconData icon, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.onSurface, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedDonationsCard() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? 'unknown';
    
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('donations_$userId'),
      future: WalletApi.create().then((api) => api.getWalletAnalytics()),
      builder: (context, snapshot) {
        double parseBalance(dynamic value) {
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        }
        final receivedFromDonations = snapshot.hasData ? parseBalance(snapshot.data!['receivedFromDonations']) : 0.0;
        
        final scheme = Theme.of(context).colorScheme;
        return _build3DContainer(
          radius: 24,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.volunteer_activism, color: scheme.primary),
            ),
            title: const Text("Donation Income", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text("Lifetime received", style: TextStyle(fontSize: 12)),
            trailing: Text(
              "${receivedFromDonations.toStringAsFixed(2)} BYC",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.primary),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernQuickActions(BuildContext context) {
    final actions = [
      (Icons.qr_code_scanner_rounded, 'Receive', () => _navigateToReceiveFlow(context)),
      (Icons.south_west_rounded, 'Withdraw', () {
        GuardedNavigator.push(context,
          MaterialPageRoute(builder: (_) => const WithdrawalRequestScreen()),
        );
      }),
      (Icons.workspace_premium_outlined, 'Karma plan', () {
        GuardedNavigator.push(context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }),
    ];

    return Row(
      children: actions.map((a) {
        final (icon, label, onTap) = a;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: a == actions.last ? 0 : 8,
            ),
            child: _buildQuickActionChip(icon, label, onTap),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActionChip(IconData icon, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalsLink(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () {
          GuardedNavigator.push(context,
            MaterialPageRoute(builder: (_) => const WithdrawalsScreen()),
          );
        },
        icon: const Icon(Icons.south_east),
        label: const Text('Withdrawals'),
      ),
    );
  }

  Widget _build3DActionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _build3DContainer(
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB CONTENT BUILDERS (PRESERVED) ---
  Widget _buildKarmaHistoryTab() {
    return Consumer<KarmaProvider>(
      builder: (context, karmaProvider, child) {
        final transactions = karmaProvider.transactions;
        if (transactions.isEmpty) return _buildEmptyState("No Karma Yet", "Help others to earn!", Icons.star_border);

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final t = transactions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _build3DContainer(
                radius: 16,
                child: ListTile(
                  leading: Icon(Icons.star, color: AppTheme.karmaColor),
                  title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_formatDateTime(t.timestamp), style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    "+${t.points} KARMA",
                    style: TextStyle(color: AppTheme.karmaColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id ?? 'unknown';
    
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('analytics_$userId'),
      future: WalletApi.create().then((api) => api.getWalletAnalytics()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const BybataLoader();
        if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Failed to load analytics'));
        
        final data = snapshot.data!;
        final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0.0;
        final totalReceived = (data['totalReceived'] as num?)?.toDouble() ?? 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              _build3DInsightRow("Total Spent", "${(data['totalSpent'] ?? 0).toString()} BYC", Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              _build3DInsightRow("Total Received", "${(data['totalReceived'] ?? 0).toString()} BYC", Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              _build3DInsightRow("Monthly Trans.", "${(data['monthlyTransactions'] ?? 0)}", Theme.of(context).colorScheme.secondary),
            ],
          ),
        );
      },
    );
  }

  Widget _build3DInsightRow(String label, String value, Color color) {
    return _build3DContainer(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
      ),
    );
  }

  // Navigation Logic
  void _navigateToFundFlow(BuildContext context) => WalletNavigator.toFundWallet(context);
  void _navigateToSendFlow(BuildContext context) => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const TransferBYCScreen()));
  void _navigateToReceiveFlow(BuildContext context) => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const ReceiveBYCScreen()));
  void _navigateToPromotions() => WalletNavigator.toPromotionCenter(context);
  void _navigateToConversion() => WalletNavigator.toConversion(context);
  void _showWalletSettings() => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const WalletSettingsScreen()));
  void _navigateToPinSetup(bool isChanging) => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => WalletPinScreen(isSetting: true, isChangingPin: isChanging)));
  void _showHelpSupport() {} 
  Future<void> _lockWallet() async { if (_securityService.hasSecurityEnabled) { await _securityService.lockWallet(); Navigator.of(context).pop(); } }

  // Helpers
  Widget _buildLockedState() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Wallet locked',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock with your PIN or biometrics to view your balance and transactions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _retryUnlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Unlock wallet',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return ErrorState(
      title: NetworkErrorMessage.titleFrom(error),
      message: NetworkErrorMessage.sanitize(error),
      type: NetworkErrorMessage.isOffline(error) ||
              NetworkErrorMessage.isTimeout(error) ||
              NetworkErrorMessage.messageIndicatesTimeout(error)
          ? ErrorStateType.network
          : ErrorStateType.server,
      actionText: 'Try again',
      onRetry: () => _initializeServices(),
    );
  }
  Widget _buildEmptyState(String t, String d, IconData i) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(i, size: 50, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(d),
          ],
        ),
      );
  String _formatDateTime(DateTime dt) => "${dt.day}/${dt.month}/${dt.year}";
  void _navigateToKarmaScreen() => GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const KarmaScreen()));
  
  // Icon/Color Helpers (re-added for completeness)
  IconData _getKarmaActivityIcon(String type) => Icons.star;
  Color _getKarmaActivityColor(String type) => AppTheme.karmaColor;
}