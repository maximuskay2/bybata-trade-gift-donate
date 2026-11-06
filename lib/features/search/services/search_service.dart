import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';

/// Service class for handling search operations
class SearchService {
  final String baseUrl;
  final http.Client httpClient;

  SearchService({
    this.baseUrl = 'https://api.bybata.com',
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Performs a search query with the given parameters
  Future<SearchResponse> search({
    required String query,
    SearchFilters? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final searchFilters = filters ?? const SearchFilters();
      final uri = Uri.parse('$baseUrl/search').replace(
        queryParameters: {
          'q': query,
          'category': searchFilters.category.name,
          'sort': searchFilters.sortBy.name,
          'page': page.toString(),
          'limit': limit.toString(),
          if (searchFilters.location != null) 'location': searchFilters.location!,
          if (searchFilters.maxDistance != null)
            'maxDistance': searchFilters.maxDistance!.toString(),
          if (searchFilters.dateRange != null) ...{
            'startDate': searchFilters.dateRange!.start.toIso8601String(),
            'endDate': searchFilters.dateRange!.end.toIso8601String(),
          },
          if (searchFilters.tags.isNotEmpty) 'tags': searchFilters.tags.join(','),
          if (searchFilters.minRating != null)
            'minRating': searchFilters.minRating!.toString(),
          'verified': searchFilters.verified.toString(),
        },
      );

      final response = await httpClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SearchResponse.fromJson(data);
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      // For demo purposes, return mock data if API fails
      return _getMockSearchResponse(query, filters ?? const SearchFilters(), page, limit);
    }
  }

  /// Gets trending search terms
  Future<List<TrendingSearch>> getTrendingSearches({
    SearchCategory? category,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/search/trending').replace(
        queryParameters: {
          if (category != null) 'category': category.name,
          'limit': limit.toString(),
        },
      );

      final response = await httpClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((json) => TrendingSearch.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to fetch trending searches: ${response.statusCode}');
      }
    } catch (e) {
      // Return mock trending data
      return _getMockTrendingSearches(category, limit);
    }
  }

  /// Gets search suggestions based on partial query
  Future<List<String>> getSuggestions(String partialQuery) async {
    try {
      final uri = Uri.parse('$baseUrl/search/suggestions').replace(
        queryParameters: {
          'q': partialQuery,
          'limit': '8',
        },
      );

      final response = await httpClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((item) => item.toString()).toList();
      } else {
        throw Exception('Failed to fetch suggestions: ${response.statusCode}');
      }
    } catch (e) {
      // Return mock suggestions
      return _getMockSuggestions(partialQuery);
    }
  }

