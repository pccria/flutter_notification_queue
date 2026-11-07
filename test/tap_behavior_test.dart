import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/notification/notification.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// TapBehavior unit tests
// ---------------------------------------------------------------------------

void main() {
  // ── Behavior taxonomy ─────────────────────────────────────────────────────

  group('TapBehavior sealed class hierarchy', () {
    test('TapToDismiss is a TapBehavior', () {
      const b = TapToDismiss();
      expect(b, isA<TapBehavior>());
    });

    test('TapToExpand is a TapBehavior', () {
      const b = TapToExpand();
      expect(b, isA<TapBehavior>());
    });

    test('TapToAct is a TapBehavior', () {
      final b = TapToAct(onTap: () {});
      expect(b, isA<TapBehavior>());
    });

    test('TapDisabled is a TapBehavior', () {
      const b = TapDisabled();
      expect(b, isA<TapBehavior>());
    });

    test('TapToAct.onTap stores its callback', () {
      var called = false;
      final b = TapToAct(onTap: () => called = true);
      b.onTap();
      expect(called, isTrue);
    });
  });

  // ── Queue-level tapBehavior ───────────────────────────────────────────────

  group('NotificationQueue.tapBehavior', () {
    test('NotificationQueue on topCenter position defaults to TapToDismiss',
        () {
      const q = NotificationQueue(position: QueuePosition.topCenter);
      expect(q.tapBehavior, isA<TapToDismiss>());
    });

    test('all concrete queues default to TapToDismiss', () {
      const queues = [
        NotificationQueue(position: QueuePosition.topLeft),
        NotificationQueue(position: QueuePosition.topCenter),
        NotificationQueue(position: QueuePosition.topRight),
        NotificationQueue(position: QueuePosition.centerLeft),
        NotificationQueue(position: QueuePosition.centerRight),
        NotificationQueue(position: QueuePosition.bottomLeft),
        NotificationQueue(position: QueuePosition.bottomCenter),
        NotificationQueue(position: QueuePosition.bottomRight),
      ];
      for (final q in queues) {
        expect(
          q.tapBehavior,
          isA<TapToDismiss>(),
          reason: '${q.runtimeType} should default to TapToDismiss',
        );
      }
    });

    test('custom tapBehavior is stored on queue', () {
      const q = NotificationQueue(
        position: QueuePosition.topCenter,
        tapBehavior: TapToExpand(),
      );
      expect(q.tapBehavior, isA<TapToExpand>());
    });

    test('TapToAct is stored on queue and callback is callable', () {
      var fired = false;
      final q = NotificationQueue(
        position: QueuePosition.topCenter,
        tapBehavior: TapToAct(onTap: () => fired = true),
      );
      (q.tapBehavior as TapToAct).onTap();
      expect(fired, isTrue);
    });

    test('TapDisabled is stored correctly', () {
      const q = NotificationQueue(
        position: QueuePosition.topCenter,
        tapBehavior: TapDisabled(),
      );
      expect(q.tapBehavior, isA<TapDisabled>());
    });
  });

  // ── NotificationQueue default factory constructor ─────────────────────────

  group('NotificationQueue default factory constructor', () {
    test('tapBehavior defaults to TapToDismiss', () {
      const q = NotificationQueue();
      expect(q.tapBehavior, isA<TapToDismiss>());
    });

    test('custom tapBehavior is forwarded through factory', () {
      const q = NotificationQueue(
        tapBehavior: TapToExpand(),
      );
      expect(q.tapBehavior, isA<TapToExpand>());
    });
  });

  // ── QueuePosition.generateQueueFrom propagation ───────────────────────────

  group('QueuePosition.generateQueueFrom propagation', () {
    test('tapBehavior is preserved when generating from another queue', () {
      const source = NotificationQueue(
        position: QueuePosition.topLeft,
        tapBehavior: TapToExpand(),
      );
      final copy = QueuePosition.topRight.generateQueueFrom(source);
      expect(copy.tapBehavior, isA<TapToExpand>());
    });

    test('TapDisabled survives generateQueueFrom', () {
      const source = NotificationQueue(
        position: QueuePosition.bottomCenter,
        tapBehavior: TapDisabled(),
      );
      final copy = QueuePosition.bottomLeft.generateQueueFrom(source);
      expect(copy.tapBehavior, isA<TapDisabled>());
    });
  });

  // ── Per-notification tapBehavior override ─────────────────────────────────

  group('NotificationWidget.tapBehavior per-notification override', () {
    test('notification.tapBehavior field stores override', () {
      final n = NotificationWidget(
        message: 'Test',
        tapBehavior: const TapToExpand(),
      );
      expect(n.tapBehavior, isA<TapToExpand>());
    });

    test('notification.tapBehavior is null when not set', () {
      final n = NotificationWidget(message: 'Test');
      expect(n.tapBehavior, isNull);
    });

    test('copyToQueue preserves tapBehavior override', () {
      final n = NotificationWidget(
        message: 'Test',
        tapBehavior: const TapToExpand(),
      );
      final copy = n.copyToQueue(
        const NotificationQueue(position: QueuePosition.topRight),
      );
      expect(copy.tapBehavior, isA<TapToExpand>());
    });

    test('copyToQueue preserves null tapBehavior', () {
      final n = NotificationWidget(message: 'Test');
      final copy = n.copyToQueue(
        const NotificationQueue(position: QueuePosition.topRight),
      );
      expect(copy.tapBehavior, isNull);
    });
  });

  // ── Widget-level resolution (_resolvedTapBehavior) ────────────────────────

  group('_resolvedTapBehavior resolution priority', () {
    testWidgets(
      'per-notification TapToExpand overrides queue TapToDismiss',
      (final tester) async {
        final n = NotificationWidget(
          message: 'Test',
          tapBehavior: const TapToExpand(),
        );
        // Verify: per-notification tapBehavior takes precedence.
        expect(n.tapBehavior, isA<TapToExpand>());
        // Queue still has TapToDismiss by default.
        expect(n.queue.tapBehavior, isA<TapToDismiss>());
      },
    );

    testWidgets(
      'null per-notification tapBehavior falls through to queue',
      (final tester) async {
        final n = NotificationWidget(message: 'Test');
        // No per-notification override set.
        expect(n.tapBehavior, isNull);
        // Queue-level fallback is TapToDismiss.
        expect(n.queue.tapBehavior, isA<TapToDismiss>());
      },
    );
  });

  // ── TapToAct callback invocation ─────────────────────────────────────────

  group('TapToAct callback behavior', () {
    test('callback is invoked and stores fields correctly', () {
      var tapCount = 0;
      final act = TapToAct(onTap: () => tapCount++, dismissOnAct: false);
      act.onTap();
      act.onTap();
      expect(tapCount, equals(2));
      expect(act.dismissOnAct, isFalse);
    });

    test('dismissOnAct defaults to true', () {
      final act = TapToAct(onTap: () {});
      expect(act.dismissOnAct, isTrue);
    });

    test('callback can be replaced via new instance', () {
      var result = '';
      final act1 = TapToAct(onTap: () => result = 'first');
      final act2 = TapToAct(onTap: () => result = 'second');
      act1.onTap();
      expect(result, equals('first'));
      act2.onTap();
      expect(result, equals('second'));
    });
  });
}
