part of 'core.dart';

/// Instance-scoped generator for unique notification identifiers.
///
/// Replaces global mutable ID counter state with encapsulated, instance-scoped
/// monotonic counters. Each generator maintains its own independent sequence,
/// preventing state leakage across test suites and coordinator instances.
class NotificationIdGenerator {
  /// Creates a [NotificationIdGenerator] with an optional [initialSeed].
  NotificationIdGenerator({final int initialSeed = 0}) : _counter = initialSeed;

  int _counter;

  /// The current monotonic sequence counter value.
  int get currentCount => _counter;

  /// Generates the next unique notification identifier.
  ///
  /// Combines the given [prefix], the monotonic sequence counter, and the
  /// current timestamp in microseconds to guarantee uniqueness.
  String nextId([final String prefix = 'notif']) {
    final count = _counter++;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${count}_$timestamp';
  }
}
