import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueCoordinator Performance & Backlog Integrity', () {
    const trQueue = NotificationQueue(
      position: QueuePosition.topRight,
      maxStackSize: 2,
    );

    const blQueue = NotificationQueue(
      position: QueuePosition.bottomLeft,
      maxStackSize: 3,
    );

    Widget buildApp(final NotificationController controller) => MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.expand()),
        );

    NotificationController createController() => NotificationController(
          queues: {trQueue, blQueue},
          channels: {
            const NotificationChannel(
              name: 'default',
              description: 'Default channel',
              position: QueuePosition.topRight,
              defaultDismissDuration: null,
            ),
          },
        );

    testWidgets(
      'controller.dismiss emits NotificationDismissed for active card',
      (final tester) async {
        final controller = createController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(buildApp(controller));
        await tester.pump();

        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        controller.show(
          const AppNotification(
            id: 'active_1',
            message: 'Active Notification',
            permanent: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Active Notification'), findsOneWidget);

        controller.dismiss(
          const AppNotification(
            id: 'active_1',
            message: 'Active Notification',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Active Notification'), findsNothing);

        final dismissedEvents =
            events.whereType<NotificationDismissed>().toList();
        expect(dismissedEvents.length, 1);
        expect(dismissedEvents.first.notification.id, 'active_1');
        expect(
          dismissedEvents.first.reason,
          DismissReason.programmatic,
        );
      },
    );

    testWidgets(
      'controller.dismiss emits NotificationDismissed for pending backlog card',
      (final tester) async {
        final controller = createController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(buildApp(controller));
        await tester.pump();

        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        // Fill maxStackSize = 2
        controller
          ..show(
            const AppNotification(
              id: 'c1',
              message: 'Card 1',
              permanent: true,
            ),
          )
          ..show(
            const AppNotification(
              id: 'c2',
              message: 'Card 2',
              permanent: true,
            ),
          )
          // c3 will be queued into pending backlog
          ..show(
            const AppNotification(
              id: 'c3',
              message: 'Card 3',
              permanent: true,
            ),
          );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Card 1'), findsOneWidget);
        expect(find.text('Card 2'), findsOneWidget);
        expect(find.text('Card 3'), findsNothing);

        // Dismiss pending card c3 directly
        controller.dismiss(
          const AppNotification(id: 'c3', message: 'Card 3'),
        );
        await tester.pump();

        final dismissedEvents =
            events.whereType<NotificationDismissed>().toList();
        expect(
          dismissedEvents.any((final e) => e.notification.id == 'c3'),
          isTrue,
        );

        // Dismiss c1 -> c3 should NOT be promoted because it was dismissed
        controller.dismiss(
          const AppNotification(id: 'c1', message: 'Card 1'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Card 3'), findsNothing);
      },
    );

    testWidgets(
      'priority eviction preserves coordinator position tracking upon '
      're-queue',
      (final tester) async {
        final controller = createController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(buildApp(controller));
        await tester.pump();

        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        // Enqueue 2 low priority items (filling maxStackSize = 2)
        controller
          ..show(
            const AppNotification(
              id: 'low_1',
              message: 'Low 1',
              priority: NotificationPriority.low,
              permanent: true,
            ),
          )
          ..show(
            const AppNotification(
              id: 'low_2',
              message: 'Low 2',
              priority: NotificationPriority.low,
              permanent: true,
            ),
          );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Low 1'), findsOneWidget);
        expect(find.text('Low 2'), findsOneWidget);

        // Enqueue critical item -> triggers priority eviction of low_1
        controller.show(
          const AppNotification(
            id: 'crit_1',
            message: 'Critical 1',
            priority: NotificationPriority.critical,
            permanent: true,
          ),
        );

        // Advance frames to complete reverse exit animation of evicted card
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Critical 1'), findsOneWidget);

        // Verify eviction event was emitted with DismissReason.evicted
        final evictedEvents = events
            .whereType<NotificationDismissed>()
            .where((final e) => e.reason == DismissReason.evicted)
            .toList();
        expect(evictedEvents.length, 1);

        // Dismiss the critical item -> evicted low card should be re-promoted
        controller.dismiss(
          const AppNotification(id: 'crit_1', message: 'Critical 1'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // The evicted item should now be visible again
        final rePromotedId = evictedEvents.first.notification.id;
        controller.pin(
          AppNotification(id: rePromotedId, message: 'Low'),
        );
        await tester.pump();

        final pinEvents = events.whereType<NotificationPinned>().toList();
        expect(
          pinEvents.any((final e) => e.notification.id == rePromotedId),
          isTrue,
        );
      },
    );

    testWidgets(
      'stress: rapid 100 notification dispatch, relocate, pin, and dismiss',
      (final tester) async {
        final controller = createController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(buildApp(controller));
        await tester.pump();

        final events = <NotificationEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(sub.cancel);

        // Enqueue 100 notifications rapidly
        for (int i = 0; i < 100; i++) {
          controller.show(
            AppNotification(
              id: 'notif_$i',
              message: 'Message $i',
              priority: i.isEven
                  ? NotificationPriority.normal
                  : NotificationPriority.high,
              permanent: true,
            ),
          );
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Pin active notification
        controller.pin(
          const AppNotification(id: 'notif_99', message: 'Message 99'),
        );
        await tester.pump();

        // Unpin active notification
        controller.unpin(
          const AppNotification(id: 'notif_99', message: 'Message 99'),
        );
        await tester.pump();

        // Relocate active notification to bottomLeft
        controller.relocate(
          const AppNotification(id: 'notif_99', message: 'Message 99'),
          QueuePosition.bottomLeft,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Dismiss active items
        controller.dismissAll();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          events.whereType<NotificationDismissed>().isNotEmpty,
          isTrue,
        );
      },
    );
  });
}
