// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_notification_queue/src/notification_queue/notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dismiss & Relocate Interaction via onDragEnd', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          NotificationQueue(
            position: QueuePosition.topRight,
            dragBehavior: Relocate.to({QueuePosition.topLeft}),
            longPressDragBehavior: const Dismiss(),
          ),
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildApp() => MaterialApp(
          builder: (final context, final child) => NotificationScope(
            controller: controller,
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox.expand(),
          ),
        );

    testWidgets('Relocates to topLeft on standard drag', (final tester) async {
      await tester.pumpWidget(buildApp());

      NotificationWidget(
        message: 'Drag me',
        channelName: 'test',
        coordinator: controller.coordinator,
      ).show();
      await tester.pumpAndSettle();

      final notifFinder = find.byType(NotificationWidget);
      expect(notifFinder, findsOneWidget);

      // Get start position to calculate exact offset to (0,0)
      final startPos = tester.getCenter(notifFinder);

      // Drag exactly to topLeft (0,0)
      await tester.drag(notifFinder, Offset(-startPos.dx, -startPos.dy));
      await tester.pumpAndSettle();

      // Verify it is now in topLeft queue (topRight queue should be unmounted)
      expect(find.byType(NotificationWidget), findsOneWidget);

      final activeQueues = controller.coordinator?.activeQueues.value;
      expect(activeQueues?.containsKey(QueuePosition.topRight), isFalse);
      expect(activeQueues?.containsKey(QueuePosition.topLeft), isTrue);
    });

    testWidgets('Dismisses to right edge on long press drag',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      NotificationWidget(
        message: 'Dismiss me',
        channelName: 'test',
        coordinator: controller.coordinator,
      ).show();
      await tester.pumpAndSettle();

      final notifFinder = find.byType(NotificationWidget);
      expect(notifFinder, findsOneWidget);

      // Start long press drag
      final gesture = await tester.startGesture(tester.getCenter(notifFinder));
      // Wait for long press to activate
      await tester.pump(const Duration(milliseconds: 600));

      // Drag towards the right edge (x > 750, assuming 800x600 screen)
      await gesture.moveTo(const Offset(780, 100));
      await tester.pump();

      // Drop
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify it was dismissed
      expect(find.byType(NotificationWidget), findsNothing);

      final activeQueues = controller.coordinator?.activeQueues.value;
      expect(activeQueues?.containsKey(QueuePosition.topRight), isFalse);
    });

    testWidgets(
      'ReorderAndRelocate: dragging out of container and back restores '
      'reorder drag state',
      (final tester) async {
        final reorderController = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'reorder_chan',
              position: QueuePosition.topCenter,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            NotificationQueue(
              position: QueuePosition.topCenter,
              dragBehavior: ReorderAndRelocate.to(
                positions: {QueuePosition.bottomCenter},
              ),
            ),
          },
        );
        addTearDown(reorderController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (final context, final child) => NotificationScope(
              controller: reorderController,
              child: child!,
            ),
            home: const Scaffold(body: SizedBox.expand()),
          ),
        );

        NotificationWidget(
          message: 'Card 1',
          channelName: 'reorder_chan',
          coordinator: reorderController.coordinator,
        ).show();
        await tester.pumpAndSettle();

        NotificationWidget(
          message: 'Card 2',
          channelName: 'reorder_chan',
          coordinator: reorderController.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final queueWidgetState = tester.state<QueueWidgetState>(
          find.byType(QueueWidget),
        );

        // Start reorder drag at origin index 0
        queueWidgetState.startDragReorder('item-1', 0);
        expect(queueWidgetState.reorderDragState.value?.target, equals(0));

        // Update target inside queue
        queueWidgetState.updateDragTarget(1);
        expect(queueWidgetState.reorderDragState.value?.target, equals(1));

        // Drag escaped container (relocating state)
        queueWidgetState.clearDragTarget();
        expect(queueWidgetState.reorderDragState.value, isNull);

        // Drag returned inside container (reordering state)
        queueWidgetState.updateDragTarget(1);
        expect(queueWidgetState.reorderDragState.value, isNotNull);
        expect(queueWidgetState.reorderDragState.value?.origin, equals(0));
        expect(queueWidgetState.reorderDragState.value?.target, equals(1));

        queueWidgetState.endDragReorder();
        expect(queueWidgetState.reorderDragState.value, isNull);
      },
    );
  });
}
