import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import '../models/chat_models.dart';
import '../models/chat_conversation.dart';
import '../../../core/api/api_client.dart';

class ChatHttpService {
  final ApiClient _apiClient;

  ChatHttpService({required ApiClient apiClient}) : _apiClient = apiClient;

  // Conversations
  Future<List<ChatConversation>> getConversations({
    int page = 1,
    int limit = 50,
    String? module, // Optional module filter: TRADE, GIFT, DONATION, COMMUNITY
    String? viewerUserId,
  }) async {
    try {
      log('DEBUG: Fetching conversations from API with page=$page, limit=$limit, module=$module');
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (module != null && module.isNotEmpty) {
        queryParams['module'] = module;
      }
      final response = await _apiClient.dio.get(
        '/chat/conversations',
        queryParameters: queryParams,
      );

      final data = response.data;
      log('DEBUG: Received conversations response with ${data['conversations']?.length ?? 0} conversations');
      if (data['conversations'] != null) {
        final conversations = <ChatConversation>[];
        for (final json in data['conversations'] as List) {
          if (json is! Map<String, dynamic>) continue;
          try {
            conversations.add(
              ChatConversation.fromJson(
                json,
                viewerUserId: viewerUserId,
              ),
            );
          } catch (e) {
            log('Skipping malformed conversation payload: $e');
          }
        }
        log('DEBUG: Parsed ${conversations.length} conversations');
        for (var i = 0; i < conversations.length; i++) {
          final conv = conversations[i];
          log('DEBUG: Conversation $i: id=${conv.id}, contextId=${conv.contextId}, contextTitle=${conv.contextTitle}, otherUserId=${conv.otherUserId}');
        }
        return conversations;
      }
      return [];
    } catch (e) {
      log('Error fetching conversations: $e');
      throw _handleError(e);
    }
  }

  Future<List<ChatConversation>> searchConversations(String query) async {
    try {
      final response = await _apiClient.dio.get(
        '/chat/conversations/search',
        queryParameters: {'q': query},
      );

      return (response.data as List)
          .map((json) => ChatConversation.fromJson(json))
          .toList();
    } catch (e) {
      log('Error searching conversations: $e');
      throw _handleError(e);
    }
  }

  Future<ChatConversation> getConversation(
    String conversationId, {
    String? viewerUserId,
  }) async {
    try {
      final response = await _apiClient.dio.get('/chat/conversations/$conversationId');
      return ChatConversation.fromJson(
        response.data as Map<String, dynamic>,
        viewerUserId: viewerUserId,
      );
    } catch (e) {
      log('Error fetching conversation: $e');
      throw _handleError(e);
    }
  }

