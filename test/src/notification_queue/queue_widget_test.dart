import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_notification_queue/src/notification_queue/notification_queue.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper to access state
QueueWidgetState getState(final WidgetTester tester) =>
    tester.state<QueueWidgetState>(find.byType(QueueWidget));

void _enqueue(final QueueWidgetState state, final NotificationWidget n) {
  state.enqueue(NotificationEntry(blueprint: n, queue: n.queue));
}

void main() {
  group('QueueWidgetState', () {
    late NotificationController controller;
    late QueueCoordinator coordinator;

    setUp(() {
      controller = NotificationController(
        queues: {
          const NotificationQueue(
            position: QueuePosition.topRight,
            maxStackSize: 2,
          ),
        },
        channels: {
          const NotificationChannel(
            name: 'default',
            description: 'Default channel',
            defaultDismissDuration: null,
          ),
        },
      );
      coordinator = QueueCoordinator.fromController(controller);
      controller.attach(coordinator);
    });

    tearDown(() {
      controller.detach();
      coordinator.dispose();
      controller.dispose();
    });

    Widget buildDirectQueue({required final NotificationQueue queue}) =>
        MaterialApp(
          home: Scaffold(
            body: QueueWidget(
              queue: queue,
              coordinator: coordinator,
            ),
          ),
        );

    testWidgets('enqueue adds to active list immediately if under limit',
        (final tester) async {
      await tester.pumpWidget(
        buildDirectQueue(
          queue: const NotificationQueue(
            position: QueuePosition.topRight,
            maxStackSize: 2,
          ),
        ),
      );

      final state = getState(tester);
      final notification = NotificationWidget(
        id: 'n1',
        message: 'Message 1',
        coordinator: coordinator,
      );

      _enqueue(state, notification);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Message 1'), findsOneWidget);
    });

    testWidgets('enqueue adds to pending if over limit', (final tester) async {
      await tester.pumpWidget(
        buildDirectQueue(
          queue: const NotificationQueue(
            position: QueuePosition.topRight,
            maxStackSize: 2,
          ),
        ),
      );

      final state = getState(tester);
      final n1 = NotificationWidget(
        id: 'n1',
        message: 'Message 1',
        coordinator: coordinator,
      );
      final n2 = NotificationWidget(
        id: 'n2',
        message: 'Message 2',
        coordinator: coordinator,
      );
      final n3 = NotificationWidget(
        id: 'n3',
        message: 'Message 3',
        coordinator: coordinator,
      );

      _enqueue(state, n1);
      _enqueue(state, n2);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Message 1'), findsOneWidget);
      expect(find.text('Message 2'), findsOneWidget);

      _enqueue(state, n3);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Message 3'), findsNothing); // Should be pending
    });

    testWidgets('dismiss promotes pending item', (final tester) async {
      await tester.pumpWidget(
        buildDirectQueue(
          queue: const NotificationQueue(
            position: QueuePosition.topRight,
            maxStackSize: 2,
          ),
        ),
      );

      final state = getState(tester);
      final n1 = NotificationWidget(
        id: 'n1',
        message: 'Message 1',
        coordinator: coordinator,
      );
      final n2 = NotificationWidget(
        id: 'n2',
        message: 'Message 2',
        coordinator: coordinator,
      );
      final n3 = NotificationWidget(
        id: 'n3',
        message: 'Message 3',
        coordinator: coordinator,
      );

      _enqueue(state, n1);
      _enqueue(state, n2);
      _enqueue(state, n3);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Message 3'), findsNothing);

      state.dismiss(n1);
      await tester.pumpAndSettle();

      expect(find.text('Message 3'), findsOneWidget);
      expect(find.text('Message 1'), findsNothing);
    });

    testWidgets('update existing notification (active)', (final tester) async {
      await tester.pumpWidget(
        buildDirectQueue(
          queue: const NotificationQueue(position: QueuePosition.topRight),
        ),
      );

      final state = getState(tester);
      final n1 = NotificationWidget(
        id: 'n1',
        message: 'Original',
        coordinator: coordinator,
      );
      _enqueue(state, n1);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsOneWidget);

      final n1Update = NotificationWidget(
        id: 'n1',
        message: 'Updated',
        coordinator: coordinator,
      );
      _enqueue(state, n1Update);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('Original'), findsNothing);
    });
  });
}
