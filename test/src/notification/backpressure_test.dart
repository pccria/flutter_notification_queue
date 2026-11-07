import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _driveAnimation(final WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Backpressure Strategy Integration Tests', () {
    testWidgets(
      'unbounded pending queue by default (no capacity limit)',
      timeout: const Timeout(Duration(seconds: 3)),
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'default',
              position: QueuePosition.topCenter,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topCenter,
              style: FlatQueueStyle(opacity: 1.0),
              maxStackSize: 1,
              maxPendingSize: null, // default is null
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
            home: const Scaffold(
              body: SizedBox.expand(),
            ),
          ),
        );

        final n1 = NotificationWidget(
          id: 'n1',
          message: 'Item 1',
          coordinator: controller.coordinator,
        );
        final n2 = NotificationWidget(
          id: 'n2',
          message: 'Item 2',
          coordinator: controller.coordinator,
        );
        final n3 = NotificationWidget(
          id: 'n3',
          message: 'Item 3',
          coordinator: controller.coordinator,
        );
        final n4 = NotificationWidget(
          id: 'n4',
          message: 'Item 4',
          coordinator: controller.coordinator,
        );
        final n5 = NotificationWidget(
          id: 'n5',
          message: 'Item 5',
          coordinator: controller.coordinator,
        );

        n1.show();
        n2.show();
        n3.show();
        n4.show();
        n5.show();

        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsNothing);

        unawaited(n1.dismiss());
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Item 2'), findsOneWidget);

        unawaited(n2.dismiss());
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Item 3'), findsOneWidget);
      },
    );

    testWidgets(
      'discardOldest strategy drops oldest pending and '
      'emits QueueOverflowed event',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'default',
              position: QueuePosition.topCenter,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topCenter,
              style: FlatQueueStyle(opacity: 1.0),
              maxStackSize: 1,
              maxPendingSize: 2,
              overflowStrategy: QueueOverflowStrategy.discardOldest,
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
            home: const Scaffold(
              body: SizedBox.expand(),
            ),
          ),
        );

        final events = <NotificationEvent>[];
        final subscription = controller.events.listen(events.add);

        final n1 = NotificationWidget(
          id: 'n1',
          message: 'Active Item',
          coordinator: controller.coordinator,
        );
        final n2 = NotificationWidget(
          id: 'n2',
          message: 'Pending Item 2',
          coordinator: controller.coordinator,
        );
        final n3 = NotificationWidget(
          id: 'n3',
          message: 'Pending Item 3',
          coordinator: controller.coordinator,
        );
        final n4 = NotificationWidget(
          id: 'n4',
          message: 'Pending Item 4',
          coordinator: controller.coordinator,
        );

        n1.show();
        n2.show();
        n3.show();

        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Active Item'), findsOneWidget);

        n4.show();
        await tester.pump();
        await _driveAnimation(tester);

        final overflowEvents = events.whereType<QueueOverflowed>().toList();
        expect(overflowEvents.length, 1);
        expect(overflowEvents.first.dropped.id, 'n2');

        unawaited(n1.dismiss());
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Pending Item 3'), findsOneWidget);
        expect(find.text('Pending Item 2'), findsNothing);

        unawaited(n3.dismiss());
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Pending Item 4'), findsOneWidget);

        subscription.cancel(); // ignore: unawaited_futures
      },
    );

    testWidgets(
      'discardNewest strategy rejects incoming item and '
      'emits QueueOverflowed event',
      (final tester) async {
        final controller = NotificationController(
          channels: {
            const NotificationChannel(
              name: 'default',
              position: QueuePosition.topCenter,
              defaultDismissDuration: null,
            ),
          },
          queues: {
            const NotificationQueue(
              position: QueuePosition.topCenter,
              style: FlatQueueStyle(opacity: 1.0),
              maxStackSize: 1,
              maxPendingSize: 2,
              overflowStrategy: QueueOverflowStrategy.discardNewest,
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
            home: const Scaffold(
              body: SizedBox.expand(),
            ),
          ),
        );

        final events = <NotificationEvent>[];
        final subscription = controller.events.listen(events.add);

        final n1 = NotificationWidget(
          id: 'n1',
          message: 'Active Item',
          coordinator: controller.coordinator,
        );
        final n2 = NotificationWidget(
          id: 'n2',
          message: 'Pending Item 2',
          coordinator: controller.coordinator,
        );
        final n3 = NotificationWidget(
          id: 'n3',
          message: 'Pending Item 3',
          coordinator: controller.coordinator,
        );
        final n4 = NotificationWidget(
          id: 'n4',
          message: 'Pending Item 4',
          coordinator: controller.coordinator,
        );

        n1.show();
        n2.show();
        n3.show();

        await tester.pump();
        await _driveAnimation(tester);

        n4.show();
        await tester.pump();
        await _driveAnimation(tester);

        final overflowEvents = events.whereType<QueueOverflowed>().toList();
        expect(overflowEvents.length, 1);
        expect(overflowEvents.first.dropped.id, 'n4');

        unawaited(n1.dismiss());
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Pending Item 2'), findsOneWidget);

        unawaited(n2.dismiss());
        await tester.pump();
        await _driveAnimation(tester);

        expect(find.text('Pending Item 3'), findsOneWidget);
        expect(find.text('Pending Item 4'), findsNothing);

        subscription.cancel(); // ignore: unawaited_futures
      },
    );
  });
}
