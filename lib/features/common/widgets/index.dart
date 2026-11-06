// Common Widgets Exports
// This file exports all the common UI components for easy importing throughout the app

// User-related components
export 'user_avatar.dart';
export 'rating_stars.dart';

// Display components  
export 'byc_amount_display.dart';
export 'activity_card.dart';
export 'progress_components.dart';

// Interaction components
export 'interaction_components.dart';

// State components
export 'state_components.dart';

// Custom Cards
export 'custom_cards.dart';

// Re-export specific classes for convenience

// User Components
export 'user_avatar.dart' show
    UserAvatar,
    UserAvatarGroup,
    UserAvatarLarge,
    UserAvatarCompact,
    UserAvatarWithInfo,
    UserStatus,
    UserAvatarData;

export 'rating_stars.dart' show
    RatingStars,
    InteractiveRatingStars,
    RatingStarsCompact;

// Display Components
export 'byc_amount_display.dart' show
    BYCAmountDisplay,
    BYCBalanceCard,
    BYCAmountCompact,
    BYCTransactionDisplay,
    BYCPriceDisplay,
    BYCDisplaySize,
    BYCTransactionType;

export 'activity_card.dart' show
    ActivityCard,
    ActivityCardCompact,
    ActivityNotificationCard,
    ActivityType;

export 'progress_components.dart' show
    CountdownTimer,
    ProgressBar,
    CampaignProgressCard,
    LevelProgressIndicator,
    CountdownTimerStyle,
    ProgressBarStyle;

// Interaction Components
export 'interaction_components.dart' show
    CategoryChip,
    ActionButton,
    ConfirmationDialog,
    LoadingDialog,
    SuccessDialog,
    ActionButtonCompact,
    CategoryChipGroup,
    CategoryChipSize,
    ActionButtonStyle,
    ActionButtonSize,
    CategoryChipData;

// State Components
export 'state_components.dart' show
    EmptyState,
    ErrorState,
    LoadingState,
    NetworkState,
    SearchState,
    ShimmerLoading,
    ShimmerContainer,
    EmptyStateType,
    ErrorStateType,
    LoadingStateType;
    
// Custom Card Components
export 'custom_cards.dart' show
    BaseCard,
    TradeItemCard,
    GiftCard,
    CampaignCard,
    CommunityCard,
    TransactionCard,
    AchievementCard,
    NotificationCard,
    UserProfileCard,
    TradeItemCardStyle,
    GiftCardStyle,
    CampaignCardStyle,
    CommunityCardStyle,
    TransactionCardStyle,
    AchievementCardStyle,
    NotificationCardStyle,
    UserProfileCardStyle,
    TransactionType,
    TransactionStatus,
    NotificationType;
