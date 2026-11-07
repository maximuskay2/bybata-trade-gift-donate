import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Device voice typing. Android opens the system speech sheet the keyboard
/// microphone uses. iOS uses the system speech recognizer and types into the
/// field as you speak, the same way keyboard dictation does.
class DeviceVoiceInput {
  static const _method = MethodChannel('bybata/device_voice');
  static const _events = EventChannel('bybata/device_voice_events');
  static StreamSubscription<dynamic>? _partials;

  /// Starts a capture. [onPartial] receives the words spoken so far.
  /// On Android it is called once, when the system sheet closes.
  /// On iOS it is called as the words update, until [stop].
  static Future<void> start({required void Function(String spoken) onPartial}) async {
    await _partials?.cancel();
    _partials = null;
    if (Platform.isAndroid) {
      final text = await _method.invokeMethod<String>('capture');
      final spoken = text?.trim() ?? '';
      if (spoken.isNotEmpty) onPartial(spoken);
      return;
    }
    _partials = _events.receiveBroadcastStream().listen((event) {
      final spoken = event?.toString().trim() ?? '';
      if (spoken.isNotEmpty) onPartial(spoken);
    });
    try {
      await _method.invokeMethod<void>('start');
    } catch (error) {
      await _partials?.cancel();
      _partials = null;
      rethrow;
    }
  }

  static Future<void> stop() async {
    await _partials?.cancel();
    _partials = null;
    if (!Platform.isIOS) return;
    try {
      await _method.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Puts [spoken] into [current] at the cursor, the way keyboard dictation
  /// inserts words without erasing the rest of the field.
  static TextEditingValue insertSpoken(TextEditingValue current, String spoken) {
    final text = current.text;
    final selection = current.selection;
    final start = selection.isValid ? selection.start.clamp(0, text.length) : text.length;
    final end = selection.isValid ? selection.end.clamp(start, text.length) : text.length;
    final prefix = text.substring(0, start);
    final suffix = text.substring(end);
    final before = prefix.isNotEmpty && !_isSpace(prefix[prefix.length - 1]) ? ' ' : '';
    final after = suffix.isNotEmpty && spoken.isNotEmpty && !_isSpace(suffix[0])
        ? ' '
        : '';
    final merged = '$prefix$before$spoken$after$suffix';
    return TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(
        offset: prefix.length + before.length + spoken.length,
      ),
    );
  }

  static bool _isSpace(String char) {
    return char == ' ' || char == '\n' || char == '\t';
  }
}
