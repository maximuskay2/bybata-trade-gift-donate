import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/karma/karma_membership_utils.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/screens/verification_screen.dart';
import '../navigation/karma_navigator.dart';
import '../services/karma_service.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Trust & KARMA tiers — simple overview with verification shortcuts.
class TrustLevelScreen extends StatefulWidget {
  const TrustLevelScreen({super.key});

  @override
  State<TrustLevelScreen> createState() => _TrustLevelScreenState();
}

class _TrustLevelScreenState extends State<TrustLevelScreen> {
  KarmaMembershipInfo? _membership;
  int _karmaPoints = 0;
  bool _loading = true;
  String? _error;

  bool _emailDone = false;
  bool _phoneDone = false;
  bool _identityDone = false;
  String _kycStatus = 'NOT_VERIFIED';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final karma = context.read<KarmaService>();
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id ?? karma.currentUserKarma?.userId;
      if (userId != null) {
        await karma.refresh(userId);
      }

      final raw = await karma.fetchKarmaAccountFromApi();
      _karmaPoints = karma.currentUserKarma?.totalPoints ??
          (raw?['currentPoints'] as num?)?.toInt() ??
          0;

      KarmaMembershipInfo? membership;
      if (raw != null) {
        membership = KarmaMembershipInfo.fromKarmaJson(raw);
      } else {
        membership = KarmaMembershipInfo.fromTier('NEWCOMER', _karmaPoints);
      }

      await _loadVerificationFlags();

