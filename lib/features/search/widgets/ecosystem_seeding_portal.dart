import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/listing_seeding_context.dart';
import '../../../core/theme/app_theme.dart';

/// Shown when geo-cascaded browse returns zero listings — invites first listings.
class EcosystemSeedingPortal extends StatelessWidget {
  const EcosystemSeedingPortal({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final karma = AppConstants.karmaPoints;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Your community is wide open!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Be the first to establish this hub by uploading a trade or gift listing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 24),
          _SeedingActionCard(
            icon: Icons.swap_horiz_rounded,
            color: AppTheme.tradeColor,
            title: 'Post a Trade',
            subtitle: 'Start the local swap economy',
            karmaBadge: '+50 $karma Seeding Bonus',
            onTap: () {
              if (AppRoutes.requireSignIn(context)) return;
              ListingSeedingContext.markTradeSeed();
              AppRoutes.navigateToCreateTrade(context);
            },
          ),
          const SizedBox(height: 12),
          _SeedingActionCard(
            icon: Icons.card_giftcard_rounded,
            color: AppTheme.giftColor,
            title: 'Give a Gift',
            subtitle: 'Kick-start kindness in your area',
            karmaBadge: '+50 $karma Seeding Bonus',
            onTap: () {
              if (AppRoutes.requireSignIn(context)) return;
              ListingSeedingContext.markGiftSeed();
              AppRoutes.navigateToCreateGift(context);
            },
          ),
        ],
      ),
    );
  }
}

class _SeedingActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String karmaBadge;
  final VoidCallback onTap;

  const _SeedingActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.karmaBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.karmaColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        karmaBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.karmaColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.north_east_rounded,
                color: scheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
