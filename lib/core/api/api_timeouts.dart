/// Per-request Dio timeouts for slow write operations (listing create, donate, etc.).
abstract final class ApiTimeouts {
  static const listingWrite = Duration(seconds: 45);
}
