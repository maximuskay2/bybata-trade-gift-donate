import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bybata/core/utils/media_utils.dart';
import 'byc_amount_display.dart';
import 'user_avatar.dart';
import 'rating_stars.dart';
import 'karma_level_badge.dart';
import 'progress_components.dart';
import 'interaction_components.dart' as ui;
import '../../../core/compliance/ios_campaign_support.dart';
import 'card_types.dart' as types;
import '../../../core/utils/media_utils.dart';
import 'package:bybata/core/theme/app_theme.dart';

// Type aliases for card enums and related types from types only
typedef TradeItemCardStyle = types.TradeItemCardStyle;
typedef GiftCardStyle = types.GiftCardStyle;
typedef CampaignCardStyle = types.CampaignCardStyle;
typedef CommunityCardStyle = types.CommunityCardStyle;
typedef TransactionCardStyle = types.TransactionCardStyle;
typedef AchievementCardStyle = types.AchievementCardStyle;
typedef NotificationCardStyle = types.NotificationCardStyle;
typedef UserProfileCardStyle = types.UserProfileCardStyle;

typedef TransactionType = types.TransactionType;
typedef TransactionStatus = types.TransactionStatus;
typedef NotificationType = types.NotificationType;

/// Base card widget with consistent styling
class BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const BaseCard({
    Key? key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.elevation,
    this.backgroundColor,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: elevation ?? 2,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

/// Trade item card for marketplace items
class TradeItemCard extends StatelessWidget {
  final String itemName;
  final String? itemDescription;
  final String? imageUrl;
  final List<String>? additionalImages;
  final double? price;
  final String? currency;
  final String sellerName;
  final String? sellerImageUrl;
  final double? sellerRating;
  final String? location;
  final String? condition;
  final String? category;
  final DateTime? postedAt;
  final bool isFavorite;
  final bool isVerifiedSeller;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onSellerTap;
  final TradeItemCardStyle style;

  const TradeItemCard({
    Key? key,
    required this.itemName,
    this.itemDescription,
    this.imageUrl,
    this.additionalImages,
    this.price,
    this.currency,
    required this.sellerName,
    this.sellerImageUrl,
    this.sellerRating,
    this.location,
    this.condition,
    this.category,
    this.postedAt,
    this.isFavorite = false,
    this.isVerifiedSeller = false,
    this.onTap,
    this.onFavorite,
    this.onSellerTap,
    this.style = TradeItemCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          const SizedBox(height: 12),
_buildItemInfo(context),
          const SizedBox(height: 12),
          _buildSellerInfo(),
          if (style == TradeItemCardStyle.detailed) ...[
            const SizedBox(height: 12),
            _buildItemDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  )
                : Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.grey.shade400,
                    size: 40,
                  ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              if (category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onFavorite,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey.shade600,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (additionalImages != null && additionalImages!.isNotEmpty)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '+${additionalImages!.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

Widget _buildItemInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          itemName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (itemDescription != null && style != TradeItemCardStyle.compact) ...[
          const SizedBox(height: 4),
          Text(
            itemDescription!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (price != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (currency == 'BYC')
BYCAmountDisplay(
                  amount: price!,
                  size: BYCDisplaySize.medium,
                  showIcon: true,
                )
              else
                Text(
                  '${currency ?? '\$'}${price!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              const Spacer(),
              if (condition != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
color: _getConditionColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getConditionColor(), width: 1),
                  ),
                  child: Text(
                    condition!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getConditionColor(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSellerInfo() {
    return Row(
      children: [
        GestureDetector(
          onTap: onSellerTap,
child: UserAvatar(
            imageUrl: sellerImageUrl,
            name: sellerName,
            size: 28,
            isVerified: isVerifiedSeller,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sellerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  if (sellerRating != null) ...[
RatingStars(
                      rating: sellerRating!,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (location != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (postedAt != null)
          Text(
            _formatTimestamp(postedAt!),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
            ),
          ),
      ],
    );
  }

  Widget _buildItemDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ui.ActionButton(
              text: 'Message',
              icon: Icons.chat_bubble_outline,
              style: ui.ActionButtonStyle.primary,
              size: ui.ActionButtonSize.small,
              onPressed: () {},
            ),
            ui.ActionButton(
              text: 'Make Offer',
              icon: Icons.local_offer_outlined,
              style: ui.ActionButtonStyle.outline,
              size: ui.ActionButtonSize.small,
              onPressed: () {},
            ),
            ui.ActionButton(
              text: 'Share',
              icon: Icons.share_outlined,
              style: ui.ActionButtonStyle.text,
              size: ui.ActionButtonSize.small,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  Color _getConditionColor() {
    switch (condition?.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'like new':
        return AppColors.primary;
      case 'good':
        return Colors.orange;
      case 'fair':
        return Colors.amber;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Gift card for gift marketplace
class GiftCard extends StatelessWidget {
  final String giftName;
  final String? giftDescription;
  final String? imageUrl;
  final double? price;
  final String? currency;
  final String? giftType;
  final bool isDigital;
  final int availableQuantity;
  final DateTime? expiryDate;
  final String? brandName;
  final String? brandLogo;
  final bool isFeatured;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final GiftCardStyle style;

  const GiftCard({
    Key? key,
    required this.giftName,
    this.giftDescription,
    this.imageUrl,
    this.price,
    this.currency,
    this.giftType,
    this.isDigital = false,
    this.availableQuantity = 1,
    this.expiryDate,
    this.brandName,
    this.brandLogo,
    this.isFeatured = false,
    this.onTap,
    this.onAddToCart,
    this.style = GiftCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      backgroundColor: isFeatured ? Colors.amber.shade50 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          const SizedBox(height: 12),
_buildGiftInfo(context),
          if (style == GiftCardStyle.detailed) ...[
            const SizedBox(height: 12),
            _buildGiftDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade100,
                  Colors.pink.shade100,
                ],
              ),
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.card_giftcard,
                          color: Colors.pink.shade300,
                          size: 40,
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.card_giftcard,
                    color: Colors.pink.shade300,
                    size: 40,
                  ),
          ),
        ),
        if (isFeatured)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Featured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (isDigital)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Digital',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (brandLogo != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: brandLogo!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Icon(
                    Icons.business,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

Widget _buildGiftInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brandName != null)
          Text(
            brandName!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          giftName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (giftDescription != null && style != GiftCardStyle.compact) ...[
          const SizedBox(height: 4),
          Text(
            giftDescription!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            if (price != null)
              Expanded(
child: currency == 'BYC'
                    ? BYCAmountDisplay(
                        amount: price!,
                        size: BYCDisplaySize.medium,
                        showIcon: true,
                      )
                    : Text(
                        '${currency ?? '\$'}${price!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
              ),
            if (availableQuantity <= 5)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Only $availableQuantity left',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGiftDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (giftType != null)
                    _buildDetailRow(Icons.category, 'Type', giftType!),
                  if (expiryDate != null) ...[
                    const SizedBox(height: 4),
                    _buildDetailRow(
                      Icons.schedule,
                      'Expires',
                      _formatExpiryDate(expiryDate!),
                    ),
                  ],
                ],
              ),
            ),
ui.ActionButton(
            text: 'Add to Cart',
            icon: Icons.shopping_cart_outlined,
style: ui.ActionButtonStyle.primary,
size: ui.ActionButtonSize.small,
            onPressed: onAddToCart,
          ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatExpiryDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Campaign card for donation campaigns
class CampaignCard extends StatelessWidget {
  final String campaignTitle;
  final String? campaignDescription;
  final String? imageUrl;
  final String organizerName;
  final String? organizerImageUrl;
  final double targetAmount;
  final double currentAmount;
  final String currency;
  final int daysLeft;
  final int supportersCount;
  final String? category;
  final bool isVerified;
  final bool isUrgent;
  final VoidCallback? onTap;
  final VoidCallback? onDonate;
  final VoidCallback? onShare;
  final CampaignCardStyle style;

  const CampaignCard({
    Key? key,
    required this.campaignTitle,
    this.campaignDescription,
    this.imageUrl,
    required this.organizerName,
    this.organizerImageUrl,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    required this.daysLeft,
    required this.supportersCount,
    this.category,
    this.isVerified = false,
    this.isUrgent = false,
    this.onTap,
    this.onDonate,
    this.onShare,
    this.style = CampaignCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      backgroundColor: isUrgent ? Colors.red.shade50 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          const SizedBox(height: 12),
          _buildCampaignInfo(),
          const SizedBox(height: 12),
_buildProgressSection(context),
          const SizedBox(height: 12),
          _buildOrganizerInfo(),
          if (style == CampaignCardStyle.detailed) ...[
            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: () {
                      final value = imageUrl!;
                      final isAbsolute = value.startsWith('http://') || value.startsWith('https://');
                      if (isAbsolute) {
                        return CachedNetworkImage(
                          imageUrl: value,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Icon(
                            Icons.campaign,
                            color: Colors.grey.shade400,
                            size: 40,
                          ),
                        );
                      }
                      return FutureBuilder<String?>(
                        future: MediaResolver.resolveUrl(value),
                        builder: (context, snapshot) {
                          final resolved = snapshot.data;
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Icon(
                              Icons.campaign,
                              color: Colors.grey.shade400,
                              size: 40,
                            );
                          }
                          if (resolved == null || resolved.isEmpty) {
                            return Icon(
                              Icons.campaign,
                              color: Colors.grey.shade400,
                              size: 40,
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: resolved,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Icon(
                              Icons.campaign,
                              color: Colors.grey.shade400,
                              size: 40,
                            ),
                          );
                        },
                      );
                    }(),
                  )
                : Icon(
                    Icons.campaign,
                    color: Colors.grey.shade400,
                    size: 40,
                  ),
          ),
        ),
        if (isUrgent)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Urgent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (category != null)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                category!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (isVerified)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCampaignInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          campaignTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (campaignDescription != null && style != CampaignCardStyle.compact) ...[
          const SizedBox(height: 4),
          Text(
            campaignDescription!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

Widget _buildProgressSection(BuildContext context) {
    final progress = currentAmount / targetAmount;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: currency == 'BYC'
? BYCAmountDisplay(
                      amount: currentAmount,
                      size: BYCDisplaySize.large,
                      showIcon: true,
                    )
                  : Text(
                      '${currency}${currentAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
            ),
            Text(
              'of ${currency == 'BYC' ? 'BYC' : currency}${targetAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
ProgressBar(
          value: progress,
          style: ProgressBarStyle.withLabel,
          valueColor: isUrgent ? Colors.red : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${(progress * 100).toStringAsFixed(0)}% funded',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.people, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '$supportersCount supporters',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '$daysLeft days left',
              style: TextStyle(
                fontSize: 12,
                color: daysLeft <= 3 ? Colors.red.shade600 : Colors.grey.shade600,
                fontWeight: daysLeft <= 3 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrganizerInfo() {
    return Row(
      children: [
UserAvatar(
          imageUrl: organizerImageUrl,
          name: organizerName,
          size: 28,
          isVerified: isVerified,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organized by',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                organizerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
Expanded(
          child: ui.ActionButton(
            text: CampaignSupportCompliance.blocksInAppDonations
                ? 'SUPPORT'
                : 'Donate Now',
            icon: Icons.volunteer_activism,
style: ui.ActionButtonStyle.primary,
size: ui.ActionButtonSize.small,
            onPressed: onDonate,
          ),
        ),
        const SizedBox(width: 12),
ui.ActionButton(
          text: 'Share',
          icon: Icons.share,
          style: ui.ActionButtonStyle.outline,
          size: ui.ActionButtonSize.small,
          onPressed: onShare,
        ),
      ],
    );
  }
}

/// Community card for community previews
class CommunityCard extends StatelessWidget {
  final String communityName;
  final String? communityDescription;
  final String? communityImage;
  final int memberCount;
  final String? category;
  final bool isPublic;
  final bool isJoined;
  final bool isVerified;
  final List<String>? memberImages;
  final int? postCount;
  final String? recentActivity;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final CommunityCardStyle style;

  const CommunityCard({
    Key? key,
    required this.communityName,
    this.communityDescription,
    this.communityImage,
    required this.memberCount,
    this.category,
    this.isPublic = true,
    this.isJoined = false,
    this.isVerified = false,
    this.memberImages,
    this.postCount,
    this.recentActivity,
    this.onTap,
    this.onJoin,
    this.style = CommunityCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildCommunityInfo(),
          const SizedBox(height: 12),
          _buildMemberInfo(),
          if (style == CommunityCardStyle.detailed) ...[
            const SizedBox(height: 12),
            _buildActivityInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade200,
          ),
          child: communityImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    communityImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.groups,
                        color: Colors.grey.shade400,
                        size: 24,
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.groups,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      communityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified)
                    Icon(
                      Icons.verified,
                      color: AppColors.primary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    isPublic ? Icons.public : Icons.lock,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isPublic ? 'Public' : 'Private',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (category != null) ...[
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(width: 8),
                    Text(
                      category!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (communityDescription != null && style != CommunityCardStyle.compact)
          Text(
            communityDescription!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildMemberInfo() {
    return Row(
      children: [
        if (memberImages != null && memberImages!.isNotEmpty) ...[
UserAvatarGroup(
            users: memberImages!.map((url) => UserAvatarData(imageUrl: url, name: 'Member')).toList(),
            avatarSize: 24,
            maxVisible: 4,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            '$memberCount member${memberCount != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
if (!isJoined)
          ui.ActionButton(
            text: 'Join',
style: ui.ActionButtonStyle.primary,
size: ui.ActionButtonSize.small,
            onPressed: onJoin,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Joined',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            if (postCount != null) ...[
              Icon(Icons.post_add, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                '$postCount posts',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (postCount != null && recentActivity != null) ...[
              const SizedBox(width: 16),
              Text('•', style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(width: 16),
            ],
            if (recentActivity != null) ...[
              Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  recentActivity!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Transaction card for wallet transactions
class TransactionCard extends StatelessWidget {
  final String transactionId;
  final String title;
  final String? description;
  final double amount;
  final String currency;
  final TransactionType type;
  final TransactionStatus status;
  final DateTime timestamp;
  final String? recipientName;
  final String? recipientImageUrl;
  final String? senderName;
  final String? senderImageUrl;
  final String? reference;
  final VoidCallback? onTap;
  final TransactionCardStyle style;

  const TransactionCard({
    Key? key,
    required this.transactionId,
    required this.title,
    this.description,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    required this.timestamp,
    this.recipientName,
    this.recipientImageUrl,
    this.senderName,
    this.senderImageUrl,
    this.reference,
    this.onTap,
    this.style = TransactionCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildTransactionIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTransactionInfo(),
                if (style == TransactionCardStyle.detailed) ...[
                  const SizedBox(height: 4),
                  _buildTransactionDetails(),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildAmountDisplay(),
              const SizedBox(height: 4),
              _buildStatusAndTime(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionIcon() {
    IconData icon;
    Color color;

switch (type) {
      case TransactionType.trade:
        icon = Icons.swap_horiz;
        color = AppColors.primary;
        break;
      case TransactionType.gift:
        icon = Icons.card_giftcard;
        color = Colors.pink;
        break;
      case TransactionType.donation:
        icon = Icons.volunteer_activism;
        color = Colors.orange;
        break;
      case TransactionType.karma:
        icon = Icons.star;
        color = Colors.amber;
        break;
      case TransactionType.wallet:
        icon = Icons.account_balance_wallet;
        color = Colors.green;
        break;
      case TransactionType.other:
        icon = Icons.receipt_long;
        color = Colors.grey;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildTransactionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recipientName != null || senderName != null)
          Row(
            children: [
Icon(
                recipientName != null ? Icons.arrow_forward : Icons.arrow_back,
                size: 12,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                recipientName != null
                    ? 'To $recipientName'
                    : (senderName != null ? 'From $senderName' : ''),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        if (reference != null) ...[
          const SizedBox(height: 2),
          Text(
            'Ref: $reference',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade400,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAmountDisplay() {
final isNegative = type == TransactionType.donation || type == TransactionType.trade;
    final sign = isNegative ? '-' : '+';
    
    return currency == 'BYC'
? BYCAmountDisplay(
            amount: amount,
            size: BYCDisplaySize.small,
            showIcon: true,
            isPositive: !isNegative,
            prefix: isNegative ? '-' : '+',
          )
        : Text(
            '$sign${currency}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isNegative ? Colors.red : Colors.green,
            ),
          );
  }

  Widget _buildStatusAndTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
color: _getStatusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _getStatusColor(),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatTimestamp(timestamp),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (status) {
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Achievement card for KARMA achievements
class AchievementCard extends StatelessWidget {
  final String achievementTitle;
  final String achievementDescription;
  final String? iconUrl;
  final IconData? icon;
  final int karmaPoints;
  final String? badgeType;
  final DateTime unlockedAt;
  final bool isUnlocked;
  final double? progress;
  final String? requirement;
  final VoidCallback? onTap;
  final AchievementCardStyle style;

  const AchievementCard({
    Key? key,
    required this.achievementTitle,
    required this.achievementDescription,
    this.iconUrl,
    this.icon,
    required this.karmaPoints,
    this.badgeType,
    required this.unlockedAt,
    this.isUnlocked = false,
    this.progress,
    this.requirement,
    this.onTap,
    this.style = AchievementCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      backgroundColor: isUnlocked ? Colors.amber.shade50 : null,
      child: Row(
        children: [
          _buildAchievementIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAchievementInfo(),
                if (style == AchievementCardStyle.detailed) ...[
                  const SizedBox(height: 8),
                  _buildAchievementDetails(),
                ],
              ],
            ),
          ),
          _buildKarmaPoints(),
        ],
      ),
    );
  }

  Widget _buildAchievementIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: isUnlocked
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.amber, Colors.orange],
              )
            : null,
        color: isUnlocked ? null : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: isUnlocked
            ? [
                BoxShadow(
color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: iconUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.network(
                iconUrl!,
                fit: BoxFit.cover,
                color: isUnlocked ? null : Colors.grey.shade400,
                colorBlendMode: isUnlocked ? null : BlendMode.saturation,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    icon ?? Icons.emoji_events,
                    color: isUnlocked ? Colors.white : Colors.grey.shade400,
                    size: 30,
                  );
                },
              ),
            )
          : Icon(
              icon ?? Icons.emoji_events,
              color: isUnlocked ? Colors.white : Colors.grey.shade400,
              size: 30,
            ),
    );
  }

  Widget _buildAchievementInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                achievementTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? Colors.black : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
color: _getBadgeColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeType!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getBadgeColor(),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          achievementDescription,
          style: TextStyle(
            fontSize: 14,
            color: isUnlocked ? Colors.grey.shade600 : Colors.grey.shade500,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (!isUnlocked && progress != null) ...[
          const SizedBox(height: 8),
ProgressBar(
            value: progress!,
            style: ProgressBarStyle.withLabel,
            height: 6,
          ),
        ],
      ],
    );
  }

  Widget _buildAchievementDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requirement != null && !isUnlocked)
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  requirement!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        if (isUnlocked) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Unlocked ${_formatTimestamp(unlockedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildKarmaPoints() {
return KarmaLevelBadge(
      karmaPoints: karmaPoints,
      showLabel: false,
      size: KarmaBadgeSize.small,
    );
  }

  Color _getBadgeColor() {
    switch (badgeType?.toLowerCase()) {
      case 'bronze':
        return Colors.brown;
      case 'silver':
        return Colors.grey.shade600;
      case 'gold':
        return Colors.amber;
      case 'diamond':
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays < 1) {
      return 'today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Notification card for app notifications
class NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? imageUrl;
  final String? actionText;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final NotificationCardStyle style;

  const NotificationCard({
    Key? key,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.imageUrl,
    this.actionText,
    this.onTap,
    this.onAction,
    this.onDismiss,
    this.style = NotificationCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      backgroundColor: isRead ? null : AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          _buildNotificationIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
_buildNotificationInfo(context),
                if (style == NotificationCardStyle.detailed && actionText != null) ...[
                  const SizedBox(height: 8),
                  _buildActionButton(),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.message:
        icon = Icons.message;
        color = AppColors.primary;
        break;
      case NotificationType.trade:
        icon = Icons.swap_horiz;
        color = Colors.green;
        break;
      case NotificationType.gift:
        icon = Icons.card_giftcard;
        color = Colors.pink;
        break;
      case NotificationType.campaign:
        icon = Icons.campaign;
        color = Colors.orange;
        break;
      case NotificationType.achievement:
        icon = Icons.emoji_events;
        color = Colors.amber;
        break;
      case NotificationType.system:
        icon = Icons.notifications_rounded;
        color = const Color(0xFF7E57C2);
        break;
      case NotificationType.reminder:
        icon = Icons.notifications;
        color = Colors.purple;
        break;
    }

    if (imageUrl != null) {
      final value = imageUrl!;
      final isAbsolute = value.startsWith('http://') || value.startsWith('https://');
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isAbsolute
              ? Image.network(
                  value,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(icon, color: color, size: 20);
                  },
                )
              : FutureBuilder<String?>(
                  future: MediaResolver.resolveUrl(value),
                  builder: (context, snapshot) {
                    final resolved = snapshot.data;
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Icon(icon, color: color, size: 20);
                    }
                    if (resolved == null || resolved.isEmpty) {
                      return Icon(icon, color: color, size: 20);
                    }
                    return Image.network(
                      resolved,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(icon, color: color, size: 20);
                      },
                    );
                  },
                ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

Widget _buildNotificationInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                margin: const EdgeInsets.only(right: 8),
              ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.3,
          ),
          maxLines: style == NotificationCardStyle.compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionButton() {
return ui.ActionButton(
      text: actionText!,
style: ui.ActionButtonStyle.primary,
size: ui.ActionButtonSize.small,
      onPressed: onAction,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// User profile card for user summaries
class UserProfileCard extends StatelessWidget {
  final String userName;
  final String? userBio;
  final String? userImageUrl;
  final String? coverImageUrl;
  final int karmaPoints;
  final double? userRating;
  final int? followersCount;
  final int? followingCount;
  final bool isFollowing;
  final bool isVerified;
  final bool isOnline;
  final List<String>? badges;
  final String? location;
  final DateTime? joinedDate;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;
  final UserProfileCardStyle style;

  const UserProfileCard({
    Key? key,
    required this.userName,
    this.userBio,
    this.userImageUrl,
    this.coverImageUrl,
    required this.karmaPoints,
    this.userRating,
    this.followersCount,
    this.followingCount,
    this.isFollowing = false,
    this.isVerified = false,
    this.isOnline = false,
    this.badges,
    this.location,
    this.joinedDate,
    this.onTap,
    this.onFollow,
    this.onMessage,
    this.style = UserProfileCardStyle.standard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
_buildCoverSection(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildUserInfo(),
                if (style == UserProfileCardStyle.detailed) ...[
                  const SizedBox(height: 12),
                  _buildUserDetails(),
                ],
                const SizedBox(height: 12),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCoverSection(BuildContext context) {
    return Stack(
      children: [
        // Cover Image
        Container(
          height: style == UserProfileCardStyle.compact ? 80 : 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            gradient: coverImageUrl == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
                Theme.of(context).primaryColor.withValues(alpha: 0.4),
                    ],
                  )
                : null,
          ),
          child: coverImageUrl != null
              ? ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
colors: [
                            Theme.of(context).primaryColor.withValues(alpha: 0.8),
                            Theme.of(context).primaryColor.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              : null,
        ),
        // Profile Avatar
        Positioned(
          bottom: -30,
          left: 16,
child: UserAvatar(
            imageUrl: userImageUrl,
            name: userName,
            size: 64,
            status: isOnline ? UserStatus.online : UserStatus.offline,
            isVerified: isVerified,
            borderColor: Colors.white,
          ),
        ),
        // KARMA Badge
        Positioned(
          bottom: -15,
          right: 16,
          child: KarmaLevelBadge(
            karmaPoints: karmaPoints,
            size: KarmaBadgeSize.medium,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30), // Space for avatar overlap
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userBio != null && style != UserProfileCardStyle.compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      userBio!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (userRating != null) ...[
RatingStars(
                rating: userRating!,
                size: 14,
              ),
              const SizedBox(width: 16),
            ],
            if (followersCount != null) ...[
              Text(
                '$followersCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'followers',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
            ],
            if (followingCount != null) ...[
              Text(
                '$followingCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'following',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildUserDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badges != null && badges!.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: badges!.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (joinedDate != null)
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                'Joined ${_formatJoinDate(joinedDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (!isFollowing)
          Expanded(
child: ui.ActionButton(
              text: 'Follow',
              icon: Icons.person_add,
style: ui.ActionButtonStyle.primary,
size: ui.ActionButtonSize.small,
              onPressed: onFollow,
            ),
          )
        else
          Expanded(
child: ui.ActionButton(
              text: 'Following',
              icon: Icons.check,
style: ui.ActionButtonStyle.secondary,
size: ui.ActionButtonSize.small,
              onPressed: onFollow,
            ),
          ),
        const SizedBox(width: 12),
ui.ActionButton(
          text: 'Message',
          icon: Icons.message,
          style: ui.ActionButtonStyle.outline,
          size: ui.ActionButtonSize.small,
          onPressed: onMessage,
        ),
      ],
    );
  }

  String _formatJoinDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

