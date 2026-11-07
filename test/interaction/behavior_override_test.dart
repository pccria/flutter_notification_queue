// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification-level behavior override unit tests', () {
    test(
      'NotificationWidget dragBehavior and '
      'longPressDragBehavior fields store overrides',
      () {
        final n = NotificationWidget(
          message: 'Override test',
          dragBehavior: const Disabled(),
          longPressDragBehavior: const Reorder(),
        );

        expect(n.dragBehavior, isA<Disabled>());
        expect(n.longPressDragBehavior, isA<Reorder>());
      },
    );

    test(
      'NotificationWidget override fields default to null '
      'when not specified',
      () {
        final n = NotificationWidget(message: 'Default test');

        expect(n.dragBehavior, isNull);
        expect(n.longPressDragBehavior, isNull);
      },
    );

    test(
      'copyToQueue preserves custom dragBehavior and '
      'longPressDragBehavior overrides',
      () {
        final n = NotificationWidget(
          message: 'Override test',
          dragBehavior: const Disabled(),
          longPressDragBehavior: const Reorder(),
        );

        final copy = n.copyToQueue(
          const NotificationQueue(position: QueuePosition.topRight),
        );

        expect(copy.dragBehavior, isA<Disabled>());
        expect(copy.longPressDragBehavior, isA<Reorder>());
      },
    );

    test('copyToQueue preserves null overrides', () {
      final n = NotificationWidget(message: 'Default test');
      final copy = n.copyToQueue(
        const NotificationQueue(position: QueuePosition.topRight),
      );

      expect(copy.dragBehavior, isNull);
      expect(copy.longPressDragBehavior, isNull);
    });
  });

  group('Notification-level behavior override integration tests', () {
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
            dragBehavior: Dismiss(),
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
      'notification with dragBehavior Disabled override '
      'is not dismissible by swipe',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        final notification = NotificationWidget(
          message: 'Sticky Notification',
          channelName: 'test',
          dragBehavior: const Disabled(),
          coordinator: controller.coordinator,
        );

        notification.show();
        await tester.pumpAndSettle();

        final notifFinder = find.text('Sticky Notification');
        expect(notifFinder, findsOneWidget);

        // Perform a swipe right gesture (normally triggers dismiss)
        await tester.drag(notifFinder, const Offset(300, 0));
        await tester.pumpAndSettle();

        // The notification must STILL be present on the screen
        expect(notifFinder, findsOneWidget);
      },
    );

    testWidgets(
      'regular notification in same queue (without override) '
      'remains dismissible',
      (final tester) async {
        await tester.pumpWidget(buildApp());

        final notification = NotificationWidget(
          message: 'Dismissible Notification',
          channelName: 'test',
          coordinator: controller.coordinator,
        );

        notification.show();
        await tester.pumpAndSettle();

        final notifFinder = find.text('Dismissible Notification');
        expect(notifFinder, findsOneWidget);

        // Perform a swipe right gesture (triggers dismiss)
        await tester.drag(notifFinder, const Offset(300, 0));
        await tester.pumpAndSettle();

        // The notification must be DISMISSED from the screen
        expect(notifFinder, findsNothing);
      },
    );
  });
}
