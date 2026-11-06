import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'dart:ui'; // For BackdropFilter
import '../../../core/widgets/app_toast.dart';
import '../services/wallet_api.dart';
import '../services/bank_details_service.dart';
import '../models/bank_details_model.dart';
import '../services/wallet_transaction_auth.dart';
import '../widgets/wallet_identity_gate.dart';
import '../../profile/services/verification_check_service.dart';
import '../../profile/services/verification_check_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class WithdrawalRequestScreen extends StatefulWidget {
  const WithdrawalRequestScreen({super.key});

  @override
  State<WithdrawalRequestScreen> createState() => _WithdrawalRequestScreenState();
}

class _WithdrawalRequestScreenState extends State<WithdrawalRequestScreen> with TickerProviderStateMixin {
  // --- ANIMATION CONTROLLERS ---
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  // --- TEXT CONTROLLERS ---
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();

  // --- STATE VARIABLES ---
  String _selectedWalletSource = 'main'; // 'main' or 'donation'
  String _selectedCurrency = 'USD'; // 'USD' or 'NGN'
  String _selectedAccountType = 'Savings'; // 'Savings' or 'Checking'
  
  bool _submitting = false;
  bool _loadingRates = true;
  bool _saveBankDetails = true;
  bool _loadingBalances = true;
  bool _isVerified = false;
  bool _checkingVerification = true;
  
  double _mainAvailable = 0.0;
  double _donationAvailable = 0.0;

  // --- CONVERSION LOGIC ---
  Map<String, double> _rates = {'USD': 0.0, 'NGN': 0.0};
  double _conversionAmount = 0.0;
  double _feeAmount = 0.0;
  double _netAmount = 0.0;

