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
  group('Queue Relocation & Cluster Invariance Tests', () {
    testWidgets(
        'ephemeral relocation (permanent: false): single card moves, '
        'future cards stay at original position', (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test_info',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          NotificationQueue(
            position: QueuePosition.topRight,
            longPressDragBehavior: Relocate.to(
              {QueuePosition.topLeft},
              permanent: false,
            ),
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

      final n1 = NotificationWidget(
        id: 'notif_1',
        message: 'Message 1',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      expect(find.text('Message 1'), findsOneWidget);

      // Relocate n1 to topLeft
      controller.coordinator?.relocateWidget(n1, QueuePosition.topLeft);
      await tester.pump();
      await tester.pumpAndSettle();

      // Fire a second notification of the same channel
      final n2 = NotificationWidget(
        id: 'notif_2',
        message: 'Message 2',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      // Verify that n2 is still routed to the original position (topRight)
      final stateKey = GlobalObjectKey<NotificationWidgetState>(n2.id);
      expect(
        stateKey.currentState?.widget.queue.position,
        equals(QueuePosition.topRight),
      );
    });

    testWidgets(
        'permanent relocation (Approach 1): migrates active siblings and '
        'redirects future cards to new position', (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test_info',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          NotificationQueue(
            position: QueuePosition.topRight,
            maxStackSize: 5,
            longPressDragBehavior: Relocate.to(
              {QueuePosition.topLeft},
              permanent: true,
            ),
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

      final n1 = NotificationWidget(
        id: 'notif_1',
        message: 'Message 1',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();

      final n2 = NotificationWidget(
        id: 'notif_2',
        message: 'Message 2',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();

      final List<NotificationEvent> capturedEvents = [];
      final sub = controller.events.listen(capturedEvents.add);
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);

      // Relocate n1 to topLeft
      controller.coordinator?.relocateWidget(n1, QueuePosition.topLeft);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify QueuePositionRelocated event was emitted
      expect(
        capturedEvents.any(
          (final e) =>
              e is QueuePositionRelocated &&
              e.from == QueuePosition.topRight &&
              e.to == QueuePosition.topLeft &&
              e.permanent,
        ),
        isTrue,
      );

      // Approach 1 Check: Verify n2 also migrated to topLeft!
      final n2Key = GlobalObjectKey<NotificationWidgetState>(n2.id);
      expect(
        n2Key.currentState?.widget.queue.position,
        equals(QueuePosition.topLeft),
      );

      // Fire a third notification of the same channel
      final n3 = NotificationWidget(
        id: 'notif_3',
        message: 'Message 3',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      sub.cancel(); // ignore: unawaited_futures

      // Verify that n3 was routed to topLeft!
      final n3Key = GlobalObjectKey<NotificationWidgetState>(n3.id);
      expect(
        n3Key.currentState?.widget.queue.position,
        equals(QueuePosition.topLeft),
      );
    });

    testWidgets(
        'permanent relocation migrates pending notifications to new queue',
        (final tester) async {
      final controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test_info',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          NotificationQueue(
            position: QueuePosition.topRight,
            maxStackSize: 2,
            longPressDragBehavior: Relocate.to(
              {QueuePosition.topLeft},
              permanent: true,
            ),
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

      // Fire 4 notifications (2 active, 2 pending)
      final n1 = NotificationWidget(
        id: 'notif_1',
        message: 'Message 1',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();

      final n2 = NotificationWidget(
        id: 'notif_2',
        message: 'Message 2',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();

      final n3 = NotificationWidget(
        id: 'notif_3',
        message: 'Message 3',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();

      final n4 = NotificationWidget(
        id: 'notif_4',
        message: 'Message 4',
        channelName: 'test_info',
        coordinator: controller.coordinator,
      )..show();

      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);
      expect(find.text('Message 3'), findsNothing);
      expect(find.text('Message 4'), findsNothing);

      // Permanently relocate n1 to topLeft
      controller.coordinator?.relocateWidget(n1, QueuePosition.topLeft);
      await tester.pump();
      await tester.pumpAndSettle();

      // n1 and n2 should both be relocated to topLeft
      final n1Key = GlobalObjectKey<NotificationWidgetState>(n1.id);
      final n2Key = GlobalObjectKey<NotificationWidgetState>(n2.id);
      expect(
        n1Key.currentState?.widget.queue.position,
        equals(QueuePosition.topLeft),
      );
      expect(
        n2Key.currentState?.widget.queue.position,
        equals(QueuePosition.topLeft),
      );

      // Dismiss n1 so the waiting item (n3) mounts
      controller.coordinator?.dismissWidget(n1);
      await tester.pump();
      await tester.pumpAndSettle();

      // n3 must be visible and at topLeft (not topRight!)
      expect(find.text('Message 3'), findsOneWidget);
      final n3Key = GlobalObjectKey<NotificationWidgetState>(n3.id);
      expect(
        n3Key.currentState?.widget.queue.position,
        equals(QueuePosition.topLeft),
      );

      // Dismiss n2 so the second waiting item (n4) mounts
      controller.coordinator?.dismissWidget(n2);
      await tester.pump();
      await tester.pumpAndSettle();

      // n4 must be visible and at topLeft (not topRight!)
      expect(find.text('Message 4'), findsOneWidget);
      final n4Key = GlobalObjectKey<NotificationWidgetState>(n4.id);
      expect(
        n4Key.currentState?.widget.queue.position,
        equals(QueuePosition.topLeft),
      );
    });

    testWidgets(
      'cross-queue same-ID dispatch: moves notification to new position',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'default',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(position: QueuePosition.topRight),
            const NotificationQueue(position: QueuePosition.bottomLeft),
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

        controller.show(
          const AppNotification(
            id: 'moving_notif',
            message: 'Original Top Right',
          ),
          targetPosition: QueuePosition.topRight,
        );
        await tester.pump();
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Original Top Right'), findsOneWidget);

        // Dispatch with same id to bottomLeft
        controller.show(
          const AppNotification(
            id: 'moving_notif',
            message: 'Updated Bottom Left',
          ),
          targetPosition: QueuePosition.bottomLeft,
        );
        await tester.pump();
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Original Top Right'), findsNothing);
        expect(find.text('Updated Bottom Left'), findsOneWidget);
      },
    );

    test(
        'Cluster Invariance: configuring target landing pad as standalone '
        'queue throws', () {
      expect(
        () => NotificationController(
          queues: {
            NotificationQueue(
              position: QueuePosition.topRight,
              longPressDragBehavior: Relocate.to({QueuePosition.topLeft}),
            ),
            const NotificationQueue(
              position: QueuePosition.topLeft,
            ),
          },
        ),
        throwsArgumentError,
      );
    });
  });
}
