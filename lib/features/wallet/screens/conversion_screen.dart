import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../services/wallet_service.dart';
import '../services/wallet_api.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';

class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  
  String _fromCurrency = 'BYC';
  String _toCurrency = 'USD';
  double _fromAmount = 0;
  double _toAmount = 0;
  bool _isFromToConversion = true;
  bool _ratesLoading = false;
  String? _ratesError;
  List<Map<String, dynamic>> _adminRates = [];
  
  // Mock conversion rates (in a real app, these would come from an API)
  final Map<String, double> _conversionRates = {
    'USD': 0.10, // 1 BYC = 0.10 USD
    'EUR': 0.09, // 1 BYC = 0.09 EUR
    'GBP': 0.08, // 1 BYC = 0.08 GBP
    'JPY': 14.50, // 1 BYC = 14.50 JPY
    'CAD': 0.14, // 1 BYC = 0.14 CAD
    'AUD': 0.15, // 1 BYC = 0.15 AUD
    'NGN': 160.0, // 1 BYC = 160 NGN
    'GHS': 1.20, // 1 BYC = 1.20 GHS
  };
  
  final List<Map<String, dynamic>> _popularCurrencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$', 'flag': '🇺🇸'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€', 'flag': '🇪🇺'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£', 'flag': '🇬🇧'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥', 'flag': '🇯🇵'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$', 'flag': '🇨🇦'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$', 'flag': '🇦🇺'},
    {'code': 'NGN', 'name': 'Nigerian Naira', 'symbol': '₦', 'flag': '🇳🇬'},
    {'code': 'GHS', 'name': 'Ghanaian Cedi', 'symbol': '₵', 'flag': '🇬🇭'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fromController.text = '1.00';
    _fromAmount = 1.0;
    _calculateConversion();
    _loadAdminRates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Currency Rates',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _refreshRates,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConverterTab(),
                _buildRatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        borderRadius: 12,
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary],
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Converter'),
            Tab(text: 'All Rates'),
          ],
        ),
      ),
    );
  }

  Widget _buildConverterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCurrentBalanceCard(),
          const SizedBox(height: 24),
          _buildConverterCard(),
          const SizedBox(height: 24),
          _buildQuickConversions(),
          const SizedBox(height: 24),
          _buildConversionHistory(),
        ],
      ),
    );
  }

  Widget _buildCurrentBalanceCard() {
    return Consumer<WalletService>(
      builder: (context, walletService, child) {
        final balanceModel = walletService.currentBalance;
        if (balanceModel == null) {
          return const SizedBox.shrink();
        }
        final balance = balanceModel.availableBalance;
        final usdValue = balance * _conversionRates['USD']!;
        
        return ShadowCard(
          shadowIntensity: ShadowIntensity.medium,
          borderRadius: 16,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.amber.shade600, Colors.orange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Current Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${balance.toStringAsFixed(2)} BYC',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '≈ \$${usdValue.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Live Rate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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

  Widget _buildConverterCard() {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.medium,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.swap_horiz,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Currency Converter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _swapCurrencies,
                  icon: const Icon(Icons.swap_vert),
                  iconSize: 20,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // From Currency
            _buildCurrencyInputField(
              label: 'From',
              controller: _fromController,
              currency: _fromCurrency,
              onCurrencyTap: () => _showCurrencyPicker(true),
              onChanged: (value) {
                setState(() {
                  _fromAmount = double.tryParse(value) ?? 0;
                  _calculateConversion();
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // To Currency
            _buildCurrencyInputField(
              label: 'To',
              controller: _toController,
              currency: _toCurrency,
              onCurrencyTap: () => _showCurrencyPicker(false),
              isReadOnly: true,
            ),
            
            const SizedBox(height: 20),
            
            // Conversion Rate Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '1 $_fromCurrency = ${_getConversionRate().toStringAsFixed(_fromCurrency == 'JPY' || _toCurrency == 'JPY' ? 0 : 4)} $_toCurrency',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyInputField({
    required String label,
    required TextEditingController controller,
    required String currency,
    required VoidCallback onCurrencyTap,
    Function(String)? onChanged,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Currency Selector
            GestureDetector(
              onTap: onCurrencyTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  color: Colors.grey[50],
                ),
                child: Row(
                  children: [
                    Text(
                      _getCurrencyFlag(currency),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currency,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            
            // Amount Input
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: isReadOnly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  filled: isReadOnly,
                  fillColor: isReadOnly ? Colors.grey[50] : Colors.white,
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isReadOnly ? Colors.grey[600] : Colors.black,
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickConversions() {
    final quickAmounts = [1.0, 10.0, 100.0, 1000.0];
    
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Conversions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickAmounts.map((amount) {
                final convertedAmount = _fromCurrency == 'BYC' 
                  ? amount * (_conversionRates[_toCurrency] ?? 1)
                  : amount / (_conversionRates[_fromCurrency] ?? 1);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _fromAmount = amount;
                      _fromController.text = amount.toStringAsFixed(amount == amount.toInt() ? 0 : 2);
                      _calculateConversion();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${amount.toStringAsFixed(amount == amount.toInt() ? 0 : 2)} $_fromCurrency',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${convertedAmount.toStringAsFixed(2)} $_toCurrency',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionHistory() {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Rate History (Last 24h)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated: ${_getLastUpdateTime()}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Mock chart placeholder
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chart Coming Soon',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildRatesHeader(),
        const SizedBox(height: 16),
        if (_ratesLoading)
          const BybataLoader(),
        if (_ratesError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_ratesError!, style: const TextStyle(color: Colors.red)),
          ),
        ..._adminRates.map((r) => _buildAdminRateCard(r)),
      ],
    );
  }

  Widget _buildRatesHeader() {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monetization_on,
                color: Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BYC Exchange Rates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Live rates updated every minute',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyRateCard(Map<String, dynamic> currency) {
    final rate = _conversionRates[currency['code']] ?? 0;
    final change = (rate * 0.02) - (rate * 0.01); // Mock change calculation
    final isPositive = change >= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Currency Flag and Code
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    currency['flag'],
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Currency Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency['code'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currency['name'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Rate and Change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${currency['symbol']}${rate.toStringAsFixed(rate < 1 ? 4 : 2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isPositive ? Colors.green : Colors.red,
                        size: 12,
                      ),
                      Text(
                        '${(change.abs() / rate * 100).toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminRateCard(Map<String, dynamic> r) {
    final base = (r['base'] as String?) ?? 'BYC';
    final quote = (r['quote'] as String?) ?? 'USD';
    final raw = r['rate'];
    double rate = 0;
    if (raw is num) rate = raw.toDouble();
    if (raw is String) rate = double.tryParse(raw) ?? 0;
    final activeVal = r['active'];
    final active = activeVal == true || activeVal == 'true' || activeVal == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Pair label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$base → $quote',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      active ? 'Active' : 'Inactive',
                      style: TextStyle(fontSize: 12, color: active ? Colors.green : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Text(
                rate.toStringAsFixed(rate < 1 ? 6 : 2),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _calculateConversion() {
    if (_fromAmount == 0) {
      _toAmount = 0;
    } else {
      if (_fromCurrency == 'BYC') {
        _toAmount = _fromAmount * (_conversionRates[_toCurrency] ?? 1);
      } else if (_toCurrency == 'BYC') {
        _toAmount = _fromAmount / (_conversionRates[_fromCurrency] ?? 1);
      } else {
        // Convert from one fiat currency to another via BYC
        final bycAmount = _fromAmount / (_conversionRates[_fromCurrency] ?? 1);
        _toAmount = bycAmount * (_conversionRates[_toCurrency] ?? 1);
      }
    }
    
    _toController.text = _toAmount.toStringAsFixed(_toCurrency == 'JPY' ? 0 : 2);
  }

  double _getConversionRate() {
    if (_fromCurrency == 'BYC') {
      return _conversionRates[_toCurrency] ?? 1;
    } else if (_toCurrency == 'BYC') {
      return 1 / (_conversionRates[_fromCurrency] ?? 1);
    } else {
      final fromRate = _conversionRates[_fromCurrency] ?? 1;
      final toRate = _conversionRates[_toCurrency] ?? 1;
      return toRate / fromRate;
    }
  }

  String _getCurrencyFlag(String currency) {
    final currencyData = _popularCurrencies.firstWhere(
      (c) => c['code'] == currency,
      orElse: () => {'flag': currency == 'BYC' ? '🪙' : '💱'},
    );
    return currencyData['flag'];
  }

  String _getLastUpdateTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _swapCurrencies() {
    setState(() {
      final tempCurrency = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tempCurrency;
      
      final tempAmount = _fromAmount;
      _fromAmount = _toAmount;
      _toAmount = tempAmount;
      
      _fromController.text = _fromAmount.toStringAsFixed(_fromCurrency == 'JPY' ? 0 : 2);
      _calculateConversion();
    });
  }

  void _showCurrencyPicker(bool isFromCurrency) {
    final currencies = ['BYC', ..._popularCurrencies.map((c) => c['code']).toList()];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Currency',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            
            ...currencies.map((currency) {
              final isSelected = isFromCurrency 
                ? currency == _fromCurrency 
                : currency == _toCurrency;
              
              final currencyData = currency == 'BYC' 
                ? {'name': 'bYbata Coin', 'flag': '🪙'}
                : _popularCurrencies.firstWhere((c) => c['code'] == currency);
              
              return ListTile(
                leading: Text(
                  currencyData['flag'],
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  currency,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(currencyData['name']),
                trailing: isSelected 
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
                onTap: () {
                  setState(() {
                    if (isFromCurrency) {
                      _fromCurrency = currency;
                    } else {
                      _toCurrency = currency;
                    }
                    _calculateConversion();
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _refreshRates() {
    _loadAdminRates(forceRefresh: true);
    AppToast.info(context, 'Refreshing rates');
  }

  Future<void> _loadAdminRates({bool forceRefresh = false}) async {
    setState(() { _ratesLoading = true; _ratesError = null; });
    try {
      final api = await WalletApi.create();
      List<dynamic> items = await api.getPublicRates(activeOnly: false);
      if (items.isEmpty) {
        items = await api.getRates(forceRefresh: forceRefresh);
      }
      final mapped = items.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).toList();
      setState(() { _adminRates = mapped; _ratesLoading = false; });
    } catch (e) {
      setState(() { _ratesError = 'Failed to load rates'; _ratesLoading = false; });
    }
  }
}
