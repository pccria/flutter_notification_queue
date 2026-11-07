import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationScopeState implements NotificationScopeState {
  final _eventController = StreamController<NotificationEvent>.broadcast();
  final List<AppNotification> shownNotifications = [];
  final List<QueuePosition?> shownPositions = [];
  final List<AppNotification> dismissedNotifications = [];
  final List<String> dismissedIds = [];
  bool dismissedAll = false;
  bool dismissedNewest = false;
  bool clearedHistory = false;
  final List<String> dismissedGroups = [];
  final List<(AppNotification, QueuePosition)> relocated = [];
  final List<(String, QueuePosition)> relocatedIds = [];
  final List<(AppNotification, int)> reordered = [];
  final List<AppNotification> snoozed = [];
  final List<(String, Duration)> snoozedIds = [];
  final List<AppNotification> pinned = [];
  final List<String> pinnedIds = [];
  final List<AppNotification> unpinned = [];
  final List<String> unpinnedIds = [];
  final List<(String, String?)> updatedMessages = [];

  @override
  Stream<NotificationEvent> get events => _eventController.stream;

  @override
  String show(
    final AppNotification notification, {
    final QueuePosition? targetPosition,
  }) {
    shownNotifications.add(notification);
    shownPositions.add(targetPosition);
    return notification.id ?? 'fake_id_${shownNotifications.length}';
  }

  @override
  void dismiss(
    final AppNotification notification, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    dismissedNotifications.add(notification);
    if (notification.id != null) {
      dismissedIds.add(notification.id!);
    }
  }

  @override
  void dismissById(
    final String id, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    dismissedIds.add(id);
  }

  @override
  void dismissAll({final DismissReason reason = DismissReason.programmatic}) {
    dismissedAll = true;
  }

  @override
  void dismissNewest() {
    dismissedNewest = true;
  }

  @override
  void dismissGroup(
    final String groupKey, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    dismissedGroups.add(groupKey);
  }

  @override
  void relocate(
    final AppNotification notification,
    final QueuePosition newPosition,
  ) {
    relocated.add((notification, newPosition));
  }

  @override
  void relocateById(final String id, final QueuePosition newPosition) {
    relocatedIds.add((id, newPosition));
  }

  @override
  void reorder(final AppNotification notification, final int targetIndex) {
    reordered.add((notification, targetIndex));
  }

  @override
  void snooze(
    final AppNotification notification,
    final Duration duration,
  ) {
    snoozed.add(notification);
  }

  @override
  void snoozeById(final String id, final Duration duration) {
    snoozedIds.add((id, duration));
  }

  @override
  void pin(final AppNotification notification) {
    pinned.add(notification);
  }

  @override
  void pinById(final String id) {
    pinnedIds.add(id);
  }

  @override
  void unpin(final AppNotification notification) {
    unpinned.add(notification);
  }

  @override
  void unpinById(final String id) {
    unpinnedIds.add(id);
  }

  @override
  bool update(
    final String id, {
    final String? message,
    final String? title,
    final Widget? icon,
    final NotificationAction? action,
    final NotificationPriority? priority,
    final Color? color,
    final Color? backgroundColor,
    final Color? foregroundColor,
    final Color? accentColor,
    final Duration? dismissDuration,
    final bool? permanent,
    final bool resetTimer = false,
  }) {
    updatedMessages.add((id, message));
    return true;
  }

  @override
  bool updateWith(
    final String id,
    final AppNotification Function(AppNotification current) transform, {
    final bool resetTimer = false,
  }) {
    final transformed = transform(const AppNotification(message: 'initial'));
    return update(
      id,
      message: transformed.message,
      resetTimer: resetTimer,
    );
  }

  @override
  List<NotificationEvent> getHistory({
    final String? channelName,
    final DismissReason? dismissReason,
    final DateTime? since,
    final int? limit,
  }) =>
      const [];

  @override
  void clearHistory() {
    clearedHistory = true;
  }

  @override
  void dispose() {
    _eventController.close();
  }

  void emitEvent(final NotificationEvent event) {
    _eventController.add(event);
  }
}

