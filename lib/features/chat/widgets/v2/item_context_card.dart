import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_utils.dart';

/// Rich tap-to-view card used for the first SYSTEM message in any interaction
/// thread (trade / gift / donation / request). Both parties see the same card
/// so the thread always has persistent, referenceable context.
///
/// [metadata] is the raw `message.metadata` map; it is expected to carry:
///   • kind            : 'item_context'
///   • sourceType      : TRADE | GIFT | CAMPAIGN | REQUEST
///   • itemId          : identifier to open the details screen
///   • itemTitle       : display title
///   • itemDescription : optional description (trimmed to 3 lines)
///   • itemImageKey    : optional storage key (resolved via MediaResolver)
class ItemContextCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final bool isMe;
  final VoidCallback? onTap;

  const ItemContextCard({
    super.key,
    required this.metadata,
    required this.isMe,
    this.onTap,
  });

  String get _sourceType =>
      (metadata['sourceType'] ?? '').toString().toUpperCase();
  String get _title => (metadata['itemTitle'] ?? '').toString();
  String get _description => (metadata['itemDescription'] ?? '').toString();
  String? get _imageKey {
    final v = metadata['itemImageKey'];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  String get _typeLabel {
    switch (_sourceType) {
      case 'TRADE':
        return 'Trade';
      case 'GIFT':
        return 'Gift';
      case 'CAMPAIGN':
        return 'Donation';
      case 'REQUEST':
        return 'Request';
      default:
        return 'Item';
    }
  }

  IconData get _typeIcon {
    switch (_sourceType) {
      case 'TRADE':
        return Icons.swap_horiz_rounded;
      case 'GIFT':
        return Icons.card_giftcard_rounded;
      case 'CAMPAIGN':
        return Icons.volunteer_activism_rounded;
      case 'REQUEST':
        return Icons.help_outline_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final border = AppColors.primary.withValues(alpha: 0.25);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header strip
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: AppColors.primary.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    Icon(_typeIcon,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _typeLabel.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              // Image (optional)
              if (_imageKey != null)
                FutureBuilder<String?>(
                  future: MediaResolver.resolveUrl(_imageKey),
                  builder: (context, snap) {
                    final url = snap.data;
                    if (url == null || !url.startsWith('http')) {
                      return const SizedBox.shrink();
                    }
                    return Image.network(
                      url,
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    );
                  },
                ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title.isEmpty ? 'Listing' : _title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _description,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: isDark
                              ? Colors.grey[300]
                              : Colors.grey[700],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to view details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
