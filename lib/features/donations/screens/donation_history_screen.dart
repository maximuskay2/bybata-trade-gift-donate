import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/graceful_errors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/receipt_download_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/donation_models.dart';
import '../providers/campaign_provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedFilter = 'All';
  String _selectedSort = 'Recent';
  DateTimeRange? _selectedDateRange;
  int _currentTabIndex = 0;

  final List<String> _filterOptions = ['All', 'Completed', 'Pending', 'Refunded'];
  final List<String> _sortOptions = [
    'Recent',
    'Amount (High)',
    'Amount (Low)',
    'Oldest',
  ];

  List<CampaignDonation> _allDonations = [];
  List<CampaignDonation> _filteredDonations = [];
  List<Map<String, dynamic>> _receipts = [];
  bool _isInitialLoading = false;
  bool _isDownloadingReceipt = false;
  String? _downloadingReceiptId;

  double _totalDonated = 0;
  int _campaignsSupported = 0;
  int _totalKarma = 0;
  double _averageDonation = 0;
  int _thisMonthCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _refreshFilteredList() {
    setState(() {
      _filteredDonations = _applyFilters(_allDonations);
    });
  }

  Widget _build3DContainer({
    required Widget child,
    Color color = Colors.white,
    double radius = 20,
    EdgeInsets? padding,
    Gradient? gradient,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            offset: const Offset(-5, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildRecessedPanel({required Widget child, Color color = const Color(0xFFEFF2F7)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
      ),
      child: child,
    );
  }

  Widget _buildTactileButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: _build3DContainer(
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;

    return PopScope(
      canPop: Navigator.canPop(context),
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          'Donation History',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: _build3DContainer(
              radius: 12,
              child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildStatsOverview(primaryColor),
                            const SizedBox(height: 20),
                            _buildFiltersSection(primaryColor),
                            const SizedBox(height: 20),
                            _buildFluidTabSwitcher(primaryColor),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDonationHistoryTab(),
                      _buildReceiptHistoryTab(),
                    ],
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

  Future<void> _loadHistory() async {
    final campaignProvider =
        Provider.of<CampaignProvider>(context, listen: false);

    setState(() => _isInitialLoading = true);

    try {
      if (campaignProvider.donationHistory.isEmpty && !campaignProvider.isLoading) {
        await campaignProvider.loadDonationHistory(force: true);
      }

      final items = campaignProvider.donationHistory.toList();
      _recomputeStats(items);

      if (mounted) {
        setState(() {
          _allDonations = items;
          _filteredDonations = _applyFilters(items);
          _receipts = _buildReceiptsFromDonations(items);
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not load donation history');
      }
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _refreshHistory() async {
    final campaignProvider =
        Provider.of<CampaignProvider>(context, listen: false);

    try {
      await campaignProvider.loadDonationHistory(force: true);
      final items = campaignProvider.donationHistory.toList();
      _recomputeStats(items);

      if (mounted) {
        setState(() {
          _allDonations = items;
          _filteredDonations = _applyFilters(items);
          _receipts = _buildReceiptsFromDonations(items);
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not refresh history');
      }
    }
  }

  List<CampaignDonation> _applyFilters(List<CampaignDonation> donations) {
    var result = List<CampaignDonation>.from(donations);

    if (_selectedFilter != 'All') {
      result = result.where((d) {
        switch (_selectedFilter) {
          case 'Completed':
            return d.status == DonationStatus.completed;
          case 'Pending':
            return d.status == DonationStatus.pending;
          case 'Refunded':
            return d.status == DonationStatus.refunded;
          default:
            return true;
        }
      }).toList();
    }

    if (_selectedDateRange != null) {
      result = result.where((d) {
        return d.donatedAt.isAfter(_selectedDateRange!.start) &&
            d.donatedAt.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    switch (_selectedSort) {
      case 'Recent':
        result.sort((a, b) => b.donatedAt.compareTo(a.donatedAt));
        break;
      case 'Amount (High)':
        result.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Amount (Low)':
        result.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'Oldest':
        result.sort((a, b) => a.donatedAt.compareTo(b.donatedAt));
        break;
    }

    return result;
  }

  List<Map<String, dynamic>> _buildReceiptsFromDonations(
    List<CampaignDonation> donations,
  ) {
    if (donations.isEmpty) return [];

    final Map<int, List<CampaignDonation>> byYear = {};
    for (final d in donations) {
      byYear.putIfAbsent(d.donatedAt.year, () => []).add(d);
    }

    final receipts = <Map<String, dynamic>>[];
    final entries = byYear.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    for (final entry in entries) {
      final year = entry.key;
      final yearDonations = entry.value;
      final total = yearDonations.fold<double>(0, (sum, d) => sum + d.amount);
      receipts.add({
        'id': 'R$year',
        'taxYear': year.toString(),
        'totalAmount': total.toStringAsFixed(2),
        'donationCount': yearDonations.length,
      });
    }

    return receipts;
  }

  void _recomputeStats(List<CampaignDonation> donations) {
    if (donations.isEmpty) {
      _totalDonated = 0;
      _campaignsSupported = 0;
      _totalKarma = 0;
      _averageDonation = 0;
      _thisMonthCount = 0;
      return;
    }

    final total = donations.fold<double>(0, (sum, d) => sum + d.amount);
    final campaigns = donations.map((d) => d.campaignId).toSet().length;
    final karma = donations.fold<int>(0, (sum, d) => sum + d.karmaAwarded);
    final count = donations.length;
    final now = DateTime.now();
    final thisMonth = donations
        .where(
          (d) => d.donatedAt.year == now.year && d.donatedAt.month == now.month,
        )
        .length;

    _totalDonated = total;
    _campaignsSupported = campaigns;
    _totalKarma = karma;
    _averageDonation = count > 0 ? total / count : 0.0;
    _thisMonthCount = thisMonth;
  }

  Widget _buildStatsOverview(Color primaryColor) {
    return _build3DContainer(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, primaryColor.withValues(alpha: 0.05)],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your giving summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem(
                '${_totalDonated.toStringAsFixed(0)} BYC',
                'Total Donated',
                Icons.volunteer_activism,
                Colors.green,
              ),
              _buildVerticalDivider(),
              _buildStatItem(
                '$_campaignsSupported',
                'Campaigns',
                Icons.campaign,
                AppColors.primary,
              ),
              _buildVerticalDivider(),
              _buildStatItem(
                '$_totalKarma',
                'KARMA',
                Icons.star,
                Colors.orange,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'Avg: ${_averageDonation.toStringAsFixed(0)} BYC',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text('•', style: TextStyle(color: Colors.grey[400])),
              Text(
                'This month: $_thisMonthCount',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(Color primaryColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildTactileButton(
            onTap: _showFilterOptions,
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(_selectedFilter, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildTactileButton(
            onTap: _showSortOptions,
            child: Row(
              children: [
                Icon(Icons.sort, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(_selectedSort, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildTactileButton(
            onTap: _showDateRangePicker,
            child: Icon(
              Icons.date_range,
              size: 18,
              color: _selectedDateRange != null ? primaryColor : Colors.grey[700],
            ),
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(width: 8),
            _buildTactileButton(
              onTap: () {
                setState(() => _selectedDateRange = null);
                _refreshFilteredList();
              },
              child: Icon(Icons.close, size: 16, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFluidTabSwitcher(Color primaryColor) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            alignment: Alignment(_currentTabIndex == 0 ? -1.0 : 1.0, 0),
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _currentTabIndex = 0);
                    _tabController.animateTo(0);
                  },
                  child: Center(
                    child: Text(
                      'Donations',
                      style: TextStyle(
                        fontWeight:
                            _currentTabIndex == 0 ? FontWeight.w900 : FontWeight.w600,
                        color: _currentTabIndex == 0 ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _currentTabIndex = 1);
                    _tabController.animateTo(1);
                  },
                  child: Center(
                    child: Text(
                      'Receipts',
                      style: TextStyle(
                        fontWeight:
                            _currentTabIndex == 1 ? FontWeight.w900 : FontWeight.w600,
                        color: _currentTabIndex == 1 ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonationHistoryTab() {
    if (_isInitialLoading && _filteredDonations.isEmpty) {
      return const BybataLoader();
    }

    if (_filteredDonations.isEmpty) {
      return _buildEmptyState(
        'No donations found',
        'Adjust filters or make a donation.',
        Icons.volunteer_activism,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _filteredDonations.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildDonationCard(_filteredDonations[index]),
        ),
      ),
    );
  }

  Widget _buildReceiptHistoryTab() {
    if (_isInitialLoading && _receipts.isEmpty) {
      return const BybataLoader();
    }

    if (_receipts.isEmpty) {
      return _buildEmptyState(
        'No receipts yet',
        'Completed donations generate yearly summary receipts.',
        Icons.receipt_long,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _receipts.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildReceiptCard(_receipts[index]),
        ),
      ),
    );
  }

  Widget _buildDonationCard(CampaignDonation donation) {
    return _build3DContainer(
      child: InkWell(
        onTap: () => _openCampaign(donation),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusColor(donation.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getDonationIcon(donation.status),
                      color: _statusColor(donation.status),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          donation.campaign.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatDate(donation.donatedAt),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  _buildRecessedPanel(
                    color: _statusColor(donation.status).withValues(alpha: 0.1),
                    child: Text(
                      donation.status.name.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(donation.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${donation.amount.toStringAsFixed(2)} BYC',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.green,
                    ),
                  ),
                  if (donation.karmaAwarded > 0)
                    Text(
                      '+${donation.karmaAwarded} KARMA',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              if (donation.message?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    donation.message!,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
              if (donation.status == DonationStatus.completed) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _isDownloadingReceipt
                            ? null
                            : () => _downloadDonationReceipt(donation),
                        child: _build3DContainer(
                          radius: 12,
                          color: Colors.grey[50]!,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_downloadingReceiptId == donation.id)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                const Icon(Icons.picture_as_pdf_outlined, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _downloadingReceiptId == donation.id
                                    ? 'Preparing...'
                                    : 'Download receipt',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _shareDonation(donation),
                      child: _build3DContainer(
                        radius: 12,
                        color: Colors.grey[50]!,
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.share, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final year = receipt['taxYear']?.toString() ?? '';
    final count = receipt['donationCount'] as int? ?? 0;

    return _build3DContainer(
      child: InkWell(
        onTap: () => _downloadYearlyReceipt(receipt),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax year $year',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$count donation${count == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${receipt['totalAmount']} BYC total',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.download_rounded, color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String desc, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DonationStatus status) {
    switch (status) {
      case DonationStatus.completed:
        return Colors.green;
      case DonationStatus.pending:
        return Colors.orange;
      case DonationStatus.refunded:
        return AppColors.primary;
      case DonationStatus.failed:
        return Colors.red;
    }
  }

  IconData _getDonationIcon(DonationStatus status) {
    switch (status) {
      case DonationStatus.completed:
        return Icons.check_circle;
      case DonationStatus.pending:
        return Icons.schedule;
      case DonationStatus.refunded:
        return Icons.refresh;
      case DonationStatus.failed:
        return Icons.error;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    }
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    return '${difference.inMinutes}m ago';
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._filterOptions.map(
              (filter) => ListTile(
                title: Text(filter),
                trailing: _selectedFilter == filter
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  _refreshFilteredList();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort by',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._sortOptions.map(
              (sort) => ListTile(
                title: Text(sort),
                trailing: _selectedSort == sort
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedSort = sort);
                  _refreshFilteredList();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _refreshFilteredList();
    }
  }

  void _openCampaign(CampaignDonation donation) {
    AppRoutes.navigateToCampaignDetailsById(context, donation.campaignId);
  }

  Future<void> _downloadDonationReceipt(CampaignDonation donation) async {
    await _downloadDonationReceiptPdf(
      donationId: donation.id,
      subject: 'Donation receipt — ${donation.campaign.title}',
    );
  }

  void _shareDonation(CampaignDonation donation) {
    ShareUtils.shareDonation(
      context,
      campaignId: donation.campaignId,
      campaignTitle: donation.campaign.title,
      amount: donation.amount,
    );
  }

  Future<void> _downloadYearlyReceipt(Map<String, dynamic> receipt) async {
    final year = int.tryParse(receipt['taxYear']?.toString() ?? '') ??
        DateTime.now().year;
    await _downloadYearlyReceiptPdf(year: year);
  }

  Future<void> _downloadDonationReceiptPdf({
    required String donationId,
    String? subject,
  }) async {
    if (_isDownloadingReceipt) return;
    setState(() {
      _isDownloadingReceipt = true;
      _downloadingReceiptId = donationId;
    });
    try {
      final provider = Provider.of<CampaignProvider>(context, listen: false);
      await ReceiptDownloadService.downloadAndShare(
        dio: provider.apiClient.dio,
        path: '/v1/campaigns/donations/$donationId/receipt.pdf',
        fallbackFilename: 'bybata-donation-$donationId.pdf',
        shareSubject: subject,
        context: context,
      );
    } on DioException catch (e) {
      if (mounted) {
        final msg = _receiptErrorMessage(e);
        AppToast.error(context, msg);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not download receipt');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingReceipt = false;
          _downloadingReceiptId = null;
        });
      }
    }
  }

  Future<void> _downloadYearlyReceiptPdf({required int year}) async {
    if (_isDownloadingReceipt) return;
    setState(() => _isDownloadingReceipt = true);
    try {
      final provider = Provider.of<CampaignProvider>(context, listen: false);
      await ReceiptDownloadService.downloadAndShare(
        dio: provider.apiClient.dio,
        path: '/v1/campaigns/donation-receipts/$year.pdf',
        fallbackFilename: 'bybata-donations-$year.pdf',
        shareSubject: 'Donation summary $year',
        context: context,
      );
    } on DioException catch (e) {
      if (mounted) {
        AppToast.error(context, _receiptErrorMessage(e));
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not download receipt');
      }
    } finally {
      if (mounted) setState(() => _isDownloadingReceipt = false);
    }
  }

  String _receiptErrorMessage(DioException e) {
    return GracefulErrors.userMessage(e);
  }
}
