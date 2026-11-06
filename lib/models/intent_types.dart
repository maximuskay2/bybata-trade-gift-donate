// Offer/Ask Intent Types
enum IntentType {
  offer('OFFER'),
  ask('ASK'),
  none('NONE');

  final String value;
  const IntentType(this.value);

  static IntentType fromString(String value) {
    return IntentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => IntentType.none,
    );
  }
}

enum IntentSubType {
  trade('TRADE'),
  give('GIVE'),
  request('REQUEST'),
  helpCampaign('HELP_CAMPAIGN'),
  none('NONE');

  final String value;
  const IntentSubType(this.value);

  static IntentSubType fromString(String value) {
    return IntentSubType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => IntentSubType.none,
    );
  }
}

enum FeedSourceType {
  trade('TRADE'),
  gift('GIFT'),
  post('POST'),
  campaign('CAMPAIGN');

  final String value;
  const FeedSourceType(this.value);

  static FeedSourceType fromString(String value) {
    return FeedSourceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FeedSourceType.post,
    );
  }
}
