/// Lets a deep link open the stage when that hub is the visible route.
class HubStageBus {
  HubStageBus._();

  static const String trade = 'trade';
  static const String gift = 'gift';
  static const String donate = 'donate';

  static final Map<String, void Function(String id)> _open = {};
  static final Set<String> _current = {};

  static void register(String hub, void Function(String id) open) {
    _open[hub] = open;
  }

  static void unregister(String hub, void Function(String id) open) {
    if (_open[hub] == open) _open.remove(hub);
  }

  static void markCurrent(String hub, bool current) {
    if (current) {
      _current.add(hub);
    } else {
      _current.remove(hub);
    }
  }

  /// True when the hub route is showing and consumed the id.
  static bool tryOpen(String hub, String id) {
    if (id.isEmpty || !_current.contains(hub)) return false;
    final open = _open[hub];
    if (open == null) return false;
    open(id);
    return true;
  }
}
