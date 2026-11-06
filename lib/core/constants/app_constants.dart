class AppConstants {
  // App Information
  static const String appName = 'bYbata';
  static const String appTagline = 'Trade, Gift, Donate - Making the World Better!';
  static const String appMission = 'Building communities for a better world through sharing';
  static const String appVersion = '1.0.0';
  
  // Currency
  static const String bycCurrency = 'BYC';
  static const String bycFullName = 'bYbata Coin';
  static const String karmaPoints = 'KARMA';
  
  // Navigation Routes
  static const String homeRoute = '/home';
  static const String tradeRoute = '/trade';
  static const String giftingRoute = '/gifting';
  static const String donationsRoute = '/donations';
  static const String communityRoute = '/community';
  static const String walletRoute = '/wallet';
  static const String profileRoute = '/profile';
  static const String searchRoute = '/search';
  static const String karmaRoute = '/karma';
  
  // Auth Routes
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String onboardingRoute = '/onboarding';
  
  // Feature Routes
  static const String createTradeRoute = '/create-trade';
  static const String tradeDetailsRoute = '/trade-details';
  static const String createGiftRoute = '/create-gift';
  static const String editGiftRoute = '/edit-gift';
  static const String giftDetailsRoute = '/gift-details';
  static const String claimGiftRoute = '/claim-gift';
  static const String myGiftsRoute = '/my-gifts';
  static const String giftHistoryRoute = '/gift-history';
  static const String createCampaignRoute = '/create-campaign';
  static const String campaignDetailsRoute = '/campaign-details';
  static const String myCampaignsRoute = '/my-campaigns';
  static const String donationHistoryRoute = '/donation-history';
  static const String campaignManagementRoute = '/campaign-management';
  static const String createCommunityRoute = '/create-community';
  static const String communityDetailsRoute = '/community-details';
  static const String communityPostsRoute = '/community-posts';
  static const String createPostRoute = '/create-post';
  static const String eventsRoute = '/events';
  static const String membersRoute = '/members';
  static const String fundWalletRoute = '/fund-wallet';
  static const String transactionHistoryRoute = '/transaction-history';
  static const String karmaHistoryRoute = '/karma-history';
  
  // API Endpoints (for backend integration)
  static const String baseUrl = 'https://bybataapi-production.up.railway.app';
  
  // Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String karmaDataKey = 'karma_data';
  static const String pendingDeepLinkKey = 'pending_deep_link';
  
  // Default Values
  static const int defaultPageSize = 20;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const int initialKarmaPoints = 100; // Starting KARMA for new users
  
  // KARMA System Values (fallback — live values from GET /v1/karma/points-config)
  static const int karmaTradeComplete = 15;
  static const int karmaGiftGiven = 10;
  static const int karmaDonationMade = 10;
  static const int karmaCommunityPost = 10;
  static const int karmaCommunityHelp = 20;
  static const int karmaVerificationBonus = 100;
  
  // Image Assets Paths
  static const String logoPath = 'assets/images/logo.png';
  static const String placeholderImagePath = 'assets/images/placeholder.png';
  static const String karmaLogoPath = 'assets/images/karma_logo.png';
  
  // Feature Icons
  static const String tradeIconPath = 'assets/icons/trade.png';
  static const String giftIconPath = 'assets/icons/gift.png';
  static const String donateIconPath = 'assets/icons/donate.png';
  static const String communityIconPath = 'assets/icons/community.png';
  static const String walletIconPath = 'assets/icons/wallet.png';
  static const String karmaIconPath = 'assets/icons/karma.png';
}

// Enums
enum TradeStatus { active, completed, cancelled, negotiating }
enum GiftStatus { available, claimed, expired }
enum CampaignStatus { active, completed, paused, expired }
enum CommunityType { public, private, restricted }
enum CommunityRole { member, moderator, admin, owner }
enum PostType { text, image, poll, event, idea }
enum TransactionType { trade, gift, donation, wallet_funding, promotion, community_boost }
enum UserVerificationStatus { unverified, pending, verified }
enum NotificationType { karma_earned, trade_offer, gift_received, campaign_update, community_invite }

// KARMA System
enum KarmaLevel {
  newbie,      // 0-499 KARMA
  helper,      // 500-999 KARMA
  contributor, // 1000-2499 KARMA
  champion,    // 2500-4999 KARMA
  hero,        // 5000-9999 KARMA
  legend       // 10000+ KARMA
}

enum TrustLevel {
  unverified,  // No verification, new user
  basic,       // Email verified
  trusted,     // Phone + ID verified
  premium,     // High KARMA + verifications
  ambassador   // Top contributors
}

class AppStrings {
  // General
  static const String loading = 'Loading...';
  static const String error = 'An error occurred';
  static const String success = 'Success';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String share = 'Share';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String sort = 'Sort';
  static const String seeAll = 'See All';
  static const String viewMore = 'View More';
  
  // Navigation
  static const String home = 'Home';
  static const String trade = 'Trade';
  static const String gifting = 'Gifting';
  static const String donations = 'Donations';
  static const String community = 'Community';
  static const String wallet = 'Wallet';
  static const String profile = 'Profile';
  
  // Auth
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String forgotPassword = 'Forgot Password';
  static const String resetPassword = 'Reset Password';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String username = 'Username';
  static const String fullName = 'Full Name';
  static const String phone = 'Phone Number';
  static const String location = 'Location';
  
