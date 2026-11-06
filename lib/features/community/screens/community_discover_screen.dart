import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/widgets/ad_placement_section.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/community_api_service.dart';
import '../widgets/community_card.dart';
import 'community_hub_screen.dart';
import 'create_community_screen.dart';
import 'community_invites_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class CommunityDiscoverScreen extends StatefulWidget {
  const CommunityDiscoverScreen({super.key});

  @override
  State<CommunityDiscoverScreen> createState() => _CommunityDiscoverScreenState();
}

class _CommunityDiscoverScreenState extends State<CommunityDiscoverScreen> {
  List<Map<String, dynamic>> _communities = [];
  bool _isLoading = true;
  bool _isLocationLoading = false;
  Position? _currentPosition;
  String _sortBy = 'Nearest'; 
  bool _showMap = false;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  // ignore: unused_field
  bool _isSearching = false;
  
  // Cache timestamps for smart refetching
  DateTime? _lastCommunitiesFetchAt;
  bool _communitiesInitialized = false;
  
  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _ensureLocation();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;
    
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        _loadForCurrentSort();
      }
    });
  }

  // --- 3D UI ENGINE ---
  Widget _build3DContainer({required Widget child, double radius = 24}) {
    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double halfTopInset = MediaQuery.of(context).padding.top / 2;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: halfTopInset + 4),
              _buildPremiumHeader(),
              _buildSearchBar(),
              _buildFluidSortSwitcher(),
              Expanded(
                child: _isLocationLoading || _isLoading
                    ? const BybataLoader()
                    : _currentPosition == null 
                        ? _buildLocationErrorState() 
                        : _showMap ? _buildMapView() : _buildListView(),
              ),
            ],
          ),
          
          // --- POSITIONED "NEW TRIBE" BUTTON (Right Middle) ---
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 0), // Flushed or slight padding
              child: _buildRightMiddleButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightMiddleButton() {
    return GestureDetector(
      onTap: () {
        GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const CreateCommunityScreen()))
            .then((created) { if (created != null) _loadNearby(); });
      },
      child: Container(
        height: 120,
        width: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(-5, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 24,
            ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 3,
              child: Text(
                'NEW TRIBE',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC PRESERVATION ---

  Future<void> _ensureLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      final status =
          await LocationService.instance.ensureForFunction(context);
      final granted = status == LocationPermission.always ||
          status == LocationPermission.whileInUse;
      if (!granted) {
        if (!mounted) return;
        setState(() => _isLocationLoading = false);
        await _loadAllCommunities();
        return;
      }
      _currentPosition = await LocationService.instance
          .getCurrentPosition(forceRefresh: true);
      await _loadForCurrentSort();
    } catch (e) {
      setState(() => _isLocationLoading = false);
      await _loadAllCommunities();
    }
  }

  Future<void> _loadNearby({bool force = false}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _communitiesInitialized && _lastCommunitiesFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastCommunitiesFetchAt!);
      if (cacheAge < _cacheDuration && _communities.isNotEmpty) {
        debugPrint('[CommunityDiscoverScreen] Using cached communities (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    if (_currentPosition == null) return;
    setState(() => _isLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);

      final communities = await service.getNearbyCommunitiesFromApi(
        _currentPosition!.latitude, _currentPosition!.longitude, radius: 20000);

      if (communities.isEmpty) {
        return _loadAllCommunities();
      }

      final joined = await service.getJoinedCommunitiesFromApi();
      final joinedIds = joined.map((c) => c.id).toSet();

      setState(() {
        _communities = communities.map((c) => {
          'id': c.id, 'name': c.name, 'description': c.description ?? '',
          'imageUrl': c.imageUrl, 'lat': c.centerLatitude, 'lng': c.centerLongitude,
          'distance': c.distanceKm ?? 0.0, 'isJoined': joinedIds.contains(c.id),
        }).toList();
        _isLoading = false;
        _isLocationLoading = false;
        
        // Update cache metadata
        _lastCommunitiesFetchAt = DateTime.now();
        _communitiesInitialized = true;
      });
    } catch (e) {
      setState(() { _isLoading = false; _isLocationLoading = false; });
      if (mounted) {
        AppToast.error(context, 'Failed to load communities: ${e.toString()}');
      }
    }
  }

  Future<void> _loadAllCommunities({bool force = false}) async {
    // Smart caching: skip if already loaded and cache is fresh
    if (!force && _communitiesInitialized && _lastCommunitiesFetchAt != null) {
      final cacheAge = DateTime.now().difference(_lastCommunitiesFetchAt!);
      if (cacheAge < _cacheDuration && _communities.isNotEmpty) {
        debugPrint('[CommunityDiscoverScreen] Using cached all communities (${cacheAge.inSeconds}s old)');
        return;
      }
    }
    
    setState(() => _isLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);

      final communities = await service.getCommunitiesFromApi(page: 1, size: 100);
      final joined = await service.getJoinedCommunitiesFromApi();
      final joinedIds = joined.map((c) => c.id).toSet();

      setState(() {
        _communities = communities.map((c) => {
          'id': c.id,
          'name': c.name,
          'description': c.description ?? '',
          'imageUrl': c.imageUrl,
          'lat': c.centerLatitude,
          'lng': c.centerLongitude,
          'distance': 0.0,
          'isJoined': joinedIds.contains(c.id),
        }).toList();
        _isLoading = false;
        _isLocationLoading = false;
        
        // Update cache metadata
        _lastCommunitiesFetchAt = DateTime.now();
        _communitiesInitialized = true;
      });
    } catch (e) {
      setState(() { _isLoading = false; _isLocationLoading = false; });
      if (mounted) {
        AppToast.error(context, 'Failed to load communities: ${e.toString()}');
      }
    }
  }

  Future<void> _loadForCurrentSort() async {
    if (_sortBy == 'All') {
      return _loadAllCommunities();
    }
    if (_currentPosition == null) {
      return _loadAllCommunities();
    }
    return _loadNearby();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadForCurrentSort();
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);

      // Search communities using the query parameter
      final communities = await service.getCommunitiesFromApi(
        page: 1,
        size: 100,
        query: query,
      );

      final joined = await service.getJoinedCommunitiesFromApi();
      final joinedIds = joined.map((c) => c.id).toSet();

      setState(() {
        _communities = communities.map((c) {
          double distance = 0.0;
          if (_currentPosition != null && c.centerLatitude != null && c.centerLongitude != null) {
            // Calculate distance using Haversine formula
            const double earthRadius = 6371; // km
            final dLat = _degreesToRadians(c.centerLatitude! - _currentPosition!.latitude);
            final dLon = _degreesToRadians(c.centerLongitude! - _currentPosition!.longitude);
            final a = sin(dLat / 2) * sin(dLat / 2) +
                cos(_degreesToRadians(_currentPosition!.latitude)) *
                    cos(_degreesToRadians(c.centerLatitude!)) *
                    sin(dLon / 2) *
                    sin(dLon / 2);
            final angle = 2 * atan2(sqrt(a), sqrt(1 - a));
            distance = earthRadius * angle;
          }
          return {
            'id': c.id,
            'name': c.name,
            'description': c.description ?? '',
            'imageUrl': c.imageUrl,
            'lat': c.centerLatitude,
            'lng': c.centerLongitude,
            'distance': distance,
            'isJoined': joinedIds.contains(c.id),
          };
        }).toList();
        _isLoading = false;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSearching = false;
      });
      if (mounted) {
        AppToast.error(context, 'Search failed: ${e.toString()}');
      }
    }
  }

  Widget _buildPremiumHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Discover",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                "Tribes",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => _showMap = !_showMap),
            child: _build3DContainer(
              radius: 16,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  _showMap ? Icons.list_rounded : Icons.map_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              GuardedNavigator.push(context,
                MaterialPageRoute(builder: (_) => const CommunityInvitesScreen()),
              );
            },
            child: _build3DContainer(
              radius: 16,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.mail_outline,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: _build3DContainer(
        radius: 20,
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            return TextField(
              controller: _searchController,
              onChanged: (value) {
                setLocalState(() {}); // Rebuild to show/hide clear button
              },
              decoration: BorderlessInputDecoration.search(
                hintText: 'Search communities by name, description, or category...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          setLocalState(() {});
                          _loadForCurrentSort();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: const TextStyle(fontSize: 15),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _performSearch(value.trim());
                } else {
                  _loadForCurrentSort();
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFluidSortSwitcher() {
    final options = ['Nearest', 'Farthest', 'All'];
    int currentIndex = options.indexOf(_sortBy);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            alignment: Alignment(-1.0 + (currentIndex * (2.0 / (options.length - 1))), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / options.length,
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Row(
            children: options.map((opt) => Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _sortBy = opt);
                  if (_searchQuery.isEmpty) {
                    _loadForCurrentSort();
                  }
                },
                child: Center(
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: _sortBy == opt
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight:
                          _sortBy == opt ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    final sorted = List<Map<String, dynamic>>.from(_communities);
    
    // Apply sorting
    if (_sortBy == 'Nearest') {
      sorted.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    } else if (_sortBy == 'Farthest') {
      sorted.sort((a, b) => (b['distance'] as double).compareTo(a['distance'] as double));
    }
    // 'All' keeps original order (or search results order)

    if (_isLoading && sorted.isEmpty) {
      return const BybataLoader();
    }

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.explore_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No communities found for "$_searchQuery"'
                  : 'No communities available',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _loadForCurrentSort();
                },
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        if (_searchQuery.isNotEmpty) {
          await _performSearch(_searchQuery);
        } else {
          // Force refresh when user pulls down
          if (_sortBy == 'All') {
            await _loadAllCommunities(force: true);
          } else {
            await _loadNearby(force: true);
          }
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: sorted.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: AdPlacementSection(
                placementKey: 'community_feed',
                title: 'Sponsored',
              ),
            );
          }
          final c = sorted[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _build3DContainer(
              child: CommunityCard(
                id: c['id'],
                name: c['name'],
                avatarUrl: c['imageUrl'],
                description: c['description'],
                distanceKm: c['distance'],
                inRange: c['distance'] <= 100.0, // Updated to 100km default
                isJoined: c['isJoined'] ?? false,
                onJoin: (c['isJoined'] ?? false) ? null : () => _joinCommunity(c),
                onOpen: () => GuardedNavigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => CommunityHubScreen(
                      communityId: c['id'],
                      communityName: c['name'],
                      communityLat: c['lat'],
                      communityLng: c['lng'],
                      isMember: c['isJoined'] ?? false,
                    ),
                  ),
                ).then((_) => _loadNearby()),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- JOIN LOGIC RESTORED ---
  Future<void> _joinCommunity(Map<String, dynamic> community) async {
    try {
      final storage = const FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final apiClient = ApiClient(baseUrl, storage);
      final service = CommunityApiService(apiClient);
      await service.joinCommunityViaApi(community['id']);
      if (!mounted) return;
      setState(() { community['isJoined'] = true; });
      AppToast.success(context, 'Joined successfully!');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Error joining tribe');
    }
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  Widget _buildLocationErrorState() => Center(child: Text("Location required"));
  Widget _buildMapView() => Center(child: Text("Map View"));
}