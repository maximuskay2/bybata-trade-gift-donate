import 'package:flutter/material.dart';

import 'collapsible_section.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Lazy-loaded horizontal strip for similar trades, gifts, or campaigns.
class SimilarItemsSection extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final bool isLoading;
  final bool hasLoaded;
  final List<dynamic> items;
  final VoidCallback? onExpand;
  final Widget Function(BuildContext context, dynamic item, int index) itemBuilder;
  final String emptyMessage;
  final double listHeight;
  final Color? backgroundColor;

  const SimilarItemsSection({
    super.key,
    required this.title,
    required this.isLoading,
    required this.hasLoaded,
    required this.items,
    required this.itemBuilder,
    this.leadingIcon = Icons.explore_rounded,
    this.onExpand,
    this.emptyMessage = 'No similar items found.',
    this.listHeight = 140,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: title,
      leadingIcon: leadingIcon,
      initiallyExpanded: false,
      backgroundColor: backgroundColor,
      onExpanded: onExpand,
      content: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: const BybataLoader(),
      );
    }

    if (items.isEmpty && hasLoaded) {
      return Text(
        emptyMessage,
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    if (items.isEmpty) {
      return Text(
        'Expand to discover more.',
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => itemBuilder(context, items[index], index),
      ),
    );
  }
}
