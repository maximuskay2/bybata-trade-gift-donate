import 'package:flutter/material.dart';
export '../../../core/models/app_models.dart' show NotificationType;

/// Card style enumerations and types for custom cards

enum TradeItemCardStyle { compact, standard, detailed }

enum GiftCardStyle { compact, standard, detailed }

enum CampaignCardStyle { compact, standard, detailed }

enum CommunityCardStyle { compact, standard, detailed }

enum TransactionCardStyle { compact, standard, detailed }

enum AchievementCardStyle { compact, standard, detailed }

enum NotificationCardStyle { compact, standard, detailed }

enum UserProfileCardStyle { compact, standard, detailed }

enum BYCAmountSize { small, medium, large }

enum BYCAmountStyle { positive, negative, neutral }

enum UserAvatarSize { small, medium, large }

enum RatingSize { small, medium, large }

enum TransactionType { 
  trade, 
  gift, 
  donation, 
  karma, 
  wallet, 
  other 
}

enum TransactionStatus { 
  pending, 
  completed, 
  cancelled, 
  failed 
}


/// Progress bar style configurations
enum ProgressBarStyle { 
  linear, 
  circular, 
  rounded 
}

/// Activity types for activity cards
enum ActivityType {
  trade,
  gift,
  donation,
  karma,
  achievement,
  community,
  system,
  other
}

/// Activity status indicators
enum ActivityStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  failed
}

/// Activity card display styles
enum ActivityCardStyle {
  compact,
  standard,
  expanded
}

/// Countdown timer display styles  
enum CountdownStyle {
  compact,
  standard,
  detailed
}

/// Category chip sizes
enum CategoryChipSize {
  small,
  medium, 
  large
}

/// Action button styles
enum ActionButtonStyle {
  primary,
  secondary,
  outlined,
  text,
  danger
}

/// Action button sizes
enum ActionButtonSize {
  small,
  medium,
  large
}

/// Loading state types
enum LoadingStateType {
  circular,
  linear,
  shimmer,
  skeleton
}

/// Empty state types
enum EmptyStateType {
  noData,
  noResults,
  noConnection,
  error,
  maintenance
}

/// Error state types
enum ErrorStateType {
  network,
  server,
  timeout,
  unknown,
  validation
}

/// Category chip data model
class CategoryChipData {
  final String id;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;

  const CategoryChipData({
    required this.id,
    required this.label,
    this.icon,
    this.color,
    this.isSelected = false,
  });

  CategoryChipData copyWith({
    String? id,
    String? label,
    IconData? icon,
    Color? color,
    bool? isSelected,
  }) {
    return CategoryChipData(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}