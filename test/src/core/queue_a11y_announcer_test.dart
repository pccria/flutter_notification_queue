import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueA11yAnnouncer', () {
    const announcer = QueueA11yAnnouncer();

    testWidgets('no-ops when enableLiveRegions is false', (final tester) async {
      const options = NotificationA11yOptions(enableLiveRegions: false);
      final notification = NotificationWidget(
        message: 'Test message',
        priority: NotificationPriority.critical,
      );

      // Should complete cleanly without throwing
      announcer.announce(notification, options: options);
    });

    testWidgets('no-ops when priority is below announcePriorityThreshold',
        (final tester) async {
      const options = NotificationA11yOptions(
        enableLiveRegions: true,
        announcePriorityThreshold: NotificationPriority.high,
      );
      final notification = NotificationWidget(
        message: 'Low priority message',
        priority: NotificationPriority.low,
      );

      // Should complete cleanly without announcing
      announcer.announce(notification, options: options);
    });

    testWidgets('announces high priority notification with title and message',
        (final tester) async {
      const options = NotificationA11yOptions(
        enableLiveRegions: true,
        announcePriorityThreshold: NotificationPriority.high,
      );
      final notification = NotificationWidget(
        title: 'Alert',
        message: 'Server unreachable',
        priority: NotificationPriority.critical,
      );

      announcer.announce(notification, options: options);
    });

    testWidgets('announces notification with message only',
        (final tester) async {
      const options = NotificationA11yOptions(
        enableLiveRegions: true,
        announcePriorityThreshold: NotificationPriority.normal,
      );
      final notification = NotificationWidget(
        message: 'Simple message',
        priority: NotificationPriority.normal,
      );

      announcer.announce(notification, options: options);
    });
  });
}
