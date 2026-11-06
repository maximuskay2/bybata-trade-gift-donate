import '../../features/search/models/search_models.dart';

/// Normalizes mixed backend category strings for feed/search deserialization.
class ListingCategoryParser {
  ListingCategoryParser._();

  static SearchCategory parseSearchCategory(String? raw) {
    final key = raw?.trim().toLowerCase() ?? '';
    switch (key) {
      case 'trade':
      case 'trades':
      case 'swap':
      case 'barter':
        return SearchCategory.trades;
      case 'gift':
      case 'gifts':
      case 'give':
        return SearchCategory.gifts;
      case 'campaign':
      case 'campaigns':
      case 'donation':
      case 'donations':
      case 'fund':
      case 'fundraiser':
        return SearchCategory.campaigns;
      case 'community':
      case 'communities':
        return SearchCategory.communities;
      case 'user':
      case 'users':
      case 'profile':
        return SearchCategory.users;
      case 'all':
      case '':
        return SearchCategory.all;
      default:
        return SearchCategory.all;
    }
  }

  static String normalizeModuleLabel(String? raw) {
    switch (parseSearchCategory(raw)) {
      case SearchCategory.trades:
        return 'trade';
      case SearchCategory.gifts:
        return 'gift';
      case SearchCategory.campaigns:
        return 'campaign';
      case SearchCategory.communities:
        return 'community';
      case SearchCategory.users:
        return 'user';
      case SearchCategory.all:
        return 'unknown';
    }
  }
}
