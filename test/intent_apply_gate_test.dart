import 'package:bybata/features/home_v2/conversational/intent_apply_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drops a stale response from an older search', () {
    final apply = IntentApplyGate.shouldApply(
      flagEnabled: true,
      requestGeneration: 1,
      currentGeneration: 2,
      elapsedMs: 200,
      confidence: 0.9,
    );
    expect(apply, isFalse);
  });

  test('keeps the keyword layout when the flag is off', () {
    final apply = IntentApplyGate.shouldApply(
      flagEnabled: false,
      requestGeneration: 3,
      currentGeneration: 3,
      elapsedMs: 100,
      confidence: 0.95,
    );
    expect(apply, isFalse);
  });

  test('applies a fresh high-confidence result inside the cutoff', () {
    final apply = IntentApplyGate.shouldApply(
      flagEnabled: true,
      requestGeneration: 4,
      currentGeneration: 4,
      elapsedMs: 1700,
      confidence: 0.6,
    );
    expect(apply, isTrue);
  });

  test('rejects a late or low-confidence result', () {
    expect(
      IntentApplyGate.shouldApply(
        flagEnabled: true,
        requestGeneration: 1,
        currentGeneration: 1,
        elapsedMs: 1801,
        confidence: 0.9,
      ),
      isFalse,
    );
    expect(
      IntentApplyGate.shouldApply(
        flagEnabled: true,
        requestGeneration: 1,
        currentGeneration: 1,
        elapsedMs: 100,
        confidence: 0.59,
      ),
      isFalse,
    );
  });
}
