import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ExpandableDescription extends StatefulWidget {
  final String description;
  final int maxLines;
  final TextStyle? textStyle;
  final String expandButtonText;
  final String collapseButtonText;

  const ExpandableDescription({
    super.key,
    required this.description,
    this.maxLines = 4,
    this.textStyle,
    this.expandButtonText = 'Read more',
    this.collapseButtonText = 'Read less',
  });

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
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
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.description,
            style: widget.textStyle ??
                TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                  height: 1.5,
                ),
          ),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isTextOverflow = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.description,
                    maxLines: _isExpanded ? null : widget.maxLines,
                    overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: widget.textStyle ??
                        TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
            if (isTextOverflow) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _toggleExpanded,
                child: Row(
                  children: [
                    Text(
                      _isExpanded ? widget.collapseButtonText : widget.expandButtonText,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.5).animate(_animation),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        );
      },
    );
  }
}
