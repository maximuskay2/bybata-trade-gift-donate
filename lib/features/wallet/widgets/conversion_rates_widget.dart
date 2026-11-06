import 'package:flutter/material.dart';
import '../services/wallet_api.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';

class ConversionRatesWidget extends StatefulWidget {
  final VoidCallback onViewAll;
  const ConversionRatesWidget({super.key, required this.onViewAll});

  @override
  State<ConversionRatesWidget> createState() => _ConversionRatesWidgetState();
}

class _ConversionRatesWidgetState extends State<ConversionRatesWidget> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rates = [];

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = await WalletApi.create();
      List<dynamic> items = await api.getPublicRates(activeOnly: true);
      if (items.isEmpty) {
        items = await api.getRates(forceRefresh: forceRefresh);
      }
      final mapped = items
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      setState(() {
        _rates = mapped.take(6).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load rates';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.swap_horiz, size: 18),
            const SizedBox(width: 8),
            Text(
              'Conversion Rates',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(onPressed: () => _loadRates(forceRefresh: true), icon: const Icon(Icons.refresh)),
            TextButton(
              onPressed: widget.onViewAll,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ..._rates.map((r) => _buildRateRow(r)).toList(),
        if (_rates.isEmpty && !_loading && _error == null)
          Text(
            'Quick snapshot of popular BYC conversion rates.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildRateRow(Map<String, dynamic> r) {
    final base = (r['base'] as String?) ?? 'BYC';
    final quote = (r['quote'] as String?) ?? 'USD';
    final raw = r['rate'];
    double rate = 0;
    if (raw is num) rate = raw.toDouble();
    if (raw is String) rate = double.tryParse(raw) ?? 0;
    final activeVal = r['active'];
    final active = activeVal == true || activeVal == 'true' || activeVal == 1;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$base → $quote',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? Colors.green : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                rate.toStringAsFixed(rate < 1 ? 6 : 2),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
