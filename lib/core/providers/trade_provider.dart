import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

class TradeProvider extends ChangeNotifier {
  // Trade listings
  List<TradeItem> _allItems = [];
  List<TradeItem> _myListings = [];
  List<TradeItem> _favorites = [];
  List<TradeItem> _filteredItems = [];
  
  // Search and filters
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedCondition;
  double? _minPrice;
  double? _maxPrice;
  String? _selectedLocation;
  String _sortBy = 'newest'; // newest, price_low, price_high, rating
  
  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasMoreItems = true;
  int _currentPage = 1;
  
  // Categories
  static const List<String> _categories = [
    'Electronics',
    'Clothing',
    'Home & Garden',
    'Sports & Outdoors',
    'Books & Media',
    'Toys & Games',
    'Automotive',
    'Health & Beauty',
    'Collectibles',
    'Other',
  ];
  
  static const List<String> _conditions = [
    'New',
    'Like New',
    'Good',
    'Fair',
    'Poor',
  ];
  
  // Getters
  List<TradeItem> get allItems => List.unmodifiable(_allItems);
  List<TradeItem> get myListings => List.unmodifiable(_myListings);
  List<TradeItem> get favorites => List.unmodifiable(_favorites);
  List<TradeItem> get filteredItems => List.unmodifiable(_filteredItems);
  List<String> get categories => _categories;
  List<String> get conditions => _conditions;
  
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedCondition => _selectedCondition;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  String? get selectedLocation => _selectedLocation;
  String get sortBy => _sortBy;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMoreItems => _hasMoreItems;
  int get currentPage => _currentPage;
  
  // Initialize trade provider
  Future<void> initializeTrade() async {
    await loadTradeItems();
  }
  
