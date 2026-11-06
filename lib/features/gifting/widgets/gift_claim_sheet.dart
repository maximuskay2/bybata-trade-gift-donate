import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/contextual_action_bar.dart';
import '../../chat/models/chat_conversation.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/utils/item_context_chat_message.dart';
import '../models/gift_models.dart' as gift_models;
import '../providers/gift_provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Opens in-context gift request UI (trade-offer style). Returns result map on close.
Future<Map<String, dynamic>?> showGiftClaimSheet(
  BuildContext context, {
  required Map<String, dynamic> gift,
  gift_models.Gift? fullGift,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GiftClaimSheetContent(
      gift: gift,
      fullGift: fullGift,
    ),
  );
}

/// Opens (or resumes) a gifting chat with the giver after a claim request.
Future<bool> openGiftGiverChat(
  BuildContext context,
  gift_models.Gift gift,
) async {
  if (AppRoutes.requireSignIn(context)) return false;

  try {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id;
    if (currentUserId == null || currentUserId == gift.giver.id) {
      return false;
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final conversation = await chatProvider.startDirectMessage(
      recipientId: gift.giver.id,
      recipientName: gift.giver.name,
      initialMessage: ItemContextChatMessage.giftIntroForGiver(gift),
      contextTitle: 'Gift: ${gift.title}',
      contextId: gift.id,
      apiType: 'DIRECT',
    );

    if (!context.mounted || conversation == null) return false;

    if (!context.mounted) return false;
    GuardedNavigator.push(context, 
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: conversation,
          chatType: ChatType.gifting,
        ),
      ),
    );
    return true;
  } catch (e) {
    debugPrint('Gift claim chat error: $e');
    return false;
  }
}

/// After claim sheet closes, open chat when the result requests it.
Future<void> followUpGiftClaimResult(
  BuildContext context,
  Map<String, dynamic>? result, {
  gift_models.Gift? fullGift,
  Map<String, dynamic>? giftMap,
}) async {
  if (result?['success'] != true || result?['openChat'] != true) return;

  gift_models.Gift? gift = fullGift ?? result?['gift'] as gift_models.Gift?;
  if (gift == null && giftMap != null) {
    try {
      gift = gift_models.Gift.fromJson(giftMap);
    } catch (_) {}
  }

  final giftId = gift?.id ?? giftMap?['id']?.toString() ?? '';
  if (gift == null && giftId.isNotEmpty && context.mounted) {
    try {
      gift = await Provider.of<GiftProvider>(context, listen: false).getGift(giftId);
    } catch (_) {}
  }

  if (gift != null && context.mounted) {
    await openGiftGiverChat(context, gift);
  }
}

class GiftClaimSheetContent extends StatefulWidget {
  final Map<String, dynamic> gift;
  final gift_models.Gift? fullGift;

  const GiftClaimSheetContent({
    super.key,
    required this.gift,
    this.fullGift,
  });

  @override
  State<GiftClaimSheetContent> createState() => _GiftClaimSheetContentState();
}

class _ClaimUiEngine {
  static Widget buildContainer({
    required Widget child,
    Color color = Colors.white,
    double radius = 24,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: child,
    );
  }

  static InputDecoration recessedInput(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.primarySurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
}

class _GiftClaimSheetContentState extends State<GiftClaimSheetContent> {
  final _messageController = TextEditingController();
  final _claimCodeController = TextEditingController();

  bool _isClaiming = false;
  bool _isLoadingGift = true;
  String? _errorMessage;
  gift_models.Gift? _fullGift;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.fullGift != null) {
      _fullGift = widget.fullGift;
      _isLoadingGift = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _getCurrentUserId();
      if (widget.fullGift == null) _loadGiftData();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _claimCodeController.dispose();
    super.dispose();
  }

