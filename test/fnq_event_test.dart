import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late NotificationController controller;
  late QueueCoordinator coordinator;

  setUp(() {
    controller = NotificationController(
      queues: {
        const NotificationQueue(position: QueuePosition.topLeft),
        const NotificationQueue(position: QueuePosition.topRight),
      },
      channels: {
        const NotificationChannel(
          name: 'info',
          position: QueuePosition.topLeft,
          defaultDismissDuration: null,
        ),
        const NotificationChannel(
          name: 'disabled_ch',
          enabled: false,
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

  // ── Helpers ──

  NotificationWidget makeWidget({
    final String? id,
    final String channelName = 'info',
    final TapBehavior? tapBehavior,
  }) =>
      NotificationWidget(
        title: 'Test',
        message: 'Test message',
        channelName: channelName,
        tapBehavior: tapBehavior,
        coordinator: coordinator,
      );

  // ── NotificationQueued ─────────────────────────────────────────────────────

  group('NotificationQueued', () {
    test('emits when show() is called', () async {
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      makeWidget().show();
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.first, isA<NotificationQueued>());
      sub.cancel(); // ignore: unawaited_futures
    });

    test('does NOT emit when channel is disabled', () async {
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      makeWidget(channelName: 'disabled_ch').show();
      await Future.delayed(Duration.zero);

      expect(events, isEmpty);
      sub.cancel(); // ignore: unawaited_futures
    });

    test('carries correct notification reference', () async {
      final n = makeWidget();
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      n.show();
      await Future.delayed(Duration.zero);

      final queued = events.first as NotificationQueued;
      expect(queued.notification.id, equals(n.id));
      sub.cancel(); // ignore: unawaited_futures
    });
  });

  // ── NotificationDismissed — programmatic ──────────────────────────────────

  group('NotificationDismissed (programmatic)', () {
    test('emits NotificationDismissed with reason=programmatic', () async {
      final n = makeWidget();
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.emitEvent(
        NotificationDismissed(
          notification: n,
          reason: DismissReason.programmatic,
        ),
      );
      await Future.delayed(Duration.zero);

      final dismissed = events.whereType<NotificationDismissed>().first;
      expect(dismissed.reason, DismissReason.programmatic);
      sub.cancel(); // ignore: unawaited_futures
    });

    test('emits with reason=timeout', () async {
      final n = makeWidget();
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.emitEvent(
        NotificationDismissed(
          notification: n,
          reason: DismissReason.timeout,
        ),
      );
      await Future.delayed(Duration.zero);

      final dismissed = events.whereType<NotificationDismissed>().first;
      expect(dismissed.reason, DismissReason.timeout);
      sub.cancel(); // ignore: unawaited_futures
    });

    test('emits with reason=userSwipe', () async {
      final n = makeWidget();
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.emitEvent(
        NotificationDismissed(
          notification: n,
          reason: DismissReason.userSwipe,
        ),
      );
      await Future.delayed(Duration.zero);

      final dismissed = events.whereType<NotificationDismissed>().first;
      expect(dismissed.reason, DismissReason.userSwipe);
      sub.cancel(); // ignore: unawaited_futures
    });

    test('emits with reason=userTap', () async {
      final n = makeWidget();
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.emitEvent(
        NotificationDismissed(
          notification: n,
          reason: DismissReason.userTap,
        ),
      );
      await Future.delayed(Duration.zero);

      final dismissed = events.whereType<NotificationDismissed>().first;
      expect(dismissed.reason, DismissReason.userTap);
      sub.cancel(); // ignore: unawaited_futures
    });
  });

  // ── NotificationRelocated ─────────────────────────────────────────────────

  group('NotificationRelocated', () {
    test('emits NotificationRelocated with correct from/to positions',
        () async {
      final n = NotificationWidget(
        title: 'Relocate me',
        message: 'Relocate message',
        channelName: 'info',
        position: QueuePosition.topLeft,
        coordinator: controller.coordinator,
      );

      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.emitEvent(
        NotificationRelocated(
          notification: n,
          from: QueuePosition.topLeft,
          to: QueuePosition.topRight,
        ),
      );
      await Future.delayed(Duration.zero);

      final relocated = events.whereType<NotificationRelocated>();
      expect(relocated, isNotEmpty);
      final r = relocated.first;
      expect(r.from, QueuePosition.topLeft);
      expect(r.to, QueuePosition.topRight);
      sub.cancel(); // ignore: unawaited_futures
    });
  });

  // ── NotificationReordered ─────────────────────────────────────────────────

  group('NotificationReordered', () {
    test('emits with correct toIndex', () async {
      final n = makeWidget();
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.reorderWidget(n, 2);
      await Future.delayed(Duration.zero);

      final reordered = events.whereType<NotificationReordered>().first;
      expect(reordered.toIndex, 2);
      expect(reordered.notification.id, n.id);
      sub.cancel(); // ignore: unawaited_futures
    });
  });

  // ── Stream integrity ──────────────────────────────────────────────────────

  group('Stream integrity', () {
    test('supports multiple concurrent listeners', () async {
      final a = <NotificationEvent>[];
      final b = <NotificationEvent>[];
      final subA = controller.events.listen(a.add);
      final subB = controller.events.listen(b.add);

      makeWidget().show();
      await Future.delayed(Duration.zero);

      expect(a, hasLength(1));
      expect(b, hasLength(1));
      subA.cancel(); // ignore: unawaited_futures
      subB.cancel(); // ignore: unawaited_futures
    });

    test('controller.events is a broadcast stream', () {
      expect(
        controller.events.isBroadcast,
        isTrue,
      );
    });
  });

  group('NotificationTapped', () {
    test('NotificationTapped carries correct behavior type via emitTapped',
        () async {
      final n = makeWidget(tapBehavior: const TapToExpand());
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.emitTapped(
        notification: n,
        behavior: const TapToExpand(),
      );
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      final tapped = events.first as NotificationTapped;
      expect(tapped.behavior, isA<TapToExpand>());
      expect(tapped.notification.id, n.id);
      sub.cancel(); // ignore: unawaited_futures
    });

    test('emitTapped emits for TapToAct with correct behavior', () async {
      final n = makeWidget(tapBehavior: TapToAct(onTap: () {}));
      final events = <NotificationEvent>[];
      final sub = controller.events.listen(events.add);

      coordinator.emitTapped(
        notification: n,
        behavior: TapToAct(onTap: () {}),
      );
      await Future.delayed(Duration.zero);

      final tapped = events.whereType<NotificationTapped>().first;
      expect(tapped.behavior, isA<TapToAct>());
      sub.cancel(); // ignore: unawaited_futures
    });
  });
}
