/// Status of a message, used for tick rendering in the UI.
///
/// none       → outgoing message not yet persisted / unknown status
/// sent       → 1 grey tick: persisted on our server
/// delivered  → 2 grey ticks: arrived on recipient's device
/// read       → 2 blue ticks: opened by the recipient
enum TickStatus { none, sent, delivered, read }

TickStatus tickStatusFromString(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'READ':
      return TickStatus.read;
    case 'DELIVERED':
      return TickStatus.delivered;
    case 'SENT':
      return TickStatus.sent;
    default:
      return TickStatus.none;
  }
}
