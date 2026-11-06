import 'package:flutter/material.dart';
import '../utils/search_item_view_data.dart';
import 'search_grid_card.dart';

/// Dual-column masonry grid for search discovery results.
class SearchStaggeredGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item) onItemTap;
  final double columnGap;
  final double rowGap;

  const SearchStaggeredGrid({
    super.key,
    required this.items,
    required this.onItemTap,
    this.columnGap = 12,
    this.rowGap = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];
    var leftHeight = 0.0;
    var rightHeight = 0.0;

    for (final raw in items) {
      final data = SearchItemViewData.fromRaw(raw);
      final card = SearchGridCard(
        key: ValueKey(
          '${data.moduleType}-${data.id}-${data.previewImageKey}-${data.media.videoKey}',
        ),
        item: data,
        onTap: () => onItemTap(raw),
      );
      final tile = Padding(
        padding: EdgeInsets.only(bottom: rowGap),
        child: card,
      );

      if (leftHeight <= rightHeight) {
        leftColumn.add(tile);
        leftHeight += data.estimatedTileHeight + rowGap;
      } else {
        rightColumn.add(tile);
        rightHeight += data.estimatedTileHeight + rowGap;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftColumn)),
        SizedBox(width: columnGap),
        Expanded(child: Column(children: rightColumn)),
      ],
    );
  }
}
