import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logd/logd.dart';
import 'package:logd/testing.dart';

void main() {
  group('FNQ Edge Cases and Reset Tests', () {
    test('maxStackSize: 0 throws AssertionError', () {
      expect(
        () => NotificationQueue(
          position: QueuePosition.topCenter,
          maxStackSize: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('Unregistered channel logs a warning and falls back to default',
        (final tester) async {
      final sink = CaptureSink();
      final handler = Handler(
        formatter: const PlainFormatter(),
        sink: sink,
      );

      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        logLevel: LogLevel.warning,
        logHandlers: [handler],
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      NotificationWidget(
        id: 'fallback_id',
        message: 'Hello Fallback',
        channelName: 'non_existent_channel',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();
      await tester.pump();

      // Verify the warning was logged
      expect(
        sink.logs.any(
          (final log) =>
              log.level == LogLevel.warning &&
              log.message.contains(
                'Channel "non_existent_channel" is not registered',
              ),
        ),
        isTrue,
      );

      // Verify the notification still renders on screen
      expect(find.text('Hello Fallback'), findsOneWidget);
    });

    testWidgets('Controller disposal mid-display clears all queues cleanly',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      NotificationWidget(
        id: 'reset_mid_id',
        message: 'Active Notif',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();
      await tester.pump();

      expect(find.text('Active Notif'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      controller.dispose();

      expect(controller.isAttached, isFalse);

      final newController = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
      );
      addTearDown(newController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: newController,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      NotificationWidget(
        id: 'new_id',
        message: 'New Notif',
        coordinator: newController.coordinator,
      ).show();

      await tester.pump();
      await tester.pump();

      expect(find.text('New Notif'), findsOneWidget);
    });

    testWidgets('Duplicate IDs update existing active notification in-place',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      NotificationWidget(
        id: 'duplicate_id',
        message: 'First Message',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();
      await tester.pump();

      expect(find.text('First Message'), findsOneWidget);

      NotificationWidget(
        id: 'duplicate_id',
        message: 'Second Message',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();

      expect(find.text('First Message'), findsNothing);
      expect(find.text('Second Message'), findsOneWidget);
    });

    testWidgets('Duplicate IDs update pending notifications in-place',
        (final tester) async {
      final controller = NotificationController(
        queues: {
          const NotificationQueue(
            position: QueuePosition.topCenter,
            maxStackSize: 1,
          ),
        },
        channels: {
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topCenter,
            defaultDismissDuration: null,
          ),
        },
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      final first = NotificationWidget(
        id: 'visible_id',
        message: 'Visible',
        coordinator: controller.coordinator,
      );
      controller.coordinator?.queue(first);

      await tester.pump();
      await tester.pump();

      NotificationWidget(
        id: 'pending_id',
        message: 'Pending 1',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();

      NotificationWidget(
        id: 'pending_id',
        message: 'Pending 2',
        coordinator: controller.coordinator,
      ).show();

      await tester.pump();

      final Future<void> dismissFuture = first.dismiss();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await dismissFuture;

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Pending 1'), findsNothing);
      expect(find.text('Pending 2'), findsOneWidget);
    });

    testWidgets(
        'strictChannelLookup: true throws ArgumentError for unregistered '
        'channelName', (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        strictChannelLookup: true,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      expect(
        () => NotificationWidget(
          message: 'Strict test',
          channelName: 'non_existent_channel',
          coordinator: controller.coordinator,
        ),
        throwsArgumentError,
      );
    });

    testWidgets('NotificationController.show creates and displays notification',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      controller.show(
        const AppNotification(
          message: 'Controller show message',
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Controller show message'), findsOneWidget);
    });

    testWidgets('nextEvent resolves with the first event of type T',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );

      final nextQueuedFuture = controller.nextEvent<NotificationQueued>();

      controller.show(
        const AppNotification(
          message: 'Event test',
        ),
      );

      final event = await nextQueuedFuture;
      expect(event.notification.message, equals('Event test'));
    });
  });
}
