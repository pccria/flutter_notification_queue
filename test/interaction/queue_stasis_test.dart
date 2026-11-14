import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Queue-Level Timer Stasis', () {
    testWidgets(
      'pauseQueue and resumeQueue freeze and resume dismiss timers for queue',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'timed',
              position: QueuePosition.topRight,
              defaultDismissDuration: Duration(seconds: 3),
            ),
          },
          queues: {
            const NotificationQueue(position: QueuePosition.topRight),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        controller.show(
          const AppNotification(
            id: 'n1',
            message: 'Stasis Card',
            channelName: 'timed',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Stasis Card'), findsOneWidget);

        // Advance 1 second — timer is ticking
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Stasis Card'), findsOneWidget);

        // Put the queue in stasis
        controller.pauseQueue(QueuePosition.topRight);
        await tester.pump();

        expect(controller.isQueuePaused(QueuePosition.topRight), isTrue);

        // Advance 5 seconds — well beyond the 3s total duration
        await tester.pump(const Duration(seconds: 5));

        // Card MUST still be visible!
        expect(find.text('Stasis Card'), findsOneWidget);

        // Resume queue
        controller.resumeQueue(QueuePosition.topRight);
        await tester.pump();

        expect(controller.isQueuePaused(QueuePosition.topRight), isFalse);

        // Remaining time is ~2 seconds. Advance 1s (still visible)
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Stasis Card'), findsOneWidget);

        // Advance 1.5s more: card dismisses cleanly
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        expect(find.text('Stasis Card'), findsNothing);
      },
    );

    testWidgets(
      'pauseAll and resumeAll freeze and resume timers across all queues',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'timed_right',
              position: QueuePosition.topRight,
              defaultDismissDuration: Duration(seconds: 3),
            ),
            const NotificationChannel(
              name: 'timed_left',
              position: QueuePosition.topLeft,
              defaultDismissDuration: Duration(seconds: 3),
            ),
          },
          queues: {
            const NotificationQueue(position: QueuePosition.topRight),
            const NotificationQueue(position: QueuePosition.topLeft),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        controller
          ..show(
            const AppNotification(
              id: 'right_1',
              message: 'Right Card',
              channelName: 'timed_right',
            ),
          )
          ..show(
            const AppNotification(
              id: 'left_1',
              message: 'Left Card',
              channelName: 'timed_left',
            ),
          );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Right Card'), findsOneWidget);
        expect(find.text('Left Card'), findsOneWidget);

        // Pause all queues
        controller.pauseAll();
        await tester.pump();

        expect(controller.isQueuePaused(QueuePosition.topRight), isTrue);
        expect(controller.isQueuePaused(QueuePosition.topLeft), isTrue);

        // Advance 10 seconds in stasis
        await tester.pump(const Duration(seconds: 10));

        expect(find.text('Right Card'), findsOneWidget);
        expect(find.text('Left Card'), findsOneWidget);

        // Resume all
        controller.resumeAll();
        await tester.pump();

        expect(controller.isQueuePaused(QueuePosition.topRight), isFalse);
        expect(controller.isQueuePaused(QueuePosition.topLeft), isFalse);

        // Advance 3.5s to let both dismiss
        await tester.pump(const Duration(milliseconds: 3500));
        await tester.pumpAndSettle();

        expect(find.text('Right Card'), findsNothing);
        expect(find.text('Left Card'), findsNothing);
      },
    );

    testWidgets(
      'Cross-queue relocation puts source and target queues into stasis',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'source_chan',
              position: QueuePosition.topRight,
              defaultDismissDuration: Duration(seconds: 3),
            ),
            const NotificationChannel(
              name: 'target_chan',
              position: QueuePosition.topLeft,
              defaultDismissDuration: Duration(seconds: 3),
            ),
            const NotificationChannel(
              name: 'neutral_chan',
              position: QueuePosition.bottomCenter,
              defaultDismissDuration: Duration(seconds: 3),
            ),
          },
          queues: {
            const NotificationQueue(position: QueuePosition.topRight),
            const NotificationQueue(position: QueuePosition.topLeft),
            const NotificationQueue(position: QueuePosition.bottomCenter),
          },
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: controller,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        controller
          ..show(
            const AppNotification(
              id: 'src_card',
              message: 'Source Card',
              channelName: 'source_chan',
            ),
          )
          ..show(
            const AppNotification(
              id: 'tgt_card',
              message: 'Target Card',
              channelName: 'target_chan',
            ),
          )
          ..show(
            const AppNotification(
              id: 'neu_card',
              message: 'Neutral Card',
              channelName: 'neutral_chan',
            ),
          );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Source Card'), findsOneWidget);
        expect(find.text('Target Card'), findsOneWidget);
        expect(find.text('Neutral Card'), findsOneWidget);

        // Simulate cross-queue relocation interaction focus between
        // topRight (source) and topLeft (target)
        controller.coordinator?.setInteractionFocus(
          source: QueuePosition.topRight,
          target: QueuePosition.topLeft,
        );
        await tester.pump();

        // Advance 4 seconds (longer than 3s dismissDuration) + transition
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Source and Target queues MUST be frozen in stasis!
        expect(find.text('Source Card'), findsOneWidget);
        expect(find.text('Target Card'), findsOneWidget);

        // Neutral queue was NOT part of the relocation, so it expired!
        expect(find.text('Neutral Card'), findsNothing);

        // Clear interaction focus
        controller.coordinator?.clearInteractionFocus();
        await tester.pump();

        // Advance remaining time for source and target
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('Source Card'), findsNothing);
        expect(find.text('Target Card'), findsNothing);
      },
    );

    testWidgets(
      'Reorder drag inside a queue freezes timers for sibling cards',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'reorder_chan',
              position: QueuePosition.topRight,
              defaultDismissDuration: Duration(seconds: 3),
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topRight,
              dragBehavior: Reorder(),
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
            home: const Scaffold(body: Center(child: Text('App Home'))),
          ),
        );

        controller
          ..show(
            const AppNotification(
              id: 'item_1',
              message: 'Item 1',
              channelName: 'reorder_chan',
            ),
          )
          ..show(
            const AppNotification(
              id: 'item_2',
              message: 'Item 2',
              channelName: 'reorder_chan',
            ),
          );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);

        // Start dragging Item 2 to reorder
        final startPos = tester.getCenter(find.text('Item 2'));
        final gesture = await tester.startGesture(startPos);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();

        // While dragging Item 2, advance 4 seconds in stasis
        await tester.pump(const Duration(seconds: 4));

        // Both items MUST still be alive!
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);

        // Finish the drag (drop)
        await gesture.up();
        await tester.pumpAndSettle();

        // Advance 4s after drop: both items dismiss cleanly
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('Item 1'), findsNothing);
        expect(find.text('Item 2'), findsNothing);
      },
    );
  });
}
