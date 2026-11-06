import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' show DioException;
import '../features/community/services/community_api_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  List<Map<String, dynamic>> _communities = [];
  String? _selectedCommunityId;
  bool _loadingCommunities = true;

  @override
  void initState() {
    super.initState();
    _loadJoinedCommunities();
  }

  Future<void> _loadJoinedCommunities() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      final communities = await service.getJoinedCommunitiesFromApi(page: 1, size: 100);
      
      if (mounted) {
        setState(() {
          _communities = communities.map((c) => {
            'id': c.id,
            'name': c.name,
          }).toList();
          _loadingCommunities = false;
          if (_communities.isNotEmpty) {
            _selectedCommunityId = _communities.first['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCommunities = false;
          _error = 'Failed to load communities. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCommunityId == null) {
      setState(() { _error = 'Please select a community'; });
      return;
    }
    setState(() { _isSubmitting = true; _error = null; });

    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final apiClient = ApiClient(baseUrl, storage);

      dynamic res;
      try {
        res = await apiClient.dio.post(
          '/v1/ask/requests',
          data: {
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'communityId': _selectedCommunityId,
          },
        );
      } catch (e) {
        // Fallback to legacy endpoint if new path is not available
        res = await apiClient.dio.post(
          '/v1/communities/requests',
          data: {
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'communityId': _selectedCommunityId,
          },
        );
      }

      if (!mounted) return;
      if ((res.statusCode ?? 400) >= 200 && (res.statusCode ?? 400) < 300) {
        AppToast.show(context, 'Request published!');
        GuardedNavigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        setState(() { _error = 'Failed to create request (${res.statusCode})'; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Request')),
      body: _loadingCommunities
          ? const BybataLoader()
          : _communities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No Communities Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You need to join a community before creating a request.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => GuardedNavigator.pushNamed(context, '/search'),
                          icon: const Icon(Icons.search),
                          label: const Text('Browse Communities'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedCommunityId,
                          decoration: const InputDecoration(
                            labelText: 'Select Community',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.group),
                          ),
                          items: _communities.map((community) {
                            return DropdownMenuItem<String>(
                              value: community['id'],
                              child: Text(community['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCommunityId = value;
                            });
                          },
                          validator: (v) => v == null ? 'Please select a community' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Enter at least 3 characters' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contentController,
                          decoration: const InputDecoration(
                            labelText: 'Describe your request',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                          validator: (v) => (v == null || v.trim().length < 10) ? 'Enter at least 10 characters' : null,
                        ),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting ? const BybataLoadingIndicator(size: BybataLoadingSize.compact) : const Text('Publish'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
