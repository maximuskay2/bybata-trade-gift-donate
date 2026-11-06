import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

class GiftProvider extends ChangeNotifier {
  // Gift catalog
  List<GiftItem> _allGifts = [];
  List<GiftItem> _featuredGifts = [];
  List<GiftItem> _filteredGifts = [];
  
  // Cart state (simple local cart)
  final Map<String, int> _cart = {}; // giftId -> quantity
  
  // Filters & search
  String _searchQuery = '';
  String? _selectedCategory;
  bool? _isDigital; // null = all, true = digital, false = physical
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'popular'; // popular, price_low, price_high, newest
  
  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasMore = true;
  int _currentPage = 1;
  
  // Categories
  static const List<String> _categories = [
    'Vouchers', 'Entertainment', 'Retail', 'Food & Drinks', 'Gaming', 'Other'
  ];
  
  // Getters
  List<GiftItem> get allGifts => List.unmodifiable(_allGifts);
  List<GiftItem> get featuredGifts => List.unmodifiable(_featuredGifts);
  List<GiftItem> get filteredGifts => List.unmodifiable(_filteredGifts);
  List<String> get categories => _categories;
  Map<String, int> get cart => Map.unmodifiable(_cart);
  
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool? get isDigital => _isDigital;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  String get sortBy => _sortBy;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  
  int get cartItemCount => _cart.values.fold(0, (sum, q) => sum + q);
  double cartTotal({String currency = 'BYC'}) {
    double total = 0.0;
    _cart.forEach((giftId, qty) {
      final gift = _allGifts.firstWhere((g) => g.id == giftId, orElse: () => 
        GiftItem(
          id: 'na', name: '', description: '', imageUrl: '', price: 0, currency: currency,
          category: 'Other', isDigital: false, availableQuantity: 0, createdAt: DateTime.now(), status: GiftItemStatus.available));
      total += (gift.price) * qty;
    });
    return total;
  }
  
  // Initialize
  Future<void> initializeGifts() async {
    await loadGifts();
    await loadFeaturedGifts();
  }
  
  // Load gifts
  Future<void> loadGifts({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    _isLoading = true;
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    notifyListeners();
    
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final newGifts = _mockGifts(_currentPage);
      if (refresh) {
        _allGifts = newGifts;
      } else {
        _allGifts.addAll(newGifts);
      }
      _hasMore = newGifts.isNotEmpty;
      _currentPage++;
      _applyFilters();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load gifts: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load featured
  Future<void> loadFeaturedGifts() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      _featuredGifts = _allGifts.where((g) => g.isFeatured).take(6).toList();
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }
  
  // Mock gifts
  List<GiftItem> _mockGifts(int page) {
    final list = <GiftItem>[];
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final idx = (page - 1) * 12 + i;
      final isDig = idx % 3 == 0;
      list.add(
        GiftItem(
          id: 'gift_$idx',
          name: 'Gift Card ${idx + 1}',
          description: 'Use this gift card at your favorite stores and services.',
          imageUrl: 'https://via.placeholder.com/320x200/E91E63/FFFFFF?text=Gift+${idx + 1}',
          price: (idx % 8 + 1) * 20.0,
          currency: 'BYC',
          brandName: idx % 2 == 0 ? 'Brand ${(idx % 5) + 1}' : null,
          brandLogo: idx % 2 == 0 ? 'https://via.placeholder.com/60x60/FFF/000?text=B${(idx % 5) + 1}' : null,
          category: _categories[idx % _categories.length],
          isDigital: isDig,
          availableQuantity: 20 - (idx % 7),
          expiryDate: isDig ? null : now.add(Duration(days: 30 + (idx % 60))),
          isFeatured: idx % 5 == 0,
          createdAt: now.subtract(Duration(days: idx % 20)),
          status: GiftItemStatus.available,
        ),
      );
    }
    return list;
  }
  
