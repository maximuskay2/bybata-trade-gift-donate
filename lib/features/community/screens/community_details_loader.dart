import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/community_api_service.dart';
import 'community_hub_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class CommunityDetailsLoader extends StatefulWidget {
  final String communityId;
  const CommunityDetailsLoader({super.key, required this.communityId});

  @override
  State<CommunityDetailsLoader> createState() => _CommunityDetailsLoaderState();
}

class _CommunityDetailsLoaderState extends State<CommunityDetailsLoader> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCommunity();
  }

  Future<void> _fetchCommunity() async {
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      final community = await service.getCommunityFromApi(widget.communityId);
      if (!mounted) return;
      setState(() => _isLoading = false);
      GuardedNavigator.pushReplacement(context, 
        MaterialPageRoute(
          builder: (_) => CommunityHubScreen(
            communityId: community.id,
            communityName: community.name,
            communityLat: community.centerLatitude,
            communityLng: community.centerLongitude,
            isMember: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load community';
      });
      AppToast.error(context, 'Failed to load community: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: BybataLoader());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: Center(child: Text(_error ?? 'Unable to open community')),
    );
  }
}
