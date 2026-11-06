import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/utils/media_utils.dart';
import '../models/chat_message.dart';
import 'package:bybata/core/widgets/app_toast.dart';

/// Reusable voice note bubble with play/pause, progress, and duration.
class VoiceNoteBubble extends StatefulWidget {
  final ChatMessage message;
  final Color primaryColor;
  final bool isMe;
  final bool isDark;

  const VoiceNoteBubble({
    super.key,
    required this.message,
    required this.primaryColor,
    required this.isMe,
    required this.isDark,
  });

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  final AudioPlayer _player = AudioPlayer();
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() {});
    });
    _player.positionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _resolveUrl() async {
    final key = widget.message.audioKey;
    if (key == null || key.isEmpty) return;
    final url = await MediaResolver.resolveUrl(key);
    if (mounted) setState(() => _resolvedUrl = url);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_resolvedUrl == null || !_resolvedUrl!.startsWith('http')) return;
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.setUrl(_resolvedUrl!);
        await _player.play();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Could not play voice note: $e');
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: widget.message.durationSeconds);
    final position = _player.position;
    final total = _player.duration ?? duration;
    final progress = total.inMilliseconds > 0
        ? position.inMilliseconds / total.inMilliseconds
        : 0.0;
    final textColor = widget.isMe ? Colors.white : (widget.isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _resolvedUrl != null ? _togglePlay : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: textColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: textColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(total)}',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
