/// Carries ecosystem seeding intent from empty-feed CTAs into create flows.
class ListingSeedingContext {
  ListingSeedingContext._();

  static bool _pendingTrade = false;
  static bool _pendingGift = false;

  static void markTradeSeed() => _pendingTrade = true;
  static void markGiftSeed() => _pendingGift = true;

  static bool consumeTradeSeed() {
    if (!_pendingTrade) return false;
    _pendingTrade = false;
    return true;
  }

  static bool consumeGiftSeed() {
    if (!_pendingGift) return false;
    _pendingGift = false;
    return true;
  }
}
