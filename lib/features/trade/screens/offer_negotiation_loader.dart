import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../models/trade_models.dart' as trade_models;
import '../providers/trade_backend_provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'existing_offer_negotiation_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Loader that fetches trade + offer and opens ExistingOfferNegotiationScreen.
/// Used when navigating from notification tap (offerId + tradeId in payload).
class OfferNegotiationLoader extends StatefulWidget {
  final String tradeId;
  final String offerId;

  const OfferNegotiationLoader({
    super.key,
    required this.tradeId,
    required this.offerId,
  });

  @override
  State<OfferNegotiationLoader> createState() => _OfferNegotiationLoaderState();
}

class _OfferNegotiationLoaderState extends State<OfferNegotiationLoader> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    try {
      final backend = Provider.of<TradeBackendProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final me = auth.currentUser;
      if (me == null) {
        if (mounted) {
          setState(() => _error = 'Please sign in');
          _isLoading = false;
        }
        return;
      }

      final tradeRes = await backend.getTrade(widget.tradeId);
      if (tradeRes == null) {
        if (mounted) setState(() => _error = 'Trade not found');
        _isLoading = false;
        return;
      }

      final tradeJson = Map<String, dynamic>.from(
        (tradeRes['data'] is Map) ? tradeRes['data'] as Map : tradeRes as Map,
      );
      final targetTrade = trade_models.Trade.fromJson(tradeJson);

      final history = await backend.getOfferHistory(widget.offerId);
      if (history == null) {
        if (mounted) setState(() => _error = 'Offer not found');
        _isLoading = false;
        return;
      }

      final timeline = history['timeline'] as List?;
      final rootOffer = history['rootOffer'] as Map?;
      final firstOffer = (timeline != null && timeline.isNotEmpty)
          ? timeline.first as Map
          : rootOffer;

      if (firstOffer == null) {
        if (mounted) setState(() => _error = 'Offer not found');
        _isLoading = false;
        return;
      }

      final bidderId = (firstOffer['bidderId'] ?? firstOffer['bidder']?['id'] ?? '').toString();
      final bidder = firstOffer['bidder'] is Map ? firstOffer['bidder'] as Map : null;
      final bidderName = bidder?['profile']?['displayName'] ?? bidder?['displayName'] ?? 'User';
      final ownerId = (tradeJson['owner']?['id'] ?? '').toString();
      final owner = tradeJson['owner'] is Map ? tradeJson['owner'] as Map : null;
      final ownerName = owner?['profile']?['displayName'] ?? owner?['displayName'] ?? 'Owner';

      final isReceived = me.id == ownerId;
      final initiatorUserId = isReceived ? bidderId : ownerId;
      final initiatorName = isReceived ? bidderName.toString() : ownerName.toString();

      trade_models.Trade? initialOfferedTrade;
      final offeredTradeMap = firstOffer['offeredTrade'];
      if (offeredTradeMap is Map) {
        try {
          initialOfferedTrade = trade_models.Trade.fromJson(
            Map<String, dynamic>.from(offeredTradeMap),
          );
        } catch (_) {
          // ignore malformed nested trade payload
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      await GuardedNavigator.pushReplacement(context,
        MaterialPageRoute(
          builder: (_) => ExistingOfferNegotiationScreen(
            targetTrade: targetTrade,
            offerId: widget.offerId,
            initiatorUserId: initiatorUserId,
            initiatorName: initiatorName,
            initialOfferedTrade: initialOfferedTrade,
            isReceived: isReceived,
          ),
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && mounted) {
        GuardedNavigator.pushNamed(context, '/login');
      }
      if (mounted) {
        setState(() {
          _error = 'Failed to load offer';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load offer';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: const BybataLoader(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Offer')),
      body: Center(
        child: Text(_error ?? 'Failed to load offer'),
      ),
    );
  }
}
