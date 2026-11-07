import 'package:bybata/core/platform/device_voice_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dictation inserts words at the cursor and keeps the rest', () {
    final next = DeviceVoiceInput.insertSpoken(
      const TextEditingValue(
        text: 'I desk',
        selection: TextSelection.collapsed(offset: 1),
      ),
      'need a',
    );
    expect(next.text, 'I need a desk');
    expect(next.selection.extentOffset, 'I need a'.length);
  });

  test('dictation adds a space before words at the end of a sentence', () {
    final next = DeviceVoiceInput.insertSpoken(
      const TextEditingValue(
        text: 'I need',
        selection: TextSelection.collapsed(offset: 6),
      ),
      'a desk',
    );
    expect(next.text, 'I need a desk');
  });

  test('dictation fills an empty field', () {
    final next = DeviceVoiceInput.insertSpoken(
      const TextEditingValue(),
      'free phone',
    );
    expect(next.text, 'free phone');
    expect(next.selection.extentOffset, 'free phone'.length);
  });
}
