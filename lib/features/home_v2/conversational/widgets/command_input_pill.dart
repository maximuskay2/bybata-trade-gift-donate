import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/platform/device_voice_input.dart';
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
  bool _listening = false;
  TextEditingValue _dictationBase = const TextEditingValue();

  Future<void> _toggleListening() async {
    HapticFeedback.selectionClick();
    if (_listening) {
      await DeviceVoiceInput.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    _dictationBase = widget.controller.value;
    setState(() => _listening = true);
    try {
      await DeviceVoiceInput.start(onPartial: _applySpoken);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _listening = false);
      final message =
          error.message ?? 'Voice typing is not available on this device.';
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
      return;
    } catch (_) {
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!mounted) return;
    if (Platform.isAndroid) {
      setState(() => _listening = false);
      widget.focusNode.requestFocus();
    }
  }

  void _applySpoken(String spoken) {
    if (!mounted) return;
    final next = DeviceVoiceInput.insertSpoken(_dictationBase, spoken);
    widget.controller.value = next;
    widget.onChanged?.call(next.text);
  }

  @override
  void dispose() {
    DeviceVoiceInput.stop();
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
                Semantics(
                  button: true,
                  label: _listening ? 'Stop voice typing' : 'Voice typing',
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
