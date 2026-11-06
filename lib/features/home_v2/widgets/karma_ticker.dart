import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'home_v2_tokens.dart';

/// One-line auto-scrolling karma moments strip.
///
/// V2 uses a static demo feed; the live wire to a "recent karma events"
/// stream is intentionally deferred (purely cosmetic, low-risk). Replace
/// [_demoMoments] with a real provider when the backend exposes one.
class KarmaTicker extends StatefulWidget {
  const KarmaTicker({super.key});

  @override
  State<KarmaTicker> createState() => _KarmaTickerState();
}

class _KarmaTickerState extends State<KarmaTicker> {
  static final _demoMoments = <_Moment>[
    _Moment(
      icon: Icons.card_giftcard_rounded,
      color: AppTheme.giftColor,
      text: 'Amaka just gifted a laptop',
      ago: '2 min ago',
    ),
    _Moment(
      icon: Icons.volunteer_activism_rounded,
      color: AppTheme.donationColor,
      text: 'Tunde funded a campaign',
      ago: '4 min ago',
    ),
    _Moment(
      icon: Icons.swap_horiz_rounded,
      color: AppTheme.tradeColor,
      text: 'Kemi closed a trade',
      ago: '7 min ago',
    ),
    _Moment(
      icon: Icons.card_giftcard_rounded,
      color: AppTheme.giftColor,
      text: 'Ifeanyi gave away a bike',
      ago: '12 min ago',
    ),
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _demoMoments.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _demoMoments[_index];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeV2Tokens.kHorizontalPad,
        HomeV2Tokens.kSliderGap,
        HomeV2Tokens.kHorizontalPad,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Karma moments',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: HomeV2Tokens.kRailHeaderGap),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Container(
              key: ValueKey(_index),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.12),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(m.icon, size: 16, color: m.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    m.ago,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Moment {
  final IconData icon;
  final Color color;
  final String text;
  final String ago;

  const _Moment({
    required this.icon,
    required this.color,
    required this.text,
    required this.ago,
  });
}
