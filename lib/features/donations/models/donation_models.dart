import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

import '../../../core/models/listing_media.dart';

// Enums for donation system
enum CampaignStatus { active, completed, paused, cancelled, draft }
enum CampaignCategory { education, healthcare, environment, emergency, community, animal, technology, art, sports, other }
enum DonationStatus { pending, completed, refunded, failed }
enum RewardTierStatus { available, claimed, soldOut }
enum CampaignPriority { normal, urgent, featured }
enum UpdateType { text, image, milestone, thankyou }

// User Profile for Donations
class DonationUser {
  final String id;
  final String name;
  final String? profileImage;
  final int trustLevel;
  final int karmaPoints;
  final int campaignsCreated;
  final int donationsMade;
  final double totalRaised;
  final double totalDonated;
  final bool isVerified;
  final String location;

  const DonationUser({
    required this.id,
    required this.name,
    this.profileImage,
    required this.trustLevel,
    required this.karmaPoints,
    required this.campaignsCreated,
    required this.donationsMade,
    required this.totalRaised,
    required this.totalDonated,
    this.isVerified = false,
    required this.location,
  });

  // Trust level display
  String get trustLevelLabel {
    switch (trustLevel) {
      case 1: return 'New';
      case 2: return 'Basic';
      case 3: return 'Trusted';
      case 4: return 'Premium';
      case 5: return 'Ambassador';
      default: return 'Unverified';
    }
  }

  Color get trustLevelColor {
    switch (trustLevel) {
      case 1: return Colors.grey;
      case 2: return AppColors.primary;
      case 3: return Colors.green;
      case 4: return Colors.purple;
      case 5: return Colors.amber;
      default: return Colors.grey;
    }
  }
}

// Campaign Model
class Campaign {
  final String id;
  final String title;
  final String story;
  final double goalAmount;
  final double raisedAmount;
  final CampaignStatus status;
  final CampaignCategory category;
  final CampaignPriority priority;
  final DonationUser creator;
  final DateTime createdAt;
  final DateTime deadline;
  final List<String> images;
  final String? videoUrl;
  final String? mediaType;
  final String? videoKey;
  final String? thumbnailKey;
  final List<RewardTier> rewardTiers;
  final List<CampaignUpdate> updates;
  final List<DonationTransaction> donations;
  final String location;
  final List<String> tags;
  final int supportersCount;
  final int viewsCount;
  final int sharesCount;
  final int likesCount;
  final bool isFeatured;
  final bool isUrgent;
  final bool isLocal;
  final String? beneficiaryInfo;

  const Campaign({
    required this.id,
    required this.title,
    required this.story,
    required this.goalAmount,
    required this.raisedAmount,
    required this.status,
    required this.category,
    required this.priority,
    required this.creator,
    required this.createdAt,
    required this.deadline,
    required this.images,
    this.videoUrl,
    this.mediaType,
    this.videoKey,
    this.thumbnailKey,
    required this.rewardTiers,
    required this.updates,
    required this.donations,
    required this.location,
    required this.tags,
    required this.supportersCount,
    required this.viewsCount,
    required this.sharesCount,
    this.likesCount = 0,
    this.isFeatured = false,
    this.isUrgent = false,
    this.isLocal = false,
    this.beneficiaryInfo,
  });

  // Calculated properties
  double get progressPercentage => (raisedAmount / goalAmount).clamp(0.0, 1.0);
  
  Duration get timeRemaining => deadline.difference(DateTime.now());
  
  bool get isExpired => DateTime.now().isAfter(deadline);
  
  bool get isCompleted => raisedAmount >= goalAmount;

  String get formattedGoal => '\$${goalAmount.toStringAsFixed(0)}';
  
  String get formattedRaised => '\$${raisedAmount.toStringAsFixed(0)}';

  String get categoryLabel => category.toString().split('.').last.toUpperCase();

  ListingMediaFields get listingMedia {
    final key = videoKey ?? videoUrl;
    final isVideo = (mediaType?.toUpperCase() == 'VIDEO') ||
        (key != null && key.isNotEmpty && images.isEmpty);
    return ListingMediaFields(
      mediaType: isVideo ? ListingMediaType.video : ListingMediaType.image,
      mediaKeys: images,
      videoKey: key,
      thumbnailKey: thumbnailKey,
    );
  }

