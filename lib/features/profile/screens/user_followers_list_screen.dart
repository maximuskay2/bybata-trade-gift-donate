import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/cached_media_image.dart';
import 'user_profile_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

enum FollowListType { followers, following }

class UserFollowersListScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final FollowListType type;

  const UserFollowersListScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.type,
  });

  @override
  State<UserFollowersListScreen> createState() => _UserFollowersListScreenState();
}

class _UserFollowersListScreenState extends State<UserFollowersListScreen> {
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
      case FollowListType.followers:
        return '${widget.userName}\'s Followers';
      case FollowListType.following:
        return '${widget.userName} Following';
    }
  }

  String get _path {
    switch (widget.type) {
      case FollowListType.followers:
        return '/v1/users/${widget.userId}/followers';
      case FollowListType.following:
        return '/v1/users/${widget.userId}/following';
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

      final response = await apiClient.get(
        _path,
        queryParameters: {'page': _page, 'size': _pageSize},
      );
      final data = response.data as Map<String, dynamic>;
      final rawItems = (data['items'] as List?) ?? [];

      final List<Map<String, dynamic>> mapped = rawItems.map<Map<String, dynamic>>((item) {
        final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
        return {
          'id': map['id']?.toString() ?? '',
          'displayName': map['displayName']?.toString() ?? 'User',
          'username': map['username']?.toString(),
          'avatarKey': map['avatarKey']?.toString(),
        };
      }).toList();

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

  void _navigateToProfile(String userId) {
    GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> item, Color primaryColor) {
    final avatarKey = item['avatarKey']?.toString();
    final displayName = item['displayName'] ?? 'User';
    final username = item['username']?.toString();

    return GestureDetector(
      onTap: () => _navigateToProfile(item['id'] ?? ''),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ByBataGlassContainer(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: avatarKey != null && avatarKey.isNotEmpty
                    ? ClipOval(
                        child: CachedMediaImage(
                          mediaKey: avatarKey,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: _buildAvatarPlaceholder(displayName, primaryColor),
                          errorWidget: _buildAvatarPlaceholder(displayName, primaryColor),
                        ),
                      )
                    : _buildAvatarPlaceholder(displayName, primaryColor),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: username != null && username.isNotEmpty
                  ? Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                  : null,
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name, Color primaryColor) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Text(
      initial,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
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
                      return _buildUserCard(_items[index], primaryColor);
                    },
                  ),
                ),
    );
  }
}
