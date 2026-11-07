import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reorder & Relocate Null Safety', () {
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
            dragBehavior: ReorderAndRelocate.to(
              positions: {
                QueuePosition.topRight,
                QueuePosition.topLeft,
              },
            ),
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

    testWidgets(
      'Reorder dragging feedback builds cleanly without null coordinator '
      'errors',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        final n1 = NotificationWidget(
          message: 'First item',
          channelName: 'test',
          coordinator: controller.coordinator,
        );
        final n2 = NotificationWidget(
          message: 'Second item',
          channelName: 'test',
          coordinator: controller.coordinator,
        );

        n1.show();
        await tester.pumpAndSettle();
        n2.show();
        await tester.pumpAndSettle();

        final finder2 = find.text('Second item');
        final finder1 = find.text('First item');

        final startPos = tester.getCenter(finder2);
        final targetPos = tester.getCenter(finder1);

        final gesture = await tester.startGesture(startPos);
        await tester.pump(const Duration(milliseconds: 100));

        await gesture.moveTo(targetPos);
        await tester.pump();

        expect(find.text('Second item'), findsWidgets);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Relocate preserves effectiveCoordinator without null exception after '
      'relocation',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        NotificationWidget(
          message: 'Relocate item',
          channelName: 'test',
          coordinator: controller.coordinator,
        ).show();
        await tester.pumpAndSettle();

        final notifFinder = find.text('Relocate item');
        final startPos = tester.getCenter(notifFinder);

        await tester.drag(notifFinder, Offset(-startPos.dx, -startPos.dy));
        await tester.pumpAndSettle();

        expect(find.text('Relocate item'), findsOneWidget);
        final activeQueues = controller.coordinator?.activeQueues.value;
        expect(activeQueues?.containsKey(QueuePosition.topLeft), isTrue);

        final activeNotifs = controller.coordinator?.activeNotifications;
        expect(activeNotifs, isNotEmpty);
        expect(
          activeNotifs?.first.effectiveCoordinator,
          equals(controller.coordinator),
        );
      },
    );
  });
}
