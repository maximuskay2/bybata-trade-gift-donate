import 'dart:async';
import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/media_utils.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/models/chat_conversation.dart';
import '../../chat/models/chat_message.dart';
import '../../chat/models/reply_preview.dart';
import '../../chat/utils/item_context_chat_message.dart';
import '../../chat/utils/chat_thread_bootstrap.dart';
import '../../chat/utils/chat_scroll_utils.dart';
import '../../chat/widgets/v2/chat_input_v2.dart';
import '../../chat/widgets/v2/message_bubble_v2.dart';
import '../../chat/widgets/v2/presence_subtitle.dart';
import '../../chat/widgets/v2/typing_bubble.dart';
import '../../chat/widgets/v2/unread_divider.dart';
import '../../chat/widgets/chat_moderation_notice.dart';
import '../../chat/widgets/dismiss_keyboard_on_tap.dart';
import '../../chat/widgets/chat_composer_overlay.dart';
import '../../chat/theme/chat_module_theme.dart';
import '../models/gift_models.dart' as gift_models;
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class GiftRequestChatScreen extends StatefulWidget {
  final gift_models.GiftRequest? request;
  final String partnerId;
  final String partnerName;
  final ChatConversation? existingConversation;

  const GiftRequestChatScreen({
    super.key,
    this.request,
    required this.partnerId,
    required this.partnerName,
    this.existingConversation,
  });

  @override
  State<GiftRequestChatScreen> createState() => _GiftRequestChatScreenState();
}

