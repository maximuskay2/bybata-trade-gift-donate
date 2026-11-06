/// Admin-configurable karma earn amounts — mirrors API `KarmaPointsConfig`.
class KarmaPointsConfig {
  final int tradeComplete;
  final int giftGiven;
  final int giftDefaultReward;
  final int giftRewardMin;
  final int giftRewardMax;
  final double donationKarmaPercent;
  final int makeDonation;
  final int createPost;
  final int helpCommunity;
  final int getVerified;
  final int referFriend;
  final int dailyLogin;
  final int joinEvent;
  final int positiveReview;
  final int negativeReview;
  final int profileLike;
  final int seedingBonus;

  const KarmaPointsConfig({
    this.tradeComplete = 1,
    this.giftGiven = 1,
    this.giftDefaultReward = 1,
    this.giftRewardMin = 1,
    this.giftRewardMax = 1,
    this.donationKarmaPercent = 10,
    this.makeDonation = 1,
    this.createPost = 5,
    this.helpCommunity = 10,
    this.getVerified = 50,
    this.referFriend = 1,
    this.dailyLogin = 5,
    this.joinEvent = 8,
    this.positiveReview = 10,
    this.negativeReview = 5,
    this.profileLike = 2,
    this.seedingBonus = 15,
  });

  static const KarmaPointsConfig defaults = KarmaPointsConfig();

  factory KarmaPointsConfig.fromJson(Map<String, dynamic> json) {
    int i(String k, int fallback) => (json[k] as num?)?.toInt() ?? fallback;
    double d(String k, double fallback) =>
        (json[k] as num?)?.toDouble() ?? fallback;
    return KarmaPointsConfig(
      tradeComplete: i('tradeComplete', 1),
      giftGiven: i('giftGiven', 1),
      giftDefaultReward: i('giftDefaultReward', 1),
      giftRewardMin: i('giftRewardMin', 1),
      giftRewardMax: i('giftRewardMax', 1),
      donationKarmaPercent: d('donationKarmaPercent', 10),
      makeDonation: i('makeDonation', 1),
      createPost: i('createPost', 5),
      helpCommunity: i('helpCommunity', 10),
      getVerified: i('getVerified', 50),
      referFriend: i('referFriend', 1),
      dailyLogin: i('dailyLogin', 5),
      joinEvent: i('joinEvent', 8),
      positiveReview: i('positiveReview', 10),
      negativeReview: i('negativeReview', 5),
      profileLike: i('profileLike', 2),
      seedingBonus: i('seedingBonus', 15),
    );
  }

  /// 10 BYC donated → 1 karma at default 10% (floored).
  int donationKarmaForAmount(double amount) {
    if (amount <= 0 || donationKarmaPercent <= 0) return 0;
    return (amount * donationKarmaPercent / 100).floor();
  }

  int clampGiftReward(int? value) {
    final base = value ?? giftDefaultReward;
    final min = giftRewardMin <= giftRewardMax ? giftRewardMin : giftRewardMax;
    final max = giftRewardMin <= giftRewardMax ? giftRewardMax : giftRewardMin;
    return base.clamp(min, max);
  }
}

/// In-memory cache updated after API fetch (fallback to [KarmaPointsConfig.defaults]).
class KarmaPointsConfigCache {
  KarmaPointsConfigCache._();
  static final KarmaPointsConfigCache instance = KarmaPointsConfigCache._();

  KarmaPointsConfig _config = KarmaPointsConfig.defaults;

  KarmaPointsConfig get current => _config;

  void update(KarmaPointsConfig config) {
    _config = config;
  }
}