  // --- CONSTANTS ---
  static const double MAIN_WALLET_FEE = 1.0; // 1 BYC flat fee
  static const double DONATION_WALLET_FEE_PERCENT = 0.10; // 10% fee

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
    _amountController.addListener(_calculateConversion);
  }

  void _setupAnimations() {
    _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController!, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController!, curve: Curves.easeOutCubic));

    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _orbAnimation = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _animationController != null) _animationController!.forward();
    });
  }

  void _loadData() {
    _checkVerification();
    _loadConversionRates();
    _loadSavedBankAccounts();
    _loadBalances();
  }

  Future<void> _checkVerification() async {
    setState(() => _checkingVerification = true);
    final verified = await VerificationCheckService.isUserVerified();
    if (mounted) setState(() {
      _isVerified = verified;
      _checkingVerification = false;
    });
  }

  @override
  void dispose() {
    _animationController?.dispose(); 
    _orbController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  // --- API & LOGIC METHODS ---

  Future<void> _loadBalances() async {
    if (!mounted) return;
    setState(() => _loadingBalances = true);
    
    try {
      final api = await WalletApi.create();

      Map<String, dynamic>? walletData;
      try {
        final analytics = await api.getWalletAnalytics();
        if (analytics is Map<String, dynamic>) walletData = analytics;
      } catch (_) {}

      if (walletData == null) {
        try {
          final w = await api.getWallet();
          if (w is Map<String, dynamic>) walletData = w;
        } catch (_) {}
      }

      double parse(dynamic v) {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }

      double mainAvail = 0.0;
      double promo = 0.0;

      if (walletData != null) {
        if (walletData.containsKey('availableBalance')) {
          mainAvail = parse(walletData['availableBalance']);
        } else if (walletData.containsKey('balance')) {
          mainAvail = parse(walletData['balance']);
        }

        if (walletData.containsKey('promotionalBalance')) {
          promo = parse(walletData['promotionalBalance']);
        } else if (walletData.containsKey('receivedFromDonations')) {
          promo = parse(walletData['receivedFromDonations']);
        }
      }

      if (mounted) {
        setState(() {
          _mainAvailable = mainAvail;
          _donationAvailable = promo;
          _loadingBalances = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBalances = false);
    }
  }

  Future<void> _loadSavedBankAccounts() async {
    try {
      final accounts = await BankDetailsService.getSavedBankAccounts();
      if (!mounted) return; 

      if (accounts.isNotEmpty) {
        final firstAccount = accounts.first;
        setState(() {
          _bankNameController.text = firstAccount.bankName;
          _accountHolderController.text = firstAccount.accountHolderName;
          _accountNumberController.text = firstAccount.accountNumber;
          _selectedAccountType = firstAccount.accountType;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved bank accounts: $e');
    }
  }

  Future<void> _loadConversionRates() async {
    if (!mounted) return;
    setState(() => _loadingRates = true);
    
    try {
      final api = await WalletApi.create();
      final ratesList = await api.getRates();
      
      if (!mounted) return; 

      final newRates = {'USD': 0.0, 'NGN': 0.0};
      
      for (var rate in ratesList) {
        if (rate is Map<String, dynamic>) {
          final toCurrency = rate['toCurrency']?.toString() ?? '';
          double rateValue = 0.0;
          final raw = rate['rate'];
          if (raw is num) {
            rateValue = raw.toDouble();
          } else if (raw is String) {
            rateValue = double.tryParse(raw) ?? 0.0;
          } else if (raw != null) {
            try {
              rateValue = double.parse(raw.toString());
            } catch (_) {
              debugPrint('Could not parse conversion rate value for $rate');
            }
          }

          if (toCurrency == 'USD' || toCurrency == 'NGN') {
            newRates[toCurrency] = rateValue;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _rates = newRates;
          _loadingRates = false;
        });
        _calculateConversion();
      }
    } catch (e) {
      debugPrint('WithdrawalRequestScreen._loadConversionRates ERROR: $e');
      if (mounted) {
        AppToast.warning(context, 'Could not load conversion rates');
        setState(() => _loadingRates = false);
      }
    }
  }

  double _calculateFee(double amount) {
    if (_selectedWalletSource == 'main') {
      return MAIN_WALLET_FEE; 
    } else {
      return amount * DONATION_WALLET_FEE_PERCENT; 
    }
  }

  void _calculateConversion() {
    if (!mounted) return;
    
    final amountBYC = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final fee = _calculateFee(amountBYC);
    final netAmountBYC = amountBYC - fee;
    final conversionRate = _rates[_selectedCurrency] ?? 0.0;
    final converted = netAmountBYC * conversionRate;

    setState(() {
      _feeAmount = fee;
      _netAmount = netAmountBYC;
      _conversionAmount = converted;
    });
  }

  String? _validateInputs() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return 'Enter a valid amount in BYC';

    final fee = _calculateFee(amount);
    if (fee >= amount) return 'Amount must be greater than the withdrawal fee';

    if (_bankNameController.text.trim().isEmpty) return 'Bank name is required';
    if (_accountHolderController.text.trim().isEmpty) return 'Account holder name is required';
    if (_accountNumberController.text.trim().isEmpty) return 'Account number is required';
    if (_accountNumberController.text.trim().length < 8) return 'Account number must be at least 8 digits';

    return null;
  }

  Future<void> _submit() async {
    if (!_isVerified) {
      if (mounted) AppToast.warning(context, 'Complete identity verification to withdraw BYC');
      return;
    }

    final validation = _validateInputs();
    if (validation != null) {
      if (mounted) AppToast.warning(context, validation);
      return;
    }

    final auth = await WalletTransactionAuth.request(
      context,
      biometricReason: 'Authenticate to request withdrawal',
    );
    if (auth == null) {
      if (mounted) AppToast.warning(context, 'Authentication cancelled');
      return;
    }

    if (mounted) setState(() => _submitting = true);
    
    try {
      final api = await WalletApi.create();
      final amount = double.parse(_amountController.text.trim());

      final bankDetails = BankDetails(
        bankName: _bankNameController.text.trim(),
        accountHolderName: _accountHolderController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountType: _selectedAccountType,
        createdAt: DateTime.now(),
        id: const Uuid().v4(),
      );

      if (_saveBankDetails) {
        await BankDetailsService.saveBankAccount(bankDetails);
      }

      final destination = {
        'bankDetails': bankDetails.toJson(),
        'walletSource': _selectedWalletSource,
        'currency': _selectedCurrency,
        'fee': _feeAmount,
        'netAmount': _netAmount,
        'conversionRate': _rates[_selectedCurrency] ?? 0.0,
        'convertedAmount': _conversionAmount,
      };

      final skipAuth = WalletTransactionAuth.isSkipped(auth);
      await api.requestWithdrawal(
        amount: amount,
        currency: _selectedCurrency,
        memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
        destination: destination,
        idempotencyKey: const Uuid().v4(),
        verificationMethod: skipAuth ? null : auth.method,
        verificationCredential: skipAuth ? null : auth.credential,
      );

      if (!mounted) return;
      AppToast.success(context, 'Withdrawal request submitted successfully');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        String msg = 'Request failed';
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map) {
            final m = data['message'];
            if (m is String && m.isNotEmpty) {
              msg = m;
            } else if (m is List && m.isNotEmpty) {
              msg = m.first.toString();
            }
          }
        } else {
          final s = e.toString();
          if (s.contains('Identity verification') ||
              s.contains('Invalid PIN') ||
              s.contains('Session expired') ||
              s.contains('authentication')) {
            msg = s.replaceFirst(RegExp(r'^.*?Exception:?\s*'), '').split('\n').first.trim();
          } else if (s.length <= 100) {
            msg = 'Request failed: $s';
          }
        }
        AppToast.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // --- THEME AWARE UI BUILDER ---

  PreferredSizeWidget _buildGlassAppBar(bool isDark, Color primaryColor) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.65),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Request Withdrawal',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    final orbOpacity = isDark ? 0.25 : 0.12;
    
    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(isDark, primaryColor),
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

          SafeArea(
            child: _checkingVerification
                ? Center(child: BybataLoadingIndicator(color: primaryColor))
                : !_isVerified
                    ? WalletIdentityGate(
                        title: 'Verification Required',
                        message:
                            'Complete identity verification to withdraw from your Main Wallet or Donation Wallet. You can still deposit and create donations.',
                        primaryColor: primaryColor,
                        isDark: isDark,
                        onVerificationChanged: _checkVerification,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        physics: const BouncingScrollPhysics(),
                        child: (_animationController == null || _fadeAnimation == null || _slideAnimation == null) 
                          ? Container() 
                          : FadeTransition(
                              opacity: _fadeAnimation!,
                              child: SlideTransition(
                                position: _slideAnimation!,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Wallet Balances
                                    _GlassCard(
                                      isDark: isDark,
                                      padding: const EdgeInsets.all(20),
                                      child: _loadingBalances
                                          ? const BybataLoader()
                                          : Row(
                                              children: [
                                                _buildBalanceItem('Main Wallet', _mainAvailable, Icons.account_balance_wallet_rounded, primaryColor, isDark),
                                                Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 16)),
                                                _buildBalanceItem('Donation Wallet', _donationAvailable, Icons.volunteer_activism_rounded, Colors.teal, isDark),
                                              ],
                                            ),
                                    ),
                                    const SizedBox(height: 28),

                                    // 2. Source Selection
                                    Text("Source & Amount", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF333333))),
                                    const SizedBox(height: 16),
                                    _GlassCard(
                                      isDark: isDark,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          _buildRadioOption('Main Wallet', 'Fee: 1 BYC flat fee', 'main', primaryColor, isDark),
                                          Divider(height: 24, color: isDark ? Colors.white12 : Colors.grey[300]),
                                          _buildRadioOption('Donation Wallet', 'Fee: 10% of withdrawal', 'donation', primaryColor, isDark),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // 3. Amount & Currency
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _GlassTextField(
                                            isDark: isDark,
                                            controller: _amountController,
                                            label: 'Amount (BYC)',
                                            hint: '0.00',
                                            icon: Icons.attach_money_rounded,
                                            isNumber: true,
                                            primaryColor: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 1,
                                          child: _GlassDropdown(
                                            isDark: isDark,
                                            value: _selectedCurrency,
                                            items: const ['USD', 'NGN'],
                                            label: 'Currency',
                                            primaryColor: primaryColor,
                                            onChanged: (val) {
                                              if (mounted) {
                                                setState(() => _selectedCurrency = val!);
                                                _calculateConversion();
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 28),

                                    // 4. Conversion Preview
                                    if (!_loadingRates && _amountController.text.isNotEmpty)
                                      _GlassCard(
                                        isDark: isDark,
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.grey[400] : Colors.grey[500], letterSpacing: 1.5)),
                                            const SizedBox(height: 16),
                                            _buildRow('Amount', '${_amountController.text} BYC', isDark),
                                            _buildRow('Fee', '-${_feeAmount.toStringAsFixed(2)} BYC', isDark, color: Colors.red),
                                            Divider(height: 24, color: isDark ? Colors.white12 : Colors.grey[200]),
                                            _buildRow('Net Amount', '${_netAmount.toStringAsFixed(2)} BYC', isDark, isBold: true),
                                            const SizedBox(height: 8),
                                            _buildRow('Exchange Rate', '1 BYC = ${_rates[_selectedCurrency]?.toStringAsFixed(2) ?? 'N/A'} $_selectedCurrency', isDark, size: 11, color: isDark ? Colors.grey[400] : Colors.grey),
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: primaryColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('You Receive', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : primaryColor)),
                                                  Text(
                                                    '${_conversionAmount.toStringAsFixed(2)} $_selectedCurrency',
                                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: primaryColor),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 28),

                                    // 5. Bank Details
                                    Text("Bank Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF333333))),
                                    const SizedBox(height: 16),
                                    _GlassTextField(isDark: isDark, controller: _bankNameController, label: 'Bank Name', hint: 'e.g. Chase, Zenith', icon: Icons.account_balance_rounded, primaryColor: primaryColor),
                                    const SizedBox(height: 12),
                                    _GlassTextField(isDark: isDark, controller: _accountNumberController, label: 'Account Number', hint: '0000000000', icon: Icons.numbers_rounded, isNumber: true, primaryColor: primaryColor),
                                    const SizedBox(height: 12),
                                    _GlassTextField(isDark: isDark, controller: _accountHolderController, label: 'Account Holder Name', hint: 'Full Name', icon: Icons.person_rounded, primaryColor: primaryColor),
                                    const SizedBox(height: 12),
                                    _GlassDropdown(
                                      isDark: isDark,
                                      value: _selectedAccountType,
                                      items: const ['Savings', 'Checking'],
                                      label: 'Account Type',
                                      primaryColor: primaryColor,
                                      onChanged: (val) { if(mounted) setState(() => _selectedAccountType = val!); },
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // Save Checkbox
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 24, width: 24,
                                          child: Checkbox(
                                            value: _saveBankDetails,
                                            activeColor: primaryColor,
                                            side: BorderSide(color: isDark ? Colors.grey[500]! : Colors.grey[600]!, width: 2),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            onChanged: (v) { if(mounted) setState(() => _saveBankDetails = v!); },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text("Save for future withdrawals", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500)),
                                      ],
                                    ),

                                    const SizedBox(height: 28),
                                    _GlassTextField(isDark: isDark, controller: _memoController, label: 'Memo (Optional)', hint: 'Reference note...', icon: Icons.notes_rounded, maxLines: 2, primaryColor: primaryColor),
                                    const SizedBox(height: 40),

                                    // Submit Button
                                    _ThreeDButton(
                                      text: _submitting ? "Processing..." : "Submit Request",
                                      color: primaryColor,
                                      textColor: Colors.white,
                                      isDark: isDark,
                                      isLoading: _submitting,
                                      onPressed: _submitting ? () {} : _submit,
                                    ),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ),
                      ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildBalanceItem(String label, double amount, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${amount.toStringAsFixed(2)} BYC',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String title, String subtitle, String value, Color primaryColor, bool isDark) {
    final isSelected = _selectedWalletSource == value;
    
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() => _selectedWalletSource = value);
          _calculateConversion();
        }
      },
      child: Container(
        color: Colors.transparent, // expand tap area
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey[600]! : Colors.grey[400]!), width: 2),
                color: isSelected ? primaryColor : Colors.transparent,
                boxShadow: isSelected ? [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 4)] : null,
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isSelected ? (isDark ? Colors.white : primaryColor) : (isDark ? Colors.grey[300] : Colors.black87))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[500] : Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark, {bool isBold = false, Color? color, double size = 13}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color ?? (isDark ? Colors.white : Colors.black87))),
        ],
      ),
    );
  }
}

