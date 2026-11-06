import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/widgets/app_toast.dart';
import '../services/referral_api_service.dart';

/// Card for sharing referral link with copy, share, and QR options.
class ReferralShareCard extends StatefulWidget {
  final ReferralStats stats;

  const ReferralShareCard({super.key, required this.stats});

  @override
  State<ReferralShareCard> createState() => _ReferralShareCardState();
}

class _ReferralShareCardState extends State<ReferralShareCard> {
  bool _showQr = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = scheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'Invite Friends & Earn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share your code or link. Earn KARMA + BYC when friends join and complete actions.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Code + Link row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your code',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.stats.referralCode,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _copyCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: primaryColor,
                  onTap: _share,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: _showQr ? Icons.link_rounded : Icons.qr_code_rounded,
                  label: _showQr ? 'Hide QR' : 'QR Code',
                  color: AppTheme.karmaColor,
                  onTap: () => setState(() => _showQr = !_showQr),
                ),
              ),
            ],
          ),
          if (_showQr) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: widget.stats.referralLink,
                  version: QrVersions.auto,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                value: '${widget.stats.totalReferrals}',
                label: 'Referrals',
                color: primaryColor,
              ),
              _StatChip(
                value: '${widget.stats.totalKarmaEarned}',
                label: 'KARMA earned',
                color: AppTheme.karmaColor,
              ),
              _StatChip(
                value: widget.stats.totalBycEarned.toStringAsFixed(0),
                label: 'BYC earned',
                color: AppTheme.tradeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.stats.referralCode));
    AppToast.success(context, 'Code copied');
  }

  void _share() {
    ShareUtils.shareReferral(
      context,
      referralLink: widget.stats.referralLink,
      referralCode: widget.stats.referralCode,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatChip({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
