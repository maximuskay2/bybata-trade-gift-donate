import 'package:flutter/material.dart';

/// Compact step progress for listing create flows.
class EnhancedStepper extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<StepConfig> steps;
  final Color primaryColor;
  final bool isDark;

  const EnhancedStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.steps,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercent = ((currentStep + 1) / totalSteps * 100).toInt();
    final step = steps[currentStep.clamp(0, steps.length - 1)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i <= currentStep
                            ? primaryColor
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                _StepDot(
                  index: i,
                  currentStep: currentStep,
                  icon: steps[i].icon,
                  accent: primaryColor,
                  isDark: isDark,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${currentStep + 1} of $totalSteps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: primaryColor.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (step.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          step.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.12),
                  border: Border.all(color: primaryColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final int currentStep;
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _StepDot({
    required this.index,
    required this.currentStep,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final done = index < currentStep;
    final active = index == currentStep;
    final color = done || active
        ? accent
        : (isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.18));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 36 : 30,
      height: active ? 36 : 30,
      decoration: BoxDecoration(
        color: done || active
            ? accent.withValues(alpha: active ? 1 : 0.85)
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: active ? 0 : 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: active ? 16 : 14,
        color: done || active
            ? Colors.white
            : (isDark ? Colors.grey[500] : Colors.grey[600]),
      ),
    );
  }
}

class StepConfig {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool isOptional;

  StepConfig({
    required this.title,
    this.subtitle,
    required this.icon,
    this.isOptional = false,
  });
}
