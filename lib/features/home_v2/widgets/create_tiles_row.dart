import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import 'home_v2_tokens.dart';

/// "What do you want to do today?" — the three primary creation surfaces.
///
/// Three equal-width cards, each tappable. Auth gating is delegated to
/// [AppRoutes.navigateToCreate*] — unauthenticated taps trigger the
/// shared Sign-In dialog (same UX as everywhere else in the app).
class CreateTilesRow extends StatelessWidget {
  const CreateTilesRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeV2Tokens.kHorizontalPad,
        6,
        HomeV2Tokens.kHorizontalPad,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you want to do today?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Trade',
                  icon: Icons.swap_horiz_rounded,
                  color: AppTheme.tradeColor,
                  onTap: () => AppRoutes.navigateToCreateTrade(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  label: 'Gift',
                  icon: Icons.card_giftcard_rounded,
                  color: AppTheme.giftColor,
                  onTap: () => AppRoutes.navigateToCreateGift(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  label: 'Donate',
                  icon: Icons.volunteer_activism_rounded,
                  color: AppTheme.donationColor,
                  onTap: () => AppRoutes.navigateToCreateCampaign(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _Tile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeV2Tokens.kCardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