  // Trade
  static const String createTrade = 'Create Trade';
  static const String myTrades = 'My Trades';
  static const String browseItems = 'Browse Items';
  static const String tradeOffers = 'Trade Offers';
  static const String negotiate = 'Negotiate';
  static const String acceptOffer = 'Accept Offer';
  static const String rejectOffer = 'Reject Offer';
  static const String completeTrade = 'Complete Trade';
  static const String itemCondition = 'Item Condition';
  static const String itemDescription = 'Item Description';
  static const String itemCategory = 'Category';
  static const String estimatedValue = 'Estimated Value';
  
  // Gifting
  static const String createGift = 'Create Gift';
  static const String myGifts = 'My Gifts';
  static const String availableGifts = 'Available Gifts';
  static const String giftHistory = 'Gift History';
  static const String claimGift = 'Claim Gift';
  static const String giftClaimed = 'Gift Claimed';
  static const String giftExpired = 'Gift Expired';
  static const String randomGift = 'Random Gift';
  static const String targetedGift = 'Targeted Gift';
  
  // Donations
  static const String createCampaign = 'Create Campaign';
  static const String myCampaigns = 'My Campaigns';
  static const String browseCampaigns = 'Browse Campaigns';
  static const String donate = 'Donate';
  static const String campaignGoal = 'Campaign Goal';
  static const String amountRaised = 'Amount Raised';
  static const String daysLeft = 'Days Left';
  static const String supporters = 'Supporters';
  static const String campaignStory = 'Campaign Story';
  
  // Community
  static const String createCommunity = 'Create Community';
  static const String myCommunities = 'My Communities';
  static const String browseCommunities = 'Browse Communities';
  static const String joinCommunity = 'Join Community';
  static const String leaveCommunity = 'Leave Community';
  static const String communityRules = 'Community Rules';
  static const String shareIdea = 'Share Idea';
  static const String discussionBoard = 'Discussion Board';
  static const String communityEvents = 'Events';
  static const String members = 'Members';
  static const String moderators = 'Moderators';
  static const String communityGoals = 'Community Goals';
  
  // Wallet
  static const String bycBalance = 'BYC Balance';
  static const String fundWallet = 'Fund Wallet';
  static const String transactionHistory = 'Transaction History';
  static const String sendBYC = 'Send BYC';
  static const String receiveBYC = 'Receive BYC';
  static const String promoteTrade = 'Promote Trade';
  static const String promoteGift = 'Promote Gift';
  static const String promoteCampaign = 'Promote Campaign';
  static const String promoteCommunity = 'Promote Community';
  static const String conversionRate = 'Conversion Rate';
  
  // KARMA System
  static const String karmaPoints = 'KARMA Points';
  static const String karmaLevel = 'KARMA Level';
  static const String trustLevel = 'Trust Level';
  static const String karmaHistory = 'KARMA History';
  static const String earnKarma = 'Earn KARMA';
  static const String karmaRewards = 'KARMA Rewards';
  static const String nextLevel = 'Next Level';
  static const String karmaLeaderboard = 'KARMA Leaderboard';
  
  // KARMA Level Names
  static const String karmaNewbie = 'Newbie';
  static const String karmaHelper = 'Helper';
  static const String karmaContributor = 'Contributor';
  static const String karmaChampion = 'Champion';
  static const String karmaHero = 'Hero';
  static const String karmaLegend = 'Legend';
  
  // Trust Level Names
  static const String trustUnverified = 'Unverified';
  static const String trustBasic = 'Basic';
  static const String trustTrusted = 'Trusted';
  static const String trustPremium = 'Premium';
  static const String trustAmbassador = 'Ambassador';
  
  // Profile
  static const String editProfile = 'Edit Profile';
  static const String verifyAccount = 'Verify Account';
  static const String activityHistory = 'Activity History';
  static const String settings = 'Settings';
  static const String notifications = 'Notifications';
  static const String privacy = 'Privacy';
  static const String security = 'Security';
  static const String helpSupport = 'Help & Support';
  static const String aboutApp = 'About bYbata';
  
  // Messages
  static const String welcomeMessage = 'Welcome to bYbata!';
  static const String karmaEarnedMessage = 'You earned KARMA points!';
  static const String levelUpMessage = 'Congratulations! You leveled up!';
  static const String tradeCompletedMessage = 'Trade completed successfully!';
  static const String giftReceivedMessage = 'You received a gift!';
  static const String donationReceivedMessage = 'Your campaign received a donation!';
  static const String communityJoinedMessage = 'Welcome to the community!';
  
  // Onboarding
  static const String onboardingTitle1 = 'Trade Without Money';
  static const String onboardingDesc1 = 'Exchange items you don\'t need for things you want';
  static const String onboardingTitle2 = 'Give & Receive Gifts';
  static const String onboardingDesc2 = 'Share joy by giving gifts to fellow community members';
  static const String onboardingTitle3 = 'Support Causes';
  static const String onboardingDesc3 = 'Donate to campaigns and make a positive impact';
  static const String onboardingTitle4 = 'Build Communities';
  static const String onboardingDesc4 = 'Join like-minded people working for a better world';
  static const String onboardingTitle5 = 'Earn KARMA & Trust';
  static const String onboardingDesc5 = 'Build your reputation through positive actions';
}