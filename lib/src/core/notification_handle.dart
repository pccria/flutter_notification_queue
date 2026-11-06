part of 'core.dart';

/// A lightweight handle to a dispatched notification.
///
/// Returned by [NotificationController.show] and
/// [NotificationController.tryShow], [NotificationHandle] provides convenient
/// methods to programmatically dismiss, update, pin, unpin, snooze, or relocate
/// a notification without needing to retain the original [AppNotification]
/// instance.
@immutable
class NotificationHandle {
  /// Creates a [NotificationHandle] for the notification with [id].
  const NotificationHandle({
    required this.id,
    required final NotificationController controller,
  }) : _controller = controller;

  /// The unique identifier of the notification.
  final String id;

  final NotificationController _controller;

  /// Programmatically dismisses this notification.
  void dismiss({
    final DismissReason reason = DismissReason.programmatic,
  }) {
    _controller.dismissById(id, reason: reason);
  }

  /// Updates this notification in place with the specified fields.
  ///
  /// Set [resetTimer] to `true` to restart the auto-dismiss countdown.
  /// Returns `true` if the notification was active or pending and updated.
  bool update({
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
  }) =>
      _controller.update(
        id,
        message: message,
        title: title,
        icon: icon,
        action: action,
        priority: priority,
        color: color,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        accentColor: accentColor,
        dismissDuration: dismissDuration,
        permanent: permanent,
        resetTimer: resetTimer,
      );

  /// Updates this notification in place by applying [transform] to its current
  /// configuration.
  ///
  /// Set [resetTimer] to `true` to restart the auto-dismiss countdown.
  /// Returns `true` if the notification was active or pending and updated.
  bool updateWith(
    final AppNotification Function(AppNotification current) transform, {
    final bool resetTimer = false,
  }) =>
      _controller.updateWith(id, transform, resetTimer: resetTimer);

  /// Pins this notification to the top of its queue, disabling swipe-dismiss.
  void pin() => _controller.pinById(id);

  /// Releases the pin on this notification.
  void unpin() => _controller.unpinById(id);

  /// Temporarily hides this notification and re-enqueues it after [duration].
  void snooze(final Duration duration) => _controller.snoozeById(id, duration);

  /// Moves this notification to [newPosition].
  void relocate(final QueuePosition newPosition) =>
      _controller.relocateById(id, newPosition);

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is NotificationHandle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NotificationHandle(id: $id)';
}
