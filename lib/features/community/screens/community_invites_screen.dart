import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/community_api_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class CommunityInvitesScreen extends StatefulWidget {
  const CommunityInvitesScreen({super.key});

  @override
  State<CommunityInvitesScreen> createState() => _CommunityInvitesScreenState();
}

class _CommunityInvitesScreenState extends State<CommunityInvitesScreen> {
  List<Map<String, dynamic>> _invites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      final items = await service.getMyInvites();
      if (mounted) {
        setState(() {
          _invites = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(context, 'Failed to load invites: ${e.toString()}');
      }
    }
  }

  Future<void> _acceptInvite(String communityId) async {
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      await service.acceptInvite(communityId);
      await _loadInvites();
      if (mounted) {
        AppToast.success(context, 'Invite accepted');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to accept invite: ${e.toString()}');
      }
    }
  }

  Future<void> _declineInvite(String communityId) async {
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      await service.declineInvite(communityId);
      await _loadInvites();
      if (mounted) {
        AppToast.info(context, 'Invite declined');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to decline invite: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Invites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvites,
          ),
        ],
      ),
      body: _isLoading
          ? const BybataLoader()
          : _invites.isEmpty
              ? const Center(child: Text('No pending invites'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final invite = _invites[index];
                    final community = invite['community'] ?? {};
                    final inviter = invite['inviter'] ?? {};
                    final inviterProfile = inviter['profile'] ?? {};
                    final metadata = invite['metadata'] ?? {};
                    final message = metadata['inviteMessage']?.toString();
                    final expiresAt = metadata['inviteExpiresAt']?.toString();
                    final inviteCode = metadata['inviteCode']?.toString();
                    final inviteLink = invite['inviteLink']?.toString();

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              community['name'] ?? 'Community',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Invited by ${inviterProfile['displayName'] ?? inviter['email'] ?? 'Someone'}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            if (message != null && message.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('"$message"'),
                            ],
                            if (expiresAt != null && expiresAt.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Expires: $expiresAt', style: TextStyle(color: Colors.grey[600])),
                            ],
                            if (inviteCode != null && inviteCode.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Invite code: $inviteCode', style: TextStyle(color: Colors.grey[600])),
                            ],
                            if (inviteLink != null && inviteLink.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Invite link: $inviteLink', style: TextStyle(color: Colors.grey[600])),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _acceptInvite(community['id']),
                                  child: const Text('Accept'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => _declineInvite(community['id']),
                                  child: const Text('Decline'),
                                ),
                              ],
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
