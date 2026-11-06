import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_conversation.dart';

class FloatingChatController extends ChangeNotifier {
  bool _isOpen = false;
  String? _activeConversationId;
  bool _isBusy = false;
  String? _error;

  bool get isOpen => _isOpen;
  String? get activeConversationId => _activeConversationId;
  bool get isBusy => _isBusy;
  String? get error => _error;

  void open() {
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    _isOpen = false;
    notifyListeners();
  }

  Future<void> openConversation(BuildContext context, String conversationId) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      _activeConversationId = conversationId;
      // Ensure messages are loaded and joined via WebSocket
      final chat = context.read<ChatProvider>();
      await chat.loadMessages(conversationId, refresh: false);
      _isOpen = true;
    } catch (e) {
      _error = 'Failed to open conversation: $e';
      log(_error!);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> openWithRecipient(BuildContext context, String recipientId) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      final chat = context.read<ChatProvider>();

      // Try to locate an existing conversation with recipient
      await chat.refreshConversations();
      ChatConversation? existing;
      for (final c in chat.conversations) {
        if (c.otherUserId == recipientId) {
          existing = c;
          break;
        }
      }

      if (existing != null) {
        await openConversation(context, existing.id);
        return;
      }

      // Otherwise, attempt to start a new direct message
      final started = await chat.startDirectMessage(recipientId: recipientId);
      if (started != null) {
        await openConversation(context, started.id);
      } else {
        _error = 'Unable to start direct message.';
      }
    } catch (e) {
      _error = 'Failed to open chat with recipient: $e';
      log(_error!);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}