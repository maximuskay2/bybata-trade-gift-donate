import 'dart:convert';
import '../api/trade_api.dart';
import '../models/trade_models.dart';
import '../../../core/api/api_client.dart';

class NegotiationService {
  final TradeApi _tradeApi;
  
  NegotiationService(ApiClient apiClient) : _tradeApi = TradeApi(apiClient);

  /// Create a new offer for a trade and return its ID
  Future<String?> createOffer(String tradeId, {String? message}) async {
    try {
      final res = await _tradeApi.createOffer(tradeId, message: message);
      final id = res['id'];
      if (id is String && id.isNotEmpty) return id;
      // Fallback key name if backend uses a different field
      final altId = res['offerId'];
      if (altId is String && altId.isNotEmpty) return altId;
      return null;
    } catch (e) {
      print('Error creating offer: $e');
      return null;
    }
  }

  /// Load messages for a negotiation
  Future<List<TradeMessage>> loadMessages(String offerId) async {
    try {
      final messages = await _tradeApi.listMessages(offerId);
      return messages
          .map((messageData) => _parseMessage(messageData, offerIdFallback: offerId))
          .toList();
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }

  /// Send a regular message
  Future<TradeMessage?> sendMessage(String offerId, String content) async {
    try {
      final response = await _tradeApi.postMessage(offerId, content);
      return _parseMessage(response);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  /// Send a proposal message
  Future<TradeMessage?> sendProposal(
    String offerId, 
    String content, 
    Map<String, dynamic> proposalData
  ) async {
    try {
      final response = await _tradeApi.postMessage(
        offerId, 
        content, 
        messageType: 'proposal',
        proposalData: proposalData,
      );
      return _parseMessage(response);
    } catch (e) {
      print('Error sending proposal: $e');
      return null;
    }
  }

  /// Send a counter-offer message
  Future<TradeMessage?> sendCounterOffer(
    String offerId, 
    String content, 
    Map<String, dynamic> proposalData
  ) async {
    try {
      final response = await _tradeApi.postMessage(
        offerId, 
        content, 
        messageType: 'counter_offer',
        proposalData: proposalData,
      );
      return _parseMessage(response);
    } catch (e) {
      print('Error sending counter offer: $e');
      return null;
    }
  }

  /// Send an acceptance message
  Future<TradeMessage?> sendAcceptance(String offerId, String content) async {
    try {
      final response = await _tradeApi.postMessage(
        offerId, 
        content, 
        messageType: 'acceptance',
      );
      return _parseMessage(response);
    } catch (e) {
      print('Error sending acceptance: $e');
      return null;
    }
  }

  /// Send a decline message
  Future<TradeMessage?> sendDecline(String offerId, String content) async {
    try {
      final response = await _tradeApi.postMessage(
        offerId, 
        content, 
        messageType: 'decline',
      );
      return _parseMessage(response);
    } catch (e) {
      print('Error sending decline: $e');
      return null;
    }
  }

  /// Send a meeting suggestion message
  Future<TradeMessage?> sendMeetingSuggestion(String offerId, String content) async {
    try {
      final response = await _tradeApi.postMessage(
        offerId, 
        content, 
        messageType: 'meeting_suggestion',
      );
      return _parseMessage(response);
    } catch (e) {
      print('Error sending meeting suggestion: $e');
      return null;
    }
  }

  /// Send a dispute report message
  Future<TradeMessage?> sendDisputeReport(String offerId, String content) async {
    try {
      final response = await _tradeApi.postMessage(
        offerId, 
        content, 
        messageType: 'dispute_report',
      );
      return _parseMessage(response);
    } catch (e) {
      print('Error sending dispute report: $e');
      return null;
    }
  }

  /// Send a schedule suggestion message
  Future<TradeMessage?> sendScheduleSuggestion(String offerId, String content) async {
    try {
      final response = await _tradeApi.postMessage(
        offerId, 
        content, 
        messageType: 'schedule_suggestion',
      );
      return _parseMessage(response);
    } catch (e) {
      print('Error sending schedule suggestion: $e');
      return null;
    }
  }

  /// Parse message data from API response
  TradeMessage _parseMessage(Map<String, dynamic> data, {String? offerIdFallback}) {
    final offerId = data['negotiation']?['offerId'] ?? data['offerId'] ?? offerIdFallback;
    return TradeMessage(
      id: data['id'] ?? '',
      tradeId: data['negotiation']?['tradeId'] ?? '',
      offerId: offerId,
      sender: _parseUser(data['sender'] ?? {}),
      content: data['content'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      isRead: true, // Assume read for now
      messageType: _parseMessageType(data['messageType']),
      proposalData: data['proposalData'] != null 
          ? (data['proposalData'] is String 
              ? json.decode(data['proposalData'])
              : data['proposalData'])
          : null,
    );
  }

  /// Parse user data from API response
  TradeUser _parseUser(Map<String, dynamic> data) {
    return TradeUser(
      id: data['id'] ?? '',
      name: data['profile']?['displayName'] ?? data['email'] ?? 'Unknown User',
      username: '@${data['email']?.split('@')[0] ?? 'unknown'}',
      rating: 4.5, // Default rating
      completedTrades: 0, // Default value
      joinedDate: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      isVerified: data['profile']?['kycStatus'] == 'VERIFIED',
    );
  }

  /// Parse message type from API response
  String _parseMessageType(String? type) {
    if (type == null) return 'regular';
    
    switch (type.toLowerCase()) {
      case 'proposal':
        return 'proposal';
      case 'counter_offer':
        return 'counterOffer';
      case 'acceptance':
        return 'acceptance';
      case 'decline':
        return 'decline';
      case 'meeting_suggestion':
        return 'meetingSuggestion';
      case 'dispute_report':
        return 'disputeReport';
      case 'schedule_suggestion':
        return 'scheduleSuggestion';
      default:
        return 'regular';
    }
  }

  /// Get negotiation status from messages
  String getNegotiationStatus(List<TradeMessage> messages) {
    if (messages.isEmpty) return 'initial';
    
    final latestMessage = messages.last;
    
    switch (latestMessage.messageType) {
      case 'acceptance':
        return 'accepted';
      case 'decline':
        return 'declined';
      case 'proposal':
      case 'counterOffer':
        return 'pending';
      default:
        return 'active';
    }
  }

  /// Get the last proposer from messages
  String? getLastProposer(List<TradeMessage> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.messageType == 'proposal' || message.messageType == 'counterOffer') {
        return message.sender.id;
      }
    }
    return null;
  }

  /// Load the full history of negotiations for a trade across all offers
  Future<List<TradeMessage>> loadTradeHistory(String tradeId, {int maxOffers = 10}) async {
    try {
      final offers = await _tradeApi.listOffers(tradeId);
      final offerIds = offers
          .map((o) => (o['id'] ?? o['offerId'])?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final limited = offerIds.take(maxOffers).toList();
      final List<TradeMessage> all = [];
      for (final oid in limited) {
        try {
          // Small delay between requests to avoid hitting rate limits
          await Future.delayed(const Duration(milliseconds: 250));
          final msgs = await _tradeApi.listMessages(oid);
          all.addAll(msgs.map((data) => _parseMessage(data, offerIdFallback: oid)));
        } catch (e) {
          // Skip problematic offers but continue aggregating others
          print('Error loading messages for offer $oid: $e');
        }
      }
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return all;
    } catch (e) {
      print('Error loading trade history: $e');
      return [];
    }
  }
}