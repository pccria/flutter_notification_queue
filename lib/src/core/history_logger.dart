part of 'core.dart';

/// A wrapper that stores a [NotificationEvent] along with its emission
/// timestamp.
@internal
class HistoryEntry {
  HistoryEntry(this.event, {final DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  /// The emitted event.
  final NotificationEvent event;

  /// The timestamp when the event was recorded.
  final DateTime timestamp;
}

/// Manages an in-memory, bounded LIFO ring buffer of [NotificationEvent]s.
///
/// Opt-in via `maxHistoryEntries` configuration.
@internal
class HistoryLogger {
  HistoryLogger({required final int maxEntries}) : _maxEntries = maxEntries;

  int _maxEntries;
  final List<HistoryEntry> _history = [];
  StreamSubscription<NotificationEvent>? _subscription;
  Stream<NotificationEvent>? _coordinatorStream;

  /// The maximum number of entries allowed in the history cache.
  int get maxEntries => _maxEntries;

  /// Starts listening to the event stream.
  void startListening(final Stream<NotificationEvent> stream) {
    _subscription?.cancel();
    _coordinatorStream = stream;
    if (_maxEntries <= 0) {
      return;
    }

    _subscription = stream.listen((final event) {
      _history.insert(0, HistoryEntry(event)); // LIFO (most recent first)
      if (_history.length > _maxEntries) {
        _history.removeLast();
      }
    });
  }

  /// Updates the maximum cache bounds dynamically.
  void updateMaxEntries(final int newMax) {
    _maxEntries = newMax;
    if (_maxEntries <= 0) {
      _subscription?.cancel();
      _subscription = null;
      _history.clear();
    } else {
      if (_subscription == null && _coordinatorStream != null) {
        startListening(_coordinatorStream!);
      }
      if (_history.length > _maxEntries) {
        _history.removeRange(_maxEntries, _history.length);
      }
    }
  }

  /// Queries the captured notification history based on filters.
  List<NotificationEvent> getHistory({
    final String? channelName,
    final DismissReason? dismissReason,
    final DateTime? since,
    final int? limit,
  }) {
    Iterable<HistoryEntry> query = _history;

    if (channelName != null) {
      query = query.where(
        (final entry) => entry.event.notification?.channelName == channelName,
      );
    }

    if (dismissReason != null) {
      query = query.where((final entry) {
        final e = entry.event;
        return e is NotificationDismissed && e.reason == dismissReason;
      });
    }

    if (since != null) {
      query = query.where((final entry) => entry.timestamp.isAfter(since));
    }

    final events = query.map((final entry) => entry.event);

    if (limit != null) {
      return events.take(limit).toList();
    }

    return events.toList();
  }

  /// Clears all recorded entries.
  void clear() {
    _history.clear();
  }

  /// Cancels subscriptions and releases resources.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _history.clear();
  }
}
