import 'package:flutter/material.dart';

/// Shared right-edge create rail for Trade / Gift / Donate hubs.
/// Presentation only — [onTap] keeps each hub's create / sign-in flow.
class HubCreateRail extends StatefulWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const HubCreateRail({
    super.key,
    required this.color,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
  });

  @override
  State<HubCreateRail> createState() => _HubCreateRailState();
}

class _HubCreateRailState extends State<HubCreateRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = reduce ? 0.28 : 0.22 + (_pulse.value * 0.14);
          return Container(
            height: 130,
            width: 48,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: glow),
                  blurRadius: 22,
                  offset: const Offset(-4, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 3,
              child: SizedBox(
                width: 85,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
