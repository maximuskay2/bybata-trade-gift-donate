import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../models/faq_item.dart';
import '../models/support_ticket.dart';

class SupportApi {
  final Dio _dio;
  SupportApi(ApiClient client) : _dio = client.dio;

  Future<List<FAQItem>> fetchFaqs() async {
    final res = await _dio.get('/v1/support/faqs');
    final items = (res.data['items'] as List?) ?? [];
    return items
        .map((e) => FAQItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<SupportTicket>> fetchTickets({String? type}) async {
    final res = await _dio.get(
      '/v1/support/tickets',
      queryParameters: {if (type != null) 'type': type},
    );
    final items = (res.data['items'] as List?) ?? [];
    return items
        .map((e) => SupportTicket.fromApiJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SupportTicket> fetchTicket(String id) async {
    final res = await _dio.get('/v1/support/tickets/$id');
    return SupportTicket.fromApiJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
    String type = 'SUPPORT',
    String priority = 'MEDIUM',
    Map<String, dynamic>? metadata,
  }) async {
    final res = await _dio.post('/v1/support/tickets', data: {
      'subject': subject,
      'description': description,
      'category': category,
      'type': type,
      'priority': priority,
      if (metadata != null) 'metadata': metadata,
    });
    return SupportTicket.fromApiJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<SupportTicket> createBugReport({
    required String subject,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final res = await _dio.post('/v1/support/bug-reports', data: {
      'subject': subject,
      'description': description,
      if (metadata != null) 'metadata': metadata,
    });
    return SupportTicket.fromApiJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Map<String, dynamic>> fetchChatSession() async {
    final res = await _dio.get('/v1/support/chat/session');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> sendChatMessage(String content) async {
    final res = await _dio.post('/v1/support/chat/messages', data: {
      'content': content,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> requestAdminChat() async {
    final res = await _dio.post('/v1/support/chat/request-admin');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> addTicketMessage(String ticketId, String content) async {
    await _dio.post('/v1/support/tickets/$ticketId/messages', data: {
      'content': content,
    });
  }
}
