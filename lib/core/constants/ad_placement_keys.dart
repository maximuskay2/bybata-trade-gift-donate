/// Must match [AdPlacement] keys in the API and admin /ad-placements.
/// Each key maps to an [AdPlacementSection] in the app.
class AdPlacementKeys {
  AdPlacementKeys._();

  static const homeFeed = 'home_feed';
  static const tradeFeed = 'trade_feed';
  static const giftFeed = 'gift_feed';
  static const campaignFeed = 'campaign_feed';
  static const communityFeed = 'community_feed';
  static const searchFeed = 'search_feed';

  /// Admin may still store `donation_feed`; API treats it as [campaignFeed].
  static const donationFeedAlias = 'donation_feed';

  static const allAppSurfaces = [
    homeFeed,
    tradeFeed,
    giftFeed,
    campaignFeed,
    communityFeed,
    searchFeed,
  ];

  static String? screenLabel(String key) {
    switch (key) {
      case homeFeed:
        return 'Home';
      case tradeFeed:
        return 'Trades';
      case giftFeed:
        return 'Gifts';
      case campaignFeed:
      case donationFeedAlias:
        return 'Donations';
      case communityFeed:
        return 'Community';
      case searchFeed:
        return 'Search';
      default:
        return null;
    }
  }
}
