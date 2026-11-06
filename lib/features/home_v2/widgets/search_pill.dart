import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../screens/search/search_screen.dart';
import 'home_v2_tokens.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Glass pill entry point to the full SearchScreen.
///
/// The mic icon on the right is an intentional stub — voice search is out of
/// scope for V2 (see plan "Out of scope" section). Tapping it falls back to
/// opening the search screen so the button never feels dead.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeV2Tokens.kHorizontalPad,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: scheme.surface.withValues(alpha: 0.55),
            child: InkWell(
              onTap: () => _openSearch(context),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: fg.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 20, color: fg.withValues(alpha: 0.6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search or post…',
                        style: TextStyle(
                          fontSize: 14,
                          color: fg.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.mic_none_rounded,
                      size: 20,
                      color: fg.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    GuardedNavigator.push(context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }
}
