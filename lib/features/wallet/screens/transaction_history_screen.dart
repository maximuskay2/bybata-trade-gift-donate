import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/theme/shadow_styles.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';
import '../services/transaction_export_service.dart';
import '../services/wallet_api.dart';
import '../../../core/services/receipt_download_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  
  TransactionType? _selectedType;
  TransactionStatus? _selectedStatus;
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTransactions());
  }

  Future<void> _refreshTransactions() async {
    if (!mounted) return;
    final walletService = Provider.of<WalletService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId != null && walletService.currentBalance == null) {
      await walletService.initializeWallet(userId);
    } else {
      await walletService.refreshTransactions();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transaction History',
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
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: _exportTransactions,
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: Consumer<WalletService>(
        builder: (context, walletService, _) {
          if (walletService.error != null && walletService.allTransactions.isEmpty) {
            return _buildErrorState(walletService.error!);
          }
          return RefreshIndicator(
            onRefresh: _refreshTransactions,
            child: Column(
              children: [
                _buildSearchAndFilters(),
                _buildTabBar(),
                Expanded(
                  child: walletService.isLoading && walletService.allTransactions.isEmpty
                      ? const BybataLoader()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAllTransactions(),
                            _buildTransactionsByType(TransactionType.fund),
                            _buildTransactionsByType(TransactionType.send),
                            _buildTransactionsByType(TransactionType.receive),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          ShadowCard(
            shadowIntensity: ShadowIntensity.light,
            borderRadius: 12,
            child: TextField(
              controller: _searchController,
              decoration: BorderlessInputDecoration.search(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Active Filters
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 12),
            _buildActiveFiltersRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Funded'),
            Tab(text: 'Sent'),
            Tab(text: 'Received'),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTransactions() {
    return Consumer<WalletService>(
      builder: (context, walletService, child) {
        final transactions = _getFilteredTransactions(walletService.allTransactions);
        
        if (transactions.isEmpty) {
          return _buildEmptyState('No transactions found');
        }
        
        return _buildTransactionsList(transactions);
      },
    );
  }

  Widget _buildTransactionsByType(TransactionType type) {
    return Consumer<WalletService>(
      builder: (context, walletService, child) {
        final transactions = _getFilteredTransactions(
          walletService.allTransactions.where((t) => t.type == type).toList()
        );
        
        if (transactions.isEmpty) {
          return _buildEmptyState('No ${type.name} transactions found');
        }
        
        return _buildTransactionsList(transactions);
      },
    );
  }

  Widget _buildTransactionsList(List<WalletTransaction> transactions) {
    // Group transactions by date
    final groupedTransactions = _groupTransactionsByDate(transactions);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedTransactions.length,
      itemBuilder: (context, index) {
        final dateEntry = groupedTransactions.entries.elementAt(index);
        final date = dateEntry.key;
        final dayTransactions = dateEntry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text(
                _formatDateHeader(date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            
            // Transactions for this date
            ...dayTransactions.map((transaction) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTransactionCard(transaction),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(WalletTransaction transaction) {
    return GestureDetector(
      onTap: () => _showTransactionDetails(transaction),
      child: ShadowCard(
        shadowIntensity: ShadowIntensity.light,
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Transaction Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: transaction.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  transaction.typeIcon,
                  color: transaction.statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Transaction Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatTime(transaction.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (transaction.recipientName != null || transaction.senderName != null) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            transaction.recipientName ?? transaction.senderName ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (transaction.transactionHash != null)
                      Text(
                        'ID: ${transaction.transactionHash!.substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
              
              // Amount and Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.isOutgoing ? '-' : '+'}${transaction.amount.toStringAsFixed(2)} BYC',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: transaction.isOutgoing ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: transaction.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(transaction.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: transaction.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _refreshTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow() {
    final List<Widget> filterChips = [];
    
    if (_selectedType != null) {
      filterChips.add(_buildFilterChip(
        '${_selectedType!.name.toUpperCase()} only',
        () => setState(() => _selectedType = null),
      ));
    }
    
    if (_selectedStatus != null) {
      filterChips.add(_buildFilterChip(
        _getStatusText(_selectedStatus!),
        () => setState(() => _selectedStatus = null),
      ));
    }
    
    if (_selectedDateRange != null) {
      filterChips.add(_buildFilterChip(
        'Date Range',
        () => setState(() => _selectedDateRange = null),
      ));
    }
    
    return Wrap(
      spacing: 8,
      children: [
        ...filterChips,
        TextButton(
          onPressed: _clearAllFilters,
          child: const Text('Clear All'),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
    );
  }

  List<WalletTransaction> _getFilteredTransactions(List<WalletTransaction> transactions) {
    var filtered = transactions;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        return t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (t.recipientName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (t.senderName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (t.transactionHash?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }
    
    // Apply type filter
    if (_selectedType != null) {
      filtered = filtered.where((t) => t.type == _selectedType).toList();
    }
    
    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((t) => t.status == _selectedStatus).toList();
    }
    
    // Apply date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((t) {
        return t.timestamp.isAfter(_selectedDateRange!.start) &&
               t.timestamp.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    
    // Sort by timestamp (newest first)
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return filtered;
  }

  Map<DateTime, List<WalletTransaction>> _groupTransactionsByDate(List<WalletTransaction> transactions) {
    final grouped = <DateTime, List<WalletTransaction>>{};
    
    for (final transaction in transactions) {
      final date = DateTime(
        transaction.timestamp.year,
        transaction.timestamp.month,
        transaction.timestamp.day,
      );
      
      grouped.putIfAbsent(date, () => []).add(transaction);
    }
    
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  bool _hasActiveFilters() {
    return _selectedType != null || _selectedStatus != null || _selectedDateRange != null;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedType = null;
      _selectedStatus = null;
      _selectedDateRange = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        selectedType: _selectedType,
        selectedStatus: _selectedStatus,
        selectedDateRange: _selectedDateRange,
        onFiltersApplied: (type, status, dateRange) {
          setState(() {
            _selectedType = type;
            _selectedStatus = status;
            _selectedDateRange = dateRange;
          });
        },
      ),
    );
  }

  void _showTransactionDetails(WalletTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TransactionDetailsSheet(transaction: transaction),
    );
  }

  void _exportTransactions() async {
    final walletService = Provider.of<WalletService>(context, listen: false);
    final transactions = walletService.allTransactions;
    
    if (transactions.isEmpty) {
      AppToast.show(context, 'No transactions to export');
      return;
    }

    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              subtitle: const Text('Comma-separated values'),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              subtitle: const Text('JavaScript Object Notation'),
              onTap: () => Navigator.pop(context, 'json'),
            ),
          ],
        ),
      ),
    );

    if (format == null) return;

    try {
      String content;
      String filename;
      
      if (format == 'csv') {
        content = await TransactionExportService.exportToCSV(transactions);
        filename = 'bybata_transactions_${DateTime.now().millisecondsSinceEpoch}.csv';
      } else {
        content = await TransactionExportService.exportToJSON(transactions);
        filename = 'bybata_transactions_${DateTime.now().millisecondsSinceEpoch}.json';
      }

      final file = await TransactionExportService.saveToFile(content, filename);
      
      if (mounted) {
        AppToast.show(context, 'Exported to $filename');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Export failed: $e');
      }
    }
  }
}

// Filter Bottom Sheet Widget
class _FilterBottomSheet extends StatefulWidget {
  final TransactionType? selectedType;
  final TransactionStatus? selectedStatus;
  final DateTimeRange? selectedDateRange;
  final Function(TransactionType?, TransactionStatus?, DateTimeRange?) onFiltersApplied;

  const _FilterBottomSheet({
    required this.selectedType,
    required this.selectedStatus,
    required this.selectedDateRange,
    required this.onFiltersApplied,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  TransactionType? _selectedType;
  TransactionStatus? _selectedStatus;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
    _selectedStatus = widget.selectedStatus;
    _selectedDateRange = widget.selectedDateRange;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Filter Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transaction Type Filter
                      const Text(
                        'Transaction Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...TransactionType.values.map((type) =>
                        CheckboxListTile(
                          title: Text(type.name.toUpperCase()),
                          value: _selectedType == type,
                          onChanged: (selected) {
                            setState(() {
                              _selectedType = selected! ? type : null;
                            });
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Transaction Status Filter
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...TransactionStatus.values.map((status) =>
                        CheckboxListTile(
                          title: Text(_getStatusText(status)),
                          value: _selectedStatus == status,
                          onChanged: (selected) {
                            setState(() {
                              _selectedStatus = selected! ? status : null;
                            });
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Date Range Filter
                      const Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(_selectedDateRange != null
                          ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                          : 'Select Date Range'
                        ),
                        trailing: const Icon(Icons.date_range),
                        onTap: _selectDateRange,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Apply Button
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onFiltersApplied(_selectedType, _selectedStatus, _selectedDateRange);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedStatus = null;
      _selectedDateRange = null;
    });
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }
}

// Transaction Details Bottom Sheet
class _TransactionDetailsSheet extends StatefulWidget {
  final WalletTransaction transaction;

  const _TransactionDetailsSheet({required this.transaction});

  @override
  State<_TransactionDetailsSheet> createState() => _TransactionDetailsSheetState();
}

class _TransactionDetailsSheetState extends State<_TransactionDetailsSheet> {
  Map<String, double>? _conversionRates;
  bool _loadingRates = false;
  bool _downloadingReceipt = false;

  @override
  void initState() {
    super.initState();
    _loadConversionRates();
  }

  Future<void> _loadConversionRates() async {
    setState(() {
      _loadingRates = true;
    });

    try {
      final api = await WalletApi.create();
      final rates = await api.getPublicRates(activeOnly: true);
      
      final rateMap = <String, double>{};
      for (final rate in rates) {
        final quote = rate['quote'] as String?;
        final rateValue = rate['rate'];
        if (quote != null && rateValue != null) {
          if (rateValue is num) {
            rateMap[quote] = rateValue.toDouble();
          } else if (rateValue is String) {
            rateMap[quote] = double.tryParse(rateValue) ?? 0.0;
          }
        }
      }

      setState(() {
        _conversionRates = rateMap;
        _loadingRates = false;
      });
    } catch (e) {
      setState(() {
        _loadingRates = false;
      });
    }
  }

  String _getFiatEquivalent(String currency, double bycAmount) {
    if (_conversionRates == null) return 'Loading...';
    final rate = _conversionRates![currency];
    if (rate == null) return 'N/A';
    final equivalent = bycAmount * rate;
    return '${equivalent.toStringAsFixed(2)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.8,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.transaction.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.transaction.typeIcon,
                      color: widget.transaction.statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.transaction.description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.transaction.isOutgoing ? '-' : '+'}${widget.transaction.amount.toStringAsFixed(2)} BYC',
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.transaction.isOutgoing ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      _buildDetailRow('Status', _getStatusText(widget.transaction.status)),
                      _buildDetailRow('Date & Time', _formatDateTime(widget.transaction.timestamp)),
                      if (widget.transaction.recipientName != null)
                        _buildDetailRow('Recipient', widget.transaction.recipientName!),
                      if (widget.transaction.senderName != null)
                        _buildDetailRow('Sender', widget.transaction.senderName!),
                      if (widget.transaction.fee > 0) ...[
                        _buildDetailRow('Fee', '${widget.transaction.fee.toStringAsFixed(2)} BYC'),
                        if (_conversionRates != null)
                          _buildDetailRow('Fee (USD)', _getFiatEquivalent('USD', widget.transaction.fee)),
                      ],
                      if (widget.transaction.transactionHash != null)
                        _buildDetailRow('Transaction ID', widget.transaction.transactionHash!),
                      if (widget.transaction.note?.isNotEmpty == true)
                        _buildDetailRow('Note', widget.transaction.note!),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _downloadingReceipt ? null : _downloadReceipt,
                          icon: _downloadingReceipt
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(
                            _downloadingReceipt ? 'Preparing PDF...' : 'Download receipt',
                          ),
                        ),
                      ),
                      
                      // Conversion Rates Section
                      if (_conversionRates != null && _conversionRates!.isNotEmpty) ...[
                        const Divider(height: 32),
                        const Text(
                          'Fiat Equivalents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...['USD', 'EUR', 'GBP', 'NGN'].where((currency) => 
                          _conversionRates!.containsKey(currency)
                        ).map((currency) => 
                          _buildDetailRow(
                            currency,
                            _getFiatEquivalent(currency, widget.transaction.amount),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }

  String _formatDateTime(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadReceipt() async {
    setState(() => _downloadingReceipt = true);
    try {
      final api = await WalletApi.create();
      await ReceiptDownloadService.downloadAndShare(
        dio: api.dio,
        path: '/v1/wallet/transactions/${widget.transaction.id}/receipt.pdf',
        fallbackFilename: 'bybata-transaction-${widget.transaction.id}.pdf',
        shareSubject: widget.transaction.description,
        context: context,
      );
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Could not download receipt');
      }
    } finally {
      if (mounted) setState(() => _downloadingReceipt = false);
    }
  }
}
