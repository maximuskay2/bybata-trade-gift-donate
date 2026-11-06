import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/campaign_provider.dart';
import 'campaign_details_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../../core/utils/listing_video_handoff.dart';

class CampaignDetailsLoader extends StatefulWidget {
  final String campaignId;
  const CampaignDetailsLoader({super.key, required this.campaignId});

  @override
  State<CampaignDetailsLoader> createState() => _CampaignDetailsLoaderState();
}

class _CampaignDetailsLoaderState extends State<CampaignDetailsLoader> {
  dynamic _campaign;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCampaign();
  }

  Future<void> _fetchCampaign() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<CampaignProvider>(context, listen: false);
      final campaign = await provider.getCampaign(widget.campaignId);
      if (!mounted) return;
      if (campaign == null) {
        ListingVideoHandoff.releaseUnclaimed();
        setState(() {
          _error = 'Campaign not found';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _campaign = campaign;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      ListingVideoHandoff.releaseUnclaimed();
      setState(() {
        _error = _friendlyDioMessage(e);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      ListingVideoHandoff.releaseUnclaimed();
      setState(() {
        _error = 'Failed to load campaign details';
        _isLoading = false;
      });
    }
  }

  String _friendlyDioMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) return 'Campaign not found';
    if (status != null && status >= 500) {
      return 'Server error ($status). Please try again.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Network timeout. Check your connection.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Failed to load campaign details';
  }

  @override
  void dispose() {
    ListingVideoHandoff.onDetailRouteClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: BybataLoader());
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Campaign Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _fetchCampaign,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return CampaignDetailsScreen(campaign: _campaign);
  }
}