  // Cart ops
  void addToCart(String giftId, {int quantity = 1}) {
    final gift = _allGifts.firstWhere((g) => g.id == giftId);
    final currentQty = _cart[giftId] ?? 0;
    final newQty = (currentQty + quantity).clamp(0, gift.availableQuantity);
    if (newQty <= 0) {
      _cart.remove(giftId);
    } else {
      _cart[giftId] = newQty;
    }
    notifyListeners();
  }
  
  void removeFromCart(String giftId, {int quantity = 1}) {
    if (!_cart.containsKey(giftId)) return;
    final newQty = (_cart[giftId]! - quantity);
    if (newQty <= 0) {
      _cart.remove(giftId);
    } else {
      _cart[giftId] = newQty;
    }
    notifyListeners();
  }
  
  void clearCart() {
    _cart.clear();
    notifyListeners();
  }
  
  // Purchase cart
  Future<bool> purchaseCart() async {
    if (_cart.isEmpty) return false;
    try {
      _isLoading = true;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      // Mock reduce quantities
      _cart.forEach((giftId, qty) {
        final idx = _allGifts.indexWhere((g) => g.id == giftId);
        if (idx != -1) {
          final g = _allGifts[idx];
          _allGifts[idx] = GiftItem(
            id: g.id,
            name: g.name,
            description: g.description,
            imageUrl: g.imageUrl,
            price: g.price,
            currency: g.currency,
            brandName: g.brandName,
            brandLogo: g.brandLogo,
            category: g.category,
            isDigital: g.isDigital,
            availableQuantity: (g.availableQuantity - qty).clamp(0, 9999),
            expiryDate: g.expiryDate,
            isFeatured: g.isFeatured,
            createdAt: g.createdAt,
            status: g.status,
          );
        }
      });
      _cart.clear();
      _applyFilters();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to complete purchase: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Filters
  void searchGifts(String query) { _searchQuery = query; _applyFilters(); notifyListeners(); }
  void setCategory(String? category) { _selectedCategory = category; _applyFilters(); notifyListeners(); }
  void setDigital(bool? digital) { _isDigital = digital; _applyFilters(); notifyListeners(); }
  void setPriceRange(double? min, double? max) { _minPrice = min; _maxPrice = max; _applyFilters(); notifyListeners(); }
  void setSortBy(String sort) { _sortBy = sort; _applyFilters(); notifyListeners(); }
  void clearFilters() { _searchQuery=''; _selectedCategory=null; _isDigital=null; _minPrice=null; _maxPrice=null; _sortBy='popular'; _applyFilters(); notifyListeners(); }
  
  void _applyFilters() {
    _filteredGifts = List.from(_allGifts);
    if (_searchQuery.isNotEmpty) {
      _filteredGifts = _filteredGifts.where((g) =>
        g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        g.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (g.brandName ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    if (_selectedCategory != null) {
      _filteredGifts = _filteredGifts.where((g) => g.category == _selectedCategory).toList();
    }
    if (_isDigital != null) {
      _filteredGifts = _filteredGifts.where((g) => g.isDigital == _isDigital).toList();
    }
    if (_minPrice != null || _maxPrice != null) {
      _filteredGifts = _filteredGifts.where((g) {
        final p = g.price;
        if (_minPrice != null && p < _minPrice!) return false;
        if (_maxPrice != null && p > _maxPrice!) return false;
        return true;
      }).toList();
    }
    _filteredGifts.sort((a, b) {
      switch (_sortBy) {
        case 'price_low': return a.price.compareTo(b.price);
        case 'price_high': return b.price.compareTo(a.price);
        case 'newest': return b.createdAt.compareTo(a.createdAt);
        case 'popular':
        default: return (b.isFeatured ? 1:0).compareTo(a.isFeatured ? 1:0);
      }
    });
  }
  
  // Helpers
  GiftItem? getGiftById(String giftId) {
    try { return _allGifts.firstWhere((g) => g.id == giftId); } catch (_) { return null; }
  }
  
  // Refresh
  Future<void> refresh() async { await loadGifts(refresh: true); await loadFeaturedGifts(); }
}
