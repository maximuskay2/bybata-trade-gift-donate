import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_create_orb_button.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../widgets/home_v2_tokens.dart';

/// Centered Gemini-style greeting — a short hello and three starter chips.
/// [hidden] fades it out completely while the input has text.
class ConversationalGreeting extends StatelessWidget {
  final bool isAuthed;
  final double focusProgress;
  final bool hidden;
  final ValueChanged<String>? onFill;

  const ConversationalGreeting({
    super.key,
    required this.isAuthed,
    required this.focusProgress,
    this.hidden = false,
    this.onFill,
  });

  String _timeOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = focusProgress.clamp(0.0, 1.0);
    final opacity = hidden ? 0.0 : 1.0 - (t * 0.25);
    final scale = hidden ? 0.94 : 1.0 - (t * 0.03);
    const duration = Duration(milliseconds: 320);
    const curve = Curves.easeOutCubic;

    final name = isAuthed ? _firstName(context.watch<AuthProvider>()) : '';
    final headline = name.isNotEmpty
        ? 'Good ${_timeOfDay()},\n$name'
        : 'Good ${_timeOfDay()}';

    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedOpacity(
          duration: duration,
          curve: curve,
          opacity: opacity,
          child: AnimatedSlide(
            duration: duration,
            curve: curve,
            offset: hidden ? const Offset(0, -0.04) : Offset.zero,
            child: AnimatedScale(
              duration: duration,
              curve: curve,
              scale: scale,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HomeV2Tokens.kHorizontalPad + 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppCreateOrbButton(),
                    const SizedBox(height: 24),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.15,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StarterChip(
                          label: 'Trade',
                          onTap: onFill == null
                              ? null
                              : () => onFill!('I want to swap something'),
                        ),
                        _StarterChip(
                          label: 'Donate',
                          onTap: onFill == null
                              ? null
                              : () => onFill!('I want to support a fundraiser'),
                        ),
                        _StarterChip(
                          label: 'Gift',
                          onTap: onFill == null
                              ? null
                              : () => onFill!('I need something free'),
                        ),
                      ],
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

  String _firstName(AuthProvider auth) {
    final raw = auth.currentUser?.displayName.trim() ?? '';
    if (raw.isEmpty) return '';
    return raw.split(' ').first;
  }
}

class _StarterChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _StarterChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
