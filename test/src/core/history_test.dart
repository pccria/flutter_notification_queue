import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _driveAnimation(final WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('F-05 Persistent History Log Database Tests', () {
    testWidgets('History is disabled by default (maxHistoryEntries = 0)',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        maxHistoryEntries: 0,
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
        id: 'test_1',
        message: 'Hello',
        channelName: 'default',
        coordinator: controller.coordinator,
      ).show();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.getHistory(), isEmpty);
    });

    testWidgets('History captures events and filters them correctly',
        (final tester) async {
      final controller = NotificationController(
        queues: {
          const NotificationQueue(position: QueuePosition.topRight),
          const NotificationQueue(position: QueuePosition.topLeft),
        },
        maxHistoryEntries: 10,
        channels: {
          NotificationChannel.successChannel(defaultDismissDuration: null),
          NotificationChannel.errorChannel(defaultDismissDuration: null),
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

      final n1 = NotificationWidget(
        id: 'test_1',
        message: 'Hello 1',
        channelName: 'success',
        permanent: true,
        coordinator: controller.coordinator,
      )..show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      NotificationWidget(
        id: 'test_2',
        message: 'Hello 2',
        channelName: 'error',
        permanent: true,
        coordinator: controller.coordinator,
      ).show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      // Verify Queued events are logged
      final history = controller.getHistory();
      expect(history.length, equals(2));
      expect(history.every((final e) => e is NotificationQueued), isTrue);

      // Dismiss one programmatically
      final dismissFuture = n1.dismiss();
      await tester.pumpAndSettle();
      await dismissFuture;

      final historyAfterDismiss = controller.getHistory();
      // Should now have 3 events: 2 queued, 1 dismissed
      expect(historyAfterDismiss.length, equals(3));
      expect(historyAfterDismiss.first, isA<NotificationDismissed>());

      // Query by channel
      final successHistory = controller.getHistory(channelName: 'success');
      expect(successHistory.length, equals(2)); // queued and dismissed
      expect(
        successHistory.every(
          (final e) =>
              (e is NotificationQueued && e.notification.id == 'test_1') ||
              (e is NotificationDismissed && e.notification.id == 'test_1'),
        ),
        isTrue,
      );

      // Query by dismiss reason
      final dismissedTimeout = controller.getHistory(
        dismissReason: DismissReason.timeout,
      );
      expect(dismissedTimeout, isEmpty);

      final dismissedProgrammatic = controller.getHistory(
        dismissReason: DismissReason.programmatic,
      );
      expect(dismissedProgrammatic.length, equals(1));
    });

    testWidgets('History obeys maximum entries and handles clear',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        maxHistoryEntries: 3,
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

      for (int i = 0; i < 5; i++) {
        NotificationWidget(
          id: 'notif_$i',
          message: 'Message $i',
          channelName: 'default',
          coordinator: controller.coordinator,
        ).show();
        await tester.pump();
        await tester.pump();
        await _driveAnimation(tester);
      }

      // History must be capped at 3
      final history = controller.getHistory();
      expect(history.length, equals(3));
      final ids = history
          .map((final e) => (e as NotificationQueued).notification.id)
          .toList();
      expect(ids, equals(['notif_4', 'notif_3', 'notif_2']));

      // Test clearHistory
      controller.clearHistory();
      expect(controller.getHistory(), isEmpty);
    });

    testWidgets('History respects limit and since filters',
        (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        maxHistoryEntries: 10,
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

      final beforeTime = DateTime.now();

      NotificationWidget(
        id: 'test_1',
        message: 'Hello 1',
        channelName: 'default',
        coordinator: controller.coordinator,
      ).show();
      await tester.pump();
      await tester.pumpAndSettle();

      final afterN1Time = DateTime.now();

      NotificationWidget(
        id: 'test_2',
        message: 'Hello 2',
        channelName: 'default',
        coordinator: controller.coordinator,
      ).show();
      await tester.pump();
      await tester.pumpAndSettle();

      // Limit query
      final limitHistory = controller.getHistory(limit: 1);
      expect(limitHistory.length, equals(1));
      expect(
        (limitHistory.first as NotificationQueued).notification.id,
        equals('test_2'),
      );

      // Since query
      final sinceHistory = controller.getHistory(since: afterN1Time);
      expect(sinceHistory.length, equals(1));
      expect(
        (sinceHistory.first as NotificationQueued).notification.id,
        equals('test_2'),
      );

      final allHistory = controller.getHistory(since: beforeTime);
      expect(allHistory.length, equals(2));
    });

    testWidgets(
        'History log cancels subscriptions and clears memory completely '
        'when reconfigured', (final tester) async {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        maxHistoryEntries: 10,
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

      // 1. Fire a notification and verify it is logged
      NotificationWidget(
        id: 'test_1',
        message: 'Logged message',
        channelName: 'default',
        coordinator: controller.coordinator,
      ).show();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.getHistory().length, equals(1));

      // 2. Reconfigure history log dynamically to 0
      controller.reconfigure(maxHistoryEntries: 0);

      // 3. Verify history cache is immediately cleared to release memory
      expect(controller.getHistory(), isEmpty);

      // 4. Fire another notification and verify it is NOT logged (ignored)
      NotificationWidget(
        id: 'test_2',
        message: 'Ignored message',
        channelName: 'default',
        coordinator: controller.coordinator,
      ).show();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.getHistory(), isEmpty);

      // 5. Re-enable history dynamically to verify it resumes listening
      controller.reconfigure(maxHistoryEntries: 5);

      NotificationWidget(
        id: 'test_3',
        message: 'Resumed message',
        channelName: 'default',
        coordinator: controller.coordinator,
      ).show();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.getHistory().length, equals(1));
      final firstEvent = controller.getHistory().first as NotificationQueued;
      expect(
        firstEvent.notification.id,
        equals('test_3'),
      );
    });
  });
}
