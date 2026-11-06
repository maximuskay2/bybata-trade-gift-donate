import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../models/wallet_balance.dart';
import '../services/wallet_api.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}


class _FundWalletScreenState extends State<FundWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _customAmountController = TextEditingController();
  
  FundingPackage? _selectedPackage;
  String _selectedPaymentMethod = 'card';
  double _customAmount = 0.0;
  bool _isProcessing = false;
  bool _paymentMethodsExpanded = false;
  
  final List<FundingPackage> _fundingPackages = [
    const FundingPackage(
      id: 'starter',
      name: 'Starter Pack',
      bycAmount: 100,
      usdPrice: 10.00,
      description: 'Perfect for getting started',
    ),
    const FundingPackage(
      id: 'popular',
      name: 'Popular Choice',
      bycAmount: 500,
      usdPrice: 45.00,
      description: 'Most popular option',
      isPopular: true,
      bonusPercentage: 10.0,
    ),
    const FundingPackage(
      id: 'value',
      name: 'Best Value',
      bycAmount: 1000,
      usdPrice: 85.00,
      description: 'Best value for money',
      bonusPercentage: 15.0,
    ),
    const FundingPackage(
      id: 'premium',
      name: 'Premium Pack',
      bycAmount: 2500,
      usdPrice: 200.00,
      description: 'For serious users',
      bonusPercentage: 20.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Fund Wallet'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showFundingInfo,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Balance Header
          _buildBalanceHeader(),
          
          // Tab Bar
          _buildTabBar(),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPackagesTab(),
                _buildCustomAmountTab(),
              ],
            ),
          ),
          
          // Payment Method & Checkout
          _buildCheckoutSection(),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400.withValues(alpha: 0.1),
            Colors.orange.shade400.withValues(alpha: 0.1),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '2,547.50 BYC',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    Text(
                      'USD \$254.75',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, Colors.amber],
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          tabs: const [
            Tab(text: 'Packages'),
            Tab(text: 'Custom Amount'),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _fundingPackages.length,
              itemBuilder: (context, index) {
                final package = _fundingPackages[index];
                return _buildPackageCard(package);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(FundingPackage package) {
    final isSelected = _selectedPackage?.id == package.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPackage = package;
          });
        },
        child: ShadowCard(
          shadowIntensity: isSelected ? ShadowIntensity.medium : ShadowIntensity.light,
          border: isSelected 
            ? Border.all(color: Theme.of(context).primaryColor, width: 2)
            : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Package Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Colors.amber,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.monetization_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Package Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  package.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (package.isPopular) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'POPULAR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            package.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Price and Amount
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            package.formattedBYC,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                            textAlign: TextAlign.end,
                          ),
                          Text(
                            package.formattedPrice,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.end,
                          ),
                          if (package.bonusPercentage > 0)
                            Text(
                              package.bonusText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.end,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (package.bonusPercentage > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bonus: ${package.bycAmount * package.bonusPercentage / 100} extra BYC',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Custom Amount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          ShadowCard(
            shadowIntensity: ShadowIntensity.light,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _customAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'USD Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _customAmount = double.tryParse(value) ?? 0.0;
                        _selectedPackage = null; // Clear package selection
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (_customAmount > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'You will receive:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(_customAmount * 10).toStringAsFixed(0)} BYC',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  Text(
                    'Exchange Rate: 1 USD = 10 BYC',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          const Text(
            'Quick Amounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildQuickAmountButton(10)),
              const SizedBox(width: 12),
              Expanded(child: _buildQuickAmountButton(25)),
              const SizedBox(width: 12),
              Expanded(child: _buildQuickAmountButton(50)),
              const SizedBox(width: 12),
              Expanded(child: _buildQuickAmountButton(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(int amount) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _customAmount = amount.toDouble();
          _customAmountController.text = amount.toString();
          _selectedPackage = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _customAmount == amount 
            ? Theme.of(context).primaryColor
            : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '\$$amount',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _customAmount == amount ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ShadowCard(
            shadowIntensity: ShadowIntensity.light,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedPackage != null
                        ? 'Checkout ${_selectedPackage!.name} – ${_selectedPackage!.formattedBYC}'
                        : _customAmount > 0
                          ? 'Checkout Custom – ${_customAmount.toStringAsFixed(2)} BYC'
                          : 'Select a package or enter amount',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : () async {
                      final amount = _selectedPackage != null ? _selectedPackage!.totalBYC : _customAmount;
                      if (amount <= 0) return;
                      setState(() => _isProcessing = true);
                      try {
                        final api = await WalletApi.create();
                        final idem = 'fund-${DateTime.now().millisecondsSinceEpoch}';
                        await api.fund(amount: amount, memo: 'app_fund', idempotencyKey: idem);
                        if (mounted) {
                          AppToast.show(context, 'Wallet funded successfully');
                          Navigator.of(context).maybePop();
                        }
                      } catch (e) {
                        if (mounted) {
                          AppToast.show(context, 'Funding failed: $e');
                        }
                      } finally {
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
                    child: Text(_isProcessing ? 'Processing…' : 'Pay'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _paymentMethodsExpanded = !_paymentMethodsExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _getSelectedPaymentIcon(),
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getSelectedPaymentLabel(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _paymentMethodsExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _paymentMethodsExpanded ? null : 0,
            child: _paymentMethodsExpanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPaymentMethodButton(
                                'card',
                                'Credit Card',
                                Icons.credit_card,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPaymentMethodButton(
                                'paypal',
                                'PayPal',
                                Icons.paypal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPaymentMethodButton(
                                'google_pay',
                                'Google Pay',
                                Icons.payment,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodButton(String method, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
          _paymentMethodsExpanded = false; // Auto-collapse after selection
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).primaryColor
              : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getCheckoutButtonText() {
    if (_selectedPackage != null) {
      return 'Pay ${_selectedPackage!.formattedPrice} - Get ${_selectedPackage!.formattedBYC}';
    } else if (_customAmount > 0) {
      return 'Pay \$${_customAmount.toStringAsFixed(2)} - Get ${(_customAmount * 10).toStringAsFixed(0)} BYC';
    }
    return 'Select Amount to Continue';
  }

  void _processPayment() async {
    if (!mounted) return;
    AppToast.info(
      context,
      'Use Fund Wallet with Paystack, Stripe, PayPal, or Flutterwave. Simulated funding is disabled.',
    );
    setState(() {
      _isProcessing = false;
    });
  }

  void _showPaymentSuccess() {
    final bycAmount = _selectedPackage?.totalBYC ?? (_customAmount * 10);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${bycAmount.toStringAsFixed(0)} BYC has been added to your wallet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to wallet
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showFundingInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How Funding Works'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• BYC is the only currency used within bYbata'),
            Text('• 1 USD = 10 BYC (current rate)'),
            Text('• Use BYC to promote listings and gift other users'),
            Text('• No refunds - BYC can only be spent within the app'),
            Text('• Secure payments through trusted processors'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  IconData _getSelectedPaymentIcon() {
    switch (_selectedPaymentMethod) {
      case 'card':
        return Icons.credit_card;
      case 'paypal':
        return Icons.paypal;
      case 'google_pay':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  String _getSelectedPaymentLabel() {
    switch (_selectedPaymentMethod) {
      case 'card':
        return 'Credit Card';
      case 'paypal':
        return 'PayPal';
      case 'google_pay':
        return 'Google Pay';
      default:
        return 'Select Payment Method';
    }
  }
}
