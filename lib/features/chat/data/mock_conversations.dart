import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class MockConversations {
  static List<ChatConversation> getMockConversations() {
    final baseTime = DateTime.now();
    
    return [
      // Trade conversation
      ChatConversation(
        id: 'trade_1',
        otherUserId: 'user1',
        otherUserName: 'John Doe',
        otherUserAvatar: '',
        chatType: ChatType.trade,
        contextTitle: 'iPhone 12 128GB',
        contextId: 'trade_item_1',
        lastMessage: ChatMessage(
          id: '1',
          senderId: 'user1',
          senderName: 'John Doe',
          message: 'Is the item still available?',
          timestamp: baseTime.subtract(const Duration(minutes: 30)),
          isFromCurrentUser: false,
          messageType: MessageType.text,
        ),
        lastActivity: baseTime.subtract(const Duration(minutes: 30)),
        unreadCount: 2,
      ),
      
      
      // Donation conversation
      ChatConversation(
        id: 'donation_1',
        otherUserId: 'user3',
        otherUserName: 'Community Helper',
        otherUserAvatar: '',
        chatType: ChatType.donation,
        contextTitle: 'Help with Medical Surgery',
        contextId: 'campaign_1',
        lastMessage: ChatMessage(
          id: '3',
          senderId: 'user3',
          senderName: 'Community Helper',
          message: 'Thank you for your donation! Every contribution helps.',
          timestamp: baseTime.subtract(const Duration(hours: 5)),
          isFromCurrentUser: false,
          messageType: MessageType.text,
        ),
        lastActivity: baseTime.subtract(const Duration(hours: 5)),
        unreadCount: 1,
      ),
      
      // Community conversation
      ChatConversation(
        id: 'community_1',
        otherUserId: 'user4',
        otherUserName: 'Mike Chen',
        otherUserAvatar: '',
        chatType: ChatType.community,
        contextTitle: 'Downtown Neighbors',
        contextId: 'community_1',
        lastMessage: ChatMessage(
          id: '4',
          senderId: 'user4',
          senderName: 'Mike Chen',
          message: 'Great idea about the community garden project!',
          timestamp: baseTime.subtract(const Duration(days: 1)),
          isFromCurrentUser: false,
          messageType: MessageType.text,
        ),
        lastActivity: baseTime.subtract(const Duration(days: 1)),
        unreadCount: 0,
      ),
    ];
  }
}