import 'package:flutter/material.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/wallet_api.dart';
import 'withdrawal_request_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({super.key});

  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = await WalletApi.create();
      final items = await api.getWithdrawals();
      if (!mounted) return;
      setState(() {
        _items = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.error(context, 'Failed to load withdrawals: $e');
    }
  }

  Future<void> _cancel(String id) async {
    try {
      final api = await WalletApi.create();
      await api.cancelWithdrawal(id, reason: 'Cancelled by user');
      if (mounted) {
        AppToast.info(context, 'Withdrawal cancelled');
      }
      await _load();
    } catch (e) {
      if (mounted) AppToast.error(context, 'Cancel failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await GuardedNavigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const WithdrawalRequestScreen()),
          );
          if (ok == true) {
            await _load();
          }
        },
        icon: const Icon(Icons.south_east),
        label: const Text('Request'),
      ),
      body: _loading
          ? const BybataLoader()
          : _items.isEmpty
              ? const Center(child: Text('No withdrawals yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final status = (item['status'] ?? '').toString();
                    final amount = item['amount']?.toString() ?? '0';
                    final currency = item['currency']?.toString() ?? 'BYC';
                    final createdAt = item['createdAt']?.toString() ?? '';
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$amount $currency',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text('Status: $status'),
                            if (createdAt.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Created: $createdAt', style: TextStyle(color: Colors.grey[600])),
                            ],
                            const SizedBox(height: 12),
                            if (status == 'PENDING')
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton(
                                  onPressed: () => _cancel(item['id'].toString()),
                                  child: const Text('Cancel'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
