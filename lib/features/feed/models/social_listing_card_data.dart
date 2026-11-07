import '../../../core/models/listing_media.dart';

enum SocialListingModule { trade, gift, donation }

/// Layout density for bento grid cells.
enum BentoTileSize { hero, standard, compact }

/// Card chrome for browse feeds — inset bento tiles, utility timeline cards,
/// edge-to-edge Instagram posts, or the trade-centre product grid.
enum SocialFeedLayout { bento, instagram, timeline, catalog }

/// View-model for [SocialListingCard] — one unified bento card contract.
class SocialListingCardData {
  final String id;
  final SocialListingModule module;
  final String title;
  final String description;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarKey;
  final String? karmaTier;
  final String? distanceLabel;
  final ListingMediaFields media;
  final String? previewImageUrl;
  final String? ownerAvatarUrl;
  final double? progress; // 0..1 for campaigns
  final String? progressLabel;
  final String? latestCommentPreview;
  final bool isVerified;
  final bool hasUnreadMessages;
  final BentoTileSize bentoSize;
  final Map<String, dynamic>? raw;

  const SocialListingCardData({
    required this.id,
    required this.module,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatarKey,
    this.karmaTier,
    this.distanceLabel,
    required this.media,
    this.previewImageUrl,
    this.ownerAvatarUrl,
    this.progress,
    this.progressLabel,
    this.latestCommentPreview,
    this.isVerified = false,
    this.hasUnreadMessages = false,
    this.bentoSize = BentoTileSize.standard,
    this.raw,
  });

  SocialListingCardData copyWith({
    BentoTileSize? bentoSize,
    bool? isVerified,
    bool? hasUnreadMessages,
  }) {
    return SocialListingCardData(
      id: id,
      module: module,
      title: title,
      description: description,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerAvatarKey: ownerAvatarKey,
      karmaTier: karmaTier,
      distanceLabel: distanceLabel,
      media: media,
      previewImageUrl: previewImageUrl,
      ownerAvatarUrl: ownerAvatarUrl,
      progress: progress,
      progressLabel: progressLabel,
      latestCommentPreview: latestCommentPreview,
      isVerified: isVerified ?? this.isVerified,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      bentoSize: bentoSize ?? this.bentoSize,
      raw: raw,
    );
  }
}
