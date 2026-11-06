import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/karma_provider.dart';
import '../screens/karma_screen.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Floating KARMA widget that can be added to any screen for quick access
class FloatingKarmaWidget extends StatefulWidget {
  final Alignment alignment;
  final EdgeInsets margin;
  final bool showOnlyWhenActive;
  
  const FloatingKarmaWidget({
    super.key,
    this.alignment = Alignment.bottomRight,
    this.margin = const EdgeInsets.all(16),
    this.showOnlyWhenActive = false,
  });

  @override
  State<FloatingKarmaWidget> createState() => _FloatingKarmaWidgetState();
}

class _FloatingKarmaWidgetState extends State<FloatingKarmaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _navigateToKarma() {
    GuardedNavigator.push(context,
      MaterialPageRoute(builder: (context) => const KarmaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KarmaProvider>(
      builder: (context, karmaProvider, child) {
        if (widget.showOnlyWhenActive && karmaProvider.totalKarma == 0) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: widget.alignment == Alignment.topLeft || widget.alignment == Alignment.topRight ? widget.margin.top : null,
          bottom: widget.alignment == Alignment.bottomLeft || widget.alignment == Alignment.bottomRight ? widget.margin.bottom : null,
          left: widget.alignment == Alignment.topLeft || widget.alignment == Alignment.bottomLeft ? widget.margin.left : null,
          right: widget.alignment == Alignment.topRight || widget.alignment == Alignment.bottomRight ? widget.margin.right : null,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: GestureDetector(
                    onTap: _isExpanded ? _navigateToKarma : _toggleExpanded,
                    onLongPress: _navigateToKarma,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: _isExpanded ? 200 : 60,
                      height: 60,
                      child: _isExpanded ? _buildExpandedWidget(karmaProvider) : _buildCollapsedWidget(karmaProvider),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCollapsedWidget(KarmaProvider karmaProvider) {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.medium,
      borderRadius: 30,
      gradient: const LinearGradient(
        colors: [Colors.amber, Colors.orange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.star,
                color: Colors.white,
                size: 28,
              ),
            ),
            if (karmaProvider.totalKarma > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
                  child: Text(
                    karmaProvider.totalKarma > 999 
                        ? '999+' 
                        : '${karmaProvider.totalKarma}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedWidget(KarmaProvider karmaProvider) {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.medium,
      borderRadius: 30,
      gradient: const LinearGradient(
        colors: [Colors.amber, Colors.orange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.star,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${karmaProvider.totalKarma}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Level ${karmaProvider.level}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick KARMA display widget for app bars and toolbars
class QuickKarmaDisplay extends StatelessWidget {
  final bool showLevel;
  final Color textColor;
  final VoidCallback? onTap;

  const QuickKarmaDisplay({
    super.key,
    this.showLevel = true,
    this.textColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<KarmaProvider>(
      builder: (context, karmaProvider, child) {
        return GestureDetector(
          onTap: onTap ?? () => GuardedNavigator.push(context,
            MaterialPageRoute(builder: (context) => const KarmaScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${karmaProvider.totalKarma}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showLevel) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 1,
                    height: 12,
                    color: textColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'L${karmaProvider.level}',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// KARMA progress indicator widget
class KarmaProgressIndicator extends StatelessWidget {
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;

  const KarmaProgressIndicator({
    super.key,
    this.height = 4,
    this.backgroundColor,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<KarmaProvider>(
      builder: (context, karmaProvider, child) {
        final progress = karmaProvider.getProgressToNextLevel();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level ${karmaProvider.level}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '${karmaProvider.getPointsForNextLevel()} to next level',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: height,
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.grey[300],
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: progressColor ?? Colors.amber,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}