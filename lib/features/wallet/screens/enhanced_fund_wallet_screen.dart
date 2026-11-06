import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/payment/payment_gateway_interface.dart';
import 'package:http/http.dart' as http;
import '../services/wallet_api.dart';
import '../models/wallet_balance.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import '../services/wallet_service.dart';
import 'paystack_webview_screen.dart'; // Now exports PaymentWebViewScreen
import '../../../core/services/user_currency_service.dart';
import '../../../core/constants/currency_constants.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class EnhancedFundWalletScreen extends StatefulWidget {
  const EnhancedFundWalletScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedFundWalletScreen> createState() => _EnhancedFundWalletScreenState();
}

class _EnhancedFundWalletScreenState extends State<EnhancedFundWalletScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form controllers
  final _amountController = TextEditingController();

  // Selected values
  String _selectedCurrency = 'USD';
  PaymentGateway? _selectedGateway;
  double _fiatAmount = 0.0;
  double _estimatedBYC = 0.0;
  double? _usdToNgnRate;
  String? _fxError;
  bool _fxLoading = false;
  FundingPackage? _selectedPackage;

  // Default packages (fallback when API returns empty)
  static const List<FundingPackage> _defaultPackages = [
    FundingPackage(id: 'starter', name: 'Starter Pack', bycAmount: 100, usdPrice: 10.00, description: 'Perfect for getting started'),
    FundingPackage(id: 'popular', name: 'Popular Choice', bycAmount: 500, usdPrice: 45.00, description: 'Most popular option', isPopular: true, bonusPercentage: 10.0),
    FundingPackage(id: 'value', name: 'Best Value', bycAmount: 1000, usdPrice: 85.00, description: 'Best value for money', bonusPercentage: 15.0),
    FundingPackage(id: 'premium', name: 'Premium Pack', bycAmount: 2500, usdPrice: 200.00, description: 'For serious users', bonusPercentage: 20.0),
  ];

  List<FundingPackage> _fundingPackages = _defaultPackages;
  bool _packagesLoading = true;
  bool _ratesLoading = true;
  /// 1 BYC = rate × fiat (from /v1/wallet/rates).
  Map<String, double> _bycToFiatRates = {};

  // Predefined amounts
  final List<Map<String, dynamic>> _quickAmounts = [
    {'label': '\$10', 'usd': 10.0, 'currency': 'USD'},
    {'label': '\$25', 'usd': 25.0, 'currency': 'USD'},
    {'label': '\$50', 'usd': 50.0, 'currency': 'USD'},
    {'label': '\$100', 'usd': 100.0, 'currency': 'USD'},
    {'label': '₦5,000', 'usd': 12.5, 'currency': 'NGN', 'ngn': 5000.0},
    {'label': '₦10,000', 'usd': 25.0, 'currency': 'NGN', 'ngn': 10000.0},
    {'label': '₵50', 'currency': 'GHS', 'ghs': 50.0, 'usd': 3.5},
    {'label': 'KES 500', 'currency': 'KES', 'kes': 500.0, 'usd': 3.5},
    {'label': 'R100', 'currency': 'ZAR', 'zar': 100.0, 'usd': 5.5},
  ];

  bool _isProcessing = false;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _orbAnimation = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);

    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await UserCurrencyService.instance.loadFromLocalPrefs();
      final preferred = UserCurrencyService.instance.preferredFiatCurrency;
      if (mounted) {
        setState(() => _selectedCurrency = preferred);
      }
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;
      final walletProvider = context.read<WalletProvider>();
      if (userId != null && !walletProvider.isPaymentInitialized) {
        walletProvider.initializeWallet(userId);
      }
      _loadFundingPackages();
      _loadConversionRates();
    });
  }

  String get _preferredCurrency =>
      UserCurrencyService.instance.preferredFiatCurrency;

  Future<void> _loadConversionRates() async {
    setState(() => _ratesLoading = true);
    try {
      final api = await WalletApi.create();
      final items = await api.getRates();
      final parsed = <String, double>{};
      for (final raw in items) {
        if (raw is! Map) continue;
        final base = (raw['base'] as String?)?.toUpperCase() ?? 'BYC';
        final quote = (raw['quote'] as String?)?.toUpperCase() ?? '';
        if (base != 'BYC' || quote.isEmpty) continue;
        final rateRaw = raw['rate'];
        final rate = rateRaw is num
            ? rateRaw.toDouble()
            : double.tryParse(rateRaw?.toString() ?? '') ?? 0;
        if (rate > 0) parsed[quote] = rate;
      }
      if (!mounted) return;
      if (parsed.isNotEmpty) {
        context.read<WalletProvider>().applyBcyToFiatRates(parsed);
      }
      setState(() {
        _bycToFiatRates = parsed;
        _ratesLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _ratesLoading = false);
        await context.read<WalletProvider>().updateExchangeRates();
        if (mounted) {
          setState(() => _bycToFiatRates = Map<String, double>.from(
            context.read<WalletProvider>().exchangeRates,
          ));
        }
      }
    }
  }

  double? _fiatForByc(double byc, String currency) {
    final rate = _bycToFiatRates[currency.toUpperCase()];
    if (rate == null || rate <= 0) return null;
    return byc * rate;
  }

  String _formatFiatAmount(double amount, String currency) {
    final decimals = currency == 'JPY' ? 0 : 2;
    final symbol = CurrencyConstants.symbolFor(currency);
    final formatted = amount.toStringAsFixed(decimals);
    if (currency == 'NGN' || currency == 'KES') {
      final parts = formatted.split('.');
      final intPart = parts[0];
      final buf = StringBuffer();
      for (var i = 0; i < intPart.length; i++) {
        if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
        buf.write(intPart[i]);
      }
      final frac = parts.length > 1 ? '.${parts[1]}' : '';
      return '$symbol$buf$frac';
    }
    return '$symbol$formatted';
  }

  String _localizedPriceForPackage(FundingPackage pkg) {
    final currency = _preferredCurrency;
    final fiat = _fiatForByc(pkg.totalBYC, currency);
    if (fiat != null) {
      return _formatFiatAmount(fiat, currency);
    }
    return pkg.formattedPrice;
  }

  String? _bycRateHint() {
    final currency = _preferredCurrency;
    final rate = _bycToFiatRates[currency];
    if (rate == null || rate <= 0) return null;
    return '1 BYC ≈ ${_formatFiatAmount(rate, currency)}';
  }

  /// Currencies Paystack / Flutterwave typically settle in Africa.
  static const _africanFundingCurrencies = {'NGN', 'GHS', 'KES', 'ZAR', 'UGX'};

  /// Currency actually charged at the gateway (may differ from display preference).
  String _resolveChargeCurrency(String preferred, WalletProvider walletProvider) {
    final upper = preferred.toUpperCase();
    if (walletProvider.getPaymentGatewaysForCurrency(upper).isNotEmpty) {
      return upper;
    }
    if (walletProvider.getPaymentGatewaysForCurrency('USD').isNotEmpty) {
      return 'USD';
    }
    if (walletProvider.getPaymentGatewaysForCurrency('NGN').isNotEmpty) {
      return 'NGN';
    }
    final all = walletProvider.getSupportedFiatCurrencies();
    return all.isNotEmpty ? all.first : 'USD';
  }

  String _gatewayHint(String currency, WalletProvider walletProvider) {
    final gateways = walletProvider.getPaymentGatewaysForCurrency(currency);
    if (gateways.isEmpty) return 'No payment method for $currency';
    final names = gateways.map((g) => g.displayName).join(' · ');
    if (_africanFundingCurrencies.contains(currency.toUpperCase())) {
      return 'African currencies → $names';
    }
    return 'International → $names';
  }

  Future<void> _loadFundingPackages() async {
    try {
      final api = await WalletApi.create();
      final list = await api.getFundingPackages();
      if (mounted && list.isNotEmpty) {
        final pkgs = list.map((e) {
          final m = e as Map<String, dynamic>;
          return FundingPackage(
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString() ?? '',
            bycAmount: (m['bycAmount'] ?? m['totalBYC'] ?? 0).toDouble(),
            usdPrice: (m['usdPrice'] ?? m['price'] ?? 0).toDouble(),
            description: m['description']?.toString() ?? '',
            isPopular: m['isPopular'] == true,
            bonusPercentage: (m['bonusPercentage'] ?? 0).toDouble(),
          );
        }).toList();
        setState(() {
          _fundingPackages = pkgs;
          _packagesLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _fundingPackages = _defaultPackages;
          _packagesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _fundingPackages = _defaultPackages;
          _packagesLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  // --- LOGIC PRESERVATION ---

  void _onAmountChanged() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _selectedPackage = null;
      _fiatAmount = amount;
      _updateEstimatedBYC();
    });
  }

  void _selectPackage(FundingPackage package) {
    final walletProvider = context.read<WalletProvider>();
    final displayCurrency = _preferredCurrency;
    final chargeCurrency = _resolveChargeCurrency(displayCurrency, walletProvider);
    final displayFiat =
        _fiatForByc(package.totalBYC, displayCurrency) ?? package.usdPrice;
    final chargeFiat = chargeCurrency == displayCurrency
        ? displayFiat
        : (_fiatForByc(package.totalBYC, chargeCurrency) ?? package.usdPrice);
    final decimals = chargeCurrency == 'JPY' ? 0 : 2;
    setState(() {
      _selectedPackage = package;
      _fiatAmount = chargeFiat;
      _estimatedBYC = package.totalBYC;
      _selectedCurrency = chargeCurrency;
      _amountController.text = chargeFiat.toStringAsFixed(decimals);
      _updateEstimatedBYC();
      _selectedGateway =
          walletProvider.getRecommendedPaymentGateway(chargeCurrency);
      if (chargeCurrency == 'USD' &&
          _selectedGateway == PaymentGateway.paystack) {
        _ensureFxRate();
      }
    });
  }

  void _updateEstimatedBYC() {
    if (_selectedPackage != null) {
      setState(() => _estimatedBYC = _selectedPackage!.totalBYC);
      return;
    }
    final walletProvider = context.read<WalletProvider>();
    setState(() {
      _estimatedBYC = walletProvider.calculateBYCForFiat(_fiatAmount, _selectedCurrency);
    });
  }

  void _selectQuickAmount(Map<String, dynamic> quickAmount) {
    setState(() {
      _selectedPackage = null;
      _selectedCurrency = quickAmount['currency'];
      if (_selectedCurrency == 'USD') {
        _fiatAmount = quickAmount['usd'];
      } else {
        _fiatAmount = quickAmount['ngn'] ?? quickAmount['usd'];
      }
      _amountController.text = _fiatAmount.toStringAsFixed(2);
      _updateEstimatedBYC();

      final walletProvider = context.read<WalletProvider>();
      _selectedGateway = walletProvider.getRecommendedPaymentGateway(_selectedCurrency);
      if (_selectedCurrency == 'USD') {
        _ensureFxRate();
      }
    });
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() { _currentStep++; });
      if (_currentStep == 2 && _selectedGateway == PaymentGateway.paystack && _selectedCurrency == 'USD') {
        if (_usdToNgnRate == null || _usdToNgnRate! <= 0) { _ensureFxRate(); }
      }
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _processPayment();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() { _currentStep--; });
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: return _fiatAmount > 0;
      case 1: return _selectedGateway != null;
      case 2: return _selectedGateway != null;
      default: return false;
    }
  }

  Future<void> _processPayment() async {
    if (_selectedGateway == null || _fiatAmount <= 0) return;
    setState(() { _isProcessing = true; });

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id;
      final userEmail = auth.currentUser?.email;
      final walletProvider = context.read<WalletProvider>();
      if (userId != null && !walletProvider.isPaymentInitialized) {
        await walletProvider.initializeWallet(userId);
      }
      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('Sign in with a valid email to fund your wallet');
      }
      double amountToCharge = _fiatAmount;
      String currencyToCharge = _selectedCurrency;
      
      if (_selectedCurrency == 'USD' && _selectedGateway == PaymentGateway.paystack) {
        if (_usdToNgnRate == null || _usdToNgnRate! <= 0) await _ensureFxRate();
        if (_usdToNgnRate == null || _usdToNgnRate! <= 0) throw Exception('Failed to fetch FX rate for USD→NGN');
        amountToCharge = _fiatAmount * _usdToNgnRate!;
        currencyToCharge = 'NGN';
      }

      final success = await walletProvider.addFundsViaGateway(
        fiatAmount: amountToCharge,
        currency: currencyToCharge,
        gateway: _selectedGateway!,
        userEmail: userEmail, 
        metadata: {
          'source': 'wallet_funding_screen',
          'estimated_byc': _estimatedBYC,
          'fx_rate_usd_ngn': _usdToNgnRate,
          'original_amount_usd': _fiatAmount,
          'returnUrl': 'bybata://payment/callback',
          if (_selectedPackage != null) 'amountByc': _selectedPackage!.totalBYC,
        },
      );

      final last = walletProvider.paymentManager?.lastPaymentResult;
      final meta = last?.metadata as Map<String, dynamic>?;
      final authUrl = meta?['authorizationUrl'] ?? 
                      meta?['authorization_url'] ?? 
                      meta?['approveLink'] ?? 
                      meta?['checkoutUrl'] ??
                      meta?['checkout_url'] ??
                      meta?['payment_link'];
      
      if (authUrl != null && mounted) {
        print('[FundWallet] Opening ${_selectedGateway!.name} WebView: $authUrl');
        
        final providerName = _selectedGateway!.name.toLowerCase();
        
        final result = await GuardedNavigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewScreen(
              authorizationUrl: authUrl,
              provider: providerName,
            ),
          ),
        );

        if (result != null && mounted) {
          final status = result['status'];
          final reference = result['reference'];
          
          print('[FundWallet] Payment result: $status, reference: $reference');
          
          if ((status == 'success' || status == 'pending') && reference != null) {
            AppToast.info(context, 'Verifying payment...');
            
            try {
              final walletApi = await WalletApi.create();
              Map<String, dynamic> verifyResult;
              
              switch (_selectedGateway!) {
                case PaymentGateway.paystack:
                  verifyResult = await walletApi.verifyPaystackFunding(providerReference: reference);
                  break;
                case PaymentGateway.stripe:
                  verifyResult = await walletApi.verifyStripeFunding(sessionId: reference);
                  break;
                case PaymentGateway.paypal:
                  verifyResult = await walletApi.verifyPaypalFunding(orderId: reference);
                  break;
                case PaymentGateway.flutterwave:
                  verifyResult = await walletApi.verifyFlutterwaveFunding(transactionId: reference);
                  break;
              }
              
              print('[FundWallet] Verification result: $verifyResult');
              
              if (verifyResult['ok'] == true) {
                final walletProvider = context.read<WalletProvider>();
                await walletProvider.refreshWallet();
                _showSuccessDialog();
              } else {
                final errorMsg = verifyResult['error'] ?? 'Payment verification failed';
                AppToast.error(context, errorMsg);
              }
            } catch (e) {
              print('[FundWallet] Verification error: $e');
              AppToast.error(context, 'Failed to verify payment: ${e.toString()}');
            }
          } else if (status == 'cancelled') {
            AppToast.warning(context, 'Payment cancelled');
          } else {
            AppToast.error(context, 'Payment failed or was not completed');
          }
        }
        
        return; 
      }

      if (success) {
        try {
          await WalletService().refreshFromServer();
          await walletProvider.refreshWallet();
        } catch (_) {}
        _showSuccessDialog();
      } else {
        final msg = walletProvider.errorMessage ?? 'Payment failed';
        AppToast.warning(context, msg);
      }
    } catch (e) {
      print('[FundWallet] Payment error: $e');
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _ensureFxRate() async {
    setState(() { _fxLoading = true; _fxError = null; });
    try {
      final api = await WalletApi.create();
      List<dynamic> items = await api.getPublicRates(activeOnly: true);
      if (items.isEmpty) items = await api.getRates();
      
      double? direct;
      double? bycUsd;
      double? bycNgn;
      for (final r in items) {
        final base = (r['base'] as String?)?.toUpperCase();
        final quote = (r['quote'] as String?)?.toUpperCase();
        final raw = r['rate'];
        double? rate;
        if (raw is num) rate = raw.toDouble();
        if (raw is String) rate = double.tryParse(raw);
        final activeVal = r['active'];
        final active = activeVal == true || activeVal == 'true' || activeVal == 1;
        if (!active || rate == null || rate <= 0) continue;
        if (base == 'USD' && quote == 'NGN') direct = rate;
        if (base == 'BYC' && quote == 'USD') bycUsd = rate;
        if (base == 'BYC' && quote == 'NGN') bycNgn = rate;
      }
      final resolved = direct ?? ((bycUsd != null && bycNgn != null && bycUsd > 0) ? (bycNgn / bycUsd) : null);
      if (resolved == null || resolved <= 0) throw Exception('No active USD→NGN rate');
      setState(() { _usdToNgnRate = resolved; _fxLoading = false; });
    } catch (e) {
      setState(() { _fxLoading = false; _fxError = 'FX fetch failed'; });
    }
  }

  // --- 3D UI ENGINE ---
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding, VoidCallback? onTap, required bool isDark}) {
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: card) : card;
  }

  Widget _buildSelectableGlassCard({required Widget child, required bool isSelected, required VoidCallback onTap, required bool isDark, required Color primaryColor}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isSelected) BoxShadow(color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.2), blurRadius: 12, offset: const Offset(0, 4))
            else BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected 
                    ? primaryColor.withValues(alpha: isDark ? 0.15 : 0.05) 
                    : (isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.7)),
                border: Border.all(
                  color: isSelected ? primaryColor : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9)), 
                  width: isSelected ? 2 : 1.5
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecessedPanel({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white, width: 1.5),
      ),
      child: child,
    );
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary; 
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    final orbOpacity = isDark ? 0.25 : 0.12;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: _build3DAppBar(primaryColor, isDark),
      body: Stack(
        children: [
          // Ambient Background Orbs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1, right: -100,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * _orbAnimation.value),
                  child: Container(
                    width: 350, height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: orbOpacity),
                      boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: orbOpacity + 0.05), blurRadius: 120)],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2, left: -80,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -30 * _orbAnimation.value),
                  child: Container(
                    width: 250, height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: orbOpacity - 0.05),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: orbOpacity), blurRadius: 90)],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Content
          SafeArea(
            child: Consumer<WalletProvider>(
              builder: (context, walletProvider, child) {
                if (!walletProvider.isPaymentInitialized) return _buildInitGatewaysState(walletProvider, isDark);

                return Column(
                  children: [
                    _build3DStepper(primaryColor, isDark),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildAmountSelectionStep(walletProvider, primaryColor, isDark),
                          _buildPaymentMethodStep(walletProvider, primaryColor, isDark),
                          _buildConfirmationStep(walletProvider, primaryColor, isDark),
                        ],
                      ),
                    ),
                    _build3DNavigationButtons(primaryColor, isDark),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _build3DAppBar(Color primaryColor, bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            title: Text('Fund Wallet', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
            backgroundColor: isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.6),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitGatewaysState(WalletProvider walletProvider, bool isDark) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const BybataLoadingIndicator(size: BybataLoadingSize.compact),
      const SizedBox(height: 16),
      Text('Initializing gateways...', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
      TextButton(onPressed: () => setState(() => _currentStep = 0), child: const Text('Skip'))
    ]));
  }

  Widget _build3DStepper(Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          for (int i = 0; i <= 2; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                decoration: BoxDecoration(
                  color: i <= _currentStep ? primaryColor : (isDark ? Colors.white12 : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: i <= _currentStep ? [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 6)] : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountSelectionStep(WalletProvider walletProvider, Color primaryColor, bool isDark) {
    final rawCurrencies = walletProvider.getSupportedFiatCurrencies();
    final supportedCurrencies = rawCurrencies.toSet().toList()..sort();
    
    if (!supportedCurrencies.contains(_selectedCurrency) && supportedCurrencies.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedCurrency = supportedCurrencies.first);
      });
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      physics: const BouncingScrollPhysics(),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Balance', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Text('${walletProvider.bycBalance.toStringAsFixed(2)} BYC', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: -1)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              Text('Packages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text(
                _ratesLoading
                    ? 'Loading rates…'
                    : 'Prices in ${CurrencyConstants.labelFor(_preferredCurrency)} · BYC includes any bonus',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              if (_bycRateHint() != null) ...[
                const SizedBox(height: 4),
                Text(
                  _bycRateHint()!,
                  style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 10),
              _buildCurrencyRoutingBanner(walletProvider, primaryColor, isDark),
              const SizedBox(height: 16),
              if (_packagesLoading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
              else
                ..._fundingPackages.map((pkg) => _buildPackageCard(pkg, primaryColor, isDark, walletProvider)),
              const SizedBox(height: 32),
              
              Text('Quick Select', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: _quickAmounts.map((amount) => _buildQuickAmountButton(amount, primaryColor, isDark)).toList(),
              ),
              const SizedBox(height: 32),
              
              Text('Custom Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(
                'Select currency to determine payment options',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildGlassCard(
                isDark: isDark,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: supportedCurrencies.contains(_selectedCurrency) ? _selectedCurrency : null,
                          icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
                          dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                          items: supportedCurrencies
                              .toSet()
                              .toList()
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(_getCurrencyLabel(c), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPackage = null; 
                              _selectedCurrency = value!;
                              _updateEstimatedBYC();
                              _selectedGateway = walletProvider.getRecommendedPaymentGateway(_selectedCurrency);
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '0.00',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          prefixText: _getCurrencyPrefix(_selectedCurrency),
                          prefixStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_estimatedBYC > 0)
                _buildRecessedPanel(
                  isDark: isDark,
                  child: Column(
                    children: [
                      Text(
                        '≈ ${_estimatedBYC.toStringAsFixed(2)} BYC',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                      ),
                      if (_fiatAmount > 0 && _selectedCurrency == _preferredCurrency)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'You pay ${_formatFiatAmount(_fiatAmount, _selectedCurrency)}',
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyRoutingBanner(
    WalletProvider walletProvider,
    Color primaryColor,
    bool isDark,
  ) {
    final preferred = _preferredCurrency.toUpperCase();
    final charge = _resolveChargeCurrency(preferred, walletProvider);
    final gateways = walletProvider.getPaymentGatewaysForCurrency(charge);
    final isAfrican = _africanFundingCurrencies.contains(preferred);
    final converted = preferred != charge;

    final title = converted
        ? 'Shown in $preferred · charged in $charge'
        : (isAfrican
            ? 'African funding ($preferred)'
            : 'International funding ($preferred)');
    final subtitle = converted
        ? 'Paystack/Flutterwave cover NGN, GHS, KES, ZAR. $preferred uses ${gateways.map((g) => g.displayName).join(' / ')} instead.'
        : _gatewayHint(charge, walletProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: primaryColor.withValues(alpha: isDark ? 0.14 : 0.08),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAfrican ? Icons.public_rounded : Icons.travel_explore_rounded,
            size: 20,
            color: primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    FundingPackage pkg,
    Color primaryColor,
    bool isDark,
    WalletProvider walletProvider,
  ) {
    final isSelected = _selectedPackage?.id == pkg.id;
    final preferred = _preferredCurrency;
    final charge = _resolveChargeCurrency(preferred, walletProvider);
    final localized = _localizedPriceForPackage(pkg);
    final gateway = walletProvider.getRecommendedPaymentGateway(charge);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _buildSelectableGlassCard(
        isSelected: isSelected,
        isDark: isDark,
        primaryColor: primaryColor,
        onTap: () => _selectPackage(pkg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white38 : Colors.grey.shade400),
                      width: 2,
                    ),
                    color: isSelected ? primaryColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pkg.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (pkg.isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                if (pkg.bonusPercentage > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pkg.bonusText,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.formattedBYC,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pkg.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      localized,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preferred,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                    if (_fiatForByc(pkg.totalBYC, preferred) == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '≈ ${pkg.formattedPrice} USD',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (gateway != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        charge == preferred
                            ? 'Pay with ${gateway.displayName}'
                            : 'Charged in $charge via ${gateway.displayName}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(Map<String, dynamic> amount, Color primaryColor, bool isDark) {
    final isSelected = _selectedPackage == null && _selectedCurrency == amount['currency'] && _fiatAmount == (amount[amount['currency'].toLowerCase()] ?? amount['usd']);
    
    return GestureDetector(
      onTap: () => _selectQuickAmount(amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white), width: 1.5),
          boxShadow: isSelected 
              ? [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] 
              : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text(amount['label'], style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildPaymentMethodStep(WalletProvider walletProvider, Color primaryColor, bool isDark) {
    final availableGateways = walletProvider.getPaymentGatewaysForCurrency(_selectedCurrency);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Method', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 8),
          Text('Select secure payment gateway', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          if (availableGateways.isEmpty)
            _buildRecessedPanel(isDark: isDark, child: Center(child: Text('No gateways available for $_selectedCurrency', style: TextStyle(color: isDark ? Colors.white : Colors.black))))
          else
            ...availableGateways.map((gateway) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSelectableGlassCard(
                isSelected: _selectedGateway == gateway,
                isDark: isDark,
                primaryColor: primaryColor,
                onTap: () {
                  setState(() => _selectedGateway = gateway);
                  if (gateway == PaymentGateway.paystack && _selectedCurrency == 'USD' && (_usdToNgnRate == null || _usdToNgnRate! <= 0)) {
                    _ensureFxRate();
                  }
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _selectedGateway == gateway ? primaryColor : (isDark ? Colors.white10 : Colors.grey[100]), shape: BoxShape.circle),
                      child: Icon(_getGatewayIcon(gateway), size: 28, color: _selectedGateway == gateway ? Colors.white : Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gateway.displayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _selectedGateway == gateway ? (isDark ? Colors.white : primaryColor) : (isDark ? Colors.white : Colors.black87))),
                          const SizedBox(height: 4),
                          Text(_getGatewayDescription(gateway), style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (_selectedGateway == gateway) Icon(Icons.check_circle_rounded, color: isDark ? Colors.white : primaryColor),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep(WalletProvider walletProvider, Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm Purchase', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 24),
          _buildGlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildSummaryRow('Amount', '${_fiatAmount.toStringAsFixed(2)} $_selectedCurrency', isDark),
                Divider(height: 32, color: isDark ? Colors.white12 : Colors.grey[200]),
                _buildSummaryRow('Method', _selectedGateway?.displayName ?? 'None', isDark),
                Divider(height: 32, color: isDark ? Colors.white12 : Colors.grey[200]),
                if (_selectedGateway == PaymentGateway.paystack && _selectedCurrency == 'USD')
                  Column(
                    children: [
                      _buildSummaryRow('FX Rate', _fxLoading ? 'Loading...' : (_fxError ?? '1 USD = ${(_usdToNgnRate ?? 0).toStringAsFixed(2)} NGN'), isDark),
                      Divider(height: 32, color: isDark ? Colors.white12 : Colors.grey[200]),
                      _buildSummaryRow('Total Charge', '${((_usdToNgnRate ?? 0) * _fiatAmount).toStringAsFixed(2)} NGN', isDark, isBold: true),
                    ],
                  )
                else
                  _buildSummaryRow('Total Charge', '${_fiatAmount.toStringAsFixed(2)} $_selectedCurrency', isDark, isBold: true),
                Divider(height: 32, color: isDark ? Colors.white12 : Colors.grey[200]),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('You Receive', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : primaryColor)),
                      Text('${_estimatedBYC.toStringAsFixed(2)} BYC', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: primaryColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _build3DNavigationButtons(Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), // Floating dock
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: GestureDetector(
                      onTap: _isProcessing ? null : _previousStep,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(child: Text("Back", style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87))),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: (_isProcessing || !_canProceed()) ? null : _nextStep,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: !_canProceed() 
                              ? [Colors.grey, Colors.grey.shade400] 
                              : (_currentStep == 2 ? [Colors.green, Colors.green.shade600] : [primaryColor, primaryColor.withValues(alpha: 0.8)]),
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _canProceed() ? [BoxShadow(color: (_currentStep == 2 ? Colors.green : primaryColor).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : null,
                      ),
                      child: Center(
                        child: _isProcessing 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Text(_getButtonText(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getButtonText() {
    switch (_currentStep) {
      case 0: return 'Continue';
      case 1: return 'Review';
      case 2: return 'Pay Now';
      default: return 'Continue';
    }
  }

  // --- ACTIONS & HELPERS ---
  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bycLabel = _estimatedBYC.toStringAsFixed(
      _estimatedBYC == _estimatedBYC.roundToDouble() ? 0 : 2,
    );
    final gatewayName = _selectedGateway?.displayName;
    final fiatLabel = _fiatAmount > 0
        ? _formatFiatAmount(_fiatAmount, _selectedCurrency)
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E1E24), const Color(0xFF16161A)]
                    : [Colors.white, AppColors.primaryTintSoft],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0.75),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Wallet funded',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your payment cleared and BYC is in your wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isDark
                        ? Colors.white70
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: isDark
                          ? Colors.white12
                          : AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '+$bycLabel BYC',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: AppColors.primary,
                        ),
                      ),
                      if (fiatLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Paid $fiatLabel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                      if (gatewayName != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white,
                          ),
                          child: Text(
                            'via $gatewayName',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(c).pop();
                      Navigator.of(c).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Failed", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), 
        content: Text(error, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87)), 
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)))]
      )
    );
  }

  IconData _getGatewayIcon(PaymentGateway g) {
    switch (g) {
      case PaymentGateway.paystack: return Icons.credit_card_rounded;
      case PaymentGateway.stripe: return Icons.payment_rounded;
      case PaymentGateway.flutterwave: return Icons.account_balance_rounded;
      case PaymentGateway.paypal: return Icons.payment_rounded;
    }
  }

  String _getGatewayDescription(PaymentGateway g) {
    switch (g) {
      case PaymentGateway.paystack: return 'Card, Bank Transfer (NG)';
      case PaymentGateway.stripe: return 'Credit/Debit Cards (Global)';
      case PaymentGateway.flutterwave: return 'Mobile Money & Cards (Africa)';
      case PaymentGateway.paypal: return 'PayPal Balance';
    }
  }

  String _getCurrencyLabel(String code) {
    switch (code) {
      case 'NGN': return 'NGN (Nigerian Naira)';
      case 'GHS': return 'GHS (Ghanaian Cedis)';
      case 'KES': return 'KES (Kenyan Shillings)';
      case 'ZAR': return 'ZAR (South African Rand)';
      case 'USD': return 'USD (US Dollar)';
      default: return code;
    }
  }

  String _getCurrencyPrefix(String code) {
    return '${CurrencyConstants.symbolFor(code)} ';
  }
}