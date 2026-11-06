import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/reply_preview.dart';
import '../../services/chat_media_helper.dart';
import '../../services/chat_moderation_service.dart';
import '../chat_safety_banner.dart';
import 'emoji_picker_sheet.dart';
import 'quoted_reply_card.dart';
import 'voice_recorder_overlay.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// WhatsApp-inspired composer.
///
/// Layout:
///   [ GlassPill (emoji | text | attach | camera) ] [ Circular FAB ]
///
/// The FAB morphs between mic / send / stop. Holding the mic starts voice
/// recording; while held, dragging LEFT past `_kCancelThreshold` arms cancel,
/// and dragging UP past `_kLockThreshold` locks recording so the user can
/// release the FAB and keep recording (WhatsApp pattern).
class ChatInputV2 extends StatefulWidget {
  final String conversationId;
  final TextEditingController controller;

  /// Called when the user taps Send with non-empty text.
  /// Return `true` on success so the field stays cleared; `false` restores text.
  final Future<bool> Function(String text, ReplyPreview? replyTo) onSendText;

  /// Active reply target, rendered as a quoted card above the field.
  final ReplyPreview? replyPreview;

  /// Called when the user dismisses the reply card.
  final VoidCallback? onCancelReply;

  /// Called after a send so the host can scroll the list to the bottom.
  final VoidCallback onScrollToBottom;

  /// Called on every text change — the host wires this to typing indicators.
  final ValueChanged<String>? onTyping;

  /// Accent tint for the circular FAB; falls back to the theme primary color.
  final Color? moduleColor;

  final String hintText;

  const ChatInputV2({
    super.key,
    required this.conversationId,
    required this.controller,
    required this.onSendText,
    required this.onScrollToBottom,
    this.replyPreview,
    this.onCancelReply,
    this.onTyping,
    this.moduleColor,
    this.hintText = 'Type a message...',
  });

  @override
  State<ChatInputV2> createState() => _ChatInputV2State();
}

class _ChatInputV2State extends State<ChatInputV2> {
  static const double _kCancelThreshold = 110.0; // horizontal drag (px)
  static const double _kLockThreshold = 70.0; // upward drag (px)

  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _leakWarningVisible = false;

