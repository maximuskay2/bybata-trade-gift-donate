import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/listing_media_constants.dart';
import '../navigation/guarded_navigator.dart';
import 'clip_subject.dart';
import 'hero_clip_channel.dart';
import 'live_capture_gate.dart';

/// In-app camera. Soft guidance, tap-to-focus, and a shutter that unlocks quickly.
class HeroCapturePage extends StatefulWidget {
  final bool recordVideo;

  const HeroCapturePage({super.key, this.recordVideo = false});

  static Future<String?> open(
    BuildContext context, {
    bool recordVideo = false,
  }) {
    return GuardedNavigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => HeroCapturePage(recordVideo: recordVideo),
      ),
      force: true,
    );
  }

  @override
  State<HeroCapturePage> createState() => _HeroCapturePageState();
}

class _HeroCapturePageState extends State<HeroCapturePage> {
  CameraController? _camera;
  String? _error;
  bool _busy = false;
  bool _recording = false;
  bool _finishing = false;
  bool _streaming = false;
  bool _pauseOk = true;
  bool _sampling = false;
  bool _shutterOpen = false;
  bool _softUnlocked = false;
  String? _hold;
  int _secondsLeft = ListingMediaConstants.heroClipMax.inSeconds;
  Timer? _ticker;
  Timer? _watch;
  Timer? _softUnlock;
  int _watchTicks = 0;
  bool _watching = false;
  Offset? _focusPoint;
  Timer? _focusRing;
  final LiveShutterLock _lock = LiveShutterLock();
  final WhipWatch _whip = WhipWatch();
  Float32List? _previousGrid;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _error = 'No camera was found on this phone.');
        }
        return;
      }
      final back = cameras.cast<CameraDescription?>().firstWhere(
            (camera) => camera!.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          )!;
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: widget.recordVideo,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      _armSoftUnlock();
      await _startStream();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'The camera could not start. ${error.toString()}',
        );
      }
    }
  }

  void _armSoftUnlock() {
    _softUnlock?.cancel();
    _softUnlocked = false;
    _softUnlock = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted || _recording || _busy) return;
      if (_shutterOpen) return;
      setState(() {
        _softUnlocked = true;
        _shutterOpen = true;
        _hold = 'Tap when ready.';
      });
    });
  }

  Future<void> _startStream() async {
    final camera = _camera;
    if (camera == null || _streaming || !camera.value.isInitialized) return;
    try {
      await camera.startImageStream(_onPreview);
      _streaming = true;
    } catch (_) {
      _streaming = false;
    }
  }

  Future<void> _stopStream() async {
    final camera = _camera;
    if (camera == null || !_streaming) return;
    try {
      await camera.stopImageStream();
    } catch (_) {}
    _streaming = false;
  }

  void _onPreview(CameraImage image) {
    if (_recording || _busy) return;
    final grid = _gridOf(image);
    if (grid == null) return;
    final previous = _previousGrid;
    _previousGrid = grid;
    final motion = previous == null
        ? LiveCaptureGate.maxMotion
        : LiveFrame.motion(previous, grid);
    final hold = _lock.consider(
      luma: LiveFrame.mean(grid),
      motion: motion,
      centerEnergy: LiveFrame.variance(grid, center: true),
      edgeEnergy: LiveFrame.variance(grid, center: false),
    );
    final ready = hold == null;
    final open = ready || _softUnlocked;
    final nextHold = ready
        ? null
        : (_softUnlocked ? 'Tap when ready.' : hold);
    if (open == _shutterOpen && nextHold == _hold) return;
    if (!mounted) return;
    if (ready) {
      _softUnlock?.cancel();
      _softUnlock = null;
      _softUnlocked = false;
    }
    setState(() {
      _shutterOpen = open;
      _hold = nextHold;
    });
  }

  Float32List? _gridOf(CameraImage image) {
    if (image.planes.isEmpty || image.width < 2 || image.height < 2) {
      return null;
    }
    final plane = image.planes.first;
    if (image.format.group == ImageFormatGroup.bgra8888) {
      return LiveFrame.gridFromBgra(
        plane.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: plane.bytesPerRow,
      );
    }
    return LiveFrame.gridFromLuma(
      plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
    );
  }

  Future<void> _tapFocus(TapDownDetails details, Size previewSize) async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    final local = details.localPosition;
    final dx = (local.dx / previewSize.width).clamp(0.0, 1.0);
    final dy = (local.dy / previewSize.height).clamp(0.0, 1.0);
    final point = Offset(dx, dy);
    HapticFeedback.selectionClick();
    setState(() => _focusPoint = local);
    _focusRing?.cancel();
    _focusRing = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _focusPoint = null);
    });
    try {
      await camera.setFocusPoint(point);
      await camera.setExposurePoint(point);
      await camera.setFocusMode(FocusMode.auto);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _watch?.cancel();
    _softUnlock?.cancel();
    _focusRing?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || _busy || !_shutterOpen || !camera.value.isInitialized) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _stopStream();
      final shot = await camera.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(shot.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'The photo did not save. Try again.';
        });
        _armSoftUnlock();
        await _startStream();
      }
    }
  }

  Future<void> _toggleVideo() async {
    final camera = _camera;
    if (camera == null || _busy || !camera.value.isInitialized) return;
    if (_recording) {
      await _finishVideo();
      return;
    }
    if (!_shutterOpen) return;
    try {
      await _stopStream();
      await camera.startVideoRecording();
      if (!mounted) return;
      _whip.reset();
      _watchTicks = 0;
      _softUnlock?.cancel();
      setState(() {
        _recording = true;
        _secondsLeft = ListingMediaConstants.heroClipMax.inSeconds;
        _hold = null;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsLeft <= 1) {
          timer.cancel();
          _finishVideo();
          return;
        }
        setState(() => _secondsLeft -= 1);
      });
      _watch = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _watchRecording();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Recording did not start. Try again.');
        _armSoftUnlock();
        await _startStream();
      }
    }
  }

  Future<void> _watchRecording() async {
    if (!_recording || _busy || _finishing || _watching) return;
    _watching = true;
    try {
      final magnitude = await HeroClipChannel.motion();
      if (!_recording || _finishing) return;
      if (_whip.add(magnitude)) {
        await _finishVideo(refusal: LiveCaptureGate.holdStill);
        return;
      }
      _watchTicks += 1;
      if (_pauseOk && !_sampling && _watchTicks % 4 == 0) {
        await _sampleWhileRecording();
      }
    } finally {
      _watching = false;
    }
  }

  Future<void> _sampleWhileRecording() async {
    final camera = _camera;
    if (camera == null || !_recording || _sampling) return;
    _sampling = true;
    try {
      await camera.pauseVideoRecording();
      final frame = Completer<CameraImage>();
      await camera.startImageStream((image) {
        if (!frame.isCompleted) frame.complete(image);
      });
      final image =
          await frame.future.timeout(const Duration(milliseconds: 500));
      await camera.stopImageStream();
      await camera.resumeVideoRecording();
      final grid = _gridOf(image);
      if (grid == null || !_recording) return;
      final message = LiveCaptureGate.message(
        luma: LiveFrame.mean(grid),
        motion: 0,
        centerEnergy: LiveFrame.variance(grid, center: true),
        edgeEnergy: LiveFrame.variance(grid, center: false),
        steadyCount: LiveCaptureGate.steadyFrames,
      );
      if (message == LiveCaptureGate.addLight ||
          LiveCaptureGate.isFramingIssue(message)) {
        await _finishVideo(
          refusal: message == LiveCaptureGate.addLight
              ? message
              : ClipSubject.leaveFrame,
        );
      }
    } catch (_) {
      _pauseOk = false;
      try {
        await camera.stopImageStream();
      } catch (_) {}
      try {
        await camera.resumeVideoRecording();
      } catch (_) {}
    } finally {
      _sampling = false;
    }
  }

  Future<void> _finishVideo({String? refusal}) async {
    final camera = _camera;
    if (camera == null || !_recording || _finishing) return;
    _finishing = true;
    _ticker?.cancel();
    _watch?.cancel();
    setState(() => _busy = true);
    try {
      final clip = await camera.stopVideoRecording();
      _recording = false;
      if (refusal != null) {
        try {
          await File(clip.path).delete();
        } catch (_) {}
        if (!mounted) return;
        _lock.reset();
        _previousGrid = null;
        setState(() {
          _busy = false;
          _finishing = false;
          _shutterOpen = false;
          _hold = refusal;
          _secondsLeft = ListingMediaConstants.heroClipMax.inSeconds;
        });
        _armSoftUnlock();
        await _startStream();
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop(clip.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _finishing = false;
          _recording = false;
          _error = 'The clip did not save. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final hint = _recording
        ? 'Keep the item in the frame and turn it slowly.'
        : (_shutterOpen
            ? (_hold ?? 'Ready — tap to shoot.')
            : (_hold ??
                (widget.recordVideo
                    ? 'Center the item, then tap to record.'
                    : 'Center the item, then tap to shoot.')));
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: camera == null
            ? _Message(
                text: _error ?? 'Opening the camera…',
                onClose: () => Navigator.of(context).pop(),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final previewSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            _tapFocus(details, previewSize),
                        child: CameraPreview(camera),
                      ),
                      const IgnorePointer(child: _CaptureFrame()),
                      if (_focusPoint != null)
                        Positioned(
                          left: _focusPoint!.dx - 28,
                          top: _focusPoint!.dy - 28,
                          child: IgnorePointer(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amberAccent,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        top: 8,
                        child: IconButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 28,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the preview to focus',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (widget.recordVideo)
                              Text(
                                _recording
                                    ? '0:0$_secondsLeft'
                                    : '8 seconds',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            const SizedBox(height: 12),
                            _Shutter(
                              recording: _recording,
                              busy: _busy,
                              enabled: _recording || _shutterOpen,
                              video: widget.recordVideo,
                              onTap: widget.recordVideo
                                  ? _toggleVideo
                                  : _takePhoto,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _CaptureFrame extends StatelessWidget {
  const _CaptureFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.78,
        heightFactor: 0.52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  final bool recording;
  final bool busy;
  final bool enabled;
  final bool video;
  final VoidCallback onTap;

  const _Shutter({
    required this.recording,
    required this.busy,
    required this.enabled,
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final live = enabled && !busy;
    return GestureDetector(
      onTap: live ? onTap : null,
      child: Opacity(
        opacity: live ? 1 : 0.45,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: live
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.28),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: recording ? 28 : 60,
              height: recording ? 28 : 60,
              decoration: BoxDecoration(
                color: video ? const Color(0xFFE11D48) : Colors.white,
                borderRadius: BorderRadius.circular(recording ? 6 : 40),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onClose;

  const _Message({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          TextButton(onPressed: onClose, child: const Text('Close')),
        ],
      ),
    );
  }
}
