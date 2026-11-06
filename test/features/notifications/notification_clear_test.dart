import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bybata/core/models/app_models.dart';
import 'package:bybata/core/providers/notification_provider.dart';

/// Tests for the notification clear flow fix.
///
/// Verifies that [NotificationProvider.clearAllNotifications] and
/// [NotificationProvider.deleteNotification] reset/decrement the unread
/// badge count immediately, so the UI no longer shows stale unread counts
/// after the user clears notifications.
///
/// The provider issues a best-effort DELETE to the backend behind an inner
/// try/catch, so these tests run fine without a live API — we only assert
/// the local state transitions that drive the UI badge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub FlutterSecureStorage so the provider's auth-token read does not
  // throw MissingPluginException in the unit test environment.
  setUpAll(() {
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      // Return null for reads, true for writes — good enough for the code
      // paths exercised here (none of which depend on real stored values).
      if (call.method == 'read') return null;
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
  });

  AppNotification makeNotif(String id, {bool isRead = false}) => AppNotification(
        id: id,
        title: 'Test $id',
        message: 'Body $id',
        type: NotificationType.message,
        isRead: isRead,
        createdAt: DateTime.now(),
      );

  group('NotificationProvider.clearAllNotifications', () {
    test('clears list and resets unread badge to zero', () async {
      final provider = NotificationProvider();

      // Seed three unread notifications via the public add API.
      provider.addNotification(makeNotif('n1'));
      provider.addNotification(makeNotif('n2'));
      provider.addNotification(makeNotif('n3'));

      expect(provider.notifications.length, 3);
      expect(provider.unreadCount, 3);

      await provider.clearAllNotifications();

      expect(provider.notifications, isEmpty,
          reason: 'clear should remove all notifications');
      expect(provider.filteredNotifications, isEmpty,
          reason: 'filtered list should also be emptied');
      expect(provider.unreadCount, 0,
          reason: 'badge must be zero immediately after clear — this is the '
              'core fix for the unread-count persistence bug');
    });

    test('notifies listeners when clearing', () async {
      final provider = NotificationProvider();
      provider.addNotification(makeNotif('n1'));

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.clearAllNotifications();

      expect(notifyCount, greaterThan(0),
          reason: 'clear must trigger listener rebuilds so the badge updates');
    });
  });

  group('NotificationProvider.deleteNotification', () {
    test('removes item and decrements unread badge when unread', () async {
      final provider = NotificationProvider();

      provider.addNotification(makeNotif('n1'));
      provider.addNotification(makeNotif('n2'));
      expect(provider.unreadCount, 2);

      await provider.deleteNotification('n1');

      expect(provider.notifications.length, 1);
      expect(provider.notifications.first.id, 'n2');
      expect(provider.unreadCount, 1,
          reason: 'deleting an unread notification should drop the badge by 1');
    });

    test('does not go below zero on repeated deletes', () async {
      final provider = NotificationProvider();
      provider.addNotification(makeNotif('n1'));

      await provider.deleteNotification('n1');
      await provider.deleteNotification('n1'); // idempotent: already gone

      expect(provider.unreadCount, 0);
      expect(provider.notifications, isEmpty);
    });
  });
}
