import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
import 'trade_details_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import '../../../core/utils/media_file_cache.dart';
import '../../../core/utils/listing_video_handoff.dart';

class TradeDetailsLoader extends StatefulWidget {
  final String tradeId;

  const TradeDetailsLoader({super.key, required this.tradeId});

  @override
  State<TradeDetailsLoader> createState() => _TradeDetailsLoaderState();
}

class _TradeDetailsLoaderState extends State<TradeDetailsLoader> {
  trade_models.Trade? _trade;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTrade();
  }

  Future<void> _fetchTrade() async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final data = await backend.getTrade(widget.tradeId);
      if (data == null) {
        ListingVideoHandoff.releaseUnclaimed();
        setState(() {
          _error = 'Trade not found';
          _isLoading = false;
        });
        return;
      }

      final trade = trade_models.Trade.fromJson(data);
      ListingVideoPrefetch.warmListingMedia(
        videoKey: trade.videoKey,
        thumbnailKey: trade.thumbnailKey,
      );
      setState(() {
        _trade = trade;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load trade details';
          _isLoading = false;
        });
        ListingVideoHandoff.releaseUnclaimed();
      }
    }
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
        appBar: AppBar(title: const Text('Trade Details')),
        body: Center(child: Text(_error!)),
      );
    }
    return TradeDetailsScreen(trade: _trade!);
  }
}
