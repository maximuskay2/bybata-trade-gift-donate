import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/compliance/ios_campaign_support.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/share_utils.dart';
import '../models/donation_models.dart';

class DonationActionsSheet extends StatelessWidget {
  final Campaign campaign;

  const DonationActionsSheet({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    final creatorId = campaign.creator.id;
    final isOwner = currentUserId != null && currentUserId == creatorId;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            campaign.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                label: 'Raised',
                value: campaign.formattedRaised,
                color: Colors.orange,
              ),
              _StatChip(
                label: 'Supporters',
                value: '${campaign.supportersCount}',
                color: AppColors.primary,
              ),
              _StatChip(
                label: 'Location',
                value: campaign.location,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOwner ? Colors.orange : Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (isOwner) {
                      AppRoutes.navigateToCampaignManagement(context, campaign);
                    } else {
                      CampaignSupportCompliance.handleSupportTap(
                        context,
                        campaign: campaign,
                      );
                    }
                  },
                  child: Text(
                    isOwner
                        ? 'Edit'
                        : CampaignSupportCompliance.hubDonateLabel(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    AppRoutes.navigateToCampaignDetails(context, campaign);
                  },
                  child: const Text('Details'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  ShareUtils.shareCampaign(
                    context,
                    id: campaign.id.toString(),
                    title: campaign.title,
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                splashRadius: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
