import 'package:flutter/material.dart';

import '../../../../core/accessibility/accessibility_utils.dart';
import 'glass_surface.dart';

/// Tappable summary above the bento grid. Clearing it returns to the idle home.
class IntentSummaryChip extends StatelessWidget {
  final String label;
  final int resultCount;
  final VoidCallback onClear;

  const IntentSummaryChip({
    super.key,
    required this.label,
    required this.resultCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantics = AccessibilityUtils.createSemanticLabel(
      mainText: label,
      value: '$resultCount results',
      hint: 'Clears this search',
    );
    return Semantics(
      label: semantics,
      button: true,
      child: GlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: BorderRadius.circular(999),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: Icon(Icons.close, size: 18, color: scheme.onSurface),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ),
      ),
    );
  }
}

class IntentRefinementChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelected;

  const IntentRefinementChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          FilterChip(
            label: Text(category.replaceAll('_', ' ').toLowerCase()),
            selected: selected == category,
            onSelected: (_) => onSelected(category),
          ),
      ],
    );
  }
}

class IntentModuleHints extends StatelessWidget {
  final VoidCallback onTrades;
  final VoidCallback onGifts;
  final VoidCallback onFundraisers;

  const IntentModuleHints({
    super.key,
    required this.onTrades,
    required this.onGifts,
    required this.onFundraisers,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Did you mean:',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _hint('Trades', onTrades),
            _hint('Gifts', onGifts),
            _hint('Fundraisers', onFundraisers),
          ],
        ),
      ],
    );
  }

  Widget _hint(String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: 'Search $label',
      child: OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}
