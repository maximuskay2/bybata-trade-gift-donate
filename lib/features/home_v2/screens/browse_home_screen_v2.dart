import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../conversational/conversational_home_body.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Unauthenticated landing — Gemini-style conversational entry.
class BrowseHomeScreenV2 extends StatelessWidget {
  const BrowseHomeScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      // CRITICAL FIX: Changed to true so layout correctly transitions up with the keyboard
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? const Color(0xFF0D0B12) : Colors.white,
      body: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: _GeminiTopBar(isAuthed: false),
          ),
          const Expanded(
            child: ConversationalHomeBody(isAuthed: false),
          ),
        ],
      ),
    );
  }
}

/// Gemini-style top chrome: menu · Bybata · compose / sign in.
class _GeminiTopBar extends StatelessWidget {
  final bool isAuthed;

  const _GeminiTopBar({required this.isAuthed});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final chipBg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16), // Balanced edge alignments
        child: Row(
          children: [
            _CircleIconButton(
              icon: Icons.menu_rounded,
              onPressed: () {
                HapticFeedback.selectionClick();
              },
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bybata',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: fg,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isAuthed)
              _CircleIconButton(
                icon: Icons.edit_outlined,
                onPressed: () {
                  HapticFeedback.selectionClick();
                },
              )
            else
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  GuardedNavigator.pushNamed(context, AppConstants.loginRoute);
                },
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: const Text('Sign In'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: fg.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}