import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/theme/borderless_input_decoration.dart';
import '../../widgets/home_v2_tokens.dart';

/// Streamlined conversational input with optional speech-to-text.
class CommandInputPill extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const CommandInputPill({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<CommandInputPill> createState() => _CommandInputPillState();
}

class _CommandInputPillState extends State<CommandInputPill> {
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;
  bool _speechReady = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechReady = false;
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) return;
    HapticFeedback.selectionClick();

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final started = await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        widget.controller.text = text;
        widget.controller.selection = TextSelection.collapsed(offset: text.length);
        widget.onChanged?.call(text);
        if (result.finalResult) {
          widget.onSubmitted?.call();
        }
      },
      listenOptions: SpeechListenOptions(listenMode: ListenMode.confirmation),
    );
    if (mounted) setState(() => _listening = started);
  }

  @override
  void dispose() {
    if (_listening) {
      _speech.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = Theme.of(context).colorScheme.onSurface;

    final pillFill = isDark
        ? const Color(0xFF1E1A28).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.94);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeV2Tokens.kHorizontalPad,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            decoration: BoxDecoration(
              color: pillFill,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: pillBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    onChanged: widget.onChanged,
                    onSubmitted: (_) => widget.onSubmitted?.call(),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                    decoration: BorderlessInputDecoration.search(
                      hintText: 'Tell Bybata what you need…',
                      hintStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: fg.withValues(alpha: 0.35),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                if (_speechReady)
                  Semantics(
                    button: true,
                    label: _listening ? 'Stop voice input' : 'Voice search',
                    child: IconButton(
                      onPressed: _toggleListening,
                      icon: Icon(
                        _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _listening
                            ? Theme.of(context).colorScheme.primary
                            : fg.withValues(alpha: 0.55),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