  // Voice recording state
  bool _isRecording = false;
  bool _isLocked = false;
  DateTime? _recordingStartedAt;
  double _slideCancelProgress = 0.0;
  double _lockProgress = 0.0;
  bool _cancelArmed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reply bar / cancel reply changes composer height — keep latest visible.
    if (oldWidget.replyPreview != widget.replyPreview) {
      widget.onScrollToBottom();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Keyboard opening shrinks the list — pin to latest like WhatsApp.
      widget.onScrollToBottom();
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted && _focusNode.hasFocus) {
          widget.onScrollToBottom();
        }
      });
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final has = text.trim().isNotEmpty;
    final leak = ChatModerationService.evaluateMessageSecurity(text);
    final leakAppeared = leak && !_leakWarningVisible;
    if (has != _hasText || leak != _leakWarningVisible) {
      setState(() {
        _hasText = has;
        _leakWarningVisible = leak;
      });
    }
    // Safety banner adds height above the field — keep latest bubble visible.
    if (leakAppeared) widget.onScrollToBottom();
    widget.onTyping?.call(text);
  }

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    if (ChatModerationService.evaluateMessageSecurity(text)) {
      final ok = await ChatModerationService.confirmInAppEscrow(context);
      if (!ok || !mounted) return;
    }

    HapticFeedback.lightImpact();
    final reply = widget.replyPreview;
    widget.controller.clear();
    final sent = await widget.onSendText(text, reply);
    if (!sent && mounted) {
      widget.controller.text = text;
      widget.controller.selection = TextSelection.collapsed(offset: text.length);
      AppToast.show(context, 'Couldn\'t send message. Please try again.');
    }
  }

  // --- Voice recording lifecycle -------------------------------------------

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    final ok = await ChatMediaHelper.startVoiceRecording();
    if (!mounted) return;
    if (!ok) {
      AppToast.show(context, 'Microphone permission required');
      return;
    }
    setState(() {
      _isRecording = true;
      _isLocked = false;
      _recordingStartedAt = DateTime.now();
      _slideCancelProgress = 0.0;
      _lockProgress = 0.0;
      _cancelArmed = false;
    });
  }

  Future<void> _stopAndPreviewRecording() async {
    final startedAt = _recordingStartedAt;
    final path = await ChatMediaHelper.stopVoiceRecording();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _recordingStartedAt = null;
      _slideCancelProgress = 0.0;
      _lockProgress = 0.0;
      _cancelArmed = false;
    });
    if (path == null) return;
    final secs = startedAt == null
        ? 1
        : DateTime.now().difference(startedAt).inSeconds.clamp(1, 300);
    await ChatMediaHelper.showVoiceNotePreviewBeforeSend(
      context,
      path: path,
      conversationId: widget.conversationId,
      durationSeconds: secs,
      onScrollToBottom: widget.onScrollToBottom,
    );
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    await ChatMediaHelper.stopVoiceRecording();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _recordingStartedAt = null;
      _slideCancelProgress = 0.0;
      _lockProgress = 0.0;
      _cancelArmed = false;
    });
  }

  // --- Gesture handlers ----------------------------------------------------

  void _onLongPressStart(LongPressStartDetails _) {
    _startRecording();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (!_isRecording || _isLocked) return;
    final dx = d.localOffsetFromOrigin.dx;
    final dy = d.localOffsetFromOrigin.dy;
    final cancel = (-dx / _kCancelThreshold).clamp(0.0, 1.0);
    final lock = (-dy / _kLockThreshold).clamp(0.0, 1.0);
    setState(() {
      _slideCancelProgress = cancel;
      _lockProgress = lock;
      _cancelArmed = cancel >= 1.0;
    });
    if (lock >= 1.0 && !_isLocked) {
      HapticFeedback.mediumImpact();
      setState(() => _isLocked = true);
    }
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    if (!_isRecording) return;
    if (_isLocked) return; // stays recording; user taps stop explicitly
    if (_cancelArmed) {
      _cancelRecording();
    } else {
      _stopAndPreviewRecording();
    }
  }

  /// Quick tap on the mic FAB (no text yet). Users often tap instead of
  /// long-press on first encounter, so we surface a brief hint telling them
  /// the recording gesture instead of doing nothing.
  void _onMicTap() {
    HapticFeedback.selectionClick();
    AppToast.dismiss();
    AppToast.info(
      context,
      'Hold to record · slide ↑ to lock · slide ← to cancel',
      title: 'Voice note',
      duration: const Duration(seconds: 2),
    );
  }

  // --- Attach sheet --------------------------------------------------------

  void _openAttachMenu() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AttachTile(
                icon: Icons.photo_camera_outlined,
                color: Colors.pink,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(ctx);
                  ChatMediaHelper.pickAndSendImage(
                    context,
                    conversationId: widget.conversationId,
                    onScrollToBottom: widget.onScrollToBottom,
                  );
                },
              ),
              _AttachTile(
                icon: Icons.videocam_outlined,
                color: Colors.deepOrange,
                label: 'Video',
                onTap: () {
                  Navigator.pop(ctx);
                  ChatMediaHelper.pickAndSendVideo(
                    context,
                    conversationId: widget.conversationId,
                    onScrollToBottom: widget.onScrollToBottom,
                  );
                },
              ),
              _AttachTile(
                icon: Icons.insert_drive_file_outlined,
                color: Theme.of(ctx).colorScheme.primary,
                label: 'Document',
                onTap: () {
                  Navigator.pop(ctx);
                  ChatMediaHelper.pickAndSendFile(
                    context,
                    conversationId: widget.conversationId,
                    onScrollToBottom: widget.onScrollToBottom,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCamera() {
    HapticFeedback.selectionClick();
    ChatMediaHelper.pickAndSendImage(
      context,
      conversationId: widget.conversationId,
      onScrollToBottom: widget.onScrollToBottom,
    );
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final moduleColor = widget.moduleColor ?? theme.colorScheme.primary;

    // Onyx glass in dark, frosted white in light — matches the surface used
    // by the chat AppBar so the composer reads as part of the same layer.
    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.75);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.9);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_leakWarningVisible) const ChatSafetyBanner(),
            if (widget.replyPreview != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                child: QuotedReplyCard(
                  preview: widget.replyPreview!,
                  onClose: widget.onCancelReply,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _GlassPill(
                    isDark: isDark,
                    pillBg: pillBg,
                    pillBorder: pillBorder,
                    child: _isRecording
                        ? VoiceRecorderOverlay(
                            startedAt:
                                _recordingStartedAt ?? DateTime.now(),
                            cancelProgress: _slideCancelProgress,
                            isLocked: _isLocked,
                            amplitudeStream:
                                ChatMediaHelper.amplitudeStream(),
                            onCancel: _cancelRecording,
                          )
                        : _buildEditorRow(isDark),
                  ),
                ),
                const SizedBox(width: 8),
                // Floating lock hint + FAB column so the lock indicator can
                // sit above the mic exactly like WhatsApp.
                _FabColumn(
                  isRecording: _isRecording,
                  isLocked: _isLocked,
                  hasText: _hasText,
                  lockProgress: _lockProgress,
                  moduleColor: moduleColor,
                  cancelArmed: _cancelArmed,
                  onSend: _handleSend,
                  onMicTap: _onMicTap,
                  onStopLocked: _stopAndPreviewRecording,
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: _onLongPressMoveUpdate,
                  onLongPressEnd: _onLongPressEnd,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorRow(bool isDark) {
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[700];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          onPressed: () {
            // Dismiss the soft keyboard (if any) before opening the emoji
            // sheet so the two surfaces don't fight for the bottom space.
            _focusNode.unfocus();
            EmojiPickerSheet.show(context, controller: widget.controller);
          },
          icon: Icon(Icons.emoji_emotions_outlined, color: iconColor),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
        ),
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _handleSend(),
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 12,
              ),
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        IconButton(
          onPressed: _openAttachMenu,
          icon: Icon(Icons.attach_file, color: iconColor),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
        ),
        if (!_hasText)
          IconButton(
            onPressed: _openCamera,
            icon: Icon(Icons.photo_camera_outlined, color: iconColor),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
          ),
      ],
    );
  }
}

