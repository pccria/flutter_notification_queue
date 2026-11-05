import 'package:flutter/widgets.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOverlayPortalController extends Mock
    implements OverlayPortalController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QueueCoordinator', () {
    late NotificationController controller;
    late QueueCoordinator coordinator;
    late MockOverlayPortalController mockOverlayController;

    setUp(() {
      controller = NotificationController(
        queues: {
          const NotificationQueue(position: QueuePosition.topRight),
          const NotificationQueue(position: QueuePosition.bottomLeft),
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
      mockOverlayController = MockOverlayPortalController();
      coordinator.attach(mockOverlayController);
      when(() => mockOverlayController.show()).thenReturn(null);
      when(() => mockOverlayController.hide()).thenReturn(null);
    });

    tearDown(() {
      coordinator.dispose();
      controller.dispose();
    });

    test('Initial state is clear', () {
      expect(coordinator.activeQueues.value.isEmpty, isTrue);
    });

    group('Initialization Queue', () {
      test('enqueue adds to initialization queue when not mounted', () {
        final notification = NotificationWidget(
          id: 'test',
          message: 'Test Message',
          coordinator: coordinator,
        );

        coordinator.queue(notification);

        // Should be active to trigger mount
        expect(coordinator.activeQueues.value.isNotEmpty, isTrue);
        expect(
          coordinator.activeQueues.value.keys.first,
          QueuePosition.topRight,
        );

        // Should be retrievable via consume
        final items =
            coordinator.consumeInitializationQueue(QueuePosition.topRight);
        expect(items.length, 1);
        expect(items.first.blueprint, notification);

        // Should trigger overlay show
        verify(() => mockOverlayController.show()).called(1);
      });

      test('consumeInitializationQueue clears the queue', () {
        final notification = NotificationWidget(
          id: 'test',
          message: 'Test Message',
          coordinator: coordinator,
        );
        coordinator.queue(notification);

        final items1 =
            coordinator.consumeInitializationQueue(QueuePosition.topRight);
        expect(items1.length, 1);

        final items2 =
            coordinator.consumeInitializationQueue(QueuePosition.topRight);
        expect(items2.isEmpty, isTrue);
      });

      test('same-ID dispatch to different queue removes from old position', () {
        final notif1 = NotificationWidget(
          id: 'cross_queue_1',
          message: 'Top Right Message',
          position: QueuePosition.topRight,
          coordinator: coordinator,
        );
        coordinator.queue(notif1);

        // Dispatch same id to bottomLeft before consume
        final notif2 = NotificationWidget(
          id: 'cross_queue_1',
          message: 'Bottom Left Message',
          position: QueuePosition.bottomLeft,
          coordinator: coordinator,
        );
        coordinator.queue(notif2);

        // topRight initialization queue should now be empty
        expect(
          coordinator
              .consumeInitializationQueue(QueuePosition.topRight)
              .isEmpty,
          isTrue,
        );
        // bottomLeft should have the entry
        final blItems =
            coordinator.consumeInitializationQueue(QueuePosition.bottomLeft);
        expect(blItems.length, 1);
        expect(blItems.first.blueprint.message, 'Bottom Left Message');
      });
    });

    group('Lifecycle & Snooze Timer', () {
      test('dispose is idempotent and marks isDisposed', () {
        expect(coordinator.isDisposed, isFalse);
        coordinator.dispose();
        expect(coordinator.isDisposed, isTrue);
        // Calling again should not throw
        expect(coordinator.dispose, returnsNormally);
      });

      test('snooze timer is cancelled on dispose', () async {
        final notification = NotificationWidget(
          id: 'snooze_test',
          message: 'Snooze Test',
          coordinator: coordinator,
        );
        coordinator
          ..queue(notification)
          ..snoozeWidget(
            notification,
            const Duration(milliseconds: 100),
          )
          ..dispose();

        // Wait past timer duration to ensure callback does not throw
        // or re-queue.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(coordinator.isDisposed, isTrue);
      });

      test('snooze timer is cancelled on detach', () async {
        final notification = NotificationWidget(
          id: 'snooze_detach_test',
          message: 'Snooze Detach Test',
          coordinator: coordinator,
        );
        coordinator
          ..queue(notification)
          ..snoozeWidget(
            notification,
            const Duration(milliseconds: 100),
          )
          ..detach();

        // Wait past timer duration
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(coordinator.activeQueues.value.isEmpty, isTrue);
      });
    });
  });
}