class _GiftRequestChatScreenState extends State<GiftRequestChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // UI Animations
  late AnimationController _entryAnimationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _orbController;
  late Animation<double> _orbAnimation;

  bool _isLoading = false;
  ChatConversation? _conversation;
  ChatProvider? _chatProvider;
  Timer? _messageRefreshTimer;
  Timer? _typingDebounce;
  int _lastMessageCount = 0;
  bool _isPartnerTyping = false;
  int? _firstUnreadIndex;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();

    _entryAnimationController = AnimationController(duration: const Duration(milliseconds: 220), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnimationController, curve: Curves.easeOut));

    _conversation = widget.existingConversation;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (_conversation != null) {
      chatProvider.upsertConversation(_conversation!);
      final cached = chatProvider.conversationMessages[_conversation!.id];
      _lastMessageCount = cached?.length ?? 0;
      _isLoading = cached == null || cached.isEmpty;
      if (_lastMessageCount > 0) {
        _entryAnimationController.value = 1.0;
      } else {
        _entryAnimationController.forward();
      }
    } else {
      _isLoading = true;
      _entryAnimationController.forward();
    }

    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _orbAnimation = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversation();
      _setupChatProviderListener();
    });
  }

  void _handleTyping(String value) {
    if (_conversation == null || _chatProvider == null) return;
    if (value.trim().isEmpty) {
      _typingDebounce?.cancel();
      _chatProvider!.stopTyping(_conversation!.id);
      return;
    }
    _chatProvider!.startTyping(_conversation!.id);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_conversation != null && _chatProvider != null) {
        _chatProvider!.stopTyping(_conversation!.id);
      }
    });
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_onChatProviderUpdate);
    _messageRefreshTimer?.cancel();
    _typingDebounce?.cancel();
    if (_conversation != null && _chatProvider != null) {
      _chatProvider!.stopTyping(_conversation!.id);
    }
    _messageController.dispose();
    _scrollController.dispose();
    _entryAnimationController.dispose();
    _orbController.dispose();
    super.dispose();
  }
  
  void _startPeriodicMessageRefresh() {
    // WebSocket delivers live updates. Polling every few seconds caused
    // visible list flicker while idle — intentionally disabled.
    _messageRefreshTimer?.cancel();
    _messageRefreshTimer = null;
  }

  void _setupChatProviderListener() {
    if (!mounted) return;
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _chatProvider?.addListener(_onChatProviderUpdate);
  }

  void _onChatProviderUpdate() async {
    if (!mounted || _conversation == null || _chatProvider == null) return;
    
    final partnerId = widget.partnerId;
    final isPartnerTyping = _chatProvider!.typingUsers[partnerId] == true;
    
    if (isPartnerTyping != _isPartnerTyping) {
      _isPartnerTyping = isPartnerTyping;
      if (mounted) {
        setState(() {});
        if (isPartnerTyping) _scrollToBottom();
      }
    }
    
    final currentMessages = _chatProvider!.conversationMessages[_conversation!.id] ?? [];
    final newMessageCount = currentMessages.length;
    
    if (newMessageCount > _lastMessageCount) {
      _lastMessageCount = newMessageCount;
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }
  }

  Future<void> _initializeConversation() async {
    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final hadCachedMessages = _conversation != null &&
        (chatProvider.conversationMessages[_conversation!.id]?.isNotEmpty ?? false);
    if (!hadCachedMessages && mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      _conversation = await ChatThreadBootstrap.resolveConversation(
        chatProvider: chatProvider,
        partnerId: widget.partnerId,
        contextId: widget.request?.giftId,
        existingConversation: widget.existingConversation,
        createIfMissing: () async {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final currentUserId = auth.currentUser?.id;

          String contextTitle;
          String contextId;
          String? initialMessage;

          if (widget.request != null) {
            final isGiver = currentUserId == widget.request!.gift.giver.id;
            contextTitle = 'Gift: ${widget.request!.gift.title}';
            contextId = widget.request!.giftId;
            initialMessage = isGiver
                ? ItemContextChatMessage.giftGiverMessageToRequester(widget.request!.gift)
                : ItemContextChatMessage.giftRequestIntroForGiver(widget.request!);
          } else {
            contextTitle = 'Chat with ${widget.partnerName}';
            contextId = '';
            initialMessage = 'Hi! Let\'s discuss.';
          }

          return chatProvider.startDirectMessage(
            recipientId: widget.partnerId,
            recipientName: widget.partnerName,
            initialMessage: initialMessage,
            contextTitle: contextTitle,
            contextId: contextId,
            apiType: 'DIRECT',
          );
        },
      );

      if (_conversation != null) {
        await ChatThreadBootstrap.loadThreadMessages(
          chatProvider: chatProvider,
          conversationId: _conversation!.id,
          conversation: _conversation,
        );
        await _sendGiftListingIntroIfNeeded(chatProvider);
        if (widget.request != null) {
          await chatProvider.sendListingThumbnailIfNeeded(
            conversationId: _conversation!.id,
            previewImageKey: ItemContextChatMessage.previewImageKeyForGift(
              widget.request!.gift,
            ),
          );
        }
        final preReadUnread = _conversation!.unreadCount;
        final msgs = chatProvider.conversationMessages[_conversation!.id] ?? const <ChatMessage>[];
        if (preReadUnread > 0 && msgs.isNotEmpty) {
          final idx = msgs.length - preReadUnread;
          if (idx > 0 && idx < msgs.length) _firstUnreadIndex = idx;
        }
        await chatProvider.markConversationAsRead(_conversation!.id);
        final initialMessages = chatProvider.conversationMessages[_conversation!.id] ?? [];
        _lastMessageCount = initialMessages.length;
        _startPeriodicMessageRefresh();
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to load conversation: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom(force: true);
      }
    }
  }

  Future<void> _sendGiftListingIntroIfNeeded(ChatProvider chatProvider) async {
    if (_conversation == null || widget.request == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.currentUser?.id;
    if (uid == null) return;
    final giverId = widget.request!.gift.giver.id;

    if (ItemContextChatMessage.shouldSendListingDetailsToOwner(
      currentUserId: uid,
      partnerId: widget.partnerId,
      listingOwnerId: giverId,
    )) {
      await chatProvider.sendFirstMessageIfThreadEmpty(
        conversationId: _conversation!.id,
        content: ItemContextChatMessage.giftRequestIntroForGiver(widget.request!),
        listingPreviewImageKey: ItemContextChatMessage.previewImageKeyForGift(
          widget.request!.gift,
        ),
      );
    } else if (uid == giverId && widget.partnerId != giverId) {
      await chatProvider.sendFirstMessageIfThreadEmpty(
        conversationId: _conversation!.id,
        content: ItemContextChatMessage.giftGiverMessageToRequester(widget.request!.gift),
        listingPreviewImageKey: ItemContextChatMessage.previewImageKeyForGift(
          widget.request!.gift,
        ),
      );
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        scrollChatToBottom(_scrollController, force: force);
      } catch (e) {
        debugPrint('Scroll error: $e');
      }
    });
  }

  Future<void> _refreshMessages(ChatProvider chatProvider) async {
    if (_conversation == null) return;
    try {
      await chatProvider.loadMessages(_conversation!.id, refresh: true);
      final updatedMessages = chatProvider.conversationMessages[_conversation!.id] ?? [];
      _lastMessageCount = updatedMessages.length;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to refresh messages: ${e.toString()}');
    }
  }

  Future<bool> _onSendText(String text, ReplyPreview? replyTo) async {
    if (_conversation == null) return false;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      _typingDebounce?.cancel();
      chatProvider.stopTyping(_conversation!.id);
      final bool ok;
      if (replyTo != null) {
        ok = await chatProvider.sendReply(
          conversationId: _conversation!.id,
          content: text,
          replyToMessageId: replyTo.messageId,
        );
      } else {
        ok = await chatProvider.sendMessage(_conversation!.id, text);
      }
      if (ok) _scrollToBottom(force: true);
      return ok;
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Failed to send message: ${e.toString()}');
      }
      return false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversation == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final reply = chatProvider.pendingReplyFor(_conversation!.id);
    _messageController.clear();
    await _onSendText(text, reply);
  }

  // --- THEME AWARE UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id;
    
    // Theme Colors for Gifting
    final primaryColor = ChatModuleTheme.forGift();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    final orbOpacity = isDark ? 0.25 : 0.12;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: _buildGlassAppBar(primaryColor, isDark),
      body: Stack(
        children: [
          // Ambient Background Orbs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1, right: -100,
            child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * _orbAnimation.value),
                  child: Container(
                    width: 350, height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: orbOpacity),
                      boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: orbOpacity + 0.03), blurRadius: 120)],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2, left: -80,
            child: IgnorePointer(
              child: AnimatedBuilder(
              animation: _orbAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -30 * _orbAnimation.value),
                  child: Container(
                    width: 250, height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.purpleAccent.withValues(alpha: orbOpacity - 0.04),
                      boxShadow: [BoxShadow(color: Colors.purpleAccent.withValues(alpha: orbOpacity), blurRadius: 90)],
                    ),
                  ),
                );
              },
            ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: ChatComposerStack(
              footer: [
                if (_isPartnerTyping)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TypingBubble(),
                    ),
                  ),
              ],
              composer: _buildGlassInput(primaryColor, isDark),
              body: Column(
              children: [
                if (widget.request != null) _buildGiftContextCard(primaryColor, isDark),

                const ChatModerationNotice(),

                Expanded(
                  child: DismissKeyboardOnTap(
                    child: Consumer<ChatProvider>(
                        builder: (context, chatProvider, child) {
                          final messages = _conversation != null 
                              ? (chatProvider.conversationMessages[_conversation!.id] ?? []) 
                              : const <ChatMessage>[];

                          if (_isLoading && messages.isEmpty) {
                            return Center(child: BybataLoadingIndicator(color: primaryColor));
                          }
                          
                          if (messages.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.5), 
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white),
                                    ),
                                    child: Icon(Icons.card_giftcard_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                  ),
                                  const SizedBox(height: 20),
                                  Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.grey[300] : Colors.black54)),
                                  const SizedBox(height: 8),
                                  Text('Start the conversation!', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          }

                          final listBottom = ChatComposerOverlay.listBottomPadding(context);

                          return RefreshIndicator(
                              onRefresh: () => _refreshMessages(chatProvider),
                              color: primaryColor,
                              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                              child: ListView.builder(
                                controller: _scrollController,
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(16, 8, 16, listBottom),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final bool isMe = currentUserId != null && (message.senderId == currentUserId || message.isFromCurrentUser);
                                  final showTimestamp = index == 0 || (index > 0 && messages[index - 1].timestamp.difference(message.timestamp).inMinutes.abs() > 15);
                                  final showUnreadDivider = _firstUnreadIndex == index;
                                  
                                  return Column(
                                    key: _messageKeys.putIfAbsent(message.id, () => GlobalKey()),
                                    children: [
                                      if (showUnreadDivider) const UnreadDivider(),
                                      if (showTimestamp) _buildTimeHeader(message.timestamp, isDark),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 400),
                                        decoration: BoxDecoration(
                                          color: _highlightedMessageId == message.id
                                              ? primaryColor.withValues(alpha: 0.12)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: _buildModernBubble(message, isMe, primaryColor, isDark),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                        },
                      ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) return 'Today';
    if (messageDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    
    final difference = now.difference(timestamp).inDays;
    if (difference < 7) return '${difference}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  PreferredSizeWidget _buildGlassAppBar(Color primaryColor, bool isDark) {
    final titleColor = isDark ? Colors.white : Colors.black87;
    final glassColor = isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.65);

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AppBar(
            backgroundColor: glassColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Center(
                    child: Text(widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.partnerName, style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      Consumer<ChatProvider>(
                        builder: (context, chatProvider, _) {
                          final presence = chatProvider.presenceFor(widget.partnerId);
                          return PresenceSubtitle(
                            presence: presence,
                            fallback: 'Gift Chat',
                            style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w800),
                            showPresence: chatProvider.showOnlineStatus,
                            showLastSeen: chatProvider.showLastSeen,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiftContextCard(Color color, bool isDark) {
    final gradientColors = isDark 
        ? [Colors.grey[900]!.withValues(alpha: 0.8), Colors.grey[850]!.withValues(alpha: 0.6)]
        : [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.6)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 6))],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(20))),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.card_giftcard_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("REGARDING GIFT", style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(widget.request?.gift.title ?? 'Gift', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeHeader(DateTime date, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Text(
            _formatTimestamp(date).toUpperCase(),
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildModernBubble(ChatMessage message, bool isMe, Color primaryColor, bool isDark) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUserId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
    final conv = _conversation;

    Widget? imageWidget;
    if (message.messageType == MessageType.image && message.imageUrl != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<String?>(
          future: MediaResolver.resolveUrl(message.imageUrl),
          builder: (context, snapshot) {
            final resolved = snapshot.data;
            if (resolved == null || !resolved.startsWith('http')) {
              return const Icon(Icons.broken_image_rounded, color: Colors.white54);
            }
            return Image.network(
              resolved,
              width: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MessageBubbleV2(
        message: message,
        currentUserId: currentUserId,
        bubbleColor: primaryColor,
        moduleAccentColor: primaryColor,
        imageWidget: imageWidget,
        onSwipeReply: conv == null
            ? null
            : () {
                chatProvider.setReplyTarget(
                  conv.id,
                  ReplyPreview(
                    messageId: message.id,
                    senderId: message.senderId,
                    senderName: message.senderName,
                    contentPreview: message.message.length > 160
                        ? message.message.substring(0, 160)
                        : message.message,
                    type: _replyTypeFromMessage(message),
                  ),
                );
              },
        onReactionSelected: (emoji) =>
            chatProvider.addReaction(message.id, emoji),
        onReactionToggled: (emoji) {
          final mine = message.reactions.any(
            (r) => r.userId == currentUserId && r.emoji == emoji,
          );
          if (mine) {
            chatProvider.removeReaction(message.id, emoji);
          } else {
            chatProvider.addReaction(message.id, emoji);
          }
        },
        onQuotedTap: message.replyTo == null
            ? null
            : () => _scrollToOriginalMessage(message.replyTo!.messageId),
      ),
    );
  }

  Future<void> _scrollToOriginalMessage(String messageId) async {
    final key = _messageKeys[messageId];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    HapticFeedback.selectionClick();
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );
    if (!mounted) return;
    setState(() => _highlightedMessageId = messageId);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _highlightedMessageId = null);
  }

  String _replyTypeFromMessage(ChatMessage m) {
    switch (m.messageType) {
      case MessageType.image:
        return 'IMAGE';
      case MessageType.video:
        return 'VIDEO';
      case MessageType.file:
        return 'FILE';
      case MessageType.voice:
        return 'VOICE';
      default:
        return 'TEXT';
    }
  }

  Widget _buildGlassInput(Color primaryColor, bool isDark) {
    final convId = _conversation?.id;
    if (convId == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      );
    }
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final reply = chatProvider.pendingReplyFor(convId);
        return ChatInputV2(
          conversationId: convId,
          controller: _messageController,
          replyPreview: reply,
          onCancelReply: () => chatProvider.clearReplyTarget(convId),
          onSendText: _onSendText,
          onScrollToBottom: () => _scrollToBottom(force: true),
          onTyping: _handleTyping,
        );
      },
    );
  }
}