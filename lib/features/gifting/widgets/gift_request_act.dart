import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion/stage_glass_field.dart';
import '../models/gift_models.dart';

class GiftRequestDraft {
  final TextEditingController note = TextEditingController();
  final TextEditingController code = TextEditingController();

  void clear() {
    note.clear();
    code.clear();
  }

  void dispose() {
    note.dispose();
    code.dispose();
  }
}

bool giftNeedsClaimCode(Gift gift) {
  final meta = gift.metadata;
  if (meta['requiresClaimCode'] == true || meta['claimCodeRequired'] == true) {
    return true;
  }
  if (meta['claimCode'] != null && meta['claimCode'].toString().isNotEmpty) {
    return true;
  }
  if (gift.isSurpriseGift) return true;
  if (gift.type == GiftType.targeted && gift.targetUserId == null) return true;
  return false;
}

class GiftRequestAct extends StatelessWidget {
  final Gift? gift;
  final GiftRequestDraft draft;

  const GiftRequestAct({super.key, required this.gift, required this.draft});

  @override
  Widget build(BuildContext context) {
    final needsCode = gift != null && giftNeedsClaimCode(gift!);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageStaggerIn(
          index: 0,
          child: Text(
            'Ask for this gift',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),
        StageStaggerIn(
          index: 1,
          child: StageGlassField(
            fieldKey: const Key('gift-request-note'),
            controller: draft.note,
            hint: 'Add a note for the giver',
            minLines: 2,
            maxLines: 4,
          ),
        ),
        AnimatedSize(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 80 : 320,
          ),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: needsCode
              ? StageStaggerIn(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Claim code',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StageGlassField(
                          controller: draft.code,
                          hint: 'Enter the code',
                          dense: true,
                          keyboardType: TextInputType.visiblePassword,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9\-]'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
