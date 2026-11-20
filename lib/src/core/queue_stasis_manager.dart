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
  ///
  /// Returns `true` if the queue entered stasis, or `false` if it was already
  /// paused or this manager is disposed.
  bool pauseQueue(final QueuePosition position) {
    if (_isDisposed || _pausedQueuesNotifier.value.contains(position)) {
      return false;
    }
    _pausedQueuesNotifier.value = {..._pausedQueuesNotifier.value, position};
    return true;
  }

  /// Resumes auto-dismiss timers for all notifications in [position].
  ///
  /// Returns `true` if the queue exited stasis, or `false` if it was not
  /// paused or this manager is disposed.
  bool resumeQueue(final QueuePosition position) {
    if (_isDisposed || !_pausedQueuesNotifier.value.contains(position)) {
      return false;
    }
    final next = Set<QueuePosition>.of(_pausedQueuesNotifier.value)
      ..remove(position);
    _pausedQueuesNotifier.value = next;
    return true;
  }

  /// Pauses auto-dismiss timers for all notifications across all queues.
  ///
  /// Returns the set of queue positions that newly entered stasis.
  Set<QueuePosition> pauseAll() {
    if (_isDisposed) {
      return const {};
    }
    final current = _pausedQueuesNotifier.value;
    final all = Set.of(QueuePosition.values);
    final newlyPaused = all.difference(current);
    if (newlyPaused.isNotEmpty) {
      _pausedQueuesNotifier.value = all;
    }
    return newlyPaused;
  }

  /// Resumes auto-dismiss timers for all notifications across all queues.
  ///
  /// Returns the set of queue positions that exited stasis.
  Set<QueuePosition> resumeAll() {
    if (_isDisposed) {
      return const {};
    }
    final previouslyPaused = Set<QueuePosition>.of(_pausedQueuesNotifier.value);
    if (previouslyPaused.isNotEmpty) {
      _pausedQueuesNotifier.value = const {};
    }
    return previouslyPaused;
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
