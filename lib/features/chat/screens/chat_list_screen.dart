import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../../features/settings/widgets/settings_ui.dart';
import '../../../core/widgets/hub_screen_top_bar.dart';
import '../../../core/widgets/hub_fluid_tab_switcher.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/tick_status.dart';
import '../providers/chat_provider.dart';
import '../utils/conversation_inbox_dedupe.dart';
import '../widgets/v2/message_status_ticks.dart';
import 'chat_screen.dart';
import 'chat_settings_screen.dart';
import '../../trade/screens/trade_chat_screen.dart';
import '../../trade/models/trade_models.dart' as trade_models;
import '../../trade/providers/trade_backend_provider.dart';
import '../../donations/screens/donation_chat_screen.dart';
import '../../donations/models/donation_models.dart' as donation_models;
import '../../donations/providers/campaign_provider.dart';
import '../../gifting/screens/gift_request_chat_screen.dart';
import '../../gifting/models/gift_models.dart' as gift_models;
import '../../gifting/providers/gift_provider.dart';
import '../../community/screens/dm_inbox_screen.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class ChatListScreen extends StatefulWidget {
  final List<ChatConversation>? conversations;
  final bool showBackButton;

  const ChatListScreen({
    super.key,
    this.conversations,
    this.showBackButton = true,
  });

  bool get _embeddedInMainNav => !showBackButton;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<ChatConversation> _filteredConversations = [];
  String _selectedModule = 'All';
  String _searchQuery = '';

  final List<String> _modules = [
    'All',
    'Trade',
    'Donation',
    'Gift',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _modules.length, vsync: this);
    _tabController.addListener(_onTabControllerUpdate);
    
    _filteredConversations = widget.conversations ?? [];
    
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next != _searchQuery) {
        setState(() {
          _searchQuery = next;
        });
      }
    });

    if (widget.conversations == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ChatProvider>().refreshConversations(force: true);
      });
    }
  }

  void _onTabControllerUpdate() {
    if (_tabController.indexIsChanging) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    setState(() {
      _selectedModule = _modules[_tabController.index];
      _updateFilteredConversations();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerUpdate);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilteredConversations() {
    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final source = widget.conversations ?? chatProvider.conversations;
    _filteredConversations = source;
  }

  List<ChatConversation> _applySearch(List<ChatConversation> source) {
    if (_searchQuery.isEmpty) return source;
    final needle = _searchQuery.toLowerCase();
    return source.where((conversation) {
      final otherUser = conversation.otherUserName.toLowerCase();
      final contextText = conversation.contextTitle.toLowerCase();
      final lastMessage = (conversation.lastMessage?.message ?? '').toLowerCase();
      return otherUser.contains(needle) || contextText.contains(needle) || lastMessage.contains(needle);
    }).toList();
  }

  Future<void> _loadConversationsByModule(String? filter) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (filter == null || filter == 'All') {
      await chatProvider.refreshConversations();
      if (mounted) setState(() => _updateFilteredConversations());
      return;
    }
    String? module;
    switch (filter) {
      case 'Trade': module = 'TRADE'; break;
      case 'Gift': module = 'GIFT'; break;
      case 'Donation': module = 'DONATION'; break;
    }
    if (module != null) {
      await chatProvider.loadConversationsByModule(module);
      if (mounted) setState(() => _updateFilteredConversations());
    }
  }

  ChatType _getChatTypeFromModule(String module) {
    switch (module) {
      case 'Trade': return ChatType.trade;
      case 'Donation': return ChatType.donation;
      case 'Gift': return ChatType.gifting;
      default: return ChatType.direct;
    }
  }

  Color _getChatTypeColor(ChatType type) {
    return AppTheme.primaryColor;
  }

  IconData _getChatTypeIcon(ChatType type) {
    switch (type) {
      case ChatType.trade: return Icons.swap_horiz_rounded;
      case ChatType.gifting: return Icons.card_giftcard_rounded;
      case ChatType.donation: return Icons.volunteer_activism_rounded;
      case ChatType.community: return Icons.groups_rounded;
      default: return Icons.chat_bubble_outline_rounded;
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'Trade': return Icons.swap_horiz_rounded;
      case 'Donation': return Icons.volunteer_activism_rounded;
      case 'Gift': return Icons.card_giftcard_rounded;
      case 'Community': return Icons.groups_rounded;
      default: return Icons.chat_bubble_outline_rounded;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'now';
  }

  Future<void> _openChat(ChatConversation conversation) async {
    if (!mounted) return;

    // Prefetch history before the route paints so reopen feels instant.
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.upsertConversation(conversation);
    unawaited(chatProvider.loadMessages(conversation.id));

    switch (conversation.chatType) {
      case ChatType.trade:
        GuardedNavigator.push(context,
          MaterialPageRoute(
            builder: (context) => TradeChatScreen(
              trade: null,
              partnerId: conversation.otherUserId,
              partnerName: conversation.otherUserName,
              existingConversation: conversation,
            ),
          ),
        );
        break;
      case ChatType.donation:
        GuardedNavigator.push(context,
          MaterialPageRoute(
            builder: (context) => DonationChatScreen(
              campaign: null,
              partnerId: conversation.otherUserId,
              partnerName: conversation.otherUserName,
              existingConversation: conversation,
            ),
          ),
        );
        break;
      case ChatType.gifting:
        GuardedNavigator.push(context,
          MaterialPageRoute(
            builder: (context) => GiftRequestChatScreen(
              request: null,
              partnerId: conversation.otherUserId,
              partnerName: conversation.otherUserName,
              existingConversation: conversation,
            ),
          ),
        );
        break;
      case ChatType.community:
      case ChatType.direct:
        if (conversation.contextTitle.toLowerCase().contains('gift')) {
          GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (context) => GiftRequestChatScreen(
                request: null,
                partnerId: conversation.otherUserId,
                partnerName: conversation.otherUserName,
                existingConversation: conversation,
              ),
            ),
          );
        } else if (conversation.chatType == ChatType.community ||
            conversation.contextTitle.toLowerCase().contains('community')) {
          GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (context) => DMInboxScreen(
                partnerId: conversation.otherUserId,
                partnerName: conversation.otherUserName,
                existingConversation: conversation,
              ),
            ),
          );
        } else {
          GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversation: conversation,
                chatType: conversation.chatType,
              ),
            ),
          );
        }
        break;
      default:
        GuardedNavigator.push(context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversation: conversation,
              chatType: conversation.chatType,
            ),
          ),
        );
    }
  }

  Future<void> _openTradeChat(ChatConversation conversation) async {
    trade_models.Trade? trade;
    try {
      if (conversation.contextId.isNotEmpty) {
        final tradeProvider = Provider.of<TradeBackendProvider>(context, listen: false);
        final tradeData = await tradeProvider.getTrade(conversation.contextId);
        if (tradeData != null) trade = trade_models.Trade.fromJson(tradeData);
      }
    } catch (e) { debugPrint('Could not load trade details: $e'); }
    
    if (mounted) {
      Navigator.pop(context);
      GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => TradeChatScreen(trade: trade, partnerId: conversation.otherUserId, partnerName: conversation.otherUserName, existingConversation: conversation)));
    }
  }

  Future<void> _openDonationChat(ChatConversation conversation) async {
    donation_models.Campaign? campaign;
    try {
      if (conversation.contextId.isNotEmpty) {
        final campaignProvider = Provider.of<CampaignProvider>(context, listen: false);
        campaign = await campaignProvider.getCampaign(conversation.contextId);
      }
    } catch (e) { debugPrint('Could not load campaign details: $e'); }
    
    if (mounted) {
      Navigator.pop(context);
      GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => DonationChatScreen(campaign: campaign, partnerId: conversation.otherUserId, partnerName: conversation.otherUserName, existingConversation: conversation)));
    }
  }

  Future<void> _openGiftChat(ChatConversation conversation) async {
    gift_models.GiftRequest? request;
    try {
      final giftId = conversation.contextId.isNotEmpty ? conversation.contextId : conversation.id;
      if (giftId.isNotEmpty) {
        final giftProvider = Provider.of<GiftProvider>(context, listen: false);
        final gift = await giftProvider.getGift(giftId);
        
        if (gift != null) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final currentUserId = authProvider.currentUser?.id ?? '';
          final isCurrentUserGiver = gift.giver.id == currentUserId;
          
          final requester = isCurrentUserGiver
              ? gift_models.GiftUser(
                  id: conversation.otherUserId, name: conversation.otherUserName,
                  username: '@${conversation.otherUserName.replaceAll(' ', '').toLowerCase()}',
                  rating: 0.0, completedGifts: 0, karmaPoints: 0, joinedDate: DateTime.now(), isVerified: false,
                )
              : gift_models.GiftUser(
                  id: currentUserId, name: authProvider.currentUser?.displayName ?? 'You',
                  username: '@${authProvider.currentUser?.email?.split('@').first ?? 'user'}',
                  rating: authProvider.currentUser?.rating ?? 0.0, completedGifts: 0, karmaPoints: authProvider.currentUser?.karmaPoints ?? 0,
                  joinedDate: authProvider.currentUser?.createdAt ?? DateTime.now(), isVerified: authProvider.currentUser?.isVerified ?? false,
                );

          request = gift_models.GiftRequest(
            id: conversation.id, giftId: giftId, gift: gift, requester: requester,
            message: null, createdAt: conversation.lastActivity, status: gift_models.GiftRequestStatus.approved,
            respondedAt: null, responseMessage: null,
          );
        }
      }
    } catch (e) { debugPrint('Could not load gift details: $e'); }
    
    if (mounted) {
      Navigator.pop(context);
      GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => GiftRequestChatScreen(request: request, partnerId: conversation.otherUserId, partnerName: conversation.otherUserName, existingConversation: conversation)));
    }
  }

  Future<void> _openCommunityChat(ChatConversation conversation) async {
    if (mounted) {
      Navigator.pop(context);
      GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => DMInboxScreen(partnerId: conversation.otherUserId, partnerName: conversation.otherUserName, existingConversation: conversation)));
    }
  }

  Future<void> _openDirectMessageChat(ChatConversation conversation) async {
    if (mounted) {
      Navigator.pop(context);
      GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => DMInboxScreen(partnerId: conversation.otherUserId, partnerName: conversation.otherUserName, existingConversation: conversation)));
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassModal(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.mark_email_read_rounded, color: AppTheme.primaryColor),
              title: const Text('Mark All as Read', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () { Navigator.pop(context); _markAllAsRead(); },
            ),
            ListTile(
              leading: Icon(Icons.settings_rounded, color: AppTheme.primaryColor),
              title: const Text('Chat Settings', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                GuardedNavigator.push(context, MaterialPageRoute(builder: (context) => const ChatSettingsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showConversationOptions(ChatConversation conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassModal(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(conversation.isActive ? Icons.archive_rounded : Icons.unarchive_rounded, color: AppTheme.primaryColor),
              title: Text(conversation.isActive ? 'Archive Chat' : 'Unarchive Chat', style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () { Navigator.pop(context); _toggleArchive(conversation); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              title: const Text('Delete Chat', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.redAccent)),
              onTap: () { Navigator.pop(context); _deleteChat(conversation); },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
              title: const Text('Block User', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.redAccent)),
              onTap: () { Navigator.pop(context); _blockUser(conversation); },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleArchive(ChatConversation conversation) => _showSnackBar(conversation.isActive ? 'Chat archived' : 'Chat unarchived');
  
  void _deleteChat(ChatConversation conversation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1A28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Chat', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete your conversation with ${conversation.otherUserName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { Navigator.pop(context); _showSnackBar('Chat deleted'); }, child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _blockUser(ChatConversation conversation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1A28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Block User', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to block ${conversation.otherUserName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () { Navigator.pop(context); _showSnackBar('User blocked'); }, child: const Text('Block', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _markAllAsRead() => _showSnackBar('All chats marked as read');
  
  void _showSnackBar(String message) {
    AppToast.info(context, message);
  }

  int _getUnreadCountForModule(String module, List<ChatConversation> conversations) {
    if (module == 'All') {
      return conversations.fold(0, (sum, c) => sum + c.unreadCount);
    }
    final moduleType = _getChatTypeFromModule(module);
    return conversations.where((c) {
      if (module == 'Gift') {
        return c.chatType == ChatType.gifting || (c.chatType == ChatType.direct && c.contextTitle.toLowerCase().contains('gift'));
      }
      return c.chatType == moduleType;
    }).fold(0, (sum, c) => sum + c.unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pageBg = SettingsUi.pageBackground(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final body = SafeArea(
      top: false,
      bottom: false,
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          final conversations = widget.conversations ?? chatProvider.conversations;

          if (!chatProvider.isLoading && chatProvider.conversations.isEmpty && widget.conversations == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              chatProvider.refreshConversations(force: true);
            });
          }

          final tabLabels = _modules.map((module) {
            final unread = _getUnreadCountForModule(module, conversations);
            if (unread <= 0) return module;
            return '$module · ${unread > 99 ? '99+' : unread}';
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget._embeddedInMainNav)
                HubScreenTopBar(
                  title: 'Messages',
                  onBack: () => Navigator.pop(context),
                  trailingActions: [
                    HubTopBarIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: _showChatOptions,
                      isDark: isDark,
                      iconColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: BorderlessInputDecoration.search(
                      hintText: 'Search chats',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: _searchController.clear,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              HubFluidTabSwitcher(
                controller: _tabController,
                labels: tabLabels,
              ),
              Expanded(
                child: chatProvider.isLoading && conversations.isEmpty && widget.conversations == null
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : chatProvider.error != null && conversations.isEmpty && widget.conversations == null
                        ? _buildErrorBody(chatProvider)
                        : TabBarView(
                            controller: _tabController,
                            children: _modules.map((module) => _buildModuleChats(module, conversations)).toList(),
                          ),
              ),
            ],
          );
        },
      ),
    );

    if (widget._embeddedInMainNav) {
      return ColoredBox(color: pageBg, child: body);
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: body,
    );
  }

  Widget _buildErrorBody(ChatProvider chatProvider) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              chatProvider.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => chatProvider.refreshConversations(),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleChats(String module, List<ChatConversation> allConversations) {
    final searchedConversations = _applySearch(allConversations);
    List<ChatConversation> moduleConversations = searchedConversations;
    
    if (module != 'All') {
      final moduleType = _getChatTypeFromModule(module);
      moduleConversations = searchedConversations.where((c) {
        if (module == 'Gift') {
          return c.chatType == ChatType.gifting || (c.chatType == ChatType.direct && c.contextTitle.toLowerCase().contains('gift'));
        }
        return c.chatType == moduleType;
      }).toList();
    }

    // WhatsApp-style inbox: one row per contact (latest activity wins).
    // All tab collapses across modules; module tabs collapse within that module.
    final List<ChatConversation> activeConversations;
    if (module == 'All') {
      activeConversations = dedupeConversationsByContact(moduleConversations);
    } else if (module == 'Gift') {
      // Gift rows may be typed as gifting or gift-titled direct — collapse by contact.
      activeConversations = dedupeConversationsByContact(moduleConversations);
    } else {
      activeConversations = dedupeConversationsByContact(
        moduleConversations,
        withinType: _getChatTypeFromModule(module),
      );
    }

    if (activeConversations.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No ${module == 'All' ? '' : module} conversations',
        _searchQuery.isNotEmpty ? 'Try a different keyword.' : 'You don\'t have any conversations yet.',
        _getModuleIcon(module),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        if (module == 'All') await chatProvider.refreshConversations();
        else await _loadConversationsByModule(module);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: activeConversations.length,
        itemBuilder: (context, index) => _buildConversationTile(activeConversations[index]),
      ),
    );
  }

  Widget _buildConversationTile(ChatConversation conversation) {
    final typeColor = _getChatTypeColor(conversation.chatType);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final presence = chatProvider.presenceFor(conversation.otherUserId);
    final isOnline = chatProvider.showOnlineStatus && (presence?.isOnline ?? false);
    final lastMsg = conversation.lastMessage;
    final isLastMsgMine = lastMsg != null && currentUserId != null && lastMsg.senderId == currentUserId;
    final tickStatus = isLastMsgMine ? lastMsg.tickStatus : TickStatus.none;

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: () => _openChat(conversation),
        onLongPress: () => _showConversationOptions(conversation),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: typeColor.withValues(alpha: 0.12),
                    child: Icon(
                      _getChatTypeIcon(conversation.chatType),
                      color: typeColor,
                      size: 24,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.otherUserName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: conversation.unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                              color: scheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(conversation.lastActivity),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isLastMsgMine && tickStatus != TickStatus.none) ...[
                          MessageStatusTicks(
                            status: tickStatus,
                            size: 14,
                            greyColor: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.lastMessage?.message ?? 'No messages yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                              fontWeight: conversation.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (conversation.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppEmptyState(String title, String description, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 56, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String description, IconData icon) {
    return _buildAppEmptyState(title, description, icon);
  }
}

class _GlassModal extends StatelessWidget {
  final Widget child;
  const _GlassModal({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1E1A28).withValues(alpha: 0.75) 
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}