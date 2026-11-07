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
  group('Intent-First Interaction Vocabulary unit tests', () {
    test('Snooze and CustomAction behavior properties are correct', () {
      const snooze = Snooze<OnDrag>(duration: Duration(seconds: 5));
      expect(snooze.duration, const Duration(seconds: 5));

      const custom = CustomAction<OnDrag>(actionName: 'custom_test');
      expect(custom.actionName, 'custom_test');
    });

    test('NotificationWidget handles isPinned and snoozedAt correctly', () {
      final now = DateTime.now();
      final n = NotificationWidget(
        message: 'Intent test',
        initialIsPinned: true,
        snoozedAt: now,
      );

      expect(n.isPinned, isTrue);
      expect(n.snoozedAt, now);

      n.isPinned = false;
      expect(n.isPinned, isFalse);
    });

    test('copyToQueue preserves isPinned and snoozedAt', () {
      final now = DateTime.now();
      final n = NotificationWidget(
        message: 'Copy test',
        initialIsPinned: true,
        snoozedAt: now,
      );

      final copy = n.copyToQueue(
        const NotificationQueue(position: QueuePosition.topRight),
      );
      expect(copy.isPinned, isTrue);
      expect(copy.snoozedAt, now);
    });
  });

  group('Intent-First Coordinator and Event integration tests', () {
    late NotificationController controller;

    setUp(() {
      controller = NotificationController(
        channels: {
          const NotificationChannel(
            name: 'test',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
          const NotificationChannel(
            name: 'default',
            position: QueuePosition.topRight,
            defaultDismissDuration: null,
          ),
        },
        queues: {
          const NotificationQueue(position: QueuePosition.topRight),
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
          home: const Scaffold(body: SizedBox.expand()),
        );

    testWidgets('pin and unpin programmatically toggle state and emit events',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      final n = NotificationWidget(
        id: 'pin_test_id',
        message: 'To be pinned',
        channelName: 'test',
        coordinator: controller.coordinator,
      );

      final List<NotificationEvent> capturedEvents = [];
      final sub = controller.events.listen(capturedEvents.add);

      n.show();
      await tester.pump();
      await tester.pump();

      await _driveAnimation(tester);

      controller.coordinator?.pinWidget(n);
      await tester.pump();
      await tester.pump();

      controller.coordinator?.unpinWidget(n);
      await tester.pump();
      await tester.pump();

      sub.cancel(); // ignore: unawaited_futures

      await _driveAnimation(tester);

      final stateKey = GlobalObjectKey<NotificationWidgetState>(n.id);
      expect(stateKey.currentState?.widget.isPinned, isFalse);
      expect(
        capturedEvents.any(
          (final e) => e is NotificationPinned && e.notification.id == n.id,
        ),
        isTrue,
      );
      expect(
        capturedEvents.any(
          (final e) => e is NotificationUnpinned && e.notification.id == n.id,
        ),
        isTrue,
      );
    });

    testWidgets('custom action triggering emits the correct event',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      final n = NotificationWidget(
        id: 'action_test_id',
        message: 'Custom action target',
        channelName: 'test',
        coordinator: controller.coordinator,
      );

      final List<NotificationEvent> capturedEvents = [];
      final sub = controller.events.listen(capturedEvents.add);

      n.show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      controller.coordinator?.triggerCustomAction(n, 'archive');
      await tester.pump();
      await tester.pump();

      sub.cancel(); // ignore: unawaited_futures
      await _driveAnimation(tester);

      final customEvent = capturedEvents.firstWhere(
        (final e) => e is NotificationCustomActionTriggered,
      ) as NotificationCustomActionTriggered;

      expect(customEvent.notification.id, n.id);
      expect(customEvent.actionName, 'archive');
    });

    testWidgets('snooze programmatically dismisses and schedules re-enqueuing',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      final n = NotificationWidget(
        id: 'snooze_test_id',
        message: 'Snoozed notification',
        channelName: 'test',
        coordinator: controller.coordinator,
      );

      final List<NotificationEvent> capturedEvents = [];
      final sub = controller.events.listen(capturedEvents.add);

      n.show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      expect(find.text('Snoozed notification'), findsOneWidget);

      controller.coordinator?.snoozeWidget(
        n,
        const Duration(milliseconds: 500),
      );

      await tester.pump();

      sub.cancel(); // ignore: unawaited_futures

      await tester.pumpAndSettle();

      expect(find.text('Snoozed notification'), findsNothing);
      expect(
        capturedEvents.any(
          (final e) => e is NotificationSnoozed && e.notification.id == n.id,
        ),
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 550));

      await _driveAnimation(tester);

      expect(find.text('Snoozed notification'), findsOneWidget);
    });

    testWidgets(
        'pinned notification does not auto-dismiss when duration expires',
        (final tester) async {
      await tester.pumpWidget(buildApp());

      final n = NotificationWidget(
        id: 'pinned_dismiss_test',
        message: 'Pinned but with duration',
        channelName: 'test',
        dismissDuration: const Duration(milliseconds: 200),
        initialIsPinned: true,
        coordinator: controller.coordinator,
      );

      final List<NotificationEvent> capturedEvents = [];
      final sub = controller.events.listen(capturedEvents.add);

      n.show();
      await tester.pump();
      await tester.pump();
      await _driveAnimation(tester);

      expect(find.text('Pinned but with duration'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('Pinned but with duration'), findsOneWidget);
      expect(
        capturedEvents.any(
          (final e) => e is NotificationDismissed && e.notification.id == n.id,
        ),
        isFalse,
      );

      controller.coordinator?.unpinWidget(n);
      await tester.pump();
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      sub.cancel(); // ignore: unawaited_futures

      expect(find.text('Pinned but with duration'), findsNothing);
      expect(
        capturedEvents.any(
          (final e) =>
              e is NotificationDismissed &&
              e.notification.id == n.id &&
              e.reason == DismissReason.timeout,
        ),
        isTrue,
      );
    });
  });
}
