import 'package:flutter/material.dart';

import '../../../feed/models/social_listing_card_data.dart';
import '../assistant_guidance.dart';
import '../intent_module.dart';
import 'conversational_item_suggestion_list.dart';

/// Plain answer under the user's words: the reply, short steps, linked
/// listings, and pills. [compact] drops the steps for the typeahead.
class AssistantGuidanceCard extends StatelessWidget {
  final AssistantGuidance guidance;
  final ValueChanged<AssistantTarget> onAction;
  final ValueChanged<SocialListingCardData>? onOpenListing;
  final VoidCallback? onDismiss;
  final bool compact;

  const AssistantGuidanceCard({
    super.key,
    required this.guidance,
    required this.onAction,
    this.onOpenListing,
    this.onDismiss,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final showSteps = !compact && guidance.steps.isNotEmpty;

    return Semantics(
      container: true,
      label: 'Bybata. ${guidance.reply}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guidance.reply,
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          if (showSteps) ...[
            const SizedBox(height: 10),
            for (final step in guidance.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  step,
                  style: TextStyle(fontSize: 14, height: 1.4, color: muted),
                ),
              ),
          ],
          if (guidance.picks.isNotEmpty && onOpenListing != null) ...[
            const SizedBox(height: 12),
            _StaggerIn(
              key: ValueKey(guidance.picks.map((p) => p.id).join(',')),
              index: 0,
              child: ConversationalItemSuggestionList(
                items: guidance.picks,
                isLoading: false,
                query: '',
                showHeader: false,
                onItemTap: onOpenListing!,
              ),
            ),
          ],
          if (guidance.actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < guidance.actions.length; i++)
                  _StaggerIn(
                    key: ValueKey(guidance.actions[i].label),
                    index: i + 1,
                    child: _ActionButton(
                      action: guidance.actions[i],
                      onTap: () => onAction(guidance.actions[i].target),
                    ),
                  ),
              ],
            ),
          ],
          if (onDismiss != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                ),
                child: const Text('Clear'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fades, lifts, and pops a child in, one beat after the item before it.
class _StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggerIn({super.key, required this.index, required this.child});

  static const _step = 90;
  static const _run = 320;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = _step * index;
    final total = delay + _run;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutBack),
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final AssistantAction action;
  final VoidCallback onTap;

  const _ActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = action.target.module.accent;
    final icon = action.target.action == IntentAction.create
        ? Icons.add_rounded
        : action.target.module.icon;

    return Material(
      color: accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
