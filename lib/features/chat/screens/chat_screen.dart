import 'dart:async';
import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Keep existing imports
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';
import '../models/reply_preview.dart';
import '../providers/chat_provider.dart';
import '../../../core/utils/media_utils.dart';
import '../../trade/screens/trade_details_loader.dart';
import '../../gifting/screens/gift_details_loader.dart';
import '../../donations/screens/campaign_details_loader.dart';
import '../../common/widgets/user_avatar.dart';
import '../widgets/v2/chat_input_v2.dart';
import '../widgets/v2/message_bubble_v2.dart';
import '../widgets/v2/presence_subtitle.dart';
import '../widgets/v2/typing_bubble.dart';
import '../widgets/v2/unread_divider.dart';
import '../widgets/chat_moderation_notice.dart';
import '../widgets/dismiss_keyboard_on_tap.dart';
import '../widgets/chat_composer_overlay.dart';
import '../utils/chat_scroll_utils.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class ChatScreen extends StatefulWidget {
  final ChatConversation conversation;
  final ChatType chatType;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.chatType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // New Animation for Screen Entry
  late AnimationController _entryAnimationController;
  late Animation<double> _fadeAnimation;

  bool _initialHistoryLoaded = false;
  Timer? _typingDebounce;
  int? _firstUnreadIndex;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    // Screen Entry Animation — skip fade when history is already cached.
    _entryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _entryAnimationController,
      curve: Curves.easeOut,
    ));
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.upsertConversation(widget.conversation);
    final cached =
        chatProvider.conversationMessages[widget.conversation.id];
    if (cached != null && cached.isNotEmpty) {
      _initialHistoryLoaded = true;
      _entryAnimationController.value = 1.0;
    } else {
      _entryAnimationController.forward();
    }

    _fetchHistory();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _entryAnimationController.dispose();
    super.dispose();
  }

  void _handleTyping(String _) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.startTyping(widget.conversation.id);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      chatProvider.stopTyping(widget.conversation.id);
    });
  }

  Future<void> _fetchHistory() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.upsertConversation(widget.conversation);
    final id = widget.conversation.id;
    chatProvider.joinConversation(id);
    await chatProvider.loadMessages(id);

    // Capture the index of the first unread message BEFORE we clear the
    // unread count, so we can render the "Unread Messages" divider there.
    final preReadUnreadCount = widget.conversation.unreadCount;
    final msgs = chatProvider.conversationMessages[widget.conversation.id]
            as List<ChatMessage>? ??
        const <ChatMessage>[];
    if (preReadUnreadCount > 0 && msgs.isNotEmpty) {
      final idx = msgs.length - preReadUnreadCount;
      if (idx > 0 && idx < msgs.length) _firstUnreadIndex = idx;
    }

    await chatProvider.markConversationAsRead(widget.conversation.id);
    if (msgs.isNotEmpty) {
      final last = msgs.last;
      chatProvider.upsertConversation(
        widget.conversation.copyWith(
          lastMessage: last,
          lastActivity: last.timestamp,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _initialHistoryLoaded = true;
      });
    }

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<bool> _onSendText(String text, ReplyPreview? replyTo) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final bool ok;
    if (replyTo != null) {
      ok = await chatProvider.sendReply(
        conversationId: widget.conversation.id,
        content: text,
        replyToMessageId: replyTo.messageId,
      );
    } else {
      ok = await chatProvider.sendMessage(widget.conversation.id, text);
    }
    if (ok) _scrollToBottom(force: true);
    return ok;
  }

  void _scrollToBottom({bool force = false}) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      scrollChatToBottom(_scrollController, force: force);
    });
  }

  Color _getChatTypeColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  String _getChatTypeLabel() {
    switch (widget.chatType) {
      case ChatType.trade: return 'Trade';
      case ChatType.donation: return 'Donation';
      case ChatType.community: return 'Community';
      default: return 'Chat';
    }
  }

  // --- THEME AWARE UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getChatTypeColor(context);
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
          // 1. Ambient Background Orbs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1, right: -100,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: orbOpacity),
                boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: orbOpacity + 0.03), blurRadius: 120)],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2, left: -80,
            child: IgnorePointer(
              child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: orbOpacity - 0.04),
                boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: orbOpacity), blurRadius: 90)],
              ),
            ),
            ),
          ),

          // 2. Main Content 
          SafeArea(
            bottom: false, 
            child: ChatComposerStack(
              composer: _buildFloatingGlassInput(primaryColor, isDark),
              body: Column(
              children: [
                const ChatModerationNotice(),

                // Messages List
                Expanded(
                  child: DismissKeyboardOnTap(
                    child: Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      final messages = chatProvider.conversationMessages[widget.conversation.id] ?? <ChatMessage>[];
                      final isOtherTyping =
                          chatProvider.typingUsers[widget.conversation.otherUserId] == true;

                      if (!_initialHistoryLoaded && messages.isEmpty) {
                        return Center(child: BybataLoadingIndicator(color: primaryColor));
                      }

                      final itemCount = messages.length + (isOtherTyping ? 1 : 0);
                      final listBottom = ChatComposerOverlay.listBottomPadding(context);

                      return ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(12, 8, 12, listBottom),
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            if (isOtherTyping && index == messages.length) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 4, bottom: 8),
                                child: TypingBubble(),
                              );
                            }
                            final message = messages[index];

                            // Date chip: "Today" / "Yesterday" / "MMM d, yyyy"
                            // — shown only when the calendar day changes.
                            final showDateChip = index == 0 ||
                                !_isSameDay(
                                  messages[index - 1].timestamp,
                                  message.timestamp,
                                );

                            // Tighter spacing for consecutive messages from
                            // the same sender (WhatsApp "chained" look).
                            final sameSenderAsPrev = index > 0 &&
                                !showDateChip &&
                                messages[index - 1].senderId == message.senderId;
                            final topGap = sameSenderAsPrev ? 2.0 : 10.0;

                            final showUnreadDivider = _firstUnreadIndex == index;

                            return Column(
                              key: _messageKeys.putIfAbsent(
                                message.id,
                                () => GlobalKey(),
                              ),
                              children: [
                                if (showUnreadDivider) const UnreadDivider(),
                                if (showDateChip) _buildDateChip(message.timestamp, isDark),
                                SizedBox(height: topGap),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  decoration: BoxDecoration(
                                    color: _highlightedMessageId == message.id
                                        ? primaryColor.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: _build3DBubble(
                                    message,
                                    primaryColor,
                                    isDark,
                                    chatProvider,
                                    isGroupedWithPrevious: sameSenderAsPrev,
                                  ),
                                ),
                              ],
                            );
                          },
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

  PreferredSizeWidget _buildGlassAppBar(Color primaryColor, bool isDark) {
    final titleColor = isDark ? Colors.white : Colors.black87;
    final glassColor = isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.65);

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          // SafeArea(top) prevents the status bar (time/battery/signal) from
          // colliding with the glass bar when extendBodyBehindAppBar is true.
          child: SafeArea(
            top: true,
            bottom: false,
            child: AppBar(
              backgroundColor: glassColor,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: titleColor),
              ),
              title: Row(
                children: [
                  // Real profile picture (falls back to initials inside
                  // UserAvatar when the imageUrl is empty / fails to resolve).
                  UserAvatar(
                    imageUrl: widget.conversation.otherUserAvatar,
                    name: widget.conversation.otherUserName,
                    size: 38,
                    showStatusIndicator: false,
                    borderColor: isDark ? Colors.grey[700] : Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.otherUserName,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor, letterSpacing: -0.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Consumer<ChatProvider>(
                          builder: (context, chatProvider, _) {
                            final presence =
                                chatProvider.presenceFor(widget.conversation.otherUserId);
                            return PresenceSubtitle(
                              presence: presence,
                              fallback: widget.conversation.contextTitle.isNotEmpty
                                  ? 'Re: ${widget.conversation.contextTitle}'
                                  : _getChatTypeLabel(),
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
              // Single overflow action — Bybata has no voice/video call
              // affordances, so the spec's Info/Call/Settings trio collapses
              // into a single more_vert that opens mute/block/report/delete.
              actions: [
                IconButton(
                  onPressed: () => _showChatOptions(isDark),
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.grey[300] : Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(msgDay).inDays;

    String label;
    if (diffDays == 0) {
      label = 'Today';
    } else if (diffDays == 1) {
      label = 'Yesterday';
    } else if (diffDays > 0 && diffDays < 7) {
      label = DateFormat('EEEE').format(date); // Monday, Tuesday, ...
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _build3DBubble(
    ChatMessage message,
    Color primaryColor,
    bool isDark,
    ChatProvider chatProvider, {
    bool isGroupedWithPrevious = false,
  }) {
    final currentUserId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';

    // For image messages, resolve the signed URL via MediaResolver so the
    // v2 bubble can render the thumbnail edge-to-edge inside its rounded
    // container. The bubble itself applies the corner clip now — we just
    // return the raw Image here.
    Widget? imageWidget;
    if (message.messageType == MessageType.image && message.imageUrl != null) {
      imageWidget = FutureBuilder<String?>(
        future: MediaResolver.resolveUrl(message.imageUrl),
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          if (resolved == null || !resolved.startsWith('http')) {
            return const SizedBox(
              width: 220,
              height: 160,
              child: Center(
                child: Icon(Icons.broken_image_rounded, color: Colors.white54),
              ),
            );
          }
          return Image.network(
            resolved,
            width: 240,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image_rounded),
          );
        },
      );
    }

    return MessageBubbleV2(
      message: message,
      currentUserId: currentUserId,
      bubbleColor: primaryColor,
      moduleAccentColor: primaryColor,
      isGroupedWithPrevious: isGroupedWithPrevious,
      imageWidget: imageWidget,
      onSwipeReply: () {
        chatProvider.setReplyTarget(
          widget.conversation.id,
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
      onReactionSelected: (emoji) {
        chatProvider.addReaction(message.id, emoji);
      },
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
      onItemContextTap: (meta) => _openItemFromContext(meta),
    );
  }

  /// Opens the appropriate details screen for an item_context SYSTEM message.
  /// Uses the existing *DetailsLoader* widgets so we can navigate with just an
  /// id — no need to refetch the full listing here.
  void _openItemFromContext(Map<String, dynamic> metadata) {
    final sourceType =
        (metadata['sourceType'] ?? '').toString().toUpperCase();
    final itemId = (metadata['itemId'] ?? '').toString();
    if (itemId.isEmpty) return;

    switch (sourceType) {
      case 'TRADE':
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (_) => TradeDetailsLoader(tradeId: itemId),
          ),
        );
        break;
      case 'GIFT':
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (_) => GiftDetailsLoader(giftId: itemId),
          ),
        );
        break;
      case 'CAMPAIGN':
        GuardedNavigator.push(context, 
          MaterialPageRoute(
            builder: (_) => CampaignDetailsLoader(campaignId: itemId),
          ),
        );
        break;
      default:
        AppToast.show(context, 'Details not available for this item.');
    }
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

  Widget _buildFloatingGlassInput(Color primaryColor, bool isDark) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final reply = chatProvider.pendingReplyFor(widget.conversation.id);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: ChatInputV2(
            conversationId: widget.conversation.id,
            controller: _messageController,
            replyPreview: reply,
            moduleColor: primaryColor,
            onCancelReply: () =>
                chatProvider.clearReplyTarget(widget.conversation.id),
            onSendText: _onSendText,
            onScrollToBottom: () => _scrollToBottom(force: true),
            onTyping: _handleTyping,
          ),
        );
      },
    );
  }

  // --- PRESERVED LOGIC HELPERS ---

  void _showChatOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.block_rounded, color: isDark ? Colors.white : Colors.black87)),
              title: Text('Block User', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              onTap: () { Navigator.pop(context); _showSnackBar('User blocked'); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], shape: BoxShape.circle), child: const Icon(Icons.report_problem_rounded, color: Colors.orange)),
              title: Text('Report Chat', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              onTap: () { Navigator.pop(context); _showSnackBar('Chat reported'); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () { Navigator.pop(context); _showDeleteConfirmation(isDark); },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Chat', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text('Are you sure you want to delete this chat? This action cannot be undone.', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              try {
                await chatProvider.deleteConversation(widget.conversation.id);
                if (mounted) {
                  Navigator.pop(context); 
                  Navigator.pop(context); 
                  _showSnackBar('Chat deleted successfully');
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); 
                  _showSnackBar('Failed to delete chat: $e');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    AppToast.info(context, message);
  }
}