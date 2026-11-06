import 'package:flutter/foundation.dart';

/// Global signal to refresh the conversational home feed (e.g. after web donate).
class ConversationalFeedRefreshBus extends ChangeNotifier {
  ConversationalFeedRefreshBus._();

  static final ConversationalFeedRefreshBus instance =
      ConversationalFeedRefreshBus._();

  void requestRefresh() => notifyListeners();
}
