import 'package:flutter/material.dart';

import '../models/gift_models.dart' as gift_models;
import '../widgets/gift_claim_sheet.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

/// Route entry for deep links — shows the same in-context sheet as gift details.
class ClaimGiftScreen extends StatefulWidget {
  final Map<String, dynamic> gift;
  final gift_models.Gift? fullGift;

  const ClaimGiftScreen({
    super.key,
    required this.gift,
    this.fullGift,
  });

  @override
  State<ClaimGiftScreen> createState() => _ClaimGiftScreenState();
}

class _ClaimGiftScreenState extends State<ClaimGiftScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (!mounted) return;
    final result = await showGiftClaimSheet(
      context,
      gift: widget.gift,
      fullGift: widget.fullGift,
    );
    if (!mounted) return;
    await followUpGiftClaimResult(
      context,
      result,
      fullGift: widget.fullGift,
      giftMap: widget.gift,
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F7FA),
      body: const BybataLoader(),
    );
  }
}
