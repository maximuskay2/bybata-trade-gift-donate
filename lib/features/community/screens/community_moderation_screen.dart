import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/community_api_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class CommunityModerationScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityModerationScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunityModerationScreen> createState() => _CommunityModerationScreenState();
}

class _CommunityModerationScreenState extends State<CommunityModerationScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<CommunityApiService> _service() async {
    final storage = const FlutterSecureStorage();
    final baseUrl = await EnvConfig.getBaseUrl();
    final apiClient = ApiClient(baseUrl, storage);
    return CommunityApiService(apiClient);
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final service = await _service();
      final items = await service.getPendingJoinRequests(widget.communityId);
      if (!mounted) return;
      setState(() {
        _pending = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.error(context, 'Failed to load join requests: $e');
    }
  }

  Future<void> _approve(String memberId) async {
    try {
      final service = await _service();
      await service.approveJoinRequest(widget.communityId, memberId);
      await _loadPending();
      if (mounted) {
        AppToast.success(context, 'Request approved');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Approve failed: $e');
    }
  }

  Future<void> _reject(String memberId) async {
    try {
      final service = await _service();
      await service.rejectJoinRequest(widget.communityId, memberId);
      await _loadPending();
      if (mounted) {
        AppToast.info(context, 'Request rejected');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Reject failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.communityName} - Moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPending,
          ),
        ],
      ),
      body: _loading
          ? const BybataLoader()
          : _pending.isEmpty
              ? const Center(child: Text('No pending join requests'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _pending[index];
                    final user = item['user'] ?? {};
                    final profile = user['profile'] ?? {};
                    final name = profile['displayName'] ?? user['email'] ?? 'Member';
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user['email']?.toString() ?? '',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _approve(item['id'].toString()),
                                  child: const Text('Approve'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => _reject(item['id'].toString()),
                                  child: const Text('Reject'),
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