      if (!mounted) return;
      setState(() {
        _membership = membership;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load trust data. Pull to refresh.';
        _loading = false;
      });
    }
  }

  Future<void> _loadVerificationFlags() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, const FlutterSecureStorage());
      final res = await api.dio.get('/v1/users/me');
      final data = res.data as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      final kyc = (profile['kycStatus'] as String?)?.toUpperCase() ?? 'NOT_VERIFIED';
      final verified = kyc == 'VERIFIED';
      final emailVerifiedAt = data['emailVerifiedAt'];
      final phone = profile['phone'] as String?;

      if (mounted) {
        setState(() {
          _kycStatus = kyc;
          _emailDone = emailVerifiedAt != null || verified;
          _phoneDone = verified || (phone?.isNotEmpty == true && kyc == 'VERIFIED');
          _identityDone = verified || kyc == 'PENDING';
        });
      }
    } catch (_) {
      // Non-fatal — tier data still shown
    }
  }

  int get _verifyStepsDone =>
      [_emailDone, _phoneDone, _identityDone].where((x) => x).length;

  Future<void> _openVerification() async {
    try {
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, const FlutterSecureStorage());
      final res = await api.dio.get('/v1/users/me');
      final data = res.data as Map<String, dynamic>;
      final profileData = data['profile'] as Map<String, dynamic>? ?? {};
      final displayName = profileData['displayName'] as String? ?? 'User';
      final parts = displayName.split(' ');
      final userProfile = UserProfile(
        id: data['id']?.toString() ?? '',
        firstName: parts.isNotEmpty ? parts.first : 'User',
        lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
        email: data['email']?.toString() ?? '',
        phone: profileData['phone'] as String?,
        avatar: profileData['avatarKey'] as String?,
        bio: profileData['bio'] as String?,
        location: null,
        dateOfBirth: null,
        occupation: null,
        interests: const [],
        stats: ProfileStats(
          totalTrades: 0,
          successfulTrades: 0,
          totalGifts: 0,
          totalDonations: 0,
          totalCommunities: 0,
          totalFollowers: 0,
          totalFollowing: 0,
          totalPosts: 0,
          totalLikes: 0,
          averageRating: 0,
          totalReviews: 0,
        ),
        trustScore: TrustScore(
          score: 0,
          level: 0,
          badges: [],
          lastUpdated: DateTime.now(),
        ),
        verification: VerificationStatus.fromKycStatus(
          profileData['kycStatus'] as String?,
          rejectionReason: profileData['kycNote'] as String?,
        ),
        settings: ProfileSettings(),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
      if (!mounted) return;
      await GuardedNavigator.push(context,
        MaterialPageRoute(
          builder: (_) => VerificationScreen(userProfile: userProfile),
        ),
      );
      await _loadVerificationFlags();
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not open verification: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = _membership ?? KarmaMembershipInfo.fromTier('NEWCOMER', _karmaPoints);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Trust & KARMA'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How it works',
            onPressed: () => _showHelpSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  const BybataLoader(),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: TextStyle(color: scheme.error)),
                    ),
                  _buildHeroCard(context, m, scheme),
                  const SizedBox(height: 20),
                  _buildTierLadder(context, m, scheme),
                  const SizedBox(height: 20),
                  _buildVerificationSection(context, scheme),
                  const SizedBox(height: 20),
                  _buildPerksSection(m, scheme),
                  const SizedBox(height: 24),
                  _buildActions(context, m),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    KarmaMembershipInfo m,
    ColorScheme scheme,
  ) {
    final style = tierStyle(m.tier);
    final progress = karmaTierProgress(_karmaPoints);
    final next = m.nextTierLabel;

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: style.$1.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(style.$2, color: style.$1, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your level',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (m.isPremium)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Premium member',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_karmaPoints KARMA',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                ),
                if (next != null)
                  Text(
                    '${m.pointsToNextTier} to $next',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: style.$1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Earn KARMA by trading, gifting, and helping others. Higher tiers unlock more features.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierLadder(
    BuildContext context,
    KarmaMembershipInfo m,
    ColorScheme scheme,
  ) {
    final currentIdx = karmaTierIndex(m.tier);

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KARMA tiers',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Everyone starts at Newcomer. Keep earning points to level up.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            ...karmaTierLadder.asMap().entries.map((e) {
              final step = e.value;
              final idx = e.key;
              final reached = idx <= currentIdx;
              final isCurrent = idx == currentIdx;
              final style = tierStyle(step.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: reached
                            ? style.$1.withValues(alpha: 0.15)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: isCurrent
                            ? Border.all(color: style.$1, width: 2)
                            : null,
                      ),
                      child: Icon(
                        reached ? Icons.check_rounded : style.$2,
                        size: 18,
                        color: reached
                            ? style.$1
                            : scheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                step.label,
                                style: TextStyle(
                                  fontWeight: isCurrent
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 14,
                                  color: reached
                                      ? scheme.onSurface
                                      : scheme.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            step.minPoints == 0
                                ? 'Starting tier'
                                : '${step.minPoints}+ points',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationSection(BuildContext context, ColorScheme scheme) {
    final statusLabel = switch (_kycStatus) {
      'VERIFIED' => 'Verified',
      'PENDING' => 'Under review',
      'REJECTED' => 'Needs update',
      _ => 'Not started',
    };
    final statusColor = switch (_kycStatus) {
      'VERIFIED' => AppTheme.successColor,
      'PENDING' => AppTheme.karmaColor,
      'REJECTED' => scheme.error,
      _ => scheme.onSurface.withValues(alpha: 0.5),
    };

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Account verification',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$_verifyStepsDone of 3 steps complete · builds trust with other members',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            _verifyRow(
              scheme,
              icon: Icons.mail_outline_rounded,
              title: 'Email',
              done: _emailDone,
              subtitle: _emailDone ? 'Confirmed' : 'Verify your email',
            ),
            const SizedBox(height: 10),
            _verifyRow(
              scheme,
              icon: Icons.phone_android_rounded,
              title: 'Phone',
              done: _phoneDone,
              subtitle: _phoneDone ? 'Confirmed' : 'Add & verify phone',
            ),
            const SizedBox(height: 10),
            _verifyRow(
              scheme,
              icon: Icons.badge_outlined,
              title: 'Identity',
              done: _identityDone,
              subtitle: _identityDone
                  ? (_kycStatus == 'PENDING' ? 'Documents submitted' : 'Verified')
                  : 'Upload government ID',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openVerification,
                icon: const Icon(Icons.verified_user_outlined, size: 20),
                label: Text(
                  _kycStatus == 'VERIFIED'
                      ? 'View verification'
                      : 'Continue verification',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifyRow(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool done,
  }) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : icon,
          color: done ? AppTheme.successColor : scheme.onSurface.withValues(alpha: 0.45),
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerksSection(KarmaMembershipInfo m, ColorScheme scheme) {
    const allPerks = [
      (100, 'Premium trade filters'),
      (150, 'Gift scheduling'),
      (200, 'Exclusive communities'),
      (250, 'Higher trading limits'),
      (600, 'Priority support'),
    ];

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlocked at your level',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            ...allPerks.map((p) {
              final on = _karmaPoints >= p.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      on ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                      size: 20,
                      color: on
                          ? AppTheme.successColor
                          : scheme.onSurface.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.$2,
                        style: TextStyle(
                          fontSize: 14,
                          color: on
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    Text(
                      '${p.$1}+',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, KarmaMembershipInfo m) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => KarmaNavigator.toEarnKarma(context),
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('Earn KARMA points'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (!m.isPremium) ...[
          const SizedBox(height: 10),
          Text(
            'Reach Gold (5,000 points) for Premium benefits',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }

  void _showHelpSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How trust works',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _helpLine(scheme, 'KARMA tiers unlock automatically as you earn points.'),
            _helpLine(scheme, 'Verify your account so others know you\'re real.'),
            _helpLine(scheme, 'Trade fairly, gift generously, and stay active in the community.'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpLine(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
