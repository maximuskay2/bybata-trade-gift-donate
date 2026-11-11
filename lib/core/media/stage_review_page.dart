import 'dart:io';

import 'package:flutter/material.dart';

import '../navigation/guarded_navigator.dart';
import 'stage_prepare.dart';
import 'subject_cutout.dart';

/// What the review screen decided.
class StageReviewExit {
  final File? file;
  final bool retake;

  const StageReviewExit({this.file, this.retake = false});
}

/// Shows the cutout on the hub color, or the shot with guidance to retake.
class StageReviewPage extends StatefulWidget {
  final String sourcePath;
  final Color stageColor;
  final bool offerRetake;
  final SubjectCutout? cutout;

  const StageReviewPage({
    super.key,
    required this.sourcePath,
    required this.stageColor,
    this.offerRetake = true,
    this.cutout,
  });

  static Future<StageReviewExit?> open(
    BuildContext context, {
    required String sourcePath,
    required Color stageColor,
    bool offerRetake = true,
    SubjectCutout? cutout,
  }) {
    return GuardedNavigator.push<StageReviewExit>(
      context,
      MaterialPageRoute(
        builder: (_) => StageReviewPage(
          sourcePath: sourcePath,
          stageColor: stageColor,
          offerRetake: offerRetake,
          cutout: cutout,
        ),
      ),
      force: true,
    );
  }

  @override
  State<StageReviewPage> createState() => _StageReviewPageState();
}

class _StageReviewPageState extends State<StageReviewPage> {
  StagePrepareResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final color = widget.stageColor;
    final result = await prepareStagePhoto(
      sourcePath: widget.sourcePath,
      red: _byte(color.r),
      green: _byte(color.g),
      blue: _byte(color.b),
      cutout: widget.cutout ?? const NativeSubjectCutout(),
    );
    if (!mounted) return;
    setState(() => _result = result);
  }

  int _byte(double channel) => (channel * 255).round().clamp(0, 255);

  void _close({bool retake = false, File? file}) {
    Navigator.of(context).pop(StageReviewExit(file: file, retake: retake));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final source = File(widget.sourcePath);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close(retake: widget.offerRetake);
      },
      child: Scaffold(
        backgroundColor: widget.stageColor,
        body: SafeArea(
          child: result == null
              ? Column(
                  children: [
                    Expanded(
                      child: source.existsSync()
                          ? Image.file(source, fit: BoxFit.contain)
                          : const SizedBox.shrink(),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 12, 24, 28),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Lifting the item off the background…',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : switch (result) {
                  StageReady(:final file) => _Ready(
                      file: file,
                      sourcePath: widget.sourcePath,
                      offerRetake: widget.offerRetake,
                      onUse: () => _close(file: file),
                      onRetake: () => _close(retake: true),
                      onClose: () => _close(),
                    ),
                  StageRejected(:final message) => _Rejected(
                      message: message,
                      sourcePath: widget.sourcePath,
                      offerRetake: widget.offerRetake,
                      onRetake: () => _close(retake: true),
                      onClose: () => _close(),
                    ),
                },
        ),
      ),
    );
  }
}

class _Ready extends StatelessWidget {
  final File file;
  final String sourcePath;
  final bool offerRetake;
  final VoidCallback onUse;
  final VoidCallback onRetake;
  final VoidCallback onClose;

  const _Ready({
    required this.file,
    required this.sourcePath,
    required this.offerRetake,
    required this.onUse,
    required this.onRetake,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              final source = File(sourcePath);
              if (!source.existsSync()) {
                return const SizedBox.shrink();
              }
              return Image.file(source, fit: BoxFit.contain);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              TextButton(
                onPressed: offerRetake ? onRetake : onClose,
                child: Text(offerRetake ? 'Retake' : 'Close'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onUse,
                child: const Text('Use this'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rejected extends StatelessWidget {
  final String message;
  final String sourcePath;
  final bool offerRetake;
  final VoidCallback onRetake;
  final VoidCallback onClose;

  const _Rejected({
    required this.message,
    required this.sourcePath,
    required this.offerRetake,
    required this.onRetake,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final source = File(sourcePath);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (source.existsSync())
                    Image.file(
                      source,
                      fit: BoxFit.cover,
                    )
                  else
                    const ColoredBox(color: Colors.black26),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: offerRetake ? onRetake : onClose,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                offerRetake ? 'Retake' : 'Close',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
