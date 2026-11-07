import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationEntry Unit Tests', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'chat',
            position: QueuePosition.topLeft,
            defaultIcon: Icon(Icons.chat),
          ),
        },
        queues: {
          const NotificationQueue(position: QueuePosition.topLeft),
          const NotificationQueue(position: QueuePosition.bottomRight),
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('getters and getters delegation', () {
      final widget = NotificationWidget(
        id: 'entry-1',
        title: 'Title 1',
        message: 'Message 1',
        channelName: 'chat',
        groupKey: 'custom_group',
        coordinator: controller.coordinator,
      );

      const queue = NotificationQueue(position: QueuePosition.topLeft);
      final entry = NotificationEntry(blueprint: widget, queue: queue);

      expect(entry.id, equals('entry-1'));
      expect(entry.title, equals('Title 1'));
      expect(entry.message, equals('Message 1'));
      expect(entry.channelName, equals('chat'));
      expect(entry.resolvedGroupKey, equals('custom_group'));
      expect(entry.resolvedPriority, equals(NotificationPriority.normal));
      expect(entry.isPinned, isFalse);

      entry.isPinned = true;
      expect(entry.isPinned, isTrue);
      expect(widget.isPinned, isTrue);
    });

    test('copyToQueue creates entry bound to new target queue', () {
      final widget = NotificationWidget(
        id: 'entry-relocate',
        message: 'Relocating',
        channelName: 'chat',
        coordinator: controller.coordinator,
      );

      const queueSrc = NotificationQueue(position: QueuePosition.topLeft);
      const queueTarget = NotificationQueue(
        position: QueuePosition.bottomRight,
      );
      final entry = NotificationEntry(blueprint: widget, queue: queueSrc);

      final relocated = entry.copyToQueue(queueTarget);

      expect(relocated.id, equals('entry-relocate'));
      expect(relocated.queue.position, equals(QueuePosition.bottomRight));
    });

    test('copyForRequeue preserves properties and sets snoozedAt', () {
      final widget = NotificationWidget(
        id: 'entry-snooze',
        message: 'Snoozing',
        channelName: 'chat',
        coordinator: controller.coordinator,
      );

      const queue = NotificationQueue(position: QueuePosition.topLeft);
      final entry = NotificationEntry(blueprint: widget, queue: queue);
      final now = DateTime.now();

      final snoozedEntry = entry.copyForRequeue(snoozedAt: now);

      expect(snoozedEntry.id, equals('entry-snooze'));
      expect(snoozedEntry.snoozedAt, equals(now));
    });
  });
}
