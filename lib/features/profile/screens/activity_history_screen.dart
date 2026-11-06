import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/utils/network_error_message.dart';
import '../models/activity.dart';
import '../services/activity_api_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Activity> _activities = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _typeQuery {
    switch (_tabController.index) {
      case 1:
        return 'trade';
      case 2:
        return 'gift';
      case 3:
        return 'community';
      case 4:
        return 'karma';
      default:
        return null;
    }
  }

  Future<void> _loadActivities({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) {
        setState(() {
          _activities = [];
          _isLoading = false;
          _error = 'Sign in to see your activity.';
        });
        return;
      }

      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ActivityApiService(
        ApiClient(baseUrl, const FlutterSecureStorage()),
      );
      final data = await api.getUserActivity(
        page: 1,
        size: 50,
        type: _typeQuery,
        forceRefresh: forceRefresh,
      );
      final items = (data['items'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _activities = api.parseActivities(items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = NetworkErrorMessage.from(
          e,
          fallback: 'Couldn\'t load activity. Please try again.',
        );
        _activities = [];
      });
    }
  }

  List<Activity> get _filteredActivities {
    if (_searchQuery.isEmpty) return _activities;
    final q = _searchQuery.toLowerCase();
    return _activities.where((activity) {
      return activity.title.toLowerCase().contains(q) ||
          activity.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (_) => _loadActivities(),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Trades'),
            Tab(text: 'Gifts'),
            Tab(text: 'Community'),
            Tab(text: 'Karma'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: BorderlessInputDecoration.search(
                hintText: 'Search activity',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: BybataLoader());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _loadActivities(forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredActivities;
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadActivities(forceRefresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No activity yet')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadActivities(forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final activity = items[index];
          return ShadowCard(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(
                  _iconFor(activity.type),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                activity.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(activity.description),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    activity.statusDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (activity.karmaPoints != null && activity.karmaPoints! > 0)
                    Text(
                      '+${activity.karmaPoints} karma',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              onTap: () {
                AppToast.show(
                  context,
                  '${activity.typeDisplayName} · ${_formatTime(activity.createdAt)}',
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(ActivityType type) {
    switch (type) {
      case ActivityType.trade:
        return Icons.swap_horiz;
      case ActivityType.gift:
        return Icons.card_giftcard;
      case ActivityType.donation:
        return Icons.volunteer_activism;
      case ActivityType.community:
        return Icons.groups_outlined;
      case ActivityType.achievement:
        return Icons.emoji_events_outlined;
      case ActivityType.karma:
        return Icons.star_outline;
      case ActivityType.verification:
        return Icons.verified_outlined;
      default:
        return Icons.history;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
