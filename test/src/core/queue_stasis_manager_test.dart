import 'package:flutter_notification_queue/flutter_notification_queue.dart';
import 'package:flutter_notification_queue/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueStasisManager', () {
    late QueueStasisManager manager;

    setUp(() {
      manager = QueueStasisManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('initial state has empty pausedQueues set', () {
      expect(manager.pausedQueues.value, isEmpty);
      expect(manager.isQueuePaused(QueuePosition.topRight), isFalse);
    });

    test('pauseQueue adds position to pausedQueues', () {
      manager.pauseQueue(QueuePosition.topRight);

      expect(manager.isQueuePaused(QueuePosition.topRight), isTrue);
      expect(manager.pausedQueues.value, {QueuePosition.topRight});
      expect(manager.isQueuePaused(QueuePosition.bottomLeft), isFalse);
    });

    test('pauseQueue is idempotent when called multiple times', () {
      manager
        ..pauseQueue(QueuePosition.topRight)
        ..pauseQueue(QueuePosition.topRight);

      expect(manager.pausedQueues.value, {QueuePosition.topRight});
    });

    test('resumeQueue removes paused position from set', () {
      manager
        ..pauseQueue(QueuePosition.topRight)
        ..pauseQueue(QueuePosition.topLeft)
        ..resumeQueue(QueuePosition.topRight);

      expect(manager.isQueuePaused(QueuePosition.topRight), isFalse);
      expect(manager.isQueuePaused(QueuePosition.topLeft), isTrue);
      expect(manager.pausedQueues.value, {QueuePosition.topLeft});
    });

    test('resumeQueue on unpaused position is safe no-op', () {
      manager.resumeQueue(QueuePosition.topRight);

      expect(manager.pausedQueues.value, isEmpty);
    });

    test('pauseAll pauses every QueuePosition value', () {
      manager.pauseAll();

      expect(manager.pausedQueues.value, Set.of(QueuePosition.values));
      for (final pos in QueuePosition.values) {
        expect(manager.isQueuePaused(pos), isTrue);
      }
    });

    test('resumeAll clears all paused queues', () {
      manager
        ..pauseAll()
        ..resumeAll();

      expect(manager.pausedQueues.value, isEmpty);
      for (final pos in QueuePosition.values) {
        expect(manager.isQueuePaused(pos), isFalse);
      }
    });

    test('no-ops safely after disposal', () {
      manager.dispose();
      expect(manager.isDisposed, isTrue);

      manager
        ..pauseQueue(QueuePosition.topRight)
        ..resumeQueue(QueuePosition.topRight)
        ..pauseAll()
        ..resumeAll()
        ..dispose();
    });
  });
}
