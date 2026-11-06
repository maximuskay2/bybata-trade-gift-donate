import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WhatsApp-style inline voice recorder shown inside the composer while the
/// user is recording. Renders:
///   * pulsing red dot + m:ss timer on the left
///   * live waveform built from [amplitudeStream]
///   * ghost "◂ Slide to cancel" hint that fades as the user drags left
///   * trash icon (only while locked, so the user has a way to cancel after
///     lifting the finger — during the long-press it's driven by gesture)
class VoiceRecorderOverlay extends StatefulWidget {
  final DateTime startedAt;

  /// 0.0 → no horizontal drag; 1.0 → at/past the cancel threshold.
  /// Drives the opacity of the "Slide to cancel" hint and the translation
  /// of the mic indicator.
  final double cancelProgress;

  /// True once the user has dragged past the lock threshold (or the
  /// recording was started in locked mode). When locked, the trash icon is
  /// visible so the user can still cancel without holding the FAB.
  final bool isLocked;

  /// Live amplitude stream (0..1 normalized). Used to paint the waveform.
  final Stream<double>? amplitudeStream;

  /// Called when the user taps the trash icon (only relevant while locked).
  final VoidCallback? onCancel;

  const VoiceRecorderOverlay({
    super.key,
    required this.startedAt,
    this.cancelProgress = 0.0,
    this.isLocked = false,
    this.amplitudeStream,
    this.onCancel,
  });

  @override
  State<VoiceRecorderOverlay> createState() => _VoiceRecorderOverlayState();
}

class _VoiceRecorderOverlayState extends State<VoiceRecorderOverlay> {
  Timer? _ticker;
  final List<double> _bars = List<double>.filled(_barCount, 0.0);
  int _barHead = 0;
  StreamSubscription<double>? _ampSub;

  static const int _barCount = 28;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _subscribeAmplitude();
  }

  @override
  void didUpdateWidget(covariant VoiceRecorderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      _ampSub?.cancel();
      _subscribeAmplitude();
    }
  }

  void _subscribeAmplitude() {
    final stream = widget.amplitudeStream;
    if (stream == null) return;
    _ampSub = stream.listen((v) {
      if (!mounted) return;
      setState(() {
        _bars[_barHead % _barCount] = v;
        _barHead++;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ampSub?.cancel();
    super.dispose();
  }

  String _elapsed() {
    final s = DateTime.now().difference(widget.startedAt).inSeconds;
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Slide-to-cancel fades the hint as the user drags and shifts the
    // pulsing dot slightly toward the trash direction so it "follows" the
    // fingertip, matching WhatsApp feedback.
    final hintOpacity = (1.0 - widget.cancelProgress).clamp(0.0, 1.0);
    final shiftX = -24 * widget.cancelProgress;

    return Row(
      children: [
        if (widget.isLocked)
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onCancel?.call();
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          )
        else
          const SizedBox(width: 12),
        Transform.translate(
          offset: Offset(shiftX, 0),
          child: const _PulsingDot(color: Colors.red),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          child: Text(
            _elapsed(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Live waveform — visible only when we actually have samples
              // so it doesn't flash on mount.
              if (_barHead > 0)
                CustomPaint(
                  size: const Size(double.infinity, 24),
                  painter: _WaveformPainter(
                    bars: _bars,
                    head: _barHead,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              // Slide-to-cancel hint overlay, fades out as user drags.
              Opacity(
                opacity: hintOpacity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chevron_left_rounded,
                        size: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    Text(
                      widget.isLocked ? 'Recording...' : 'Slide to cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final int head;
  final Color color;

  _WaveformPainter({
    required this.bars,
    required this.head,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    final n = bars.length;
    final spacing = size.width / n;
    for (int i = 0; i < n; i++) {
      // Render oldest → newest left-to-right using the ring buffer order.
      final idx = (head + i) % n;
      final v = bars[idx];
      final h = math.max(2.0, v * size.height);
      final cx = spacing * i + spacing / 2;
      canvas.drawLine(
        Offset(cx, size.height / 2 - h / 2),
        Offset(cx, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.head != head || oldDelegate.color != color;
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.3 + 0.7 * _c.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