  void _getCurrentUserId() {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (mounted) setState(() => _currentUserId = auth.currentUser?.id);
    } catch (_) {
      if (mounted) setState(() => _currentUserId = null);
    }
  }

  Future<void> _loadGiftData() async {
    final giftId = widget.gift['id']?.toString() ?? '';
    if (giftId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingGift = false;
          _errorMessage = 'Invalid gift ID';
        });
      }
      return;
    }

    setState(() => _isLoadingGift = true);
    try {
      final gift = await Provider.of<GiftProvider>(
        context,
        listen: false,
      ).getGift(giftId);
      if (mounted) {
        setState(() {
          _fullGift = gift;
          _isLoadingGift = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGift = false;
          _errorMessage = 'Failed to load gift: $e';
        });
      }
    }
  }

  bool get _isOwner =>
      _fullGift != null &&
      _currentUserId != null &&
      _fullGift!.giver.id == _currentUserId;

  bool get _isTargetedForSomeoneElse {
    final gift = _fullGift;
    if (gift == null || _currentUserId == null) return false;
    if (gift.type != gift_models.GiftType.targeted) return false;
    final target = gift.targetUserId;
    return target != null && target.isNotEmpty && target != _currentUserId;
  }

  bool get _canClaim {
    if (_isOwner || _isTargetedForSomeoneElse) return false;
    if (_fullGift == null) return false;
    if (!_fullGift!.isAvailable) return false;
    if (_fullGift!.minimumKarmaLevel != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final points = auth.currentUser?.karmaPoints ?? 0;
      if (points < _fullGift!.minimumKarmaLevel!.requiredPoints) return false;
    }
    return true;
  }

  /// Claim code when: metadata requires it, open targeted gift, or surprise gift.
  bool get _needsClaimCode {
    final gift = _fullGift;
    if (gift == null) return false;
    final meta = gift.metadata;
    if (meta['requiresClaimCode'] == true || meta['claimCodeRequired'] == true) {
      return true;
    }
    if (meta['claimCode'] != null && meta['claimCode'].toString().isNotEmpty) {
      return true;
    }
    if (gift.isSurpriseGift) return true;
    if (gift.type == gift_models.GiftType.targeted && gift.targetUserId == null) {
      return true;
    }
    return false;
  }

  String _typeApprovalNote(gift_models.Gift gift) {
    switch (gift.type) {
      case gift_models.GiftType.random:
        return 'Open gift — the giver reviews requests and approves one recipient.';
      case gift_models.GiftType.targeted:
        if (gift.targetUserId != null) {
          return 'Reserved gift — the giver confirms your request before it is yours.';
        }
        return 'Targeted gift — use a claim code if you have one. The giver approves requests.';
      case gift_models.GiftType.skill:
        return 'Skill gift — describe how you can use it. The giver approves your request.';
      case gift_models.GiftType.experience:
        return 'Experience gift — mention availability in your message. Approval required.';
      case gift_models.GiftType.digital:
        return 'Digital gift — the giver approves before access is granted.';
    }
  }

  Future<void> _handleClaimGift() async {
    if (!_canClaim) {
      setState(() => _errorMessage = _blockedReason());
      return;
    }

    if (_needsClaimCode && _claimCodeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter the claim code for this gift.');
      return;
    }

    final giftId = widget.gift['id']?.toString() ?? _fullGift?.id ?? '';
    if (giftId.isEmpty) {
      setState(() => _errorMessage = 'Invalid gift ID');
      return;
    }

    setState(() {
      _isClaiming = true;
      _errorMessage = null;
    });

    try {
      final giftProvider = Provider.of<GiftProvider>(context, listen: false);
      if (AppRoutes.requireSignIn(context)) {
        setState(() => _isClaiming = false);
        return;
      }
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = auth.currentUser!;

      final displayName = currentUser.displayName.isNotEmpty
          ? currentUser.displayName
          : currentUser.email;
      final requester = gift_models.GiftUser(
        id: currentUser.id,
        name: displayName,
        username: '@${displayName.replaceAll(' ', '').toLowerCase()}',
        rating: currentUser.rating,
        completedGifts: 0,
        karmaPoints: currentUser.karmaPoints,
        joinedDate: currentUser.createdAt,
        isVerified: currentUser.isVerified,
      );

      final request = await giftProvider.claimGift(
        giftId,
        claimCode: _claimCodeController.text.trim().isNotEmpty
            ? _claimCodeController.text.trim()
            : null,
        requester: requester,
        message: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (request != null) {
        var message = 'Request sent. Waiting for the giver to approve.';
        if (_fullGift?.isChainGift == true) {
          message +=
              ' This is a gift chain — after approval, check Gift History to Pay it Forward.';
        }
        Navigator.of(context).pop({
          'success': true,
          'message': message,
          'requestId': request.id,
          'openChat': true,
          if (_fullGift != null) 'gift': _fullGift,
        });
      } else {
        setState(() {
          _errorMessage = giftProvider.error ?? 'Failed to send request';
          _isClaiming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isClaiming = false;
        });
      }
    }
  }

  String _blockedReason() {
    if (_isOwner) return 'You cannot request your own gift.';
    if (_isTargetedForSomeoneElse) {
      return 'This gift is reserved for someone else.';
    }
    final gift = _fullGift;
    if (gift == null) return 'This gift is not available.';
    if (gift.status == gift_models.GiftStatus.claimed) {
      return 'This gift has already been claimed.';
    }
    if (gift.status == gift_models.GiftStatus.expired || gift.isExpired) {
      return 'This gift has expired.';
    }
    if (gift.minimumKarmaLevel != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final points = auth.currentUser?.karmaPoints ?? 0;
      if (points < gift.minimumKarmaLevel!.requiredPoints) {
        return 'You need ${gift.minimumKarmaLevel!.requiredPoints} karma (you have $points).';
      }
    }
    return 'This gift is not available for requests right now.';
  }

  Future<void> _openChatWithGiver() async {
    final gift = _fullGift;
    if (gift == null || _currentUserId == null || _isOwner) return;
    await openGiftGiverChat(context, gift);
  }

  @override
  Widget build(BuildContext context) {
    final title = _fullGift?.title ?? widget.gift['title']?.toString() ?? 'Gift';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request gift',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_fullGift != null && !_isOwner)
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: _openChatWithGiver,
                      tooltip: 'Message giver',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _isLoadingGift
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: const BybataLoader(),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_canClaim)
                            _buildBlocked()
                          else ...[
                            _buildBeforeYouSend(),
                            if (_needsClaimCode) ...[
                              const SizedBox(height: 20),
                              _buildClaimCodeField(),
                            ],
                            const SizedBox(height: 20),
                            _buildMessageField(),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _buildError(),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
            if (_canClaim && !_isLoadingGift)
              ContextualActionBar(
                actions: [
                  ContextualAction(
                    label: 'Cancel',
                    icon: Icons.close_rounded,
                    onPressed: _isClaiming
                        ? null
                        : () => Navigator.pop(context),
                  ),
                  ContextualAction(
                    label: 'Send request',
                    icon: Icons.send_rounded,
                    isPrimary: true,
                    flex: 2,
                    onPressed: _isClaiming ? null : _handleClaimGift,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeforeYouSend() {
    final gift = _fullGift!;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userKarma = auth.currentUser?.karmaPoints ?? 0;
    final spotsLeft = gift.maxClaims - gift.currentClaims;
    final expiry = gift.expiresAt != null ? gift.timeRemaining : null;

    return _ClaimUiEngine.buildContainer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before you send',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _typeApprovalNote(gift),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _infoLine('Approval', 'Required from giver'),
            _infoLine('Karma reward', '+${gift.karmaReward}'),
            _infoLine(
              'Spots left',
              '$spotsLeft of ${gift.maxClaims}',
            ),
            if (expiry != null && expiry.isNotEmpty)
              _infoLine('Expires', expiry),
            if (gift.minimumKarmaLevel != null) ...[
              _infoLine(
                'Min karma',
                '${gift.minimumKarmaLevel!.requiredPoints} (${gift.minimumKarmaLevel!.label})',
              ),
              _infoLine(
                'Your karma',
                '$userKarma ${userKarma >= gift.minimumKarmaLevel!.requiredPoints ? '✓' : '— too low'}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text('Claim code', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        _ClaimUiEngine.buildContainer(
          radius: 20,
          child: TextField(
            controller: _claimCodeController,
            decoration: _ClaimUiEngine.recessedInput('Enter claim code'),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'Propose your terms',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _ClaimUiEngine.buildContainer(
          radius: 20,
          child: TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add a friendly message (optional)...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlocked() {
    return _ClaimUiEngine.buildContainer(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          _errorMessage ?? _blockedReason(),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[800], height: 1.4),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
