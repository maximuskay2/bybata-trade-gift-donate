import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import 'home_v2_tokens.dart';

/// Welcoming row at the top of every V2 home surface.
///
/// Authenticated: "Good morning, Chidi".
/// Unauthenticated: "Welcome to Bybata" + soft subtitle.
///
/// Karma chip intentionally removed — the top chrome already carries
/// the user's status and stacking a karma pill here added a third
/// vertical row before the search pill without paying its keep.
class GreetingHeader extends StatelessWidget {
  final bool isAuthed;

  const GreetingHeader({super.key, required this.isAuthed});

  String _timeOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    String headline;
    String? subline;

    if (isAuthed) {
      final auth = context.watch<AuthProvider>();
      final name = _firstName(auth);
      headline = 'Good ${_timeOfDay()}${name.isNotEmpty ? ', $name' : ''}';
      subline = null;
    } else {
      headline = 'Welcome to Bybata';
      subline = 'Trade, gift, donate — all in your neighborhood.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeV2Tokens.kHorizontalPad,
        12,
        HomeV2Tokens.kHorizontalPad,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          if (subline != null) ...[
            const SizedBox(height: 4),
            Text(
              subline,
              style: textTheme.bodyMedium?.copyWith(
                color: onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _firstName(AuthProvider auth) {
    final raw = auth.currentUser?.displayName.trim() ?? '';
    if (raw.isEmpty) return '';
    return raw.split(' ').first;
  }
}