/// Frosted glass pill that hosts the editor row (or the recording overlay).
class _GlassPill extends StatelessWidget {
  final bool isDark;
  final Color pillBg;
  final Color pillBorder;
  final Widget child;

  const _GlassPill({
    required this.isDark,
    required this.pillBg,
    required this.pillBorder,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: pillBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );
  }
}

/// Holds the floating lock hint above the circular FAB.
class _FabColumn extends StatelessWidget {
  final bool isRecording;
  final bool isLocked;
  final bool hasText;
  final double lockProgress;
  final Color moduleColor;
  final bool cancelArmed;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onStopLocked;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;

  const _FabColumn({
    required this.isRecording,
    required this.isLocked,
    required this.hasText,
    required this.lockProgress,
    required this.moduleColor,
    required this.cancelArmed,
    required this.onSend,
    required this.onMicTap,
    required this.onStopLocked,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Decide which icon the FAB shows in its current state.
    IconData icon;
    Color bg;
    VoidCallback? onTap;
    GestureLongPressStartCallback? lpStart;
    GestureLongPressMoveUpdateCallback? lpMove;
    GestureLongPressEndCallback? lpEnd;

    if (isRecording && isLocked) {
      icon = Icons.send_rounded;
      bg = moduleColor;
      onTap = onStopLocked;
    } else if (isRecording) {
      icon = Icons.mic_rounded;
      bg = cancelArmed ? Colors.red : moduleColor;
      lpStart = onLongPressStart;
      lpMove = onLongPressMoveUpdate;
      lpEnd = onLongPressEnd;
    } else if (hasText) {
      icon = Icons.send_rounded;
      bg = moduleColor;
      onTap = onSend;
    } else {
      icon = Icons.mic_rounded;
      bg = moduleColor;
      // Quick tap shows the recording-gesture hint; long-press actually
      // starts recording. A null onTap would make the mic feel "dead" on
      // first contact, which several users reported.
      onTap = onMicTap;
      lpStart = onLongPressStart;
      lpMove = onLongPressMoveUpdate;
      lpEnd = onLongPressEnd;
    }

    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lock hint — floats above the FAB only while holding the mic.
          // Opacity ramps up as the user drags upward; at 1.0 the gesture
          // handler also sets isLocked=true which collapses this widget.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: (isRecording && !isLocked)
                ? (0.35 + 0.65 * lockProgress).clamp(0.0, 1.0)
                : 0.0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: 36,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: moduleColor,
                    ),
                    const SizedBox(height: 2),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPressStart: lpStart,
            onLongPressMoveUpdate: lpMove,
            onLongPressEnd: lpEnd,
            child: Material(
              color: bg,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: moduleColor.withValues(alpha: 0.5),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _AttachTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
