import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNotification', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'orders',
            position: QueuePosition.topRight,
            defaultIcon: Icon(Icons.shopping_bag),
          ),
        },
        queues: {
          const NotificationQueue(position: QueuePosition.topRight),
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('instantiates as a pure data object with expected properties', () {
      const notification = AppNotification(
        id: 'order-123',
        message: 'Your order has been confirmed',
        title: 'Order Confirmed',
        channelName: 'orders',
        priority: NotificationPriority.high,
        dismissDuration: Duration(seconds: 5),
        permanent: false,
        accentColor: Color(0xFF112233),
        groupKey: 'order_bundle',
      );

      expect(notification.id, equals('order-123'));
      expect(notification.message, equals('Your order has been confirmed'));
      expect(notification.title, equals('Order Confirmed'));
      expect(notification.channelName, equals('orders'));
      expect(notification.priority, equals(NotificationPriority.high));
      expect(notification.dismissDuration, equals(const Duration(seconds: 5)));
      expect(notification.permanent, isFalse);
      expect(notification.accentColor, equals(const Color(0xFF112233)));
      expect(notification.groupKey, equals('order_bundle'));
    });

    test('copyWith replaces specified fields and falls back for null', () {
      const original = AppNotification(
        id: 'original-1',
        message: 'Original Message',
        title: 'Original Title',
        channelName: 'orders',
        priority: NotificationPriority.normal,
      );

      final copy = original.copyWith(
        title: 'Updated Title',
        priority: NotificationPriority.critical,
      );

      expect(copy.id, equals('original-1'));
      expect(copy.message, equals('Original Message'));
      expect(copy.title, equals('Updated Title'));
      expect(copy.priority, equals(NotificationPriority.critical));
      expect(original.toString(), contains('AppNotification'));
    });

    test('toWidget converts AppNotification to NotificationWidget', () {
      const notification = AppNotification(
        id: 'notif-abc',
        message: 'Hello World',
        title: 'Greeting',
        channelName: 'orders',
        priority: NotificationPriority.low,
      );

      final widget = notification.toWidget(
        controller.configuration,
        controller.coordinator,
      );

      expect(widget.id, equals('notif-abc'));
      expect(widget.message, equals('Hello World'));
      expect(widget.title, equals('Greeting'));
      expect(widget.channelName, equals('orders'));
      expect(widget.priority, equals(NotificationPriority.low));
    });

    test('toEntry converts AppNotification to NotificationEntry', () {
      const notification = AppNotification(
        id: 'entry-test',
        message: 'Entry message',
        channelName: 'orders',
      );

      final entry = notification.toEntry();

      expect(entry.id, equals('entry-test'));
      expect(entry.message, equals('Entry message'));
      expect(entry.channelName, equals('orders'));
    });
  });
}
