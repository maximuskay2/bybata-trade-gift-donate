import '../../core/models/listing_media.dart';
import '../../core/motion/living_slide.dart';
import '../donations/models/donation_models.dart';
import '../gifting/models/gift_models.dart';

/// Builds stage slides from the lists the hubs already loaded.
class LivingSlideMapper {
  LivingSlideMapper._();

  static LivingSlide fromTradeMap(
    Map<String, dynamic> trade, {
    String? currentUserId,
    bool treatAsMine = false,
  }) {
    final owner = trade['owner'];
    var ownerId = '';
    var ownerName = trade['ownerFirstName']?.toString() ?? 'Member';
    if (owner is Map) {
      ownerId = owner['id']?.toString() ?? '';
      final profile = owner['profile'];
      if (profile is Map &&
          (profile['displayName']?.toString().trim().isNotEmpty ?? false)) {
        ownerName = profile['displayName'].toString();
      } else if ((owner['name']?.toString().trim().isNotEmpty ?? false)) {
        ownerName = owner['name'].toString();
      }
    }
    final mine = treatAsMine ||
        ownerName == 'Me' ||
        (currentUserId != null &&
            currentUserId.isNotEmpty &&
            ownerId == currentUserId);
    // Prefer storage keys over resolved preview URLs. Putting a CDN URL first
    // made the hero blank while the second strip thumb (same key) loaded fine.
    final media = ListingMediaFields.fromJson(trade);
    final gallery = <String>[];
    for (final key in media.mediaKeys) {
      final value = key.trim();
      if (value.isEmpty) continue;
      if (ListingMediaFields.isLikelyVideoKey(value)) continue;
      if (media.videoKey != null && value == media.videoKey) continue;
      gallery.add(value);
    }
    final thumb = media.previewImageKey?.trim();
    final imageUrl = trade['imageUrl']?.toString().trim();
    String? imageKey;
    if (thumb != null && thumb.isNotEmpty) {
      imageKey = thumb;
    } else if (gallery.isNotEmpty) {
      imageKey = gallery.first;
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageKey = imageUrl;
    }
    if (imageKey != null &&
        imageKey.isNotEmpty &&
        !stageImageIsRemote(imageKey) &&
        !gallery.contains(imageKey)) {
      gallery.insert(0, imageKey);
    }
    final wanted = trade['interestedItems'];
    final want = wanted is List
        ? wanted.map((item) => item.toString()).where((item) => item.isNotEmpty).join(', ')
        : '';
    final trust = trade['trustScore'];
    final subtitle = trust is num
        ? '$ownerName · ${trust.toStringAsFixed(1)}'
        : ownerName;
    final estimated = _asInt(trade['estimatedValue']);
    return LivingSlide(
      id: trade['id']?.toString() ?? '',
      title: trade['title']?.toString() ?? 'Untitled',
      subtitle: subtitle,
      story: trade['description']?.toString() ?? '',
      place: trade['location']?.toString() ?? '',
      want: want.isEmpty ? '' : 'Wants · $want',
      imageKey: imageKey,
      galleryKeys: gallery,
      numberLabel: estimated == null || estimated <= 0 ? '' : '$estimated BYC',
      primaryLabel: mine ? 'Edit' : 'Offer this',
      isOwner: mine,
      ownerId: ownerId,
      ownerName: ownerName,
      value: estimated,
      source: trade,
    );
  }

  static LivingSlide fromGift(
    Gift gift, {
    String? currentUserId,
    bool treatAsMine = false,
  }) {
    final mine = treatAsMine ||
        (currentUserId != null &&
            currentUserId.isNotEmpty &&
            gift.giver.id == currentUserId);
    final gallery = gift.imageUrls
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty && !stageImageIsRemote(key))
        .toList();
    final remoteGallery = gift.imageUrls
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty && stageImageIsRemote(key))
        .toList();
    final thumb = gift.thumbnailKey?.trim();
    final imageKey = (thumb != null && thumb.isNotEmpty)
        ? thumb
        : (gallery.isNotEmpty
            ? gallery.first
            : (remoteGallery.isEmpty ? null : remoteGallery.first));
    final frames = <String>[
      if (imageKey != null &&
          imageKey.isNotEmpty &&
          !stageImageIsRemote(imageKey))
        imageKey,
      ...gallery,
      if ((imageKey == null || stageImageIsRemote(imageKey)) &&
          gallery.isEmpty)
        ...remoteGallery,
    ];
    return LivingSlide(
      id: gift.id,
      title: gift.title,
      subtitle: gift.giver.name,
      story: gift.description,
      place: gift.location ?? '',
      want: 'Karma reward · ${gift.karmaReward}',
      imageKey: imageKey,
      galleryKeys: frames.toSet().toList(),
      numberLabel: '${gift.karmaReward} karma',
      primaryLabel: mine ? 'Edit' : 'Request',
      isOwner: mine,
      ownerId: gift.giver.id,
      ownerName: gift.giver.name,
      value: gift.karmaReward,
      source: gift,
    );
  }

  static LivingSlide fromCampaign(Campaign campaign, {String? currentUserId}) {
    final mine = currentUserId != null &&
        currentUserId.isNotEmpty &&
        campaign.creator.id == currentUserId;
    final gallery = campaign.images
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty && !stageImageIsRemote(key))
        .toList();
    final remoteGallery = campaign.images
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty && stageImageIsRemote(key))
        .toList();
    final thumb = campaign.thumbnailKey?.trim();
    final imageKey = (thumb != null && thumb.isNotEmpty)
        ? thumb
        : (gallery.isNotEmpty
            ? gallery.first
            : (remoteGallery.isEmpty ? null : remoteGallery.first));
    final frames = <String>[
      if (imageKey != null &&
          imageKey.isNotEmpty &&
          !stageImageIsRemote(imageKey))
        imageKey,
      ...gallery,
      if ((imageKey == null || stageImageIsRemote(imageKey)) &&
          gallery.isEmpty)
        ...remoteGallery,
    ];
    return LivingSlide(
      id: campaign.id,
      title: campaign.title,
      subtitle: campaign.creator.name,
      story: campaign.story,
      place: campaign.location,
      want: campaign.beneficiaryInfo ?? '',
      imageKey: imageKey,
      galleryKeys: frames.toSet().toList(),
      numberLabel: '${campaign.formattedRaised} / ${campaign.formattedGoal}',
      primaryLabel: mine ? 'Edit' : 'Give',
      isOwner: mine,
      ownerId: campaign.creator.id,
      ownerName: campaign.creator.name,
      value: campaign.raisedAmount.round(),
      source: campaign,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}
