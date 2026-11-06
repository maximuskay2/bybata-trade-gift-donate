import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../trade/screens/trade_details_loader.dart';
import '../../gifting/screens/gift_details_loader.dart';
import '../../donations/screens/campaign_details_loader.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

enum UserItemsType { trades, gifts, campaigns }

class UserItemsListScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final UserItemsType type;

  const UserItemsListScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.type,
  });

  @override
  State<UserItemsListScreen> createState() => _UserItemsListScreenState();
}

class _UserItemsListScreenState extends State<UserItemsListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  String get _title {
    switch (widget.type) {
      case UserItemsType.trades:
        return '${widget.userName}\'s Trades';
      case UserItemsType.gifts:
        return '${widget.userName}\'s Gifts';
      case UserItemsType.campaigns:
        return '${widget.userName}\'s Donations';
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _items = [];
        _hasMore = true;
      });
    }
    if (!_hasMore && !refresh) return;

    setState(() => _isLoading = true);
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final storage = const FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);

      String path;
      Map<String, dynamic> queryParams = {
        'page': _page,
        'size': _pageSize,
      };

      switch (widget.type) {
        case UserItemsType.trades:
          path = '/v1/trades';
          queryParams['ownerId'] = widget.userId;
          break;
        case UserItemsType.gifts:
          path = '/v1/gifts';
          queryParams['giverId'] = widget.userId;
          break;
        case UserItemsType.campaigns:
          path = '/v1/campaigns';
          queryParams['founderId'] = widget.userId;
          break;
      }

      final response = await apiClient.get(path, queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      final rawItems = (data['items'] as List?) ?? [];

      final List<Map<String, dynamic>> mapped = [];
      for (final item in rawItems) {
        final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
        final id = map['id']?.toString() ?? '';
        final title = map['title']?.toString() ?? 'Untitled';
        final status = map['status']?.toString() ?? '';
        final category = map['category']?.toString() ?? 'OTHERS';
        List<String> mediaKeys = [];
        if (map['mediaKeys'] is List) {
          mediaKeys = (map['mediaKeys'] as List).map((e) => e.toString()).toList();
        }
        final thumbnailKey = map['thumbnailKey']?.toString();
        if (thumbnailKey != null && thumbnailKey.isNotEmpty) {
          mediaKeys = [thumbnailKey, ...mediaKeys];
        }
        mapped.add({
          'id': id,
          'title': title,
          'status': status,
          'category': category,
          'mediaKeys': mediaKeys,
        });
      }

      if (mounted) {
        setState(() {
          _items = refresh ? mapped : [..._items, ...mapped];
          _hasMore = rawItems.length >= _pageSize;
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.show(context, 'Failed to load: ${e.toString()}');
      }
    }
  }

  void _navigateToDetails(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;

    Widget? screen;
    switch (widget.type) {
      case UserItemsType.trades:
        screen = TradeDetailsLoader(tradeId: id);
        break;
      case UserItemsType.gifts:
        screen = GiftDetailsLoader(giftId: id);
        break;
      case UserItemsType.campaigns:
        screen = CampaignDetailsLoader(campaignId: id);
        break;
    }
    if (screen != null) {
      GuardedNavigator.push(context,
        MaterialPageRoute(builder: (_) => screen!),
      );
    }
  }

  Widget _buildItemCard(Map<String, dynamic> item, Color primaryColor) {
    final mediaKeys = (item['mediaKeys'] as List?)?.cast<String>() ?? [];
    final firstKey = mediaKeys.isNotEmpty ? mediaKeys.first : null;

    return GestureDetector(
      onTap: () => _navigateToDetails(item),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: firstKey != null
                        ? CachedMediaImage(
                            mediaKey: firstKey,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: _buildPlaceholder(primaryColor),
                            errorWidget: _buildPlaceholder(primaryColor),
                          )
                        : _buildPlaceholder(primaryColor),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? 'Untitled',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['category'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if ((item['status'] ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item['status'],
                              style: TextStyle(
                                fontSize: 11,
                                color: primaryColor.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color primaryColor) {
    return Container(
      width: 100,
      height: 100,
      color: primaryColor.withValues(alpha: 0.1),
      child: Icon(
        widget.type == UserItemsType.trades
            ? Icons.swap_horiz
            : widget.type == UserItemsType.gifts
                ? Icons.card_giftcard
                : Icons.volunteer_activism,
        size: 32,
        color: primaryColor.withValues(alpha: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
      ),
      body: _isLoading && _items.isEmpty
          ? const BybataLoader()
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No ${widget.type.name} yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadItems(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        _loadItems();
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: const BybataLoader(),
                        );
                      }
                      return _buildItemCard(_items[index], primaryColor);
                    },
                  ),
                ),
    );
  }
}