void main() {
  group('NotificationController', () {
    test('initializes with configuration without attaching', () {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topRight)},
        channels: {const NotificationChannel(name: 'custom')},
      );

      expect(controller.isAttached, isFalse);
      expect(
        controller.configuration.getQueue(QueuePosition.topRight).position,
        equals(QueuePosition.topRight),
      );
      expect(
        controller.configuration.getChannel('custom').name,
        equals('custom'),
      );

      controller.dispose();
    });

    test('show throws StateError when controller is unattached', () {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );

      const notification = AppNotification(message: 'Unattached');

      expect(
        () => controller.show(notification),
        throwsStateError,
      );

      controller.dispose();
    });

    test('tryShow does not throw when controller is unattached', () {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );

      const notification = AppNotification(message: 'Safe no-op');

      expect(
        () => controller.tryShow(notification),
        returnsNormally,
      );

      controller.dispose();
    });

    test('attaches and detaches scope successfully', () {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );
      final fakeScope = _FakeNotificationScopeState();

      expect(controller.isAttached, isFalse);

      controller.attach(fakeScope);
      expect(controller.isAttached, isTrue);

      const notification = AppNotification(message: 'Hello Scope');
      controller.show(notification);
      expect(fakeScope.shownNotifications.length, equals(1));
      expect(
        fakeScope.shownNotifications.first.message,
        equals('Hello Scope'),
      );

      controller.detach();
      expect(controller.isAttached, isFalse);

      controller.dispose();
    });

    test('proxies events from attached scope to controller events stream',
        () async {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );
      final fakeScope = _FakeNotificationScopeState();

      controller.attach(fakeScope);

      final event = QueueOverflowed(
        queue: const NotificationQueue(),
        dropped: NotificationWidget(message: 'Dropped'),
      );

      final nextEventFuture = controller.nextEvent<QueueOverflowed>();
      fakeScope.emitEvent(event);

      final received = await nextEventFuture;
      expect(received, equals(event));

      controller.dispose();
    });

    test('dismiss, dismissAll, clearHistory delegate to attached scope', () {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );
      final fakeScope = _FakeNotificationScopeState();
      const notification = AppNotification(message: 'Test', id: 'notif-1');

      controller
        ..attach(fakeScope)
        ..dismiss(notification)
        ..dismissAll()
        ..clearHistory();

      expect(
        fakeScope.dismissedNotifications.map((final n) => n.id),
        contains('notif-1'),
      );
      expect(fakeScope.dismissedAll, isTrue);
      expect(fakeScope.clearedHistory, isTrue);

      controller.dispose();
    });

    test(
        'dismissNewest, dismissGroup, relocate, reorder, snooze, pin, unpin '
        'delegate to attached scope', () {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );
      final fakeScope = _FakeNotificationScopeState();
      const notification = AppNotification(message: 'Test');

      controller
        ..attach(fakeScope)
        ..dismissNewest()
        ..dismissGroup('orders')
        ..relocate(notification, QueuePosition.topLeft)
        ..reorder(notification, 2)
        ..snooze(notification, const Duration(seconds: 5))
        ..pin(notification)
        ..unpin(notification);

      expect(fakeScope.dismissedNewest, isTrue);
      expect(fakeScope.dismissedGroups, contains('orders'));
      expect(fakeScope.relocated, isNotEmpty);
      expect(fakeScope.reordered, isNotEmpty);
      expect(fakeScope.snoozed, isNotEmpty);
      expect(fakeScope.pinned, isNotEmpty);
      expect(fakeScope.unpinned, isNotEmpty);

      controller.dispose();
    });

    test('reconfigure updates configuration settings in-place', () {
      final controller = NotificationController(
        queues: {const NotificationQueue(position: QueuePosition.topCenter)},
        channels: {const NotificationChannel(name: 'default')},
        maxHistoryEntries: 10,
      );

      expect(controller.configuration.queues.length, equals(1));
      expect(controller.configuration.maxHistoryEntries, equals(10));

      controller.reconfigure(
        queues: {
          const NotificationQueue(position: QueuePosition.topCenter),
          const NotificationQueue(position: QueuePosition.bottomRight),
        },
        maxHistoryEntries: 50,
      );

      expect(controller.configuration.queues.length, equals(2));
      expect(controller.configuration.maxHistoryEntries, equals(50));

      controller.dispose();
    });

    test('dispose is idempotent and marks isDisposed', () {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );

      expect(controller.isDisposed, isFalse);
      controller.dispose();
      expect(controller.isDisposed, isTrue);
      expect(controller.dispose, returnsNormally);
    });

    test('captureFlutterErrors chains original FlutterError.onError handler',
        () {
      final originalHandler = FlutterError.onError;
      var originalCalled = false;

      FlutterError.onError = (final details) {
        originalCalled = true;
      };

      try {
        final controller = NotificationController(
          queues: {const NotificationQueue()},
          captureFlutterErrors: true,
        );
        addTearDown(controller.dispose);

        FlutterError.onError?.call(
          FlutterErrorDetails(exception: Exception('test error')),
        );

        expect(originalCalled, isTrue);
      } finally {
        FlutterError.onError = originalHandler;
      }
    });

    test('show and tryShow forward targetPosition to attached scope', () {
      final controller = NotificationController(
        queues: {const NotificationQueue()},
      );
      final fakeScope = _FakeNotificationScopeState();
      controller.attach(fakeScope);
      addTearDown(controller.dispose);

      const notif1 = AppNotification(message: 'Default routing');
      const notif2 = AppNotification(message: 'Targeted routing');

      controller
        ..show(notif1)
        ..show(notif2, targetPosition: QueuePosition.bottomCenter)
        ..tryShow(notif1, targetPosition: QueuePosition.topRight);

      expect(fakeScope.shownNotifications.length, equals(3));
      expect(fakeScope.shownPositions[0], isNull);
      expect(fakeScope.shownPositions[1], equals(QueuePosition.bottomCenter));
      expect(fakeScope.shownPositions[2], equals(QueuePosition.topRight));
    });

    test('instantiates with zero-config default queues', () {
      final controller = NotificationController();
      addTearDown(controller.dispose);

      expect(controller.configuration.queues.length, equals(1));
      expect(
        controller.configuration.queues.first.position,
        equals(QueuePosition.topCenter),
      );
    });

    test('show and tryShow return NotificationHandle with correct ID', () {
      final controller = NotificationController();
      final fakeScope = _FakeNotificationScopeState();
      controller.attach(fakeScope);
      addTearDown(controller.dispose);

      const notif = AppNotification(id: 'custom_id_1', message: 'Hello');
      final handle = controller.show(notif);

      expect(handle, isA<NotificationHandle>());
      expect(handle.id, equals('custom_id_1'));

      final tryHandle = controller.tryShow(notif);
      expect(tryHandle?.id, equals('custom_id_1'));

      final unattachedController = NotificationController();
      addTearDown(unattachedController.dispose);
      expect(unattachedController.tryShow(notif), isNull);
    });

    test('NotificationHandle operations forward to controller and scope', () {
      final fakeScope = _FakeNotificationScopeState();
      final controller = NotificationController()..attach(fakeScope);
      addTearDown(controller.dispose);

      const notif = AppNotification(id: 'handle_test', message: 'Testing');
      controller.show(notif)
        ..pin()
        ..unpin()
        ..snooze(const Duration(seconds: 5))
        ..relocate(QueuePosition.bottomLeft)
        ..update(message: 'Updated message')
        ..updateWith((final curr) => curr.copyWith(message: 'Transformed'))
        ..dismiss();

      expect(fakeScope.pinnedIds, contains('handle_test'));
      expect(fakeScope.unpinnedIds, contains('handle_test'));
      expect(
        fakeScope.snoozedIds,
        contains(('handle_test', const Duration(seconds: 5))),
      );
      expect(
        fakeScope.relocatedIds,
        contains(('handle_test', QueuePosition.bottomLeft)),
      );
      expect(
        fakeScope.updatedMessages,
        contains(('handle_test', 'Updated message')),
      );
      expect(
        fakeScope.updatedMessages,
        contains(('handle_test', 'Transformed')),
      );
      expect(fakeScope.dismissedIds, contains('handle_test'));
    });

    test('showAsync and tryShowAsync handle Future success and error',
        () async {
      final fakeScope = _FakeNotificationScopeState();
      final controller = NotificationController()..attach(fakeScope);
      addTearDown(controller.dispose);

      final successCompleter = Completer<String>();
      final successHandle = controller.showAsync<String>(
        successCompleter.future,
        loading: const AppNotification(message: 'Loading...'),
        onSuccess: (final val) => AppNotification(message: 'Success: $val'),
        onError: (final err, final _) =>
            const AppNotification(message: 'Error'),
      );

      expect(fakeScope.shownNotifications.first.permanent, isTrue);

      successCompleter.complete('data_123');
      await pumpEventQueue();

      expect(
        fakeScope.updatedMessages,
        contains((successHandle.id, 'Success: data_123')),
      );

      final errorCompleter = Completer<String>();
      final errorHandle = controller.showAsync<String>(
        errorCompleter.future,
        loading: const AppNotification(message: 'Loading 2...'),
        onSuccess: (final val) => const AppNotification(message: 'Success'),
        onError: (final err, final _) =>
            AppNotification(message: 'Failed: $err'),
      );

      errorCompleter.completeError(Exception('network_error'));
      await pumpEventQueue();

      expect(
        fakeScope.updatedMessages,
        contains((errorHandle.id, 'Failed: Exception: network_error')),
      );
    });
  });
}
