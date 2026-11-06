import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../features/donations/models/donation_models.dart';
import '../../features/gifting/models/gift_models.dart' as gift_models;
import '../../features/trade/models/trade_models.dart';
import '../widgets/app_toast.dart';

/// Client-side hints for when delete is likely allowed (server validates authoritatively).
class ListingDeleteRules {
  ListingDeleteRules._();

  static bool canDeleteTrade(Trade trade) {
    if (trade.status == TradeStatus.inOffer) return false;
    return trade.status == TradeStatus.active ||
        trade.status == TradeStatus.pending;
  }

  static bool canDeleteGift(gift_models.Gift gift) {
    return gift.status == gift_models.GiftStatus.active && gift.currentClaims == 0;
  }

  static bool canDeleteCampaign(Campaign campaign) {
    return campaign.raisedAmount <= 0 && campaign.supportersCount <= 0;
  }

  static String? tradeDeleteBlockedReason(Trade trade) {
    if (trade.status == TradeStatus.inOffer) {
      return 'This trade has an active swap in progress and cannot be deleted.';
    }
    if (!canDeleteTrade(trade)) {
      return 'Only open or draft trades without active swaps can be deleted.';
    }
    return null;
  }

  static String? giftDeleteBlockedReason(gift_models.Gift gift) {
    if (gift.currentClaims > 0) {
      return 'This gift has already been given and cannot be deleted.';
    }
    if (gift.status != gift_models.GiftStatus.active) {
      return 'Only active gifts with no claims can be deleted.';
    }
    return null;
  }

  static String? campaignDeleteBlockedReason(Campaign campaign) {
    if (campaign.raisedAmount > 0 || campaign.supportersCount > 0) {
      return 'Campaigns that have received donations cannot be deleted.';
    }
    return null;
  }
}

Future<bool> confirmDeleteListing(
  BuildContext context, {
  required String title,
  required String itemLabel,
  String? blockedReason,
}) async {
  if (blockedReason != null) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cannot delete $itemLabel'),
        content: Text(blockedReason),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $itemLabel?'),
      content: Text(
        'Permanently delete "$title"? This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

String parseDeleteListingError(Object error, {String fallback = 'Failed to delete'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
  }
  return fallback;
}

void showDeleteListingResult(BuildContext context, {required bool success, String? message}) {
  if (success) {
    AppToast.success(context, message ?? 'Deleted successfully');
  } else {
    AppToast.error(context, message ?? 'Failed to delete');
  }
}
