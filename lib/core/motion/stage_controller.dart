import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What is covering the hub photo.
enum StageLayer { closed, hero, details, builder, success }

/// Result of a swipe-down submit. Null from the caller means the form stays.
class StageCommitResult {
  final String line;
  final int karmaMarks;
  final bool playGoalCheck;

  const StageCommitResult(
    this.line, {
    this.karmaMarks = 0,
    this.playGoalCheck = false,
  });
}

/// Eight marks only when karma actually increased.
int karmaFlyCount(int before, int after) => after > before ? 8 : 0;

/// One 100% check per campaign for this app session. The border does not loop.
class GoalCheckSession {
  static final Set<String> played = <String>{};

  static bool claim(String campaignId) {
    if (campaignId.isEmpty) return false;
    return played.add(campaignId);
  }

  static void reset() => played.clear();
}

/// Open layers for one hub stage.
///
/// Back order: success → builder → details → hero → let the route pop.
class StageController extends ChangeNotifier {
  StageLayer layer = StageLayer.closed;
  String? focusId;
  String? successLine;
  int chapter = 0;
  Rect? origin;
  bool _closing = false;

  bool get isOpen => layer != StageLayer.closed;
  bool get isClosing => _closing;
  bool get showBuilder =>
      layer == StageLayer.builder || layer == StageLayer.success;
  bool get showDetails => layer == StageLayer.details;
  bool get showSuccess => layer == StageLayer.success;

  void open(String id, {Rect? origin}) {
    focusId = id;
    layer = StageLayer.hero;
    chapter = 0;
    successLine = null;
    this.origin = origin;
    _closing = false;
    notifyListeners();
  }

  /// The shrink-back finished. The hub can drop the overlay.
  void finishClose() {
    layer = StageLayer.closed;
    origin = null;
    _closing = false;
    successLine = null;
    notifyListeners();
  }

  void focus(String id) {
    if (!isOpen || id.isEmpty || id == focusId) return;
    focusId = id;
    notifyListeners();
  }

  /// Horizontal swipe. Changes [focusId] only. Does not push a route.
  String? focusNeighbor(List<String> ids, int delta) {
    if (!isOpen || ids.isEmpty) return focusId;
    final current = ids.indexOf(focusId ?? '');
    final base = current < 0 ? 0 : current;
    final next = (base + delta).clamp(0, ids.length - 1);
    focusId = ids[next];
    notifyListeners();
    return focusId;
  }

  void openDetails() {
    if (layer == StageLayer.hero) {
      layer = StageLayer.details;
      notifyListeners();
    }
  }

  void openBuilder() {
    if (layer == StageLayer.hero || layer == StageLayer.details) {
      layer = StageLayer.builder;
      notifyListeners();
    }
  }

  void markSuccess(String line) {
    successLine = line;
    layer = StageLayer.success;
    notifyListeners();
  }

  /// True when this back press was consumed by the stage.
  bool back() {
    switch (layer) {
      case StageLayer.success:
        layer = StageLayer.hero;
        successLine = null;
        notifyListeners();
        return true;
      case StageLayer.builder:
        layer = StageLayer.hero;
        notifyListeners();
        return true;
      case StageLayer.details:
        layer = StageLayer.hero;
        notifyListeners();
        return true;
      case StageLayer.hero:
        if (_closing) return true;
        if (origin != null) {
          _closing = true;
          notifyListeners();
          return true;
        }
        layer = StageLayer.closed;
        notifyListeners();
        return true;
      case StageLayer.closed:
        return false;
    }
  }
}
