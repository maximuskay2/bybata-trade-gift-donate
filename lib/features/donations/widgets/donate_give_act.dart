import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/motion/stage_glass_field.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/utils/haptic_utils.dart';
import '../models/donation_models.dart';

/// Amounts already used by [DonationBottomSheet].
const List<double> donateAmountRail = <double>[10, 25, 50, 100, 250, 500];

class DonateDraft extends ChangeNotifier {
  double? amount;
  bool anonymous = false;
  String? tierId;
  String label = '';
  final TextEditingController note = TextEditingController();
  final TextEditingController custom = TextEditingController();

  void select(double value) {
    amount = value;
    label = '\$${value.toStringAsFixed(0)}';
    if (!donateAmountRail.contains(value)) {
      custom.text = value.toStringAsFixed(0);
    }
    notifyListeners();
  }

  void setAnonymous(bool value) {
    anonymous = value;
    notifyListeners();
  }

  void setTier(String? id) {
    tierId = id;
    notifyListeners();
  }

  void clear() {
    amount = null;
    anonymous = false;
    tierId = null;
    label = '';
    note.clear();
    custom.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    note.dispose();
    custom.dispose();
    super.dispose();
  }
}

class DonateAmountRail extends StatelessWidget {
  final DonateDraft draft;

  const DonateAmountRail({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (var i = 0; i < donateAmountRail.length; i++)
              StageStaggerIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _AmountChip(
                    amount: donateAmountRail[i],
                    selected: draft.amount == donateAmountRail[i],
                    reduce: reduce,
                    onTap: () {
                      HapticUtils.selection();
                      draft.select(donateAmountRail[i]);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AmountChip extends StatelessWidget {
  final double amount;
  final bool selected;
  final bool reduce;
  final VoidCallback onTap;

  const _AmountChip({
    required this.amount,
    required this.selected,
    required this.reduce,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.06 : 1.0,
      duration: Duration(milliseconds: reduce ? 80 : 240),
      curve: Curves.easeOutBack,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        elevation: selected ? 2 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 40,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: reduce ? 80 : 200),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: selected ? Colors.black : Colors.white,
                ),
                child: Text('\$${amount.toStringAsFixed(0)}'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DonateGiveFields extends StatefulWidget {
  final Campaign campaign;
  final DonateDraft draft;

  const DonateGiveFields({
    super.key,
    required this.campaign,
    required this.draft,
  });

  @override
  State<DonateGiveFields> createState() => _DonateGiveFieldsState();
}

class _DonateGiveFieldsState extends State<DonateGiveFields> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WalletProvider>().refreshWallet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<WalletProvider>().bycBalance;
    final draft = widget.draft;
    final tiers = widget.campaign.rewardTiers.where((tier) => tier.isAvailable);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.55);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StageStaggerIn(
              index: 0,
              child: AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: reduce ? 80 : 240),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                child: Text('Balance ${balance.toStringAsFixed(0)} BYC'),
              ),
            ),
            const SizedBox(height: 10),
            StageStaggerIn(
              index: 1,
              child: StageGlassField(
                controller: draft.custom,
                hint: 'Custom amount',
                dense: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null && parsed > 0) draft.select(parsed);
                },
              ),
            ),
            const SizedBox(height: 8),
            StageStaggerIn(
              index: 2,
              child: StageGlassField(
                controller: draft.note,
                hint: 'Note',
                dense: true,
              ),
            ),
            const SizedBox(height: 10),
            StageStaggerIn(
              index: 3,
              child: _AnonymousToggle(
                value: draft.anonymous,
                onChanged: (value) {
                  HapticUtils.selection();
                  draft.setAnonymous(value);
                },
                muted: muted,
                isDark: isDark,
                reduce: reduce,
              ),
            ),
            if (tiers.isNotEmpty) ...[
              const SizedBox(height: 10),
              StageStaggerIn(
                index: 4,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tier in tiers)
                      _TierChip(
                        title: tier.title,
                        selected: draft.tierId == tier.id,
                        reduce: reduce,
                        onTap: () {
                          HapticUtils.selection();
                          draft.setTier(
                            draft.tierId == tier.id ? null : tier.id,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AnonymousToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color muted;
  final bool isDark;
  final bool reduce;

  const _AnonymousToggle({
    required this.value,
    required this.onChanged,
    required this.muted,
    required this.isDark,
    required this.reduce,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduce ? 80 : 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.08))
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: value
                ? (isDark ? Colors.white54 : Colors.black26)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 16,
              color: muted,
            ),
            const SizedBox(width: 8),
            Text(
              value ? 'Giving anonymously' : 'Show my name',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String title;
  final bool selected;
  final bool reduce;
  final VoidCallback onTap;

  const _TierChip({
    required this.title,
    required this.selected,
    required this.reduce,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedScale(
      scale: selected ? 1.04 : 1.0,
      duration: Duration(milliseconds: reduce ? 80 : 220),
      curve: Curves.easeOutBack,
      child: Material(
        color: selected
            ? (isDark ? Colors.white : Colors.black)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
