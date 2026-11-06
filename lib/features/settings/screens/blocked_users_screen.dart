import 'package:flutter/material.dart';
import 'package:bybata/features/profile/services/users_api.dart';
import 'package:bybata/core/utils/media_utils.dart';
import 'package:intl/intl.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final UsersApi _usersApi = UsersApi();
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final blocked = await _usersApi.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blockedUsers = blocked;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load blocked users: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $displayName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _usersApi.unblockUser(userId);
      if (mounted) {
        AppToast.show(context, '$displayName has been unblocked');
        _loadBlockedUsers();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to unblock user: $e');
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: _isLoading
          ? const BybataLoader()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBlockedUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _blockedUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.block,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No blocked users',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Users you block will appear here',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBlockedUsers,
                      child: ListView.builder(
                        itemCount: _blockedUsers.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final block = _blockedUsers[index];
                          final blockedUser = block['blockedUser'] as Map<String, dynamic>?;
                          if (blockedUser == null) return const SizedBox.shrink();

                          final userId = blockedUser['id'] as String;
                          final displayName = blockedUser['displayName'] as String? ?? 'Unknown User';
                          final avatarKey = blockedUser['avatarKey'] as String?;
                          final reason = block['reason'] as String?;
                          final blockedAt = block['blockedAt'] as String?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: FutureBuilder<String?>(
                                future: MediaResolver.resolveUrl(avatarKey),
                                builder: (context, snapshot) {
                                  final url = snapshot.data;
                                  return CircleAvatar(
                                    backgroundImage: url != null
                                        ? NetworkImage(url)
                                        : null,
                                    child: url == null
                                        ? Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : '?',
                                          )
                                        : null,
                                  );
                                },
                              ),
                              title: Text(displayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (reason != null && reason.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Reason: $reason',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  if (blockedAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Blocked on ${_formatDate(blockedAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.green),
                                onPressed: () => _unblockUser(userId, displayName),
                                tooltip: 'Unblock user',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

