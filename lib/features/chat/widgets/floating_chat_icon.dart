import 'package:flutter/material.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../screens/chat_list_screen.dart';
import '../models/chat_conversation.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class FloatingChatIcon extends StatefulWidget {
  final List<ChatConversation> conversations;
  final VoidCallback? onTap;

  const FloatingChatIcon({
    super.key,
    required this.conversations,
    this.onTap,
  });

  @override
  State<FloatingChatIcon> createState() => _FloatingChatIconState();
}

class _FloatingChatIconState extends State<FloatingChatIcon>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;
  
  Offset _position = const Offset(0.85, 0.75); // Default position (right side, lower)
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));

    // Start pulsing if there are unread messages
    _checkForUnreadMessages();
  }

  @override
  void didUpdateWidget(FloatingChatIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkForUnreadMessages();
  }

  void _checkForUnreadMessages() {
    final hasUnread = widget.conversations.any((c) => c.unreadCount > 0);
    if (hasUnread && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!hasUnread && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final unreadCount = widget.conversations.fold<int>(
      0,
      (sum, conversation) => sum + conversation.unreadCount,
    );

    return Positioned(
      left: _position.dx * screenSize.width - 30, // Center the 60px wide button
      top: _position.dy * screenSize.height - 30, // Center the 60px high button
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _bounceAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value * _bounceAnimation.value,
            child: GestureDetector(
              onPanStart: (_) {
                setState(() {
                  _isDragging = true;
                });
                _bounceController.forward();
              },
              onPanEnd: (_) {
                setState(() {
                  _isDragging = false;
                });
                _bounceController.reverse();
                _snapToEdge(screenSize);
              },
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    (_position.dx * screenSize.width + details.delta.dx) / screenSize.width,
                    (_position.dy * screenSize.height + details.delta.dy) / screenSize.height,
                  );
                  
                  // Constrain to screen bounds
                  _position = Offset(
                    _position.dx.clamp(0.1, 0.9),
                    _position.dy.clamp(0.1, 0.9),
                  );
                });
              },
              onTap: () {
                if (!_isDragging) {
                  _openChatList();
                }
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _isDragging 
                    ? ShadowStyles.heavyShadow 
                    : ShadowStyles.floatingShadow,
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.chat,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _snapToEdge(Size screenSize) {
    // Snap to the nearest vertical edge
    setState(() {
      if (_position.dx < 0.5) {
        _position = Offset(0.1, _position.dy);
      } else {
        _position = Offset(0.9, _position.dy);
      }
    });
  }

  void _openChatList() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      GuardedNavigator.push(context, 
        MaterialPageRoute(
          builder: (context) => ChatListScreen(
            conversations: widget.conversations,
          ),
        ),
      );
    }
  }
}

// Helper widget to overlay the floating chat icon on any screen
class FloatingChatOverlay extends StatelessWidget {
  final Widget child;
  final List<ChatConversation> conversations;
  final VoidCallback? onChatTap;

  const FloatingChatOverlay({
    super.key,
    required this.child,
    required this.conversations,
    this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        FloatingChatIcon(
          conversations: conversations,
          onTap: onChatTap,
        ),
      ],
    );
  }
}