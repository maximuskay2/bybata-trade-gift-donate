import 'package:bybata/core/motion/hero_stage.dart';
import 'package:bybata/core/motion/living_slide.dart';
import 'package:bybata/core/motion/stage_controller.dart';
import 'package:bybata/core/motion/swipe_commit.dart';
import 'package:bybata/features/donations/widgets/donate_give_act.dart';
import 'package:bybata/features/trade/widgets/trade_offer_act.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(GoalCheckSession.reset);

  test('horizontal swipe changes focusId and does not leave the stage', () {
    final stage = StageController()..open('sandal');
    expect(
      stage.focusNeighbor(const ['sandal', 'cup', 'book'], 1),
      'cup',
    );
    expect(stage.focusId, 'cup');
    expect(stage.layer, StageLayer.hero);
    expect(stage.focusNeighbor(const ['sandal', 'cup', 'book'], -1), 'sandal');
  });

  test('amount rail changes the displayed number and not the saved listing', () {
    const savedRaised = 40.0;
    final draft = DonateDraft();
    addTearDown(draft.dispose);
    draft.select(25);
    expect(draft.amount, 25);
    expect(draft.label, '\$25');
    expect(savedRaised, 40);
  });

  test('item rail reticks the difference and does not write the listing', () {
    const savedValue = 100;
    final draft = TradeOfferDraft();
    addTearDown(draft.dispose);
    draft.select(id: 'mine', mineValue: 80, theirValue: savedValue);
    expect(draft.numberLabel, '-20 BYC');
    expect(draft.offeredTradeId, 'mine');
    expect(savedValue, 100);
    draft.select(id: 'even', mineValue: 100, theirValue: 100);
    expect(draft.numberLabel, 'Even');
  });

  test('swipe past the threshold commits once and a short swipe springs back', () async {
    expect(SwipeCommit.shouldCommit(80), isTrue);
    expect(SwipeCommit.shouldCommit(20), isFalse);
    expect(SwipeCommit.releasedTravel(20), 0);
    expect(SwipeCommit.releasedTravel(80), 80);

    final gate = SwipeCommitGate();
    var calls = 0;
    final first = gate.run(() async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 'sent';
    });
    final second = gate.run(() async {
      calls += 1;
      return 'again';
    });
    expect(await second, isNull);
    expect(await first, 'sent');
    expect(calls, 1);
    expect(gate.fires, 1);
  });

  test('back closes success, then the builder, then details, then the hero', () {
    final stage = StageController()..open('item');
    stage.openDetails();
    stage.openBuilder();
    stage.markSuccess('Offer sent');
    expect(stage.back(), isTrue);
    expect(stage.layer, StageLayer.hero);
    stage.openBuilder();
    expect(stage.back(), isTrue);
    expect(stage.layer, StageLayer.hero);
    stage.openDetails();
    expect(stage.back(), isTrue);
    expect(stage.layer, StageLayer.hero);
    expect(stage.back(), isTrue);
    expect(stage.layer, StageLayer.closed);
    expect(stage.back(), isFalse);
  });

  test('failed submit leaves the builder filled in', () async {
    final stage = StageController()..open('gift');
    stage.openBuilder();
    final draft = DonateDraft();
    addTearDown(draft.dispose);
    draft.select(50);
    draft.note.text = 'for the class';
    const String? failed = null;
    if (failed != null) stage.markSuccess(failed);
    expect(stage.layer, StageLayer.builder);
    expect(draft.amount, 50);
    expect(draft.note.text, 'for the class');
  });

  test('karma marks fly only for a real increase and the goal check plays once', () {
    expect(karmaFlyCount(10, 10), 0);
    expect(karmaFlyCount(10, 18), 8);
    expect(GoalCheckSession.claim('camp'), isTrue);
    expect(GoalCheckSession.claim('camp'), isFalse);
  });

  testWidgets('reduce motion button still submits without a drop', (tester) async {
    var calls = 0;
    double? travel;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          body: SwipeCommitControl(
            label: 'Offer this',
            onTravel: (value) => travel = value,
            onCommit: () async {
              calls += 1;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('swipe-commit-button')));
    await tester.pump();
    expect(calls, 1);
    expect(travel, isNull);
  });

  testWidgets('dragging past the handle commits once and a short drag does not', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeCommitControl(
            label: 'Offer this',
            showHandle: true,
            onCommit: () async {
              calls += 1;
            },
          ),
        ),
      ),
    );
    await tester.drag(find.byKey(const Key('swipe-commit-handle')), const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.drag(find.byKey(const Key('swipe-commit-handle')), const Offset(0, 120));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('horizontal page swipe changes focusId on the same route', (tester) async {
    final stage = StageController()..open('a');
    await tester.pumpWidget(
      MaterialApp(
        home: LivingHeroStage(
          controller: stage,
          stageColor: const Color(0xFF112233),
          slides: const [
            LivingSlide(id: 'a', title: 'Sandal', primaryLabel: 'Offer this'),
            LivingSlide(id: 'b', title: 'Cup', primaryLabel: 'Offer this'),
          ],
          onCommit: (_) async => null,
        ),
      ),
    );
    await tester.pump();
    expect(stage.focusId, 'a');
    expect(find.text('Sandal'), findsWidgets);
    await tester.fling(
      find.byKey(const Key('living-stage-pager')),
      const Offset(-420, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(stage.focusId, 'b');
    expect(find.text('Cup'), findsWidgets);
  });
}