  Future<ChatConversation> createConversation({
    required String type, // 'DIRECT' or 'GROUP'
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
    required List<String> participantIds,
  }) async {
    try {
      // Build payload omitting nulls to avoid backend validation errors
      final payload = <String, dynamic>{
        'type': type,
        'participantIds': participantIds,
      };
      if (title != null) payload['title'] = title;
      if (description != null) payload['description'] = description;
      if (metadata != null) payload['metadata'] = metadata;
      
      final response = await _apiClient.dio.post(
        '/chat/conversations',
        data: payload,
        options: Options(
          // Prevent Dio from throwing on non-2xx; we will handle manually
          validateStatus: (_) => true,
        ),
      );

      // Manually surface server-side errors
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw _httpResponseError(response);
      }

      // Handle flexible response shapes: { conversation: {...} } or direct conversation object
      final data = response.data;
      Map<String, dynamic>? convJson;
      if (data is Map<String, dynamic>) {
        if (data['conversation'] is Map<String, dynamic>) {
          convJson = data['conversation'] as Map<String, dynamic>;
        } else if (data['id'] != null) {
          convJson = data;
        }
      }
      if (convJson == null) {
        throw Exception('Unexpected response format when creating conversation');
      }
      
      return ChatConversation.fromJson(convJson);
    } catch (e) {
      log('Error creating conversation: $e');
      throw _handleError(e);
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      await _apiClient.dio.post('/chat/conversations/$conversationId/read');
    } catch (e) {
      log('Error marking conversation as read: $e');
      throw _handleError(e);
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _apiClient.dio.delete('/chat/conversations/$conversationId');
    } catch (e) {
      log('Error deleting conversation: $e');
      throw _handleError(e);
    }
  }

  // Direct messages
  Future<ChatConversation> startDirectMessage({
    required String recipientId,
    String? initialMessage,
    String? type,
    String? contextId,
    String? contextTitle,
    String? viewerUserId,
  }) async {
    try {
      log('DEBUG: startDirectMessage called with recipientId=$recipientId, contextId=$contextId, contextTitle=$contextTitle, type=$type');
      // Build payload omitting nulls to avoid backend validation errors
      final payload = <String, dynamic>{
        'recipientId': recipientId,
      };
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        // Backend expects only 'message' key; do not include 'initialMessage'
        payload['message'] = initialMessage;
      }

      // Only send a conversation type when it matches the backend enum.
      // GIFT uses DIRECT type with metadata.sourceType = 'GIFT'.
      const allowedTypes = ['DIRECT', 'TRADE', 'GROUP', 'SUPPORT', 'DONATION'];
      if (type != null && type.trim().isNotEmpty) {
        final upper = type.trim().toUpperCase();
        if (allowedTypes.contains(upper)) {
          payload['type'] = upper;
        }
      }

      // Send context for gift/trade/donation so backend stores metadata (enables Gift tab filtering)
      if (contextTitle != null && contextTitle!.trim().isNotEmpty) {
        payload['contextTitle'] = contextTitle!.trim();
      }
      if (contextId != null && contextId!.trim().isNotEmpty) {
        payload['contextId'] = contextId!.trim();
      }
      log('DEBUG: Sending payload to /chat/direct-messages: $payload');

      final response = await _apiClient.dio.post(
        '/chat/direct-messages',
        data: payload,
        options: Options(
          // Do not throw on 4xx/5xx; let us inspect the response
          validateStatus: (_) => true,
        ),
      );
      log('DEBUG: Received response from /chat/direct-messages with status=${response.statusCode}');
      log('DEBUG: Response data: ${response.data}');

      // Manually handle HTTP errors
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        log('DEBUG: Throwing HTTP error for status=$status');
        throw _httpResponseError(response);
      }

      // Handle flexible response shapes: { conversation: {...} } or direct conversation object
      final data = response.data;
      log('DEBUG: Parsing response data: $data');
      Map<String, dynamic>? convJson;
      if (data is Map<String, dynamic>) {
        if (data['conversation'] is Map<String, dynamic>) {
          convJson = data['conversation'] as Map<String, dynamic>;
        } else if (data['id'] != null) {
          convJson = data;
        }
      }
      if (convJson == null) {
        log('DEBUG: convJson is null, throwing exception');
        throw Exception('Unexpected response format when starting DM');
      }
      log('DEBUG: Creating ChatConversation from convJson: $convJson');
      final conversation = ChatConversation.fromJson(
        convJson,
        viewerUserId: viewerUserId,
      );
      log('DEBUG: Created conversation: id=${conversation.id}, contextId=${conversation.contextId}, contextTitle=${conversation.contextTitle}');
      return conversation;
    } catch (e) {
      log('Error starting direct message: $e');
      throw _handleError(e);
    }
  }

  // Messages
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final data = response.data;
      if (data['messages'] != null) {
        return (data['messages'] as List)
            .map((json) => ChatMessage.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      log('Error fetching messages: $e');
      throw _handleError(e);
    }
  }

  // Cursor-based messages fetch (if backend supports it)
  Future<Map<String, dynamic>> getMessagesCursor(
    String conversationId, {
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit.toString(),
      };
      if (cursor != null && cursor.isNotEmpty) {
        query['cursor'] = cursor;
      }
      final response = await _apiClient.dio.get(
        '/chat/conversations/$conversationId/messages',
        queryParameters: query,
      );

      final data = response.data;
      final List<ChatMessage> messages = (data['messages'] as List?)
              ?.map((json) => ChatMessage.fromJson(json))
              .toList() ??
          [];

      String? nextCursor;
      if (data is Map<String, dynamic>) {
        nextCursor = data['nextCursor'] as String? ??
            data['next'] as String? ??
            (data['cursor'] is Map<String, dynamic>
                ? (data['cursor'] as Map<String, dynamic>)['next'] as String?
                : null);
      }

      return {
        'messages': messages,
        'nextCursor': nextCursor,
      };
    } catch (e) {
      log('Error fetching messages (cursor): $e');
      throw _handleError(e);
    }
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String? type,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/chat/conversations/$conversationId/messages',
        data: {
          'content': content,
          'type': type,
          'replyToId': replyToId,
          'metadata': metadata,
        },
        options: Options(
          // Avoid throwing on non-2xx; handle below
          validateStatus: (_) => true,
        ),
      );

      // Check for HTTP error responses
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw _httpResponseError(response);
      }

      return ChatMessage.fromJson(response.data);
    } catch (e) {
      log('Error sending message: $e');
      throw _handleError(e);
    }
  }

  Future<List<ChatMessage>> searchMessages(
    String conversationId,
    String query,
  ) async {
    try {
      final response = await _apiClient.dio.get(
        '/chat/conversations/$conversationId/messages/search',
        queryParameters: {'q': query},
      );

      return (response.data as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      log('Error searching messages: $e');
      throw _handleError(e);
    }
  }

  Future<void> markMessageAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _apiClient.dio.post(
        '/chat/conversations/$conversationId/messages/$messageId/read',
      );
    } catch (e) {
      log('Error marking message as read: $e');
      throw _handleError(e);
    }
  }

  // Message reactions
  Future<ChatReaction> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/chat/messages/$messageId/reactions',
        data: {'emoji': emoji},
      );

      return ChatReaction.fromJson(response.data);
    } catch (e) {
      log('Error adding reaction: $e');
      throw _handleError(e);
    }
  }

  Future<void> removeReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _apiClient.dio.delete('/chat/messages/$messageId/reactions/$emoji');
    } catch (e) {
      log('Error removing reaction: $e');
      throw _handleError(e);
    }
  }

  // Report message
  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String? description,
  }) async {
    try {
      await _apiClient.dio.post('/chat/messages/$messageId/report', data: {
        'reason': reason,
        'description': description,
      });
    } catch (e) {
      log('Error reporting message: $e');
      throw _handleError(e);
    }
  }

  // Health check
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _apiClient.dio.get('/chat/health');
      return response.data;
    } catch (e) {
      log('Error checking chat health: $e');
      throw _handleError(e);
    }
  }

  String _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Please check your internet connection.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data?['message'] ?? 'Unknown error';
          
          switch (statusCode) {
            case 401:
              return 'You are not authorized. Please log in again.';
            case 403:
              return 'You do not have permission to perform this action.';
            case 404:
              return 'The requested resource was not found.';
            case 429:
              return 'Too many requests. Please try again later.';
            case 500:
              // Prefer server-provided message if available to aid debugging
              return message.toString().isNotEmpty
                  ? message.toString()
                  : 'Server error. Please try again later.';
            default:
              return message.toString();
          }
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        case DioExceptionType.unknown:
          if (error.error.toString().contains('SocketException')) {
            return 'No internet connection. Please check your network.';
          }
          return 'An unexpected error occurred. Please try again.';
        default:
          return 'An error occurred. Please try again.';
      }
    }
    // Manual HTTP error surfaced via _httpResponseError
    if (error is String) {
      return error;
    }
    return error.toString();
  }

  // Build a readable message from non-2xx HTTP responses when validateStatus allows them
  String _httpResponseError(Response response) {
    final status = response.statusCode ?? 0;
    final data = response.data;
    String serverMessage = '';

    if (data is Map<String, dynamic>) {
      final m = data['message'];
      if (m is String) serverMessage = m;
      // Some Nest handlers may use { error: '...', message: '...' }
      if (serverMessage.isEmpty && data['error'] is String) {
        serverMessage = data['error'] as String;
      }
      // Or { details: {...} }
      if (serverMessage.isEmpty && data['details'] is Map<String, dynamic>) {
        serverMessage = jsonEncode(data['details']);
      }
    } else if (data is String) {
      serverMessage = data;
    }

    final fallback = response.statusMessage ?? 'HTTP $status error';
    final message = (serverMessage.isNotEmpty ? serverMessage : fallback);
    return message;
  }
}

// Response wrapper classes for paginated results
class ConversationsResponse {
  final List<ChatConversation> conversations;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  ConversationsResponse({
    required this.conversations,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory ConversationsResponse.fromJson(Map<String, dynamic> json) {
    return ConversationsResponse(
      conversations: (json['conversations'] as List)
          .map((c) => ChatConversation.fromJson(c))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}

class MessagesResponse {
  final List<ChatMessage> messages;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  MessagesResponse({
    required this.messages,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory MessagesResponse.fromJson(Map<String, dynamic> json) {
    return MessagesResponse(
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 50,
      totalPages: json['totalPages'] ?? 1,
    );
  }
}