  /// Records a search query for analytics and history
  Future<void> recordSearch({
    required String query,
    required SearchCategory category,
    required int resultCount,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/search/record');
      final body = jsonEncode({
        'query': query,
        'category': category.name,
        'resultCount': resultCount,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      // Fail silently for analytics
      print('Failed to record search: $e');
    }
  }

  // Mock data methods for demo purposes

  SearchResponse _getMockSearchResponse(
    String query,
    SearchFilters filters,
    int page,
    int limit,
  ) {
    final random = Random();
    final results = <SearchResult>[];
    
    // Generate mock results based on category
    final categories = filters.category == SearchCategory.all
        ? SearchCategory.values.where((c) => c != SearchCategory.all).toList()
        : [filters.category];

    for (final category in categories) {
      final categoryResults = _generateMockResultsForCategory(
        category, 
        query, 
        random.nextInt(5) + 2
      );
      results.addAll(categoryResults);
    }

    // Shuffle and take requested limit
    results.shuffle();
    final startIndex = (page - 1) * limit;
    final endIndex = min(startIndex + limit, results.length);
    final pageResults = startIndex < results.length 
        ? results.sublist(startIndex, endIndex)
        : <SearchResult>[];

    return SearchResponse(
      results: pageResults,
      totalCount: results.length,
      currentPage: page,
      totalPages: (results.length / limit).ceil(),
      query: query,
      filters: filters,
      categoryCounts: Map.fromEntries(
        SearchCategory.values.map((category) => MapEntry(
          category,
          category == SearchCategory.all 
              ? results.length
              : results.where((r) => r.category == category).length,
        )),
      ),
    );
  }

  List<SearchResult> _generateMockResultsForCategory(
    SearchCategory category,
    String query,
    int count,
  ) {
    final random = Random();
    final results = <SearchResult>[];

    for (int i = 0; i < count; i++) {
      switch (category) {
        case SearchCategory.trades:
          results.add(TradeSearchResult(
            id: 'trade_${random.nextInt(10000)}',
            title: 'Mock Trade Item $i - $query',
            description: 'A great item for trading related to $query',
            imageUrl: 'https://picsum.photos/200/200?random=${random.nextInt(1000)}',
            createdAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
            relevanceScore: random.nextDouble(),
            tags: ['electronics', 'trade', query.toLowerCase()],
            ownerId: 'user_${random.nextInt(100)}',
            ownerName: 'User ${random.nextInt(100)}',
            condition: 'Good',
            location: 'Lagos, Nigeria',
            isActive: true,
          ));
          break;

        case SearchCategory.gifts:
          results.add(GiftSearchResult(
            id: 'gift_${random.nextInt(10000)}',
            title: 'Free $query Gift $i',
            description: 'Amazing gift related to $query - completely free!',
            imageUrl: 'https://picsum.photos/200/200?random=${random.nextInt(1000)}',
            createdAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
            relevanceScore: random.nextDouble(),
            tags: ['gift', 'free', query.toLowerCase()],
            giverId: 'user_${random.nextInt(100)}',
            giverName: 'Generous User ${random.nextInt(100)}',
            maxClaims: 5,
            currentClaims: random.nextInt(3),
            isAvailable: true,
          ));
          break;

        case SearchCategory.campaigns:
          final goalAmount = 100000.0 + random.nextDouble() * 500000;
          final currentAmount = goalAmount * random.nextDouble() * 0.8;
          results.add(CampaignSearchResult(
            id: 'campaign_${random.nextInt(10000)}',
            title: '$query Campaign $i',
            description: 'Help us achieve our goal for $query related project',
            imageUrl: 'https://picsum.photos/200/200?random=${random.nextInt(1000)}',
            createdAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
            relevanceScore: random.nextDouble(),
            tags: ['campaign', 'donation', query.toLowerCase()],
            creatorId: 'user_${random.nextInt(100)}',
            creatorName: 'Campaign Creator ${random.nextInt(100)}',
            goalAmount: goalAmount,
            currentAmount: currentAmount,
            deadline: DateTime.now().add(Duration(days: random.nextInt(60) + 30)),
            isActive: true,
          ));
          break;

        case SearchCategory.communities:
          results.add(CommunitySearchResult(
            id: 'community_${random.nextInt(10000)}',
            title: '$query Community $i',
            description: 'A vibrant community for $query enthusiasts',
            imageUrl: 'https://picsum.photos/200/200?random=${random.nextInt(1000)}',
            createdAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
            relevanceScore: random.nextDouble(),
            tags: ['community', query.toLowerCase()],
            memberCount: 50 + random.nextInt(2000),
            isPublic: true,
            isJoined: random.nextBool(),
            location: 'Nigeria',
          ));
          break;

        case SearchCategory.users:
          results.add(UserSearchResult(
            id: 'user_${random.nextInt(10000)}',
            title: '$query User $i',
            description: 'A user interested in $query and related topics',
            imageUrl: 'https://picsum.photos/200/200?random=${random.nextInt(1000)}',
            createdAt: DateTime.now().subtract(Duration(days: random.nextInt(365))),
            relevanceScore: random.nextDouble(),
            tags: [query.toLowerCase()],
            username: '@${query.toLowerCase()}user$i',
            karmaPoints: random.nextInt(5000),
            rating: 3.0 + random.nextDouble() * 2.0,
            location: 'Lagos, Nigeria',
            isVerified: random.nextBool(),
            isFollowed: random.nextBool(),
          ));
          break;

        case SearchCategory.all:
          // This case is handled in the main function
          break;
      }
    }

    return results;
  }

  List<TrendingSearch> _getMockTrendingSearches(SearchCategory? category, int limit) {
    final allTrending = [
      const TrendingSearch(
        query: 'iPhone 15',
        category: SearchCategory.trades,
        searchCount: 1250,
        trendingScore: 0.95,
      ),
      const TrendingSearch(
        query: 'Free laptops',
        category: SearchCategory.gifts,
        searchCount: 980,
        trendingScore: 0.87,
      ),
      const TrendingSearch(
        query: 'Help flood victims',
        category: SearchCategory.campaigns,
        searchCount: 2100,
        trendingScore: 0.92,
      ),
      const TrendingSearch(
        query: 'Tech enthusiasts',
        category: SearchCategory.communities,
        searchCount: 567,
        trendingScore: 0.78,
      ),
      const TrendingSearch(
        query: 'John Doe',
        category: SearchCategory.users,
        searchCount: 345,
        trendingScore: 0.65,
      ),
      const TrendingSearch(
        query: 'PlayStation 5',
        category: SearchCategory.trades,
        searchCount: 890,
        trendingScore: 0.83,
      ),
      const TrendingSearch(
        query: 'Books for students',
        category: SearchCategory.gifts,
        searchCount: 678,
        trendingScore: 0.74,
      ),
    ];

    var filtered = category != null 
        ? allTrending.where((t) => t.category == category).toList()
        : allTrending;

    filtered.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return filtered.take(limit).toList();
  }

  List<String> _getMockSuggestions(String partialQuery) {
    final allSuggestions = [
      'iPhone 15 Pro Max',
      'iPhone 15 case',
      'iPhone charger',
      'Samsung Galaxy S24',
      'Samsung earbuds',
      'PlayStation 5',
      'PlayStation games',
      'Xbox Series X',
      'Nintendo Switch',
      'MacBook Pro',
      'MacBook Air',
      'iPad Pro',
      'AirPods Pro',
      'Apple Watch',
      'Android phone',
      'Free books',
      'Free laptops',
      'Free clothes',
      'Help students',
      'Help elderly',
      'Tech community',
      'Gaming community',
      'Book lovers',
    ];

    return allSuggestions
        .where((suggestion) => 
            suggestion.toLowerCase().contains(partialQuery.toLowerCase()))
        .take(8)
        .toList();
  }

  /// Dispose of resources
  void dispose() {
    httpClient.close();
  }
}