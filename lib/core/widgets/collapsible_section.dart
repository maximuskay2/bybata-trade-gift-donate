import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget content;
  final bool initiallyExpanded;
  final IconData? leadingIcon;
  final VoidCallback? onExpanded;
  final VoidCallback? onCollapsed;
  final Color? backgroundColor;
  final EdgeInsets contentPadding;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = true,
    this.leadingIcon,
    this.onExpanded,
    this.onCollapsed,
    this.backgroundColor,
    this.contentPadding = const EdgeInsets.all(16),
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _rotateAnimation;
  late AnimationController _heightController;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    if (_isExpanded) {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);

    if (_isExpanded) {
      _animController.forward();
      widget.onExpanded?.call();
    } else {
      _animController.reverse();
      widget.onCollapsed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final scheme = Theme.of(context).colorScheme;
    final bgColor = widget.backgroundColor ??
        (isDark ? scheme.surface : scheme.surface.withValues(alpha: 0.92));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300] ?? Colors.grey,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (widget.leadingIcon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.leadingIcon,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300] ?? Colors.grey,
                      width: 1,
                    ),
                  ),
                ),
                padding: widget.contentPadding,
                child: widget.content,
              ),
            ),
        ],
      ),
    );
  }
}
