import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reorder Interaction via onDragEnd', () {
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
          const NotificationQueue(
            position: QueuePosition.topRight,
            dragBehavior: Reorder(),
            longPressDragBehavior: Reorder(),
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

    testWidgets('Reorders items within the same queue', (final tester) async {
      await tester.pumpWidget(buildApp());

      final notification1 = NotificationWidget(
        message: 'Item 1',
        channelName: 'test',
        coordinator: controller.coordinator,
      );

      final notification2 = NotificationWidget(
        message: 'Item 2',
        channelName: 'test',
        coordinator: controller.coordinator,
      );

      notification1.show();
      await tester.pumpAndSettle();

      notification2.show();
      await tester.pumpAndSettle();

      final notifFinder1 = find.text('Item 1');
      final notifFinder2 = find.text('Item 2');
      expect(notifFinder1, findsOneWidget);
      expect(notifFinder2, findsOneWidget);

      final startPos = tester.getCenter(notifFinder2);
      final targetPos = tester.getCenter(notifFinder1);

      final gesture = await tester.startGesture(startPos);
      await tester.pump(const Duration(milliseconds: 100));

      // Move in small steps
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveTo(targetPos);
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();

      final newPos1 = tester.getCenter(notifFinder1);
      final newPos2 = tester.getCenter(notifFinder2);

      // Item 2 should now be visually at Item 1's old position
      expect(newPos2.dy, closeTo(targetPos.dy, 1.0));
      // Item 1 should be shifted down
      expect(newPos1.dy, closeTo(startPos.dy, 1.0));
    });

    testWidgets('Shifts items visually during drag before drop',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      final notification1 = NotificationWidget(
        message: 'Item 1',
        channelName: 'test',
        coordinator: controller.coordinator,
      );

      final notification2 = NotificationWidget(
        message: 'Item 2',
        channelName: 'test',
        coordinator: controller.coordinator,
      );

      notification1.show();
      await tester.pumpAndSettle();

      notification2.show();
      await tester.pumpAndSettle();

      final notifFinder1 = find.text('Item 1');
      final notifFinder2 = find.text('Item 2');

      final startPos = tester.getCenter(notifFinder2);
      final targetPos = tester.getCenter(notifFinder1);

      final gesture = await tester.startGesture(startPos);
      await tester.pump(const Duration(milliseconds: 100));

      // Drag Item 2 towards Item 1's location (break gesture slop)
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();

      // Drag to targetPos
      await gesture.moveTo(targetPos);
      await tester.pump();
      // Wait for AnimatedContainer shift duration
      await tester.pump(const Duration(milliseconds: 300));

      // Measure Item 1's position. It should have shifted down into
      // Item 2's space.
      final shiftedPos1 = tester.getCenter(notifFinder1);
      expect(shiftedPos1.dy, closeTo(startPos.dy, 5.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