// --- REUSABLE 3D COMPONENTS ---

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool isDark;
  
  const _GlassCard({required this.child, required this.padding, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            padding: padding,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.7),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isNumber;
  final int maxLines;
  final bool isDark;
  final Color primaryColor;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.primaryColor,
    this.isNumber = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          icon: Icon(icon, color: isDark ? Colors.grey[500] : Colors.grey[400], size: 20),
          labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600),
          hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        ),
      ),
    );
  }
}

class _GlassDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String label;
  final Function(String?) onChanged;
  final bool isDark;
  final Color primaryColor;

  const _GlassDropdown({
    required this.value, 
    required this.items, 
    required this.label, 
    required this.onChanged,
    required this.isDark,
    required this.primaryColor
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          icon: Icon(Icons.arrow_drop_down_rounded, color: primaryColor),
          dropdownColor: isDark ? Colors.grey[900] : Colors.white,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ThreeDButton extends StatefulWidget {
  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isLoading;
  final IconData? icon;

  const _ThreeDButton({
    required this.text, 
    required this.color, 
    required this.textColor, 
    required this.onPressed,
    required this.isDark,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<_ThreeDButton> createState() => _ThreeDButtonState();
}

class _ThreeDButtonState extends State<_ThreeDButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(top: _isPressed ? 4 : 0),
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.color, widget.color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isPressed 
              ? [] 
              : [BoxShadow(color: widget.color.withValues(alpha: widget.isDark ? 0.6 : 0.4), offset: const Offset(0, 6), blurRadius: 12)],
        ),
        alignment: Alignment.center,
        child: widget.isLoading 
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: widget.textColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(color: widget.textColor, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
      ),
    );
  }
}