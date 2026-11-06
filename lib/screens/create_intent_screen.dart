import 'package:flutter/material.dart';
import '../core/navigation/app_routes.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class CreateIntentScreen extends StatelessWidget {
  const CreateIntentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')), 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What would you like to create?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Offer section
            const Text('Offer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _IntentCard(
                    title: 'Trade',
                    icon: Icons.swap_horiz,
                    onTap: () => AppRoutes.navigateToCreateTrade(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IntentCard(
                    title: 'Give',
                    icon: Icons.card_giftcard,
                    onTap: () => AppRoutes.navigateToCreateGift(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Ask section
            const Text('Ask', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _IntentCard(
                    title: 'Request',
                    icon: Icons.help_outline,
                    onTap: () => GuardedNavigator.pushNamed(context, '/create-request'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IntentCard(
                    title: 'Help Campaign',
                    icon: Icons.campaign,
                    onTap: () => AppRoutes.navigateToCreateCampaign(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _IntentCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
