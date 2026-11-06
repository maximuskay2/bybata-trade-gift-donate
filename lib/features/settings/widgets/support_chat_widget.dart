import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../services/support_api.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;
  final String? senderName;
  final bool isBot;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
    this.senderName,
    this.isBot = false,
  });

  factory ChatMessage.fromApi(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isFromUser: json['isFromUser'] == true,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      senderName: json['senderName']?.toString(),
      isBot: json['isBot'] == true,
    );
  }
}

class SupportChatWidget extends StatefulWidget {
  const SupportChatWidget({super.key});

  @override
  State<SupportChatWidget> createState() => _SupportChatWidgetState();
}

class _SupportChatWidgetState extends State<SupportChatWidget> {
  static const _botName = 'BYBATA Assistant';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  SupportApi? _api;
  String? _sessionStatus;
  bool _loading = true;
  bool _sending = false;
  bool _requestingAdmin = false;
  String? _error;

  bool get _awaitingAdmin =>
      _sessionStatus == 'AWAITING_ADMIN' || _sessionStatus == 'ADMIN_ACTIVE';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      const storage = FlutterSecureStorage();
      final client = ApiClient(await EnvConfig.getBaseUrl(), storage);
      _api = SupportApi(client);
      final session = await _api!.fetchChatSession();
      if (!mounted) return;
      setState(() {
        _sessionStatus = session['status']?.toString();
        _messages
          ..clear()
          ..addAll(
            ((session['messages'] as List?) ?? [])
                .map((m) => ChatMessage.fromApi(Map<String, dynamic>.from(m as Map))),
          );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySession(Map<String, dynamic> session) {
    setState(() {
      _sessionStatus = session['status']?.toString();
      _messages
        ..clear()
        ..addAll(
          ((session['messages'] as List?) ?? [])
              .map((m) => ChatMessage.fromApi(Map<String, dynamic>.from(m as Map))),
        );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _api == null || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      final res = await _api!.sendChatMessage(content);
      if (!mounted) return;
      setState(() {
        if (res['session'] != null) {
          final session = Map<String, dynamic>.from(res['session'] as Map);
          _sessionStatus = session['status']?.toString();
          _messages
            ..clear()
            ..addAll(
              ((session['messages'] as List?) ?? [])
                  .map((m) => ChatMessage.fromApi(Map<String, dynamic>.from(m as Map))),
            );
        } else {
          if (res['userMessage'] != null) {
            _messages.add(ChatMessage.fromApi(
              Map<String, dynamic>.from(res['userMessage'] as Map),
            ));
          }
          if (res['botMessage'] != null) {
            _messages.add(ChatMessage.fromApi(
              Map<String, dynamic>.from(res['botMessage'] as Map),
            ));
          }
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not send message: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _requestAdmin() async {
    if (_api == null || _requestingAdmin) return;
    setState(() => _requestingAdmin = true);
    try {
      final session = await _api!.requestAdminChat();
      if (!mounted) return;
      setState(() => _applySession(session));
      AppToast.show(context, 'Support team notified — an agent will join soon');
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not request admin: $e');
      }
    } finally {
      if (mounted) setState(() => _requestingAdmin = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BybataLoader();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Could not load chat', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _initChat, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final statusLabel = switch (_sessionStatus) {
      'ADMIN_ACTIVE' => 'Agent connected',
      'AWAITING_ADMIN' => 'Waiting for agent',
      _ => 'Automated assistant',
    };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.support_agent, color: Theme.of(context).colorScheme.onPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Support Chat', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text(statusLabel, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (!_awaitingAdmin)
                TextButton.icon(
                  onPressed: _requestingAdmin ? null : _requestAdmin,
                  icon: _requestingAdmin
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Talk to admin'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _sending) {
                return _buildTypingIndicator();
              }
              return _buildMessageBubble(_messages[index]);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _awaitingAdmin ? 'Message support team…' : 'Ask a question or type "talk to admin"…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                onPressed: _sending ? null : _sendMessage,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isFromUser;
    final sender = isUser ? 'You' : (message.senderName ?? _botName);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(sender, style: Theme.of(context).textTheme.bodySmall),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
              ),
              child: Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isUser ? Theme.of(context).colorScheme.onPrimary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Typing…'),
      ),
    );
  }
}
