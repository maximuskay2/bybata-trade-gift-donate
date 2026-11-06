import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:bybata/core/widgets/app_toast.dart';

class DetailCardItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool copyable;

  DetailCardItem({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.onTap,
    this.copyable = false,
  });
}

class DetailCardGrid extends StatelessWidget {
  final List<DetailCardItem> items;
  final int? columns;

  const DetailCardGrid({
    super.key,
    required this.items,
    this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;
    final isSmallPhone = width < 380;
    
    final columnCount = columns ?? 
        (isTablet ? 4 : (isSmallPhone ? 2 : 3));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _DetailCard(item: item);
      },
    );
  }
}

class _DetailCard extends StatefulWidget {
  final DetailCardItem item;

  const _DetailCard({required this.item});

  @override
  State<_DetailCard> createState() => _DetailCardState();
}

class _DetailCardState extends State<_DetailCard> {
  bool _showCopiedFeedback = false;

  void _handleTap() {
    if (widget.item.copyable) {
      AppToast.show(context, '${widget.item.value} copied to clipboard');
      setState(() => _showCopiedFeedback = true);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _showCopiedFeedback = false);
      });
    }
    widget.item.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = scheme.surface;
    final accentColor = widget.item.accentColor ?? AppColors.primary;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300] ?? Colors.grey,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.icon,
              size: 28,
              color: accentColor.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              widget.item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