  // Load trade items
  Future<void> loadTradeItems({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    
    _isLoading = true;
    if (refresh) {
      _currentPage = 1;
      _hasMoreItems = true;
    }
    notifyListeners();
    
    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      final newItems = _generateMockTradeItems(_currentPage);
      
      if (refresh) {
        _allItems = newItems;
      } else {
        _allItems.addAll(newItems);
      }
      
      _hasMoreItems = newItems.isNotEmpty;
      _currentPage++;
      
      _applyFilters();
      _errorMessage = null;
      
    } catch (e) {
      _errorMessage = 'Failed to load trade items: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Generate mock trade items
  List<TradeItem> _generateMockTradeItems(int page) {
    final items = <TradeItem>[];
    final now = DateTime.now();
    
    for (int i = 0; i < 10; i++) {
      final index = (page - 1) * 10 + i;
      items.add(
        TradeItem(
          id: 'trade_$index',
          title: 'Trade Item ${index + 1}',
          description: 'This is a description for trade item ${index + 1}. Great condition and ready for trade!',
          images: [
            'https://via.placeholder.com/300x200/4CAF50/FFFFFF?text=Item+${index + 1}',
            'https://via.placeholder.com/300x200/7E57C2/FFFFFF?text=Image+2',
          ],
          category: _categories[index % _categories.length],
          condition: _conditions[index % _conditions.length],
          price: (index % 10 + 1) * 50.0,
          currency: index % 3 == 0 ? 'BYC' : 'USD',
          sellerId: 'seller_$index',
          sellerName: 'Seller ${index + 1}',
          sellerImageUrl: 'https://via.placeholder.com/100x100/FF9800/FFFFFF?text=S${index + 1}',
          sellerRating: 3.0 + (index % 3),
          location: 'City ${index % 5 + 1}',
          createdAt: now.subtract(Duration(days: index % 30)),
          updatedAt: now.subtract(Duration(hours: index % 24)),
          status: TradeItemStatus.active,
        ),
      );
    }
    
    return items;
  }
  
  // Load my listings
  Future<void> loadMyListings(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate API call
      
      _myListings = _allItems.where((item) => item.sellerId == userId).toList();
      _errorMessage = null;
      
    } catch (e) {
      _errorMessage = 'Failed to load your listings: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create new trade item
  Future<bool> createTradeItem({
    required String title,
    required String description,
    required List<String> images,
    required String category,
    required String condition,
    double? price,
    String? currency,
    required String sellerId,
    required String sellerName,
    String? sellerImageUrl,
    String? location,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      final newItem = TradeItem(
        id: 'trade_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        images: images,
        category: category,
        condition: condition,
        price: price,
        currency: currency,
        sellerId: sellerId,
        sellerName: sellerName,
        sellerImageUrl: sellerImageUrl,
        location: location,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: TradeItemStatus.active,
      );
      
      _allItems.insert(0, newItem);
      _myListings.insert(0, newItem);
      _applyFilters();
      _errorMessage = null;
      
      notifyListeners();
      return true;
      
    } catch (e) {
      _errorMessage = 'Failed to create trade item: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update trade item
  Future<bool> updateTradeItem(String itemId, {
    String? title,
    String? description,
    List<String>? images,
    String? category,
    String? condition,
    double? price,
    String? currency,
    String? location,
    TradeItemStatus? status,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      final itemIndex = _allItems.indexWhere((item) => item.id == itemId);
      if (itemIndex != -1) {
        final updatedItem = _allItems[itemIndex].copyWith(
          title: title ?? _allItems[itemIndex].title,
          description: description ?? _allItems[itemIndex].description,
          images: images ?? _allItems[itemIndex].images,
          category: category ?? _allItems[itemIndex].category,
          condition: condition ?? _allItems[itemIndex].condition,
          price: price ?? _allItems[itemIndex].price,
          currency: currency ?? _allItems[itemIndex].currency,
          location: location ?? _allItems[itemIndex].location,
          status: status ?? _allItems[itemIndex].status,
          updatedAt: DateTime.now(),
        );
        
        _allItems[itemIndex] = updatedItem;
        
        // Update in my listings if applicable
        final myListingIndex = _myListings.indexWhere((item) => item.id == itemId);
        if (myListingIndex != -1) {
          _myListings[myListingIndex] = updatedItem;
        }
        
        _applyFilters();
        _errorMessage = null;
      }
      
      notifyListeners();
      return true;
      
    } catch (e) {
      _errorMessage = 'Failed to update trade item: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Delete trade item
  Future<bool> deleteTradeItem(String itemId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      _allItems.removeWhere((item) => item.id == itemId);
      _myListings.removeWhere((item) => item.id == itemId);
      _favorites.removeWhere((item) => item.id == itemId);
      
      _applyFilters();
      _errorMessage = null;
      
      notifyListeners();
      return true;
      
    } catch (e) {
      _errorMessage = 'Failed to delete trade item: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Toggle favorite
  Future<void> toggleFavorite(String itemId) async {
    try {
      final item = _allItems.firstWhere((item) => item.id == itemId);
      
      if (_favorites.any((fav) => fav.id == itemId)) {
        _favorites.removeWhere((fav) => fav.id == itemId);
      } else {
        _favorites.add(item);
      }
      
      // TODO: Save to backend
      await Future.delayed(const Duration(milliseconds: 300)); // Simulate API call
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update favorite: ${e.toString()}';
      notifyListeners();
    }
  }
  
  // Check if item is favorite
  bool isFavorite(String itemId) {
    return _favorites.any((item) => item.id == itemId);
  }
  
  // Search items
  void searchItems(String query) {
    _searchQuery = query;
    _currentPage = 1;
    _applyFilters();
    notifyListeners();
  }
  
  // Set category filter
  void setCategory(String? category) {
    _selectedCategory = category;
    _currentPage = 1;
    _applyFilters();
    notifyListeners();
  }
  
  // Set condition filter
  void setCondition(String? condition) {
    _selectedCondition = condition;
    _currentPage = 1;
    _applyFilters();
    notifyListeners();
  }
  
  // Set price range
  void setPriceRange(double? minPrice, double? maxPrice) {
    _minPrice = minPrice;
    _maxPrice = maxPrice;
    _currentPage = 1;
    _applyFilters();
    notifyListeners();
  }
  
  // Set location filter
  void setLocation(String? location) {
    _selectedLocation = location;
    _currentPage = 1;
    _applyFilters();
    notifyListeners();
  }
  
  // Set sort by
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    _applyFilters();
    notifyListeners();
  }
  
  // Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedCondition = null;
    _minPrice = null;
    _maxPrice = null;
    _selectedLocation = null;
    _sortBy = 'newest';
    _currentPage = 1;
    _applyFilters();
    notifyListeners();
  }
  
  // Apply filters and sorting
  void _applyFilters() {
    _filteredItems = List.from(_allItems);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      _filteredItems = _filteredItems.where((item) {
        return item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Apply category filter
    if (_selectedCategory != null) {
      _filteredItems = _filteredItems.where((item) => item.category == _selectedCategory).toList();
    }
    
    // Apply condition filter
    if (_selectedCondition != null) {
      _filteredItems = _filteredItems.where((item) => item.condition == _selectedCondition).toList();
    }
    
    // Apply price range filter
    if (_minPrice != null || _maxPrice != null) {
      _filteredItems = _filteredItems.where((item) {
        if (item.price == null) return false;
        if (_minPrice != null && item.price! < _minPrice!) return false;
        if (_maxPrice != null && item.price! > _maxPrice!) return false;
        return true;
      }).toList();
    }
    
    // Apply location filter
    if (_selectedLocation != null) {
      _filteredItems = _filteredItems.where((item) => item.location == _selectedLocation).toList();
    }
    
    // Apply sorting
    _filteredItems.sort((a, b) {
      switch (_sortBy) {
        case 'price_low':
          if (a.price == null && b.price == null) return 0;
          if (a.price == null) return 1;
          if (b.price == null) return -1;
          return a.price!.compareTo(b.price!);
        case 'price_high':
          if (a.price == null && b.price == null) return 0;
          if (a.price == null) return 1;
          if (b.price == null) return -1;
          return b.price!.compareTo(a.price!);
        case 'rating':
          if (a.sellerRating == null && b.sellerRating == null) return 0;
          if (a.sellerRating == null) return 1;
          if (b.sellerRating == null) return -1;
          return b.sellerRating!.compareTo(a.sellerRating!);
        case 'newest':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
  }
  
  // Get item by id
  TradeItem? getItemById(String itemId) {
    try {
      return _allItems.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }
  
  // Get items by seller
  List<TradeItem> getItemsBySeller(String sellerId) {
    return _allItems.where((item) => item.sellerId == sellerId && item.status == TradeItemStatus.active).toList();
  }
  
  // Get recommended items
  List<TradeItem> getRecommendedItems({int limit = 10}) {
    final recommended = List.from(_allItems);
    recommended.shuffle();
    return recommended.take(limit).toList().cast<TradeItem>();
  }
  
  // Get trending items
  List<TradeItem> getTrendingItems({int limit = 10}) {
    final trending = List.from(_allItems);
    // Sort by a combination of recent and popular (mock implementation)
    trending.sort((a, b) {
      final aScore = (a.sellerRating ?? 0) * 0.3 + DateTime.now().difference(a.createdAt).inDays * 0.7;
      final bScore = (b.sellerRating ?? 0) * 0.3 + DateTime.now().difference(b.createdAt).inDays * 0.7;
      return aScore.compareTo(bScore);
    });
    return trending.take(limit).toList().cast<TradeItem>();
  }
  
  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // Refresh all data
  Future<void> refresh() async {
    await loadTradeItems(refresh: true);
  }
}