import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationEvent Subclasses & QueueGroupingBehavior Unit Tests', () {
    final notifWidget = NotificationWidget(
      id: 'e1',
      message: 'Event Test',
      channelName: 'info',
    );

    test('NotificationQueued constructor and toString', () {
      final e1 = NotificationQueued(notification: notifWidget);
      expect(e1.notification, equals(notifWidget));
      expect(e1.toString(), contains('NotificationQueued'));
    });

    test('NotificationDismissed constructor and toString', () {
      final e1 = NotificationDismissed(
        notification: notifWidget,
        reason: DismissReason.userSwipe,
      );
      expect(e1.notification, equals(notifWidget));
      expect(e1.reason, equals(DismissReason.userSwipe));
      expect(e1.toString(), contains('NotificationDismissed'));
    });

    test('NotificationTapped constructor and toString', () {
      final e1 = NotificationTapped(
        notification: notifWidget,
        behavior: const TapToDismiss(),
      );
      expect(e1.notification, equals(notifWidget));
      expect(e1.behavior, equals(const TapToDismiss()));
      expect(e1.toString(), contains('NotificationTapped'));
    });

    test('NotificationSnoozed constructor and toString', () {
      const duration = Duration(minutes: 5);
      final e1 = NotificationSnoozed(
        notification: notifWidget,
        duration: duration,
      );
      expect(e1.notification, equals(notifWidget));
      expect(e1.duration, equals(duration));
      expect(e1.toString(), contains('NotificationSnoozed'));
    });

    test('NotificationRelocated constructor and toString', () {
      final e1 = NotificationRelocated(
        notification: notifWidget,
        from: QueuePosition.topRight,
        to: QueuePosition.bottomCenter,
      );
      expect(e1.notification, equals(notifWidget));
      expect(e1.from, equals(QueuePosition.topRight));
      expect(e1.to, equals(QueuePosition.bottomCenter));
      expect(e1.toString(), contains('NotificationRelocated'));
    });

    test('NotificationReordered constructor and toString', () {
      final e1 = NotificationReordered(
        notification: notifWidget,
        toIndex: 2,
      );
      expect(e1.notification, equals(notifWidget));
      expect(e1.toIndex, equals(2));
      expect(e1.toString(), contains('NotificationReordered'));
    });

    test('NotificationPinned and NotificationUnpinned', () {
      final pin1 = NotificationPinned(notification: notifWidget);
      expect(pin1.notification, equals(notifWidget));
      expect(pin1.toString(), contains('NotificationPinned'));

      final unpin1 = NotificationUnpinned(notification: notifWidget);
      expect(unpin1.notification, equals(notifWidget));
      expect(unpin1.toString(), contains('NotificationUnpinned'));
    });

    test('QueueOverflowed constructor and toString', () {
      const queue = NotificationQueue(position: QueuePosition.topRight);
      final overflow = QueueOverflowed(queue: queue, dropped: notifWidget);
      expect(overflow.queue, equals(queue));
      expect(overflow.dropped, equals(notifWidget));
      expect(overflow.toString(), contains('QueueOverflowed'));
    });

    test('NotificationCustomActionTriggered constructor and toString', () {
      final actionEvt = NotificationCustomActionTriggered(
        notification: notifWidget,
        actionName: 'archive',
      );
      expect(actionEvt.notification, equals(notifWidget));
      expect(actionEvt.actionName, equals('archive'));
      expect(
        actionEvt.toString(),
        contains('NotificationCustomActionTriggered'),
      );
    });

    test('QueueGroupingBehavior equality and hashCode', () {
      const g1 = QueueGroupingBehavior(
        enabled: true,
        maxBeforeGrouping: 3,
        maxStackedLayers: 4,
        stackStepOffset: 8.0,
        stackScaleMultiplier: 0.1,
        enableGroupSwipeDismiss: true,
        groupDismissThreshold: 0.6,
      );
      const g2 = QueueGroupingBehavior(
        enabled: true,
        maxBeforeGrouping: 3,
        maxStackedLayers: 4,
        stackStepOffset: 8.0,
        stackScaleMultiplier: 0.1,
        enableGroupSwipeDismiss: true,
        groupDismissThreshold: 0.6,
      );
      const g3 = QueueGroupingBehavior(enabled: false);

      expect(g1, equals(g2));
      expect(g1.hashCode, equals(g2.hashCode));
      expect(g1, isNot(equals(g3)));
    });
  });
}
