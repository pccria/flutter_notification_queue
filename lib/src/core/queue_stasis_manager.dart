part of 'core.dart';

/// Manages programmatic timer stasis states and mutations across queues.
///
/// Encapsulates the set of paused [QueuePosition]s, providing read-only
/// [ValueListenable] exposure and atomic pause/resume transitions.
@internal
final class QueueStasisManager {
  /// Creates a [QueueStasisManager].
  QueueStasisManager();

  final _pausedQueuesNotifier = ValueNotifier<Set<QueuePosition>>({});

  bool _isDisposed = false;

  /// Whether this stasis manager has been disposed.
  bool get isDisposed => _isDisposed;

  /// Notifier exposing the set of queues currently in programmatic timer
  /// stasis.
  ValueListenable<Set<QueuePosition>> get pausedQueues => _pausedQueuesNotifier;

  /// Whether the queue at [position] is currently paused.
  bool isQueuePaused(final QueuePosition position) =>
      _pausedQueuesNotifier.value.contains(position);

  /// Pauses auto-dismiss timers for all notifications in [position].
  void pauseQueue(final QueuePosition position) {
    if (_isDisposed || _pausedQueuesNotifier.value.contains(position)) {
      return;
    }
    _pausedQueuesNotifier.value = {..._pausedQueuesNotifier.value, position};
  }

  /// Resumes auto-dismiss timers for all notifications in [position].
  void resumeQueue(final QueuePosition position) {
    if (_isDisposed || !_pausedQueuesNotifier.value.contains(position)) {
      return;
    }
    final next = Set<QueuePosition>.of(_pausedQueuesNotifier.value)
      ..remove(position);
    _pausedQueuesNotifier.value = next;
  }

  /// Pauses auto-dismiss timers for all notifications across all queues.
  void pauseAll() {
    if (_isDisposed) {
      return;
    }
    _pausedQueuesNotifier.value = Set.of(QueuePosition.values);
  }

  /// Resumes auto-dismiss timers for all notifications across all queues.
  void resumeAll() {
    if (_isDisposed) {
      return;
    }
    _pausedQueuesNotifier.value = {};
  }

  /// Disposes the underlying stasis notifier.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _pausedQueuesNotifier.dispose();
  }
}
