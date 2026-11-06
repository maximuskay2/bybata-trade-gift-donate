import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/web_links_config.dart';
import '../widgets/share_sheet.dart';

class ShareUtils {
  ShareUtils._();

  /// Share directly to native share sheet (WhatsApp, Messages, etc.) without showing the in-app modal.
  static Future<void> shareToOtherApps({
    required String message,
    String? subject,
  }) async {
    await Share.share(message, subject: subject);
  }

  static String campaignLink(String id) => WebLinksConfig.campaignLink(id.trim());
  static String donationLink(String id) => WebLinksConfig.donationLink(id.trim());
  static String giftLink(String id) => WebLinksConfig.giftLink(id.trim());
  static String tradeLink(String id) => WebLinksConfig.tradeLink(id.trim());
  static String profileLink({String? userId, String? username}) {
    final slug = (username ?? '').trim();
    if (slug.isNotEmpty) return WebLinksConfig.profileLink(slug);
    return WebLinksConfig.profileLink((userId ?? '').trim());
  }

  static void shareCampaign(
    BuildContext context, {
    required String id,
    required String title,
    String? summary,
  }) {
    final link = campaignLink(id);
    final headline = (summary?.trim().isNotEmpty ?? false)
        ? summary!.trim()
        : 'Support "$title" on bYbata';
    final message = '$headline\n\n$link';
    ShareSheet.show(
      context,
      title: title,
      message: message,
      link: link,
      subject: title,
    );
  }

  static void shareDonation(
    BuildContext context, {
    required String campaignId,
    required String campaignTitle,
    double? amount,
  }) {
    final link = campaignLink(campaignId);
    final prefix = amount != null
        ? 'I donated ${amount.toStringAsFixed(0)} BYC to "$campaignTitle" on bYbata.'
        : 'Support "$campaignTitle" on bYbata.';
    final message = '$prefix\n\n$link';
    ShareSheet.show(
      context,
      title: campaignTitle,
      message: message,
      link: link,
      subject: campaignTitle,
    );
  }

  static void shareGift(
    BuildContext context, {
    required String id,
    required String title,
  }) {
    final link = giftLink(id);
    final message = 'Check out "$title" on bYbata\n\n$link';
    ShareSheet.show(
      context,
      title: title,
      message: message,
      link: link,
      subject: title,
    );
  }

  static void shareTrade(
    BuildContext context, {
    required String id,
    required String title,
  }) {
    final link = tradeLink(id);
    final message = 'Check out "$title" on bYbata\n\n$link';
    ShareSheet.show(
      context,
      title: title,
      message: message,
      link: link,
      subject: title,
    );
  }

  static void shareProfile(
    BuildContext context, {
    required String displayName,
    String? userId,
    String? username,
  }) {
    final link = profileLink(userId: userId, username: username);
    final resolvedName = displayName.trim().isEmpty ? 'this profile' : displayName;
    final message = 'Check out $resolvedName on bYbata\n\n$link';
    ShareSheet.show(
      context,
      title: resolvedName,
      message: message,
      link: link,
      subject: resolvedName,
    );
  }

  static void shareCustom(
    BuildContext context, {
    required String title,
    required String message,
    required String link,
    String? subject,
  }) {
    final trimmedMsg = message.trim();
    final payload = trimmedMsg.isEmpty ? link : '$trimmedMsg\n\n$link';
    ShareSheet.show(
      context,
      title: title,
      message: payload,
      link: link,
      subject: subject ?? title,
    );
  }

  /// Share referral link/code for user referral program.
  static void shareReferral(
    BuildContext context, {
    required String referralLink,
    required String referralCode,
  }) {
    const appName = 'bYbata';
    final message =
        'Join me on $appName! Use my referral code $referralCode or tap: $referralLink';
    ShareSheet.show(
      context,
      title: 'Invite Friends',
      message: message,
      link: referralLink,
      subject: 'Join me on $appName',
    );
  }
}
