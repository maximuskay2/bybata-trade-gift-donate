// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/config/env_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/services/location_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/utils/image_resize_utils.dart';
import '../services/community_api_service.dart';
import '../models/community_api.dart';
import '../widgets/post_item.dart';
import '../widgets/event_card.dart';
import '../widgets/member_card.dart';
import 'community_moderation_screen.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/models/chat_conversation.dart' show ChatConversation, ChatType;
import '../../chat/utils/conversation_inbox_dedupe.dart';
import 'dm_inbox_screen.dart';
import '../../../features/storage/repository/storage_repository.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class CommunityHubScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final double? communityLat;
  final double? communityLng;
  final bool isMember;

  const CommunityHubScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    this.communityLat,
    this.communityLng,
    this.isMember = false,
  });

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CommunityApiService? _service;

  // Community data
  CommunityApi? _community;
  bool _isLoadingCommunity = true;
  bool _isMember = false;
  bool _isOwner = false;
  bool _canModerate = false;
  int _pendingJoinRequestCount = 0;
  bool _isLoadingPendingRequests = false;

  // Feed Tab
  List<Map<String, dynamic>> _posts = [];
  bool _isLoadingPosts = false;
  final int _postsPage = 1;
  final Set<String> _likedPosts = {};

  // Events Tab
  List<Map<String, dynamic>> _events = [];
  bool _isLoadingEvents = false;
  bool _showUpcomingEvents = true;
  final Set<String> _registeredEvents = {};

  // Members Tab
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = false;
  List<Map<String, dynamic>> _communityInvites = [];
  bool _isLoadingInvites = false;

  // Chat Tab
  final TextEditingController _chatSearchController = TextEditingController();
  String _chatSearchQuery = '';

  // All Communities Tab
  List<CommunityApi> _allCommunities = [];
  // ignore: unused_field
  List<CommunityApi> _filteredCommunities = [];
  bool _isLoadingAllCommunities = false;
  final TextEditingController _searchController = TextEditingController();
  Position? _currentPosition;
  // ignore: unused_field
  bool _isLocationLoading = false;
  Set<String> _joinedCommunityIds = {};

  // Real-time updates
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _tabController.addListener(() {
      setState(() {});
      if (_tabController.index == 0) {
        // All tab - load both posts and events
        if (_posts.isEmpty && !_isLoadingPosts) {
          _loadPosts();
        }
        if (_events.isEmpty && !_isLoadingEvents) {
          _loadEvents();
        }
      } else if (_tabController.index == 1 && _posts.isEmpty && !_isLoadingPosts) {
        _loadPosts();
      } else if (_tabController.index == 2 && _events.isEmpty && !_isLoadingEvents) {
        _loadEvents();
      } else if (_tabController.index == 3) {
        // Chat tab - load members and conversations
        if (_members.isEmpty && !_isLoadingMembers) {
          _loadMembers();
        }
        // Also ensure conversations are loaded
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        if (chatProvider.conversations.isEmpty && !chatProvider.isLoading) {
          chatProvider.refreshConversations();
        }
      } else if (_tabController.index == 4 && _members.isEmpty && !_isLoadingMembers) {
        _loadMembers();
        if (_isOwner) {
          _loadInvites();
        }
      }
    });
    _ensureLocation();
    _loadCommunityData();
    _startPeriodicRefresh();
  }

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
        return;
      }
      _currentPosition = await LocationService.instance
          .getCurrentPosition(forceRefresh: true);
      setState(() => _isLocationLoading = false);
    } catch (e) {
      setState(() => _isLocationLoading = false);
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        if (_tabController.index == 0) {
          // All tab - refresh both posts and events
          _loadPosts();
          _loadEvents();
        } else if (_tabController.index == 1) {
          _loadPosts();
        } else if (_tabController.index == 2) {
          _loadEvents();
        }
      }
    });
  }

  Future<CommunityApiService> _getService() async {
    if (_service != null) return _service!;
    final storage = const FlutterSecureStorage();
    final baseUrl = await EnvConfig.getBaseUrl();
    final apiClient = ApiClient(baseUrl, storage);
    _service = CommunityApiService(apiClient);
    return _service!;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _chatSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterCommunities();
  }

  void _filterCommunities() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredCommunities = List.from(_allCommunities));
    } else {
      setState(() {
        _filteredCommunities = _allCommunities.where((community) {
          final name = community.name.toLowerCase();
          final description = (community.description ?? '').toLowerCase();
          final category = (community.category ?? '').toLowerCase();
          return name.contains(query) || 
                 description.contains(query) || 
                 category.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _loadCommunityData() async {
    if (!mounted) return;
    setState(() => _isLoadingCommunity = true);
    try {
      final service = await _getService();
      final community = await service.getCommunityFromApi(widget.communityId);
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.currentUser?.id;
      
      // Check if user is the creator/owner - they are automatically a member
      final isOwner = community.createdById == currentUserId;
      
      // Check membership status (this will return true for owners)
      bool isMember = await service.isUserMemberOfCommunity(widget.communityId);
      
      // If user is owner, they are definitely a member
      if (isOwner) {
        isMember = true;
      }

      if (mounted) {
        setState(() {
          _community = community;
          _isLoadingCommunity = false;
          _isMember = isMember;
          _isOwner = isOwner;
          _canModerate = isOwner;
        });
      }

      if (isOwner) {
        _loadPendingJoinRequests();
      }

      if (isMember && _members.isEmpty && !_isLoadingMembers) {
        _loadMembers();
      }

      // Load initial tab data
      if (mounted && _tabController.index == 1) {
        _loadPosts();
      }
    } catch (e) {
      setState(() => _isLoadingCommunity = false);
      if (mounted) {
        AppToast.error(context, 'Failed to load community: ${e.toString()}');
      }
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoadingPosts) return;
    setState(() => _isLoadingPosts = true);
    try {
      final service = await _getService();
      final posts = await service.getCommunityPostsFromApi(
        widget.communityId,
        page: _postsPage,
        size: 20,
      );
      setState(() {
        _posts = posts;
        _isLoadingPosts = false;
      });
    } catch (e) {
      setState(() => _isLoadingPosts = false);
      // Check if it's a 403 Forbidden error (user not a member)
      if (e.toString().contains('403') || e.toString().contains('Forbidden') || e.toString().contains('member')) {
        // Silently handle - user needs to join first
        // Posts will be empty, which is fine
      setState(() {
          _posts = [];
        });
      } else {
        if (mounted) {
          AppToast.error(context, 'Failed to load posts: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _loadEvents() async {
    if (_isLoadingEvents) return;
    setState(() => _isLoadingEvents = true);
    try {
      final service = await _getService();
      final events = await service.getCommunityEventsFromApi(
        widget.communityId,
        upcoming: _showUpcomingEvents,
      );
        setState(() {
        _events = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      setState(() => _isLoadingEvents = false);
      // Check if it's a 403 Forbidden error (user not a member)
      if (e.toString().contains('403') || e.toString().contains('Forbidden') || e.toString().contains('member')) {
        // Silently handle - user needs to join first
        setState(() {
          _events = [];
        });
      } else {
        if (mounted) {
          AppToast.error(context, 'Failed to load events: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _loadMembers() async {
    if (_isLoadingMembers || !mounted) return;
    setState(() => _isLoadingMembers = true);
    try {
      final service = await _getService();
      final response = await service.getCommunityMembersFromApi(widget.communityId);
      if (mounted) {
        setState(() {
          _members = response;
          _isLoadingMembers = false;
        });
      }
      _updateModerationAccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
        AppToast.error(context, 'Failed to load members: ${e.toString()}');
      }
    }
  }

  void _updateModerationAccess() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    final currentMember = _members.firstWhere(
      (member) {
        final user = member['user'] ?? {};
        final userId = user['id'] ?? member['userId'];
        return userId == currentUserId;
      },
      orElse: () => {},
    );
    final role = (currentMember['role'] ?? '').toString().toUpperCase();
    final canModerate = _isOwner || role == 'OWNER' || role == 'ADMIN' || role == 'MODERATOR';
    if (!mounted) return;
    setState(() => _canModerate = canModerate);
    if (canModerate) {
      _loadPendingJoinRequests();
    } else if (_pendingJoinRequestCount != 0) {
      setState(() => _pendingJoinRequestCount = 0);
    }
  }

  Future<void> _loadPendingJoinRequests() async {
    if (_isLoadingPendingRequests || !_canModerate) return;
    setState(() => _isLoadingPendingRequests = true);
    try {
      final service = await _getService();
      final data = await service.getPendingJoinRequestsMeta(widget.communityId);
      final total = (data['total'] as num?)?.toInt();
      final items = (data['items'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _pendingJoinRequestCount = total ?? items.length;
        _isLoadingPendingRequests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPendingRequests = false);
    }
  }

  Future<void> _openModerationScreen() async {
    await GuardedNavigator.push(context,
      MaterialPageRoute(
        builder: (_) => CommunityModerationScreen(
          communityId: widget.communityId,
          communityName: widget.communityName,
        ),
      ),
    );
    await _loadPendingJoinRequests();
    await _loadMembers();
  }

  Future<void> _loadInvites() async {
    if (_isLoadingInvites || !mounted) return;
    setState(() => _isLoadingInvites = true);
    try {
      final service = await _getService();
      final items = await service.getCommunityInvites(widget.communityId);
      if (!mounted) return;
      setState(() {
        _communityInvites = items;
        _isLoadingInvites = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingInvites = false);
      AppToast.error(context, 'Failed to load invites: ${e.toString()}');
    }
  }

  Future<void> _loadAllCommunities() async {
    if (_isLoadingAllCommunities) return;
    setState(() => _isLoadingAllCommunities = true);
    try {
      final service = await _getService();
      // Load all communities (with pagination support)
      final communities = await service.getCommunitiesFromApi(
        page: 1,
        size: 100, // Load many communities
      );
      
      // Load joined communities to track membership
      final joined = await service.getJoinedCommunitiesFromApi(page: 1, size: 100);
      final joinedIds = joined.map((c) => c.id).toSet();
      
        setState(() {
        _allCommunities = communities;
        _joinedCommunityIds = joinedIds;
        _filterCommunities();
        _isLoadingAllCommunities = false;
      });
    } catch (e) {
      setState(() => _isLoadingAllCommunities = false);
      if (mounted) {
        AppToast.error(context, 'Failed to load communities: ${e.toString()}');
      }
    }
  }

  // ignore: unused_element
  Future<void> _handleJoinCommunity(CommunityApi community) async {
    try {
      final service = await _getService();
      
      // Check if user is within range (if location is available)
      if (_currentPosition != null && community.centerLatitude != null && community.centerLongitude != null) {
        final isInRange = await service.isUserWithinCommunityRadius(
          community.id,
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        
        if (!isInRange) {
          if (mounted) {
            AppToast.error(context, 'You are too far from this community. Must be within 20km.');
          }
        return;
        }
      }
      
      await service.joinCommunityViaApi(community.id);
      setState(() => _joinedCommunityIds.add(community.id));
      if (mounted) {
        AppToast.success(context, 'Joined community successfully');
      }
      _loadAllCommunities(); // Refresh to update UI
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to join: ${e.toString()}');
      }
    }
  }

  // ignore: unused_element
  bool _isCommunityInRange(CommunityApi community) {
    if (_currentPosition == null || 
        community.centerLatitude == null || 
        community.centerLongitude == null) {
      return true; // Assume in range if location data unavailable
    }
    
      final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      community.centerLatitude!,
      community.centerLongitude!,
    ) / 1000; // Convert to km
    
    return distance <= 20.0;
  }

  // ignore: unused_element
  double? _getCommunityDistance(CommunityApi community) {
    if (_currentPosition == null || 
        community.centerLatitude == null || 
        community.centerLongitude == null) {
      return null;
    }
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      community.centerLatitude!,
      community.centerLongitude!,
    ) / 1000; // Convert to km
  }

  Future<void> _handleJoinLeave() async {
    try {
      // Owners cannot leave their own community
      if (_isOwner) {
        if (mounted) {
          AppToast.warning(context, 'Community owners cannot leave their own community');
        }
        return;
      }

      final service = await _getService();
      if (_isMember) {
        await service.leaveCommunityViaApi(widget.communityId);
        setState(() {
          _isMember = false;
        });
        if (mounted) {
          AppToast.success(context, 'Left community successfully');
        }
      } else {
        await service.joinCommunityViaApi(widget.communityId);
        // Reload community data to get updated membership status
        await _loadCommunityData();
        if (mounted) {
          AppToast.success(context, 'Joined community successfully');
        }
      }
    } catch (e) {
      // Reload community data even on error to ensure UI is in sync
      await _loadCommunityData();
      if (mounted) {
        final errorMsg = e.toString();
        // Don't show error if user is already a member (handled gracefully)
        if (!errorMsg.contains('Already a member') && !errorMsg.contains('already a member')) {
          AppToast.error(context, 'Failed: $errorMsg');
        }
      }
    }
  }

  Future<void> _handleLikePost(String postId) async {
    try {
      final service = await _getService();
      final isLiked = _likedPosts.contains(postId);
      if (isLiked) {
        await service.unlikePost(widget.communityId, postId);
        setState(() => _likedPosts.remove(postId));
      } else {
        await service.likePost(widget.communityId, postId);
        setState(() => _likedPosts.add(postId));
      }
      // Reload posts to get updated counts
      _loadPosts();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to like post: ${e.toString()}');
      }
    }
  }

  Future<void> _handleRegisterEvent(String eventId) async {
    try {
      final service = await _getService();
      await service.registerForEventViaApi(widget.communityId, eventId);
      setState(() => _registeredEvents.add(eventId));
      if (mounted) {
        AppToast.success(context, 'Registered for event');
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to register: ${e.toString()}');
      }
    }
  }

  void _showCreatePostDialog() {
    final contentController = TextEditingController();
    final titleController = TextEditingController();
    List<File> selectedImages = [];
    File? selectedVideo;
    bool isUploading = false;
    double uploadProgress = 0.0;
    
    showDialog(
      context: context,
      barrierColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: _build3DContainer(
            radius: 28,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create Post',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Title field
                  _buildRecessedInput(
                    controller: titleController,
                    hint: 'Post title (optional)',
                    icon: Icons.title,
                  ),
                  const SizedBox(height: 16),
                  
                  // Content field
                  _buildRecessedInput(
                    controller: contentController,
                    hint: 'What\'s on your mind?',
                    icon: Icons.edit,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 20),
                  
                  // Media preview section
                  if (selectedImages.isNotEmpty || selectedVideo != null) ...[
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: selectedVideo != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    selectedVideo!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(() => selectedVideo = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Theme.of(context).colorScheme.onError,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.play_circle_filled,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Video',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(8),
                              itemCount: selectedImages.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        selectedImages[index],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setDialogState(() => selectedImages.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Theme.of(context).colorScheme.onError,
                                        size: 14,
                                      ),
                                    ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Media selection buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildMediaButton(
                          icon: Icons.photo_library,
                          label: 'Photos',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () async {
                            if (selectedVideo != null) {
                              AppToast.warning(context, 'Remove video first to add photos');
                              return;
                            }
                            if (selectedImages.length >= 5) {
                              AppToast.warning(context, 'Maximum 5 photos allowed');
                              return;
                            }
                            final picker = ImagePicker();
                            final List<XFile> images = await picker.pickMultiImage(
                              maxWidth: 1920,
                              maxHeight: 1920,
                              imageQuality: 85,
                            );
                            if (images.isNotEmpty) {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final user = auth.currentUser;
                              final displayName = user?.displayName;
                              final email = user?.email;
                              final baseName = (displayName != null && displayName.trim().isNotEmpty)
                                  ? displayName.trim()
                                  : (email != null && email.isNotEmpty
                                      ? email.split('@').first
                                      : 'bybata');
                              final handle = '@${baseName.replaceAll(' ', '').toLowerCase()}';

                              final processed = <File>[];
                              for (final imgFile in images) {
                                if (selectedImages.length + processed.length >= 5) break;
                                final normalized = await ImageResizeUtils.resizeAndWatermark(
                                  File(imgFile.path),
                                  handle,
                                );
                                processed.add(normalized);
                              }

                              if (processed.isNotEmpty) {
                                setDialogState(() {
                                  selectedImages.addAll(processed);
                                });
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMediaButton(
                          icon: Icons.videocam,
                          label: 'Video',
                          color: Theme.of(context).colorScheme.secondary,
                          onTap: () async {
                            if (selectedImages.isNotEmpty) {
                              AppToast.warning(context, 'Remove photos first to add video');
                              return;
                            }
                            final picker = ImagePicker();
                            final XFile? video = await picker.pickVideo(
                              source: ImageSource.gallery,
                              maxDuration: const Duration(minutes: 5),
                            );
                            if (video != null) {
                              setDialogState(() => selectedVideo = File(video.path));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: uploadProgress),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Uploading... ${(uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: isUploading ? null : () async {
                            if (contentController.text.trim().isEmpty && selectedImages.isEmpty && selectedVideo == null) {
                              AppToast.error(context, 'Please add content, images, or video');
                              return;
                            }
                            
                            setDialogState(() => isUploading = true);
                            
                            try {
                              List<String> imageUrls = [];
                              String? videoUrl;
                              
                              // Upload images
                              if (selectedImages.isNotEmpty) {
                                final baseUrl = await EnvConfig.getBaseUrl();
                                final storage = const FlutterSecureStorage();
                                final apiClient = ApiClient(baseUrl, storage);
                                final storageRepo = StorageRepository(apiClient.dio);
                                
                                int uploaded = 0;
                                for (var imgFile in selectedImages) {
                                  try {
                                    final bytes = await imgFile.readAsBytes();
                                    final ext = imgFile.path.toLowerCase().endsWith('.png') ? 'png' : 
                                                imgFile.path.toLowerCase().endsWith('.jpg') || imgFile.path.toLowerCase().endsWith('.jpeg') ? 'jpg' : 'bin';
                                    final contentType = ext == 'png' ? 'image/png' : 
                                                     ext == 'jpg' ? 'image/jpeg' : 'application/octet-stream';
                                    
                                    final up = await storageRepo.createUploadUrl(
                                      domain: 'communities',
                                      ext: ext,
                                      contentType: contentType,
                                    );
                                    await storageRepo.uploadToSignedUrl(
                                      uploadUrl: up['uploadUrl'] as String,
                                      bytes: bytes,
                                      contentType: contentType,
                                      onProgress: (sent, total) {
                                        final fileProgress = uploaded / selectedImages.length;
                                        final currentFileProgress = (sent / total) / selectedImages.length;
                                        setDialogState(() => uploadProgress = fileProgress + currentFileProgress);
                                      },
                                    );
                                    imageUrls.add(up['key'] as String);
                                    uploaded++;
                                    setDialogState(() => uploadProgress = uploaded / selectedImages.length);
                                  } catch (e) {
                                    debugPrint('Failed to upload image: $e');
                                  }
                                }
                              }
                              
                              // Upload video
                              if (selectedVideo != null) {
                                final baseUrl = await EnvConfig.getBaseUrl();
                                final storage = const FlutterSecureStorage();
                                final apiClient = ApiClient(baseUrl, storage);
                                final storageRepo = StorageRepository(apiClient.dio);
                                
                                try {
                                  final bytes = await selectedVideo!.readAsBytes();
                                  final ext = selectedVideo!.path.toLowerCase().endsWith('.mp4') ? 'mp4' : 
                                              selectedVideo!.path.toLowerCase().endsWith('.mov') ? 'mov' : 'mp4';
                                  final contentType = ext == 'mp4' ? 'video/mp4' : 'video/quicktime';
                                  
                                  final up = await storageRepo.createUploadUrl(
                                    domain: 'communities',
                                    ext: ext,
                                    contentType: contentType,
                                  );
                                  await storageRepo.uploadToSignedUrl(
                                    uploadUrl: up['uploadUrl'] as String,
                                    bytes: bytes,
                                    contentType: contentType,
                                    onProgress: (sent, total) {
                                      final imageProgress = selectedImages.isNotEmpty ? 1.0 : 0.0;
                                      final videoProgress = (sent / total) * 0.5;
                                      setDialogState(() => uploadProgress = imageProgress + videoProgress);
                                    },
                                  );
                                  videoUrl = up['key'] as String;
                                  setDialogState(() => uploadProgress = 1.0);
                                } catch (e) {
                                  debugPrint('Failed to upload video: $e');
                                }
                              }
                              
                              Navigator.pop(context);
                              await _createPost(
                                content: contentController.text.trim(),
                                title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
                                imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
                                videoUrl: videoUrl,
                              );
                            } catch (e) {
                              if (mounted) {
                                AppToast.error(context, 'Upload failed: ${e.toString()}');
                              }
                              setDialogState(() => isUploading = false);
                            }
                          },
                          child: _build3DContainer(
                            color: Theme.of(context).colorScheme.primary,
                            radius: 16,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Post',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPost({
    required String content,
    String? title,
    List<String>? imageUrls,
    String? videoUrl,
  }) async {
    try {
      final service = await _getService();
      String postType = 'TEXT';
      if (videoUrl != null) {
        postType = 'VIDEO';
      } else if (imageUrls != null && imageUrls.isNotEmpty) {
        postType = 'IMAGE';
      }
      
      await service.createPostViaApi(
        communityId: widget.communityId,
        title: title,
        content: content,
        type: postType,
        images: imageUrls,
        videoUrl: videoUrl,
      );
      if (mounted) {
        AppToast.success(context, 'Post created successfully');
      }
      _loadPosts();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to create post: ${e.toString()}');
      }
    }
  }

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final virtualLinkController = TextEditingController();
    final capacityController = TextEditingController();
    
    DateTime? startDate;
    DateTime? endDate;
    bool isVirtual = false;
    List<File> selectedImages = [];
    File? selectedVideo;
    bool isUploading = false;
    double uploadProgress = 0.0;
    
    showDialog(
      context: context,
      barrierColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: _build3DContainer(
            radius: 28,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create Event',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Title field
                  _buildRecessedInput(
                    controller: titleController,
                    hint: 'Event Title *',
                    icon: Icons.event,
                  ),
                  const SizedBox(height: 16),
                  
                  // Description field
                  _buildRecessedInput(
                    controller: descriptionController,
                    hint: 'Describe your event',
                    icon: Icons.description,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Date & Time pickers
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  startDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: _buildRecessedInput(
                            controller: TextEditingController(
                              text: startDate != null
                                  ? DateFormat('MMM dd, yyyy - hh:mm a').format(startDate!)
                                  : '',
                            ),
                            hint: 'Start Date & Time *',
                            icon: Icons.calendar_today,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  endDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: _buildRecessedInput(
                            controller: TextEditingController(
                              text: endDate != null
                                  ? DateFormat('MMM dd, yyyy - hh:mm a').format(endDate!)
                                  : '',
                            ),
                            hint: 'End Date & Time *',
                            icon: Icons.calendar_today,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Virtual Event toggle
                  _build3DContainer(
                    color: Theme.of(context).colorScheme.surface,
                    radius: 16,
                    child: CheckboxListTile(
                      title: Text('Virtual Event', style: Theme.of(context).textTheme.titleMedium),
                      value: isVirtual,
                      onChanged: (value) {
                        setDialogState(() {
                          isVirtual = value ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Location or Virtual Link
                  if (!isVirtual)
                    _buildRecessedInput(
                      controller: locationController,
                      hint: 'Event location',
                      icon: Icons.location_on,
                    ),
                  if (isVirtual) ...[
                    _buildRecessedInput(
                      controller: virtualLinkController,
                      hint: 'Virtual Link * (Zoom, Google Meet, etc.)',
                      icon: Icons.video_call,
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Capacity
                  _buildRecessedInput(
                    controller: capacityController,
                    hint: 'Capacity (optional)',
                    icon: Icons.people,
                  ),
                  const SizedBox(height: 20),
                  
                  // Media preview section
                  if (selectedImages.isNotEmpty || selectedVideo != null) ...[
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: selectedVideo != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    selectedVideo!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(() => selectedVideo = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Theme.of(context).colorScheme.onError,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.play_circle_filled,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Video',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(8),
                              itemCount: selectedImages.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        selectedImages[index],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setDialogState(() => selectedImages.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Theme.of(context).colorScheme.onError,
                                        size: 14,
                                      ),
                                    ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Media selection buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildMediaButton(
                          icon: Icons.photo_library,
                          label: 'Photos',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () async {
                            if (selectedVideo != null) {
                              AppToast.warning(context, 'Remove video first to add photos');
                              return;
                            }
                            if (selectedImages.length >= 5) {
                              AppToast.warning(context, 'Maximum 5 photos allowed');
                              return;
                            }
                            final picker = ImagePicker();
                            final List<XFile> images = await picker.pickMultiImage(
                              maxWidth: 1920,
                              maxHeight: 1920,
                              imageQuality: 85,
                            );
                            if (images.isNotEmpty) {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final user = auth.currentUser;
                              final displayName = user?.displayName;
                              final email = user?.email;
                              final baseName = (displayName != null && displayName.trim().isNotEmpty)
                                  ? displayName.trim()
                                  : (email != null && email.isNotEmpty
                                      ? email.split('@').first
                                      : 'bybata');
                              final handle = '@${baseName.replaceAll(' ', '').toLowerCase()}';

                              final processed = <File>[];
                              for (final imgFile in images) {
                                if (selectedImages.length + processed.length >= 5) break;
                                final normalized = await ImageResizeUtils.resizeAndWatermark(
                                  File(imgFile.path),
                                  handle,
                                );
                                processed.add(normalized);
                              }

                              if (processed.isNotEmpty) {
                                setDialogState(() {
                                  selectedImages.addAll(processed);
                                });
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMediaButton(
                          icon: Icons.videocam,
                          label: 'Video',
                          color: Theme.of(context).colorScheme.secondary,
                          onTap: () async {
                            if (selectedImages.isNotEmpty) {
                              AppToast.warning(context, 'Remove photos first to add video');
                              return;
                            }
                            final picker = ImagePicker();
                            final XFile? video = await picker.pickVideo(
                              source: ImageSource.gallery,
                              maxDuration: const Duration(minutes: 5),
                            );
                            if (video != null) {
                              setDialogState(() => selectedVideo = File(video.path));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: uploadProgress),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Uploading... ${(uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: isUploading ? null : () async {
                            if (titleController.text.trim().isEmpty) {
                              AppToast.error(context, 'Please enter an event title');
                              return;
                            }
                            if (startDate == null) {
                              AppToast.error(context, 'Please select a start date');
                              return;
                            }
                            if (endDate == null) {
                              AppToast.error(context, 'Please select an end date');
                              return;
                            }
                            if (endDate!.isBefore(startDate!)) {
                              AppToast.error(context, 'End date must be after start date');
                              return;
                            }
                            if (isVirtual && virtualLinkController.text.trim().isEmpty) {
                              AppToast.error(context, 'Please enter a virtual link');
                              return;
                            }
                            
                            setDialogState(() => isUploading = true);
                            
                            try {
                              List<String> imageUrls = [];
                              String? videoUrl;
                              
                              // Upload images
                              if (selectedImages.isNotEmpty) {
                                final baseUrl = await EnvConfig.getBaseUrl();
                                final storage = const FlutterSecureStorage();
                                final apiClient = ApiClient(baseUrl, storage);
                                final storageRepo = StorageRepository(apiClient.dio);
                                
                                int uploaded = 0;
                                for (var imgFile in selectedImages) {
                                  try {
                                    final bytes = await imgFile.readAsBytes();
                                    final ext = imgFile.path.toLowerCase().endsWith('.png') ? 'png' : 
                                                imgFile.path.toLowerCase().endsWith('.jpg') || imgFile.path.toLowerCase().endsWith('.jpeg') ? 'jpg' : 'bin';
                                    final contentType = ext == 'png' ? 'image/png' : 
                                                     ext == 'jpg' ? 'image/jpeg' : 'application/octet-stream';
                                    
                                    final up = await storageRepo.createUploadUrl(
                                      domain: 'communities',
                                      ext: ext,
                                      contentType: contentType,
                                    );
                                    await storageRepo.uploadToSignedUrl(
                                      uploadUrl: up['uploadUrl'] as String,
                                      bytes: bytes,
                                      contentType: contentType,
                                      onProgress: (sent, total) {
                                        final fileProgress = uploaded / selectedImages.length;
                                        final currentFileProgress = (sent / total) / selectedImages.length;
                                        setDialogState(() => uploadProgress = fileProgress + currentFileProgress);
                                      },
                                    );
                                    imageUrls.add(up['key'] as String);
                                    uploaded++;
                                    setDialogState(() => uploadProgress = uploaded / selectedImages.length);
                                  } catch (e) {
                                    debugPrint('Failed to upload image: $e');
                                  }
                                }
                              }
                              
                              // Upload video
                              if (selectedVideo != null) {
                                final baseUrl = await EnvConfig.getBaseUrl();
                                final storage = const FlutterSecureStorage();
                                final apiClient = ApiClient(baseUrl, storage);
                                final storageRepo = StorageRepository(apiClient.dio);
                                
                                try {
                                  final bytes = await selectedVideo!.readAsBytes();
                                  final ext = selectedVideo!.path.toLowerCase().endsWith('.mp4') ? 'mp4' : 
                                              selectedVideo!.path.toLowerCase().endsWith('.mov') ? 'mov' : 'mp4';
                                  final contentType = ext == 'mp4' ? 'video/mp4' : 'video/quicktime';
                                  
                                  final up = await storageRepo.createUploadUrl(
                                    domain: 'communities',
                                    ext: ext,
                                    contentType: contentType,
                                  );
                                  await storageRepo.uploadToSignedUrl(
                                    uploadUrl: up['uploadUrl'] as String,
                                    bytes: bytes,
                                    contentType: contentType,
                                    onProgress: (sent, total) {
                                      final imageProgress = selectedImages.isNotEmpty ? 1.0 : 0.0;
                                      final videoProgress = (sent / total) * 0.5;
                                      setDialogState(() => uploadProgress = imageProgress + videoProgress);
                                    },
                                  );
                                  videoUrl = up['key'] as String;
                                  setDialogState(() => uploadProgress = 1.0);
                                } catch (e) {
                                  debugPrint('Failed to upload video: $e');
                                }
                              }
                              
                              Navigator.pop(context);
                              await _createEvent(
                                title: titleController.text.trim(),
                                description: descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                                startDate: startDate!,
                                endDate: endDate!,
                                location: locationController.text.trim().isEmpty
                                    ? null
                                    : locationController.text.trim(),
                                isVirtual: isVirtual,
                                virtualLink: virtualLinkController.text.trim().isEmpty
                                    ? null
                                    : virtualLinkController.text.trim(),
                                capacity: capacityController.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(capacityController.text.trim()),
                                imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
                                videoUrl: videoUrl,
                              );
                            } catch (e) {
                              if (mounted) {
                                AppToast.error(context, 'Upload failed: ${e.toString()}');
                              }
                              setDialogState(() => isUploading = false);
                            }
                          },
                          child: _build3DContainer(
                            color: Theme.of(context).colorScheme.primary,
                            radius: 16,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Create Event',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createEvent({
    required String title,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    bool isVirtual = false,
    String? virtualLink,
    int? capacity,
    List<String>? imageUrls,
    String? videoUrl,
  }) async {
    try {
      final service = await _getService();
      await service.createEventViaApi(
        communityId: widget.communityId,
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        location: location,
        isVirtual: isVirtual,
        virtualLink: virtualLink,
        capacity: capacity,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
      );
      if (mounted) {
        AppToast.success(context, 'Event created successfully');
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to create event: ${e.toString()}');
      }
    }
  }

  Widget _build3DContainer({required Widget child, Color? color, double radius = 24, EdgeInsets? padding}) {
    return ByBataGlassContainer(
      padding: padding,
      borderRadius: BorderRadius.circular(radius),
      child: color == null
          ? child
          : Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: child,
            ),
    );
  }
  
  Widget _buildRecessedInput({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: scheme.onSurface.withValues(alpha: 0.6)) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
  
  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _build3DContainer(
        color: color.withValues(alpha: 0.1),
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double halfTopInset = MediaQuery.of(context).padding.top / 2;

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          SizedBox(height: halfTopInset + 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: _build3DContainer(
                  color: scheme.surface,
                  radius: 14,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, color: scheme.onSurface),
                  ),
                ),
              ),
            ),
          ),
          _buildHeader(),
          _buildTabSwitcher(),
          Expanded(
            child: TabBarView(
          controller: _tabController,
              children: [
                _buildAllCommunitiesTab(),
                _buildFeedTab(),
                _buildEventsTab(),
                _buildChatTab(),
                _buildMembersTab(),
          ],
        ),
      ),
        ],
      ),
      floatingActionButton: _isMember && _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreatePostDialog,
              icon: const Icon(Icons.add),
              label: const Text('Post'),
              backgroundColor: scheme.primary,
            )
          : _isMember && _tabController.index == 2
              ? FloatingActionButton.extended(
                  onPressed: _showCreateEventDialog,
                  icon: const Icon(Icons.event),
                  label: const Text('Event'),
                  backgroundColor: scheme.primary,
                )
              : null,
    );
  }

  Widget _buildHeader() {
    if (_isLoadingCommunity) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: const BybataLoader(),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    Text(
                      _community?.name ?? widget.communityName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_community?.shortDescription != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _community!.shortDescription!,
                        style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isOwner ? null : _handleJoinLeave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOwner
                      ? scheme.secondary
                      : (_isMember ? scheme.surfaceContainerHighest : scheme.primary),
                  foregroundColor: _isOwner || !_isMember
                      ? scheme.onPrimary
                      : scheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(_isOwner ? 'Owner' : (_isMember ? 'Leave' : 'Join')),
                            ),
                          ],
                        ),
          if (_community != null) ...[
            const SizedBox(height: 12),
              Row(
                          children: [
                _buildStatChip(Icons.people, '${_community!.memberCount}'),
                  const SizedBox(width: 16),
                _buildStatChip(Icons.article, '${_community!.postCount}'),
                const SizedBox(width: 16),
                _buildStatChip(Icons.event, '${_community!.eventCount}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    final labels = ['All', 'Feed', 'Events', 'Chat', 'Members'];
    final scheme = Theme.of(context).colorScheme;
    final pendingLabel = _pendingJoinRequestCount > 99 ? '99+' : _pendingJoinRequestCount.toString();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            alignment: Alignment(-1.0 + (_tabController.index * (2.0 / (labels.length - 1))), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.onSurface.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                            ),
                          ],
                        ),
        ),
            ),
          ),
          Row(
            children: List.generate(labels.length, (index) {
              final label = labels[index];
              final isActive = _tabController.index == index;
              final showBadge = label == 'Members' && _canModerate && _pendingJoinRequestCount > 0;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(index),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isActive ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        if (showBadge) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              pendingLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCommunitiesTab() {
    // Combined feed of posts and events, sorted by creation date (latest first)
    final combinedItems = <Map<String, dynamic>>[];
    
    // Add posts with type marker
    for (var post in _posts) {
      combinedItems.add({
        ...post,
        '_itemType': 'post',
        '_sortDate': post['createdAt'] ?? post['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }
    
    // Add events with type marker
    for (var event in _events) {
      combinedItems.add({
        ...event,
        '_itemType': 'event',
        '_sortDate': event['createdAt'] ?? event['created_at'] ?? event['startDate'] ?? event['start_date'] ?? DateTime.now().toIso8601String(),
      });
    }
    
    // Sort by creation date (latest first)
    combinedItems.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['_sortDate'] as String);
        final dateB = DateTime.parse(b['_sortDate'] as String);
        return dateB.compareTo(dateA); // Latest first
      } catch (e) {
        return 0;
      }
    });

    final isLoading = _isLoadingPosts || _isLoadingEvents;

    if (isLoading && combinedItems.isEmpty) {
      return const BybataLoader();
    }

    if (!_isMember && combinedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Join to view posts and events',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to be a member to view community content',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleJoinLeave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Join Community'),
            ),
          ],
        ),
      );
    }

    if (combinedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feed_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No posts or events yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to post or create an event!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadPosts(), _loadEvents()]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: combinedItems.length,
        itemBuilder: (context, index) {
          final item = combinedItems[index];
          final itemType = item['_itemType'] as String;
          
          if (itemType == 'post') {
            final postId = item['id'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PostItem(
                post: item,
                isLiked: _likedPosts.contains(postId),
                onLike: () => _handleLikePost(postId),
                onComment: () => _showCommentsDialog(item),
                onShare: () {
                  AppToast.info(context, 'Share coming soon');
                },
              ),
            );
          } else if (itemType == 'event') {
            final eventId = item['id'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: EventCard(
                event: item,
                isRegistered: _registeredEvents.contains(eventId),
                onRegister: () => _handleRegisterEvent(eventId),
                onTap: () {
                  // TODO: Navigate to event details
                  AppToast.info(context, 'Event details coming soon');
                },
              ),
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildFeedTab() {
    if (_isLoadingPosts) {
      return const BybataLoader();
    }

    if (_posts.isEmpty) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
              const SizedBox(height: 16),
              Text(
              'No posts yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to post!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              ),
            ],
          ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          final postId = post['id'] ?? '';
          return PostItem(
            post: post,
            isLiked: _likedPosts.contains(postId),
            onLike: () => _handleLikePost(postId),
            onComment: () => _showCommentsDialog(post),
            onShare: () {
              // TODO: Implement share
              AppToast.info(context, 'Share coming soon');
            },
          );
        },
        ),
      );
    }

  Widget _buildEventsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Upcoming'),
                  selected: _showUpcomingEvents,
                  onSelected: (selected) {
                    setState(() => _showUpcomingEvents = selected);
                    _loadEvents();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Past'),
                  selected: !_showUpcomingEvents,
                  onSelected: (selected) {
                    setState(() => _showUpcomingEvents = !selected);
                    _loadEvents();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingEvents
              ? const BybataLoader()
              : !_isMember && _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
            children: [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Join to view events',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You need to be a member to view events',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _handleJoinLeave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Join Community'),
                          ),
                        ],
                      ),
                    )
              : _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
            children: [
                          Icon(
                            Icons.event_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events yet',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 16,
                            ),
                          ),
            ],
          ),
        )
                  : RefreshIndicator(
                      onRefresh: _loadEvents,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final eventId = event['id'] ?? '';
                          return EventCard(
                            event: event,
                            isRegistered: _registeredEvents.contains(eventId),
                            onRegister: () => _handleRegisterEvent(eventId),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildChatTab() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Ensure members are loaded when this tab is accessed
        if (_members.isEmpty && !_isLoadingMembers) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadMembers();
          });
        }

        // Load conversations if not already loaded
        if (!chatProvider.isLoading && chatProvider.conversations.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            chatProvider.refreshConversations();
          });
        }

        // Extract member user IDs from the community members list
        // Handle different possible ID formats from the API
        final Set<String> communityMemberIds = _members
            .map<String>((member) {
              // Try multiple possible ID locations
              final user = member['user'] as Map<String, dynamic>? ?? {};
              final userId = user['id'] ?? 
                           user['sub'] ?? 
                           member['userId'] ?? 
                           member['id'] ?? 
                           '';
              return userId.toString().trim();
            })
            .where((id) => id.isNotEmpty)
            .toSet();

        // Debug: Print member IDs for troubleshooting
        if (communityMemberIds.isNotEmpty) {
          debugPrint('[ChatTab] Community member IDs: $communityMemberIds');
        }

        // Filter to show only direct message conversations
        List<ChatConversation> directConversations = chatProvider.conversations
            .where((c) => c.chatType == ChatType.direct)
            .toList();

        debugPrint('[ChatTab] Total direct conversations: ${directConversations.length}');
        if (directConversations.isNotEmpty) {
          debugPrint('[ChatTab] Sample conversation otherUserId: ${directConversations.first.otherUserId}');
        }

        // Filter to only show conversations with community members
        // Only filter if we have members loaded, otherwise show empty
        List<ChatConversation> communityMemberConversations = [];
        final int totalDirectConversations = directConversations.length;
        if (!_isLoadingMembers && _members.isNotEmpty && communityMemberIds.isNotEmpty) {
          communityMemberConversations = directConversations
              .where((conv) {
                // Normalize IDs for comparison (remove any whitespace, convert to string)
                final convUserId = conv.otherUserId.toString().trim();
                final isMatch = communityMemberIds.contains(convUserId);
                if (isMatch) {
                  debugPrint('[ChatTab] Matched conversation with user: ${conv.otherUserName} ($convUserId)');
                }
                return isMatch;
              })
              .toList();
          debugPrint('[ChatTab] Filtered conversations: ${communityMemberConversations.length}');
        } else if (_isLoadingMembers) {
          debugPrint('[ChatTab] Still loading members...');
        } else if (_members.isEmpty) {
          debugPrint('[ChatTab] No members loaded yet');
        } else if (communityMemberIds.isEmpty) {
          debugPrint('[ChatTab] No member IDs extracted from members list');
        }

        // Filter conversations based on search query
        List<ChatConversation> filteredConversations = communityMemberConversations;
        if (_chatSearchQuery.isNotEmpty) {
          final query = _chatSearchQuery.toLowerCase();
          filteredConversations = communityMemberConversations.where((conv) {
            final name = conv.otherUserName.toLowerCase();
            return name.contains(query);
          }).toList();
        }

        // Sort by last activity (most recent first)
        filteredConversations.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

        // One row per contact (WhatsApp-style) — no repeated users.
        filteredConversations = dedupeConversationsByContact(filteredConversations);
        
        // Store counts for use in empty state
        final bool hasDirectConversations = totalDirectConversations > 0;
        final bool hasCommunityMemberConversations = communityMemberConversations.isNotEmpty;

        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _chatSearchController,
                decoration: BorderlessInputDecoration.search(
                  hintText: 'Search by username...',
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  suffixIcon: _chatSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _chatSearchController.clear();
                            setState(() {
                              _chatSearchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                onChanged: (value) {
                  setState(() {
                    _chatSearchQuery = value;
                  });
                },
              ),
            ),
            Expanded(
              child: chatProvider.isLoading || _isLoadingMembers
                  ? const BybataLoader()
                  : filteredConversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _chatSearchQuery.isNotEmpty
                                    ? Icons.search_off
                                    : Icons.chat_bubble_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _chatSearchQuery.isNotEmpty
                                    ? 'No conversations found'
                                    : _isLoadingMembers
                                        ? 'Loading members...'
                                        : _members.isEmpty
                                            ? 'No members found'
                                            : chatProvider.conversations.isEmpty
                                                ? 'No conversations yet'
                                                : !hasDirectConversations
                                                    ? 'No direct messages yet'
                                                    : 'No conversations with community members yet',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _chatSearchQuery.isNotEmpty
                                    ? 'Try a different search term'
                                    : _isLoadingMembers
                                        ? 'Please wait while we load community members'
                                        : _members.isEmpty
                                            ? 'This community has no members'
                                            : chatProvider.conversations.isEmpty
                                                ? 'You haven\'t started any conversations yet'
                                                : !hasDirectConversations
                                                    ? 'You don\'t have any direct messages'
                                                    : 'Start a conversation with a community member from the Members tab',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!_isLoadingMembers && _members.isNotEmpty && hasDirectConversations && !hasCommunityMemberConversations) ...[
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    'Note: You have $totalDirectConversations conversation(s), but none are with members of this community.',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await chatProvider.refreshConversations();
                            await _loadMembers(); // Refresh members list as well
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredConversations.length,
                            itemBuilder: (context, index) {
                              final conversation = filteredConversations[index];
                              return _buildConversationTile(conversation, chatProvider);
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversationTile(ChatConversation conversation, ChatProvider chatProvider) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: scheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: scheme.primary.withValues(alpha: 0.1),
          backgroundImage: conversation.otherUserAvatar.isNotEmpty &&
                  conversation.otherUserAvatar.startsWith('http')
              ? NetworkImage(conversation.otherUserAvatar)
              : null,
          child: conversation.otherUserAvatar.isEmpty ||
                  !conversation.otherUserAvatar.startsWith('http')
              ? Text(
                  conversation.otherUserName.isNotEmpty
                      ? conversation.otherUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: scheme.primary,
                  ),
                )
              : null,
        ),
        title: Text(
          conversation.otherUserName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: conversation.lastMessage != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage!.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatLastActivity(conversation.lastActivity),
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Text(
                _formatLastActivity(conversation.lastActivity),
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
        trailing: conversation.unreadCount > 0
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () {
          GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => DMInboxScreen(
                partnerId: conversation.otherUserId,
                partnerName: conversation.otherUserName,
                existingConversation: conversation,
              ),
            ),
          ).then((_) {
            // Refresh conversations when returning from chat
            chatProvider.refreshConversations();
          });
        },
      ),
    );
  }

  String _formatLastActivity(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showInviteDialog() async {
    final recipientsController = TextEditingController();
    final messageController = TextEditingController();
    final expiryController = TextEditingController(text: '7');
    final templateController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: recipientsController,
              decoration: const InputDecoration(
                labelText: 'Recipients (emails, usernames, or id:USERID)',
              ),
            ),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message (optional)'),
              maxLines: 2,
            ),
            TextField(
              controller: expiryController,
              decoration: const InputDecoration(labelText: 'Expires in days'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: templateController,
              decoration: const InputDecoration(labelText: 'Template key (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final raw = recipientsController.text.trim();
              if (raw.isEmpty) return;
              final parts = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final emails = <String>[];
              final userIds = <String>[];
              final usernames = <String>[];
              for (final p in parts) {
                if (p.toLowerCase().startsWith('id:')) {
                  userIds.add(p.substring(3).trim());
                } else if (p.startsWith('@')) {
                  usernames.add(p.substring(1));
                } else if (p.contains('@')) {
                  emails.add(p);
                } else {
                  usernames.add(p);
                }
              }
              final days = int.tryParse(expiryController.text.trim()) ?? 7;
              final expiresAt = DateTime.now().add(Duration(days: days));
              try {
                final service = await _getService();
                await service.inviteMembers(
                  widget.communityId,
                  userIds: userIds.isEmpty ? null : userIds,
                  emails: emails.isEmpty ? null : emails,
                  usernames: usernames.isEmpty ? null : usernames,
                  message: messageController.text.trim(),
                  expiresAt: expiresAt,
                  templateKey: templateController.text.trim().isEmpty ? null : templateController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(context);
                  AppToast.success(context, 'Invite sent');
                  await _loadInvites();
                }
              } catch (e) {
                if (mounted) {
                  AppToast.error(context, 'Failed to invite: ${e.toString()}');
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeInvite(String inviteId) async {
    try {
      final service = await _getService();
      await service.revokeInvite(widget.communityId, inviteId: inviteId);
      await _loadInvites();
      if (mounted) AppToast.info(context, 'Invite revoked');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Failed to revoke invite: ${e.toString()}');
    }
  }

  Future<void> _resendInvite(String inviteId) async {
    try {
      final service = await _getService();
      await service.resendInvite(widget.communityId, inviteId: inviteId);
      if (mounted) AppToast.success(context, 'Invite resent');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Failed to resend invite: ${e.toString()}');
    }
  }

  Widget _buildMembersTab() {
    if (_isLoadingMembers) {
      return const BybataLoader();
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadMembers();
        if (_isOwner) await _loadInvites();
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_canModerate) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Join Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _openModerationScreen,
                  icon: const Icon(Icons.shield_moon_outlined),
                  label: Text(
                    _pendingJoinRequestCount > 0
                        ? 'View (${_pendingJoinRequestCount > 99 ? '99+' : _pendingJoinRequestCount})'
                        : 'View',
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
          ],
          if (_isOwner) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pending Invites', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _showInviteDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite'),
                ),
              ],
            ),
            if (_isLoadingInvites)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else if (_communityInvites.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No pending invites',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              )
            else
              ..._communityInvites.map((invite) {
                final invitee = invite['invitee'] ?? {};
                final profile = invitee['profile'] ?? {};
                final message = invite['message']?.toString();
                final expiresAt = invite['expiresAt']?.toString();
                final inviteId = invite['id']?.toString() ?? '';
                final inviteeEmail = invite['inviteeEmail']?.toString();
                final inviteCode = invite['inviteCode']?.toString();
                final inviteLink = invite['inviteLink']?.toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(profile['displayName'] ?? inviteeEmail ?? 'User'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message != null && message.isNotEmpty) Text(message),
                        if (expiresAt != null && expiresAt.isNotEmpty)
                          Text(
                            'Expires: $expiresAt',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        if (inviteCode != null && inviteCode.isNotEmpty)
                          Text(
                            'Code: $inviteCode',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        if (inviteLink != null && inviteLink.isNotEmpty)
                          Text(
                            'Link: $inviteLink',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: inviteId.isEmpty ? null : () => _resendInvite(inviteId),
                          child: const Text('Resend'),
                        ),
                        TextButton(
                          onPressed: inviteId.isEmpty ? null : () => _revokeInvite(inviteId),
                          child: const Text('Revoke'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const Divider(height: 32),
          ],
          if (_members.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No members yet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._members.map((member) {
              final user = member['user'] ?? {};
              final userId = user['id'] ?? member['userId'] ?? '';
              return MemberCard(
                member: member,
                canManage: _isOwner || _isMember, // TODO: Check for admin role
                onTap: userId.isNotEmpty
                    ? () {
                        GuardedNavigator.push(context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: userId),
                          ),
                        );
                      }
                    : null,
              );
            }),
        ],
      ),
    );
  }

  void _showCommentsDialog(Map<String, dynamic> post) {
    final postId = post['id'] ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsBottomSheet(
        communityId: widget.communityId,
        postId: postId,
        getService: _getService,
      ),
    );
  }
}

class _CommentsBottomSheet extends StatefulWidget {
  final String communityId;
  final String postId;
  final Future<CommunityApiService> Function() getService;

  const _CommentsBottomSheet({
    required this.communityId,
    required this.postId,
    required this.getService,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final service = await widget.getService();
      final comments = await service.getPostComments(
        widget.communityId,
        widget.postId,
      );
    setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final content = _commentController.text.trim();
    _commentController.clear();
    try {
      final service = await widget.getService();
      await service.createPostComment(
        communityId: widget.communityId,
        postId: widget.postId,
        content: content,
      );
      _loadComments();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to post comment');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
            return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
                      children: [
                        Container(
              padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                              IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const BybataLoader()
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final author = comment['author'] ?? {};
                            final authorName = author['name'] ?? author['displayName'] ?? 'Anonymous';
                            final avatarUrl = author['profile']?['avatarUrl'] ?? author['avatarUrl'];
                            final createdAt = comment['createdAt'] is String
                                ? DateTime.tryParse(comment['createdAt'])
                                : comment['createdAt'] as DateTime?;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    backgroundImage: avatarUrl != null && avatarUrl.toString().startsWith('http')
                                        ? NetworkImage(avatarUrl.toString())
                                        : null,
                                    child: avatarUrl == null || !avatarUrl.toString().startsWith('http')
                                        ? Text(authorName[0].toUpperCase(), style: const TextStyle(fontSize: 14))
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                                            Text(
                                              authorName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            if (createdAt != null) ...[
              const SizedBox(width: 8),
                                              Text(
                                                _formatDate(createdAt),
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment['content'] ?? '',
                                          style: const TextStyle(fontSize: 14, height: 1.4),
                                        ),
                                      ],
                                    ),
          ),
        ],
      ),
    );
                          },
                        ),
            ),
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
        child: Row(
          children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
              ),
              const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                    onPressed: _postComment,
                  ),
            ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
