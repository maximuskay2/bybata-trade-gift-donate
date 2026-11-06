import 'package:flutter/material.dart';
import '../models/trade_models.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../../../core/theme/app_theme.dart';

class FullscreenChatModal extends StatefulWidget {
  final Trade targetTrade;
  final List<TradeMessage> messages;
  final TextEditingController messageController;
  final ScrollController messagesScrollController;
  final Function(String content, String messageType, {Map<String, dynamic>? proposalData}) onSendMessage;
  final VoidCallback onClose;
  final String negotiationStatus;
  final String? lastProposerUserId;

  const FullscreenChatModal({
    super.key,
    required this.targetTrade,
    required this.messages,
    required this.messageController,
    required this.messagesScrollController,
    required this.onSendMessage,
    required this.onClose,
    required this.negotiationStatus,
    this.lastProposerUserId,
  });

  @override
  State<FullscreenChatModal> createState() => _FullscreenChatModalState();
}

class _FullscreenChatModalState extends State<FullscreenChatModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeModal() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          color: Colors.black.withValues(alpha: 0.5 * _fadeAnimation.value),
          child: GestureDetector(
            onTap: _closeModal,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent close when tapping modal content
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.95,
                        height: MediaQuery.of(context).size.height * 0.85,
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Modal Header
                            _buildModalHeader(primaryColor),
                            
                            // Messages Area
                            Expanded(
                              child: _buildMessagesArea(primaryColor),
                            ),
                            
                            // Input Area
                            _buildMessageInput(primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _closeModal,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                color: primaryColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 20,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Text(
              widget.targetTrade.owner.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat with ${widget.targetTrade.owner.name}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  'About: ${widget.targetTrade.title}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildStatusIndicator(primaryColor),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(Color primaryColor) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (widget.negotiationStatus) {
      case 'initial':
        statusText = 'No proposal yet';
        statusColor = Colors.grey;
        statusIcon = Icons.chat_bubble_outline;
        break;
      case 'pending':
        if (widget.lastProposerUserId == 'current_user') {
          statusText = 'Waiting';
          statusColor = Colors.orange;
          statusIcon = Icons.hourglass_empty;
        } else {
          statusText = 'Your turn';
          statusColor = primaryColor;
          statusIcon = Icons.notification_important;
        }
        break;
      case 'accepted':
        statusText = 'Accepted!';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'declined':
        statusText = 'Declined';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusText = 'Active';
        statusColor = primaryColor;
        statusIcon = Icons.chat_bubble;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ListView.builder(
        controller: widget.messagesScrollController,
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          final isCurrentUser = message.sender.id == 'current_user';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: _buildMessageBubble(message, isCurrentUser, primaryColor),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(TradeMessage message, bool isCurrentUser, Color primaryColor) {
    switch (message.messageType) {
      case 'proposal':
      case 'counterOffer':
        return _buildProposalBubble(message, isCurrentUser, primaryColor);
      case 'acceptance':
        return _buildAcceptanceBubble(message, isCurrentUser, primaryColor);
      case 'decline':
        return _buildDeclineBubble(message, isCurrentUser, primaryColor);
      default:
        return _buildRegularMessageBubble(message, isCurrentUser, primaryColor);
    }
  }

  Widget _buildRegularMessageBubble(TradeMessage message, bool isCurrentUser, Color primaryColor) {
    return Row(
      mainAxisAlignment: isCurrentUser 
          ? MainAxisAlignment.end 
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCurrentUser) ...[ 
          CircleAvatar(
            radius: 14,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Text(
              message.sender.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentUser 
                  ? primaryColor 
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: isCurrentUser 
                    ? const Radius.circular(16)
                    : const Radius.circular(4),
                bottomRight: isCurrentUser 
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isCurrentUser 
                        ? Colors.white 
                        : Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.timeAgo,
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrentUser 
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        if (isCurrentUser) ...[ 
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Text(
              message.sender.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProposalBubble(TradeMessage message, bool isCurrentUser, Color primaryColor) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withValues(alpha: 0.1),
              primaryColor.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    message.messageType == 'counterOffer' 
                        ? Icons.swap_calls 
                        : Icons.handshake,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentUser 
                            ? (message.messageType == 'counterOffer' 
                                ? 'You made a counter offer' 
                                : 'You proposed a trade')
                            : (message.messageType == 'counterOffer' 
                                ? '${message.sender.name} made a counter offer'
                                : '${message.sender.name} proposed a trade'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.timeAgo,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message.content.isNotEmpty) ...[ 
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptanceBubble(TradeMessage message, bool isCurrentUser, Color primaryColor) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCurrentUser 
                      ? 'You accepted the offer'
                      : '${message.sender.name} accepted the offer',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 13,
                  ),
                ),
                Text(
                  message.timeAgo,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclineBubble(TradeMessage message, bool isCurrentUser, Color primaryColor) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.cancel,
                color: Colors.red,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCurrentUser 
                      ? 'You declined the offer'
                      : '${message.sender.name} declined the offer',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
                Text(
                  message.timeAgo,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: widget.messageController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          GestureDetector(
            onTap: () {
              if (widget.messageController.text.trim().isNotEmpty) {
                widget.onSendMessage(
                  widget.messageController.text.trim(),
                  'regular',
                );
                widget.messageController.clear();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}