import 'package:flutter/material.dart';

/// Pill-style tab switcher used across Trade Center, Gift Hub, Help & Support, etc.
class HubFluidTabSwitcher extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final bool Function(int index)? guardTabTap;

  const HubFluidTabSwitcher({
    super.key,
    required this.controller,
    required this.labels,
    this.guardTabTap,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final divisor = labels.length > 1 ? labels.length - 1 : 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      height: 60,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            alignment: Alignment(
              -1.0 + (controller.index * (2.0 / divisor)),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(
              labels.length,
              (index) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (guardTabTap != null && !guardTabTap!(index)) return;
                    if (controller.index != index) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                    controller.animateTo(index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: controller.index == index
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: controller.index == index
                            ? FontWeight.w800
                            : FontWeight.w500,
                        fontSize: labels.length > 4 ? 11 : 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
