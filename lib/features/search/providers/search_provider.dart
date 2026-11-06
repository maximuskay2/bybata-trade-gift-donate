import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_models.dart';
import '../services/search_service.dart';

/// Provider for managing search state across the app
class SearchProvider extends ChangeNotifier {
  final SearchService _searchService = SearchService();

  // State variables
  SearchResponse? _currentSearchResponse;
  List<SearchHistoryItem> _searchHistory = [];
  List<TrendingSearch> _trendingSearches = [];
  List<String> _suggestions = [];
  SearchFilters _filters = const SearchFilters();
  bool _isLoading = false;
  String? _error;
  bool _showSuggestions = false;

  // Pagination
  int _currentPage = 1;
  bool _hasMoreResults = false;
  bool _isLoadingMore = false;

  // Getters
  SearchResponse? get currentSearchResponse => _currentSearchResponse;
  List<SearchHistoryItem> get searchHistory => _searchHistory;
  List<TrendingSearch> get trendingSearches => _trendingSearches;
  List<String> get suggestions => _suggestions;
  SearchFilters get filters => _filters;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get showSuggestions => _showSuggestions;
  bool get hasMoreResults => _hasMoreResults;

  /// Initialize the provider
  Future<void> initialize() async {
    await _loadSearchHistory();
    await loadTrendingSearches();
  }

  /// Performs a search with the current filters
  Future<void> search(String query, {bool clearPrevious = true}) async {
    if (query.trim().isEmpty) return;

    if (clearPrevious) {
      _currentPage = 1;
      _currentSearchResponse = null;
    }

    _isLoading = true;
    _error = null;
    _showSuggestions = false;
    notifyListeners();

    try {
      final response = await _searchService.search(
        query: query.trim(),
        filters: _filters,
        page: _currentPage,
        limit: 20,
      );

      if (clearPrevious) {
        _currentSearchResponse = response;
      } else {
        // Append results for pagination
        if (_currentSearchResponse != null) {
          final combinedResults = [
            ..._currentSearchResponse!.results,
            ...response.results,
          ];
          _currentSearchResponse = SearchResponse(
            results: combinedResults,
            totalCount: response.totalCount,
            currentPage: response.currentPage,
            totalPages: response.totalPages,
            query: response.query,
            filters: response.filters,
            categoryCounts: response.categoryCounts,
          );
        } else {
          _currentSearchResponse = response;
        }
      }

      _hasMoreResults = _currentPage < response.totalPages;
      _error = null;

      // Add to search history
      await _addToSearchHistory(query, _filters.category, response.totalCount);

      // Record search analytics
      await _searchService.recordSearch(
        query: query,
        category: _filters.category,
        resultCount: response.totalCount,
      );
    } catch (e) {
      _error = e.toString();
      print('Search error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more results for pagination
  Future<void> loadMoreResults() async {
    if (!_hasMoreResults || 
        _isLoadingMore || 
        _currentSearchResponse == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      await search(_currentSearchResponse!.query, clearPrevious: false);
    } catch (e) {
      _currentPage--; // Revert page number on error
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Get search suggestions based on partial query
  Future<void> getSuggestions(String partialQuery) async {
    if (partialQuery.trim().isEmpty) {
      _suggestions.clear();
      _showSuggestions = false;
      notifyListeners();
      return;
    }

    try {
      final suggestions = await _searchService.getSuggestions(partialQuery.trim());
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
      notifyListeners();
    } catch (e) {
      print('Failed to get suggestions: $e');
      _suggestions.clear();
      _showSuggestions = false;
      notifyListeners();
    }
  }

  /// Hide suggestions
  void hideSuggestions() {
    _showSuggestions = false;
    notifyListeners();
  }

  /// Load trending searches
  Future<void> loadTrendingSearches({SearchCategory? category}) async {
    try {
      final trending = await _searchService.getTrendingSearches(
        category: category,
        limit: 10,
      );
      _trendingSearches = trending;
      notifyListeners();
    } catch (e) {
      print('Failed to load trending searches: $e');
    }
  }

  /// Update search filters
  void updateFilters(SearchFilters newFilters) {
    _filters = newFilters;
    notifyListeners();
  }

  /// Reset filters to default
  void resetFilters() {
    _filters = const SearchFilters();
    notifyListeners();
  }

  /// Clear current search results
  void clearSearch() {
    _currentSearchResponse = null;
    _currentPage = 1;
    _hasMoreResults = false;
    _error = null;
    _suggestions.clear();
    _showSuggestions = false;
    notifyListeners();
  }

  /// Remove item from search history
  Future<void> removeFromHistory(String historyId) async {
    _searchHistory.removeWhere((item) => item.id == historyId);
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Clear all search history
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Add search to history
  Future<void> _addToSearchHistory(
    String query, 
    SearchCategory category, 
    int resultCount
  ) async {
    // Don't add duplicates - remove existing entry for same query and category
    _searchHistory.removeWhere(
      (item) => item.query == query && item.category == category,
    );

    // Add new entry at the beginning
    final historyItem = SearchHistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      query: query,
      category: category,
      timestamp: DateTime.now(),
      resultCount: resultCount,
    );

    _searchHistory.insert(0, historyItem);

    // Keep only the last 20 searches
    if (_searchHistory.length > 20) {
      _searchHistory = _searchHistory.take(20).toList();
    }

    await _saveSearchHistory();
  }

  /// Load search history from storage
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('search_history') ?? [];
      
      _searchHistory = historyJson
          .map((json) {
            try {
              return SearchHistoryItem.fromJson(
                jsonDecode(json) as Map<String, dynamic>
              );
            } catch (e) {
              return null;
            }
          })
          .whereType<SearchHistoryItem>()
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Failed to load search history: $e');
    }
  }

  /// Save search history to storage
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _searchHistory
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      
      await prefs.setStringList('search_history', historyJson);
    } catch (e) {
      print('Failed to save search history: $e');
    }
  }

  /// Get recent searches for a specific category
  List<SearchHistoryItem> getRecentSearchesForCategory(SearchCategory category) {
    if (category == SearchCategory.all) {
      return _searchHistory;
    }
    return _searchHistory.where((item) => item.category == category).toList();
  }

  /// Get trending searches for a specific category
  List<TrendingSearch> getTrendingForCategory(SearchCategory category) {
    if (category == SearchCategory.all) {
      return _trendingSearches;
    }
    return _trendingSearches.where((item) => item.category == category).toList();
  }

  /// Dispose of resources
  @override
  void dispose() {
    _searchService.dispose();
    super.dispose();
  }
}