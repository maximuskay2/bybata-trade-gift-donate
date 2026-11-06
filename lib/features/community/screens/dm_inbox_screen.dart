import 'dart:async';
import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../chat/models/chat_message.dart';
import '../../chat/models/chat_conversation.dart' show ChatConversation, ChatType;
import '../../chat/providers/chat_provider.dart';
import '../../chat/utils/chat_thread_bootstrap.dart';
import '../../chat/utils/chat_scroll_utils.dart';
import '../../chat/services/chat_media_helper.dart';
import '../../chat/widgets/voice_note_bubble.dart';
import '../../chat/widgets/v2/chat_media_attachments.dart';
import '../../chat/widgets/v2/document_bubble.dart';
import '../../chat/widgets/dismiss_keyboard_on_tap.dart';
import '../../chat/widgets/chat_composer_overlay.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class DMInboxScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final ChatConversation? existingConversation;

  const DMInboxScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.existingConversation,
  });

  @override
  State<DMInboxScreen> createState() => _DMInboxScreenState();
}

class _DMInboxScreenState extends State<DMInboxScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  
  // UI Animations
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonAnimation;
  late AnimationController _entryAnimationController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  ChatConversation? _conversation;
  ChatProvider? _chatProvider;
  Timer? _messageRefreshTimer;
  Timer? _typingTimer;
  int _lastMessageCount = 0;
  bool _isPartnerTyping = false;

  @override
  void initState() {
    super.initState();

    // Animations Initialization
    _sendButtonController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _sendButtonAnimation = CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut);

    _entryAnimationController = AnimationController(duration: const Duration(milliseconds: 220), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnimationController, curve: Curves.easeOut));

    _conversation = widget.existingConversation;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        _scrollToBottom(force: true);
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (mounted && _inputFocusNode.hasFocus) {
            _scrollToBottom(force: true);
          }
        });
      }
    });
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

    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversation();
      _setupChatProviderListener();
    });
  }
  
  void _onTextChanged() {
    setState(() {});
    
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText) {
      _sendButtonController.forward();
    } else {
      _sendButtonController.reverse();
    }
    
    // Handle typing indicator
    if (_conversation != null && _chatProvider != null) {
      if (hasText) {
        _chatProvider!.startTyping(_conversation!.id);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_conversation != null && _chatProvider != null) {
            _chatProvider!.stopTyping(_conversation!.id);
          }
        });
      } else {
        _typingTimer?.cancel();
        if (_conversation != null && _chatProvider != null) {
          _chatProvider!.stopTyping(_conversation!.id);
        }
      }
    }
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_onChatProviderUpdate);
    _messageRefreshTimer?.cancel();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    if (_conversation != null && _chatProvider != null) {
      _chatProvider!.stopTyping(_conversation!.id);
    }
    _messageController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _sendButtonController.dispose();
    _entryAnimationController.dispose();
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
        existingConversation: widget.existingConversation,
        createIfMissing: () => chatProvider.startDirectMessage(
          recipientId: widget.partnerId,
          recipientName: widget.partnerName,
          initialMessage: "Hi! Let's chat.",
          contextTitle: null,
          contextId: null,
          apiType: 'DIRECT',
        ),
      );

      if (_conversation != null) {
        await ChatThreadBootstrap.loadThreadMessages(
          chatProvider: chatProvider,
          conversationId: _conversation!.id,
          conversation: _conversation,
        );
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

  Future<void> _pickImageFromCamera() async {
    if (_conversation == null) return;
    await ChatMediaHelper.pickAndSendImage(
      context,
      conversationId: _conversation!.id,
      onScrollToBottom: () => _scrollToBottom(force: true),
    );
  }

  Future<void> _toggleRecording() async {
    if (_conversation == null) return;
    if (_isRecording) {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      final path = await ChatMediaHelper.stopVoiceRecording();
      if (mounted) setState(() => _isRecording = false);
      if (path != null && _recordingStartTime != null && mounted) {
        final durationSeconds = DateTime.now().difference(_recordingStartTime!).inSeconds.clamp(1, 300);
        await ChatMediaHelper.showVoiceNotePreviewBeforeSend(
          context,
          path: path,
          conversationId: _conversation!.id,
          durationSeconds: durationSeconds,
          onScrollToBottom: () => _scrollToBottom(force: true),
        );
      }
      _recordingStartTime = null;
    } else {
      final started = await ChatMediaHelper.startVoiceRecording();
      if (mounted && started) {
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
        });
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
          if (mounted) setState(() {});
        });
      } else if (mounted) {
        AppToast.show(context, 'Microphone permission required for voice notes');
      }
    }
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final bool hasText = text.isNotEmpty;
    if (!hasText || _conversation == null) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    try {
      _typingTimer?.cancel();
      chatProvider.stopTyping(_conversation!.id);
      
      _messageController.clear();
      
      await chatProvider.sendMessage(_conversation!.id, text);
      _scrollToBottom(force: true);
    } catch (e) {
      if (mounted) AppToast.show(context, 'Failed to send message: ${e.toString()}');
    }
  }

  // --- THEME AWARE UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.id;
    final primaryColor = Theme.of(context).colorScheme.primary;
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
          
          SafeArea(
            bottom: false,
            child: ChatComposerStack(
              footer: [
                if (_isPartnerTyping) _buildTypingIndicator(primaryColor, isDark),
              ],
              composer: _buildGlassInput(primaryColor, isDark),
              body: Column(
              children: [
                _buildContextCard(primaryColor, isDark),

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
                                    child: Icon(Icons.forum_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
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
                                  
                                  return Column(
                                    children: [
                                      if (showTimestamp) _buildTimeHeader(message.timestamp, isDark),
                                      _buildModernBubble(message, isMe, primaryColor, isDark),
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
                      Text("Direct Message", style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w800)),
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

  Widget _buildContextCard(Color color, bool isDark) {
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
                    child: Icon(Icons.forum_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("COMMUNITY CHAT", style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text("Private Conversation", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
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
    final bool isImage = message.messageType == MessageType.image;
    final bool isVideo = message.messageType == MessageType.video;
    final bool isVoice = message.messageType == MessageType.voice;
    final bool isFile = message.messageType == MessageType.file;

    final receiverGradient = isDark
        ? [const Color(0xFF2A2A35), const Color(0xFF1E1E24)]
        : [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.8)];
        
    final senderGradient = [primaryColor.withValues(alpha: 0.9), primaryColor];

    final textColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final timeColor = isMe ? Colors.white.withValues(alpha: 0.8) : (isDark ? Colors.grey[400] : Colors.grey[500]);
    final borderColor = isMe 
        ? Colors.white.withValues(alpha: 0.2) 
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isMe ? senderGradient : receiverGradient,
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft: Radius.circular(isMe ? 24 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 24),
                ),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: isMe ? primaryColor.withValues(alpha: isDark ? 0.5 : 0.35) : Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isImage && message.mediaStorageKey != null)
                        ChatImageAttachment(storageKey: message.mediaStorageKey!),
                      if (isVideo && message.mediaStorageKey != null)
                        ChatVideoAttachment(storageKey: message.mediaStorageKey!),
                      if (isFile)
                        DocumentBubble(
                          message: message,
                          isMe: isMe,
                          isDark: isDark,
                        ),
                      if (isVoice)
                        VoiceNoteBubble(
                          message: message,
                          primaryColor: primaryColor,
                          isMe: isMe,
                          isDark: isDark,
                        ),
                      if (message.message.isNotEmpty &&
                          !isImage &&
                          !isVideo &&
                          !isFile &&
                          !isVoice)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Text(
                            message.message,
                            style: TextStyle(color: textColor, fontSize: 15, height: 1.3, fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(message.timestamp),
                    style: TextStyle(color: timeColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isReadByRecipient
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 14,
                      color: message.isReadByRecipient
                          ? primaryColor
                          : Colors.white.withValues(alpha: 0.75),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassInput(Color primaryColor, bool isDark) {
    final bool hasText = _messageController.text.trim().isNotEmpty;
    
    final bgColor = isDark ? const Color(0xFF1E1E24).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.8);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white;
    final hintColor = isDark ? Colors.grey[500] : Colors.grey[400];
    final textColor = isDark ? Colors.white : Colors.black87;

    return SafeArea(
      top: false,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                // 3D Attachment Button
                GestureDetector(
                  onTap: () => _showAttachmentSheet(primaryColor),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                    child: Icon(Icons.add_rounded, color: primaryColor, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Inset Input Field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputFocusNode,
                    maxLines: 4, minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
                    decoration: InputDecoration(
                      hintText: _isRecording
                          ? ChatMediaHelper.formatRecordingElapsed(_recordingStartTime)
                          : "Type your message...",
                      hintStyle: TextStyle(color: _isRecording ? Colors.red : hintColor, fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Animated 3D Send/Voice Button
                AnimatedBuilder(
                  animation: _sendButtonAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.8 + (_sendButtonAnimation.value * 0.2),
                      child: GestureDetector(
                        onTap: hasText ? _sendMessage : _toggleRecording,
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: hasText 
                                  ? [primaryColor, primaryColor.withValues(alpha: 0.8)] 
                                  : (_isRecording ? [Colors.red, Colors.redAccent] : (isDark ? [Colors.grey[800]!, Colors.grey[900]!] : [Colors.white, Colors.grey[200]!])),
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark && !hasText && !_isRecording ? Colors.grey[700]! : Colors.white, width: hasText || _isRecording ? 0 : 1.5),
                            boxShadow: hasText || _isRecording
                                ? [BoxShadow(color: (hasText ? primaryColor : Colors.red).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))] 
                                : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Icon(
                            hasText ? Icons.send_rounded : (_isRecording ? Icons.stop_rounded : Icons.mic_rounded), 
                            color: hasText || _isRecording ? Colors.white : (isDark ? Colors.grey[600] : Colors.grey[400]), 
                            size: 20
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _showAttachmentSheet(Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.camera_alt_rounded, color: color)),
                  title: Text("Camera", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  onTap: () { Navigator.pop(context); _pickImageFromCamera(); },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.videocam_rounded, color: color)),
                  title: Text("Video", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    if (_conversation != null) {
                      ChatMediaHelper.pickAndSendVideo(
                        context,
                        conversationId: _conversation!.id,
                        onScrollToBottom: () => _scrollToBottom(force: true),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.attach_file_rounded, color: color)),
                  title: Text("File", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    if (_conversation != null) {
                      ChatMediaHelper.pickAndSendFile(context, conversationId: _conversation!.id, onScrollToBottom: () => _scrollToBottom(force: true));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTypingIndicator(Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.partnerName.split(' ').first} is typing',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700], fontStyle: FontStyle.italic),
                ),
                const SizedBox(width: 4),
                _TypingDots(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Animated typing dots widget
class _TypingDots extends StatefulWidget {
  final bool isDark;
  const _TypingDots({required this.isDark});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..repeat(),
    );
    
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();
    
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Opacity(
                opacity: _animations[index].value,
                child: Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], shape: BoxShape.circle),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}