  Color get categoryColor {
    switch (category) {
      case CampaignCategory.education: return AppColors.primary;
      case CampaignCategory.healthcare: return Colors.red;
      case CampaignCategory.environment: return Colors.green;
      case CampaignCategory.emergency: return Colors.orange;
      case CampaignCategory.community: return Colors.purple;
      case CampaignCategory.animal: return Colors.brown;
      case CampaignCategory.technology: return AppColors.primaryLight;
      case CampaignCategory.art: return Colors.pink;
      case CampaignCategory.sports: return AppColors.primaryDark;
      case CampaignCategory.other: return Colors.grey;
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case CampaignCategory.education: return Icons.school;
      case CampaignCategory.healthcare: return Icons.medical_services;
      case CampaignCategory.environment: return Icons.eco;
      case CampaignCategory.emergency: return Icons.emergency;
      case CampaignCategory.community: return Icons.groups;
      case CampaignCategory.animal: return Icons.pets;
      case CampaignCategory.technology: return Icons.computer;
      case CampaignCategory.art: return Icons.palette;
      case CampaignCategory.sports: return Icons.sports;
      case CampaignCategory.other: return Icons.category;
    }
  }

  String get timeRemainingText {
    if (isExpired) return 'Campaign ended';
    
    final duration = timeRemaining;
    if (duration.inDays > 0) {
      return '${duration.inDays} days left';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours left';
    } else {
      return '${duration.inMinutes} minutes left';
    }
  }

  factory Campaign.fromJson(Map<String, dynamic> data) {
    final founder = (data['founder'] as Map?)?.cast<String, dynamic>() ??
        (data['creator'] as Map?)?.cast<String, dynamic>() ??
        {};
    final founderProfile =
        (founder['profile'] as Map?)?.cast<String, dynamic>() ?? {};

    final donations = (data['donations'] as List? ?? []).map((d) {
      final dm = Map<String, dynamic>.from(d as Map);
      final statusRaw = dm['status']?.toString().toUpperCase();
      DonationStatus status;
      switch (statusRaw) {
        case 'PENDING':
          status = DonationStatus.pending;
          break;
        case 'FAILED':
          status = DonationStatus.failed;
          break;
        case 'SUCCESS':
        default:
          status = DonationStatus.completed;
      }
      return DonationTransaction(
        id: dm['id']?.toString() ?? '',
        campaignId: (data['id'] ?? '').toString(),
        donor: DonationUser(
          id: dm['donor']?['id']?.toString() ?? '',
          name: dm['donor']?['profile']?['displayName']?.toString() ??
              'Anonymous',
          trustLevel: 3,
          karmaPoints: 0,
          campaignsCreated: 0,
          donationsMade: 1,
          totalRaised: 0.0,
          totalDonated: _campaignToDouble(dm['amount']),
          location: 'Unknown',
        ),
        amount: _campaignToDouble(dm['amount']),
        donatedAt: DateTime.tryParse((dm['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        status: status,
        isAnonymous: dm['isAnonymous'] == true,
        message: dm['message']?.toString(),
        karmaEarned: _campaignToInt(dm['karmaAwarded']),
        transactionHash: (dm['transactionHash'] ?? '').toString(),
        paymentMethod: 'BYC',
      );
    }).toList();

    return Campaign(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      story: (data['description'] ?? data['story'] ?? '').toString(),
      goalAmount: _campaignToDouble(data['goalAmount']),
      raisedAmount: _campaignToDouble(data['currentAmount'] ?? data['raisedAmount']),
      status: _campaignParseStatus(data['status']?.toString()),
      category: _campaignParseCategory(data['category']?.toString()),
      priority: data['isUrgent'] == true
          ? CampaignPriority.urgent
          : data['isFeatured'] == true
              ? CampaignPriority.featured
              : CampaignPriority.normal,
      creator: DonationUser(
        id: (founder['id'] ?? '').toString(),
        name: (founderProfile['displayName'] ?? 'Unknown').toString(),
        trustLevel: 3,
        karmaPoints: 0,
        campaignsCreated: 1,
        donationsMade: 0,
        totalRaised: _campaignToDouble(data['currentAmount']),
        totalDonated: 0.0,
        location: (data['location'] ?? 'Unknown').toString(),
        isVerified: data['isVerified'] == true,
      ),
      createdAt: DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      deadline: DateTime.tryParse((data['endsAt'] ?? '').toString()) ??
          DateTime.now().add(const Duration(days: 30)),
      images: _campaignParseImages(data),
      videoUrl: data['videoKey']?.toString(),
      mediaType: data['mediaType']?.toString(),
      videoKey: data['videoKey']?.toString(),
      thumbnailKey: data['thumbnailKey']?.toString(),
      rewardTiers: const [],
      updates: const [],
      donations: donations,
      location: (data['location'] ?? 'Unknown').toString(),
      tags: List<String>.from(data['tags'] ?? []),
      supportersCount: _campaignToInt(data['donorCount']),
      viewsCount: _campaignToInt(data['viewCount']),
      sharesCount: _campaignToInt(data['shareCount']),
      likesCount: _campaignToInt(
        data['likeCount'] ?? (data['metadata'] as Map?)?['likes'] ?? 0,
      ),
      isFeatured: data['isFeatured'] == true,
      isUrgent: data['isUrgent'] == true,
      isLocal: false,
    );
  }
}

CampaignStatus _campaignParseStatus(String? status) {
  switch (status?.toLowerCase()) {
    case 'active':
      return CampaignStatus.active;
    case 'completed':
      return CampaignStatus.completed;
    case 'paused':
      return CampaignStatus.paused;
    case 'cancelled':
      return CampaignStatus.cancelled;
    case 'draft':
      return CampaignStatus.draft;
    default:
      return CampaignStatus.active;
  }
}

CampaignCategory _campaignParseCategory(String? category) {
  switch (category?.toLowerCase()) {
    case 'education':
      return CampaignCategory.education;
    case 'healthcare':
      return CampaignCategory.healthcare;
    case 'environment':
      return CampaignCategory.environment;
    case 'emergency':
      return CampaignCategory.emergency;
    case 'community':
      return CampaignCategory.community;
    case 'animal':
      return CampaignCategory.animal;
    case 'technology':
      return CampaignCategory.technology;
    case 'art':
      return CampaignCategory.art;
    case 'sports':
      return CampaignCategory.sports;
    default:
      return CampaignCategory.other;
  }
}

List<String> _campaignParseImages(Map<String, dynamic> data) {
  final images = <String>[];

  void addFrom(dynamic raw) {
    if (raw is List) {
      for (final item in raw) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) images.add(value);
      }
    } else if (raw is String) {
      final value = raw.trim();
      if (value.isNotEmpty) images.add(value);
    }
  }

  addFrom(data['mediaKeys']);
  addFrom(data['images']);

  final thumbnail = data['thumbnailKey']?.toString().trim() ?? '';
  if (thumbnail.isNotEmpty && !images.contains(thumbnail)) {
    images.insert(0, thumbnail);
  }

  return images.where((key) {
    if (key.startsWith('file://')) return false;
    if (key.startsWith('/') &&
        (key.contains('/tmp/') ||
            key.contains('image_picker') ||
            key.contains('/Containers/Data/Application'))) {
      return false;
    }
    return true;
  }).toList();
}

double _campaignToDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

int _campaignToInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// Donation Transaction
class DonationTransaction {
  final String id;
  final String campaignId;
  final DonationUser donor;
  final double amount;
  final DateTime donatedAt;
  final DonationStatus status;
  final String? message;
  final String? rewardTierId;
  final bool isAnonymous;
  final int karmaEarned;
  final String transactionHash;
  final String paymentMethod;

  const DonationTransaction({
    required this.id,
    required this.campaignId,
    required this.donor,
    required this.amount,
    required this.donatedAt,
    required this.status,
    this.message,
    this.rewardTierId,
    this.isAnonymous = false,
    required this.karmaEarned,
    required this.transactionHash,
    required this.paymentMethod,
  });

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
  
  String get donorName => isAnonymous ? 'Anonymous' : donor.name;

  Color get statusColor {
    switch (status) {
      case DonationStatus.completed: return Colors.green;
      case DonationStatus.pending: return Colors.orange;
      case DonationStatus.refunded: return AppColors.primary;
      case DonationStatus.failed: return Colors.red;
    }
  }
}

// Campaign Update
class CampaignUpdate {
  final String id;
  final String campaignId;
  final String title;
  final String content;
  final UpdateType type;
  final DateTime createdAt;
  final List<String> images;
  final String? videoUrl;
  final bool isPinned;
  final int likesCount;
  final int commentsCount;

  const CampaignUpdate({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.images,
    this.videoUrl,
    this.isPinned = false,
    required this.likesCount,
    required this.commentsCount,
  });

  Color get typeColor {
    switch (type) {
      case UpdateType.text: return AppColors.primary;
      case UpdateType.image: return Colors.green;
      case UpdateType.milestone: return Colors.purple;
      case UpdateType.thankyou: return Colors.pink;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case UpdateType.text: return Icons.article;
      case UpdateType.image: return Icons.image;
      case UpdateType.milestone: return Icons.flag;
      case UpdateType.thankyou: return Icons.favorite;
    }
  }
}

// Reward Tier
class RewardTier {
  final String id;
  final String campaignId;
  final String title;
  final String description;
  final double minimumDonation;
  final int? limitedQuantity;
  final int claimedCount;
  final RewardTierStatus status;
  final DateTime? estimatedDelivery;
  final List<String> includes;
  final bool isPhysical;
  final double? shippingCost;

  const RewardTier({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.description,
    required this.minimumDonation,
    this.limitedQuantity,
    required this.claimedCount,
    required this.status,
    this.estimatedDelivery,
    required this.includes,
    this.isPhysical = false,
    this.shippingCost,
  });

  String get formattedMinimumDonation => '\$${minimumDonation.toStringAsFixed(0)}';
  
  bool get isAvailable => status == RewardTierStatus.available && 
                         (limitedQuantity == null || claimedCount < limitedQuantity!);

  int? get remainingQuantity => limitedQuantity != null ? 
                               (limitedQuantity! - claimedCount) : null;

  String get availabilityText {
    if (status == RewardTierStatus.soldOut) return 'Sold Out';
    if (limitedQuantity != null) {
      return '${remainingQuantity} of ${limitedQuantity} left';
    }
    return 'Available';
  }
}

// Campaign Analytics
class CampaignAnalytics {
  final String campaignId;
  final int totalViews;
  final int uniqueVisitors;
  final int totalDonations;
  final double conversionRate;
  final Map<String, int> trafficSources;
  final Map<DateTime, double> dailyDonations;
  final Map<String, int> donorLocations;
  final double averageDonation;
  final List<String> topReferrers;

  const CampaignAnalytics({
    required this.campaignId,
    required this.totalViews,
    required this.uniqueVisitors,
    required this.totalDonations,
    required this.conversionRate,
    required this.trafficSources,
    required this.dailyDonations,
    required this.donorLocations,
    required this.averageDonation,
    required this.topReferrers,
  });

  String get formattedAverageDonation => '\$${averageDonation.toStringAsFixed(2)}';
  String get formattedConversionRate => '${(conversionRate * 100).toStringAsFixed(1)}%';
}

// Donation Filter Options
class DonationFilter {
  final List<CampaignCategory> categories;
  final double? minGoal;
  final double? maxGoal;
  final List<CampaignStatus> statuses;
  final bool? isLocal;
  final bool? isFeatured;
  final bool? isUrgent;
  final String? location;
  final DateTimeRange? dateRange;

  const DonationFilter({
    required this.categories,
    this.minGoal,
    this.maxGoal,
    required this.statuses,
    this.isLocal,
    this.isFeatured,
    this.isUrgent,
    this.location,
    this.dateRange,
  });
}

// Sort Options
class DonationSortOption {
  final String value;
  final String label;
  final String description;

  const DonationSortOption({
    required this.value,
    required this.label,
    required this.description,
  });
}

// Success Story
class SuccessStory {
  final String id;
  final Campaign campaign;
  final String summary;
  final String impactDescription;
  final List<String> beforeAfterImages;
  final List<String> testimonials;
  final DateTime completedAt;
  final Map<String, dynamic> impactMetrics;

  const SuccessStory({
    required this.id,
    required this.campaign,
    required this.summary,
    required this.impactDescription,
    required this.beforeAfterImages,
    required this.testimonials,
    required this.completedAt,
    required this.impactMetrics,
  });
}

// Campaign Draft (for creation process)
class CampaignDraft {
  String? title;
  String? story;
  double? goalAmount;
  CampaignCategory? category;
  DateTime? deadline;
  List<String> images;
  String? videoUrl;
  List<RewardTier> rewardTiers;
  String? location;
  List<String> tags;
  String? beneficiaryInfo;

  CampaignDraft({
    this.title,
    this.story,
    this.goalAmount,
    this.category,
    this.deadline,
    this.images = const [],
    this.videoUrl,
    this.rewardTiers = const [],
    this.location,
    this.tags = const [],
    this.beneficiaryInfo,
  });

  bool get isValid {
    return title != null && 
           title!.isNotEmpty &&
           story != null && 
           story!.isNotEmpty &&
           goalAmount != null && 
           goalAmount! > 0 &&
           category != null &&
           deadline != null &&
           deadline!.isAfter(DateTime.now());
  }

  double get completionPercentage {
    int completedFields = 0;
    int totalFields = 8;

    if (title?.isNotEmpty == true) completedFields++;
    if (story?.isNotEmpty == true) completedFields++;
    if (goalAmount != null && goalAmount! > 0) completedFields++;
    if (category != null) completedFields++;
    if (deadline != null) completedFields++;
    if (images.isNotEmpty) completedFields++;
    if (location?.isNotEmpty == true) completedFields++;
    if (tags.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }
}