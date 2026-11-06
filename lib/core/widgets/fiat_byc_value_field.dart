import 'package:flutter/material.dart';

import '../constants/currency_constants.dart';
import '../services/user_currency_service.dart';
import '../../features/wallet/services/wallet_api.dart';

/// Estimated value input: user enters fiat; stored value is BYC (ledger).
class FiatBycValueField extends StatefulWidget {
  final TextEditingController bycController;
  final String fiatCurrency;
  final bool isDark;
  final Color? primaryColor;
  final String label;
  final String? helperText;

  const FiatBycValueField({
    super.key,
    required this.bycController,
    required this.fiatCurrency,
    this.isDark = false,
    this.primaryColor,
    this.label = 'Estimated value',
    this.helperText,
  });

  @override
  State<FiatBycValueField> createState() => _FiatBycValueFieldState();
}

class _FiatBycValueFieldState extends State<FiatBycValueField> {
  final _fiatController = TextEditingController();
  double? _bycPerFiat;
  bool _loadingRates = true;

  @override
  void initState() {
    super.initState();
    _fiatController.addListener(_onFiatChanged);
    _loadRates();
    _seedFromBycController();
  }

  @override
  void didUpdateWidget(covariant FiatBycValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fiatCurrency != widget.fiatCurrency) {
      _loadRates();
    }
  }

  void _seedFromBycController() {
    final byc = double.tryParse(widget.bycController.text.trim());
    if (byc != null && byc > 0 && _bycPerFiat != null && _bycPerFiat! > 0) {
      _fiatController.text = (byc / _bycPerFiat!).toStringAsFixed(2);
    }
  }

  Future<void> _loadRates() async {
    setState(() => _loadingRates = true);
    try {
      final api = await WalletApi.create();
      final items = await api.getRates();
      final quote = widget.fiatCurrency.toUpperCase();
      for (final raw in items) {
        if (raw is! Map) continue;
        final base = (raw['base'] as String?)?.toUpperCase() ?? 'BYC';
        final q = (raw['quote'] as String?)?.toUpperCase() ?? '';
        if (base != 'BYC' || q != quote) continue;
        final rateRaw = raw['rate'];
        final rate = rateRaw is num
            ? rateRaw.toDouble()
            : double.tryParse(rateRaw?.toString() ?? '') ?? 0;
        if (rate > 0) {
          _bycPerFiat = rate;
          break;
        }
      }
      _seedFromBycController();
    } catch (_) {
      _bycPerFiat = null;
    } finally {
      if (mounted) setState(() => _loadingRates = false);
    }
  }

  void _onFiatChanged() {
    final fiat = double.tryParse(_fiatController.text.trim());
    if (fiat == null || fiat <= 0 || _bycPerFiat == null || _bycPerFiat! <= 0) {
      widget.bycController.text = '';
      return;
    }
    final byc = fiat * _bycPerFiat!;
    widget.bycController.text = byc.toStringAsFixed(2);
    setState(() {});
  }

  @override
  void dispose() {
    _fiatController.removeListener(_onFiatChanged);
    _fiatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = CurrencyConstants.symbolFor(widget.fiatCurrency);
    final bycText = widget.bycController.text.trim();
    final byc = double.tryParse(bycText);
    final subtitle = _loadingRates
        ? 'Loading rates…'
        : byc != null && byc > 0
            ? '≈ ${byc.toStringAsFixed(2)} BYC stored on listing'
            : 'Optional — helps others compare value';

    final isDark = widget.isDark;
    final primary = widget.primaryColor ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.label} ($symbol ${widget.fiatCurrency})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _fiatController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: Icon(Icons.payments_outlined, color: primary),
            prefixText: '$symbol ',
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.helperText ?? subtitle,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
        ),
      ],
    );
  }
}

/// Convenience builder using [UserCurrencyService].
class UserFiatBycValueField extends StatelessWidget {
  final TextEditingController bycController;
  final bool isDark;
  final Color? primaryColor;

  const UserFiatBycValueField({
    super.key,
    required this.bycController,
    this.isDark = false,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserCurrencyService.instance,
      builder: (context, _) {
        return FiatBycValueField(
          bycController: bycController,
          fiatCurrency: UserCurrencyService.instance.preferredFiatCurrency,
          isDark: isDark,
          primaryColor: primaryColor,
        );
      },
    );
  }
}
