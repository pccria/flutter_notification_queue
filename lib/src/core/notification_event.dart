part of 'core.dart';

// ── Dismiss reason ─────────────────────────────────────────────────────────

/// Describes why a [NotificationWidget] was dismissed.
enum DismissReason {
  /// The notification's auto-dismiss timer expired.
  timeout,

  /// The user swiped the notification away via a drag gesture.
  userSwipe,

  /// The user tapped the notification and the queue's [TapToDismiss] behavior
  /// triggered the dismissal.
  userTap,

  /// The notification was dismissed programmatically via
  /// [NotificationWidget.dismiss].
  programmatic,

  /// The notification was evicted by the priority triage engine to make room
  /// for a higher-priority notification.
  ///
  /// The evicted notification is re-queued in the pending list and may
  /// reappear when the higher-priority notifications clear.
  evicted,
}

// ── Event hierarchy ────────────────────────────────────────────────────────

/// Base class for all events emitted by [NotificationController.events] and
/// [QueueCoordinator.events].
///
/// Listen to the stream:
/// ```dart
/// controller.events.listen((event) {
///   switch (event) {
///     case NotificationQueued(:final notification):
///       analytics.track('notification_shown', id: notification.id);
///     case NotificationDismissed(:final notification, :final reason):
///       if (reason == DismissReason.timeout) log('auto-dismissed');
///     case NotificationTapped():
///     case NotificationRelocated():
///     case NotificationReordered():
///     case QueueOverflowed():
///   }
/// });
/// ```
sealed class NotificationEvent {
  const NotificationEvent();

  /// The notification associated with this event, or `null` if the event is a
  /// queue-level, group-level, or routing event.
  NotificationWidget? get notification => null;
}

/// Emitted when a [NotificationWidget] is accepted into a queue.
///
/// Not emitted when the notification's channel is disabled.
final class NotificationQueued extends NotificationEvent {
  const NotificationQueued({required this.notification});

  /// The notification that was queued.
  @override
  final NotificationWidget notification;

  @override
  String toString() => 'NotificationQueued(id: ${notification.id}, '
      'queue: ${notification.queue.position.name})';
}

/// Emitted when an active or pending [NotificationWidget] is updated in place.
final class NotificationUpdated extends NotificationEvent {
  const NotificationUpdated({
    required this.notification,
    required this.oldNotification,
  });

  /// The updated notification widget.
  @override
  final NotificationWidget notification;

  /// The previous notification widget before the update.
  final NotificationWidget oldNotification;

  @override
  String toString() => 'NotificationUpdated(id: ${notification.id})';
}

/// Emitted when a [NotificationWidget] is removed from its queue.
final class NotificationDismissed extends NotificationEvent {
  const NotificationDismissed({
    required this.notification,
    required this.reason,
  });

  /// The notification that was dismissed.
  @override
  final NotificationWidget notification;

  /// Why the notification was dismissed.
  final DismissReason reason;

  @override
  String toString() =>
      'NotificationDismissed(id: ${notification.id}, reason: ${reason.name})';
}

/// Emitted when the user taps a [NotificationWidget].
///
/// Always fired for tap interactions, regardless of the resolved [TapBehavior].
/// Use the [behavior] field to distinguish intent:
/// - [TapToDismiss] — the tap also triggered a [NotificationDismissed] event.
/// - [TapToAct] — the callback has been invoked.
/// - [TapToExpand] — the card toggled its expanded state.
/// - [TapDisabled] — this event is *not* emitted when tapping is disabled.
final class NotificationTapped extends NotificationEvent {
  const NotificationTapped({
    required this.notification,
    required this.behavior,
  });

  /// The notification that was tapped.
  @override
  final NotificationWidget notification;

  /// The resolved tap behavior that handled this tap.
  final TapBehavior behavior;

  @override
  String toString() => 'NotificationTapped(id: ${notification.id}, '
      'behavior: ${behavior.runtimeType})';
}

/// Emitted when a [NotificationWidget] is successfully relocated to a new
/// queue.
final class NotificationRelocated extends NotificationEvent {
  const NotificationRelocated({
    required this.notification,
    required this.from,
    required this.to,
  });

  /// The notification after relocation (its [NotificationWidget.queue] now
  /// points to [to]).
  @override
  final NotificationWidget notification;

  /// The queue position the notification was moved *from*.
  final QueuePosition from;

  /// The queue position the notification was moved *to*.
  final QueuePosition to;

  @override
  String toString() => 'NotificationRelocated(id: ${notification.id}, '
      'from: ${from.name}, to: ${to.name})';
}

/// Emitted when a [NotificationWidget] is reordered within its queue.
final class NotificationReordered extends NotificationEvent {
  const NotificationReordered({
    required this.notification,
    required this.toIndex,
  });

  /// The notification that was reordered.
  @override
  final NotificationWidget notification;

  /// The new zero-based index within the queue stack.
  final int toIndex;

  @override
  String toString() =>
      'NotificationReordered(id: ${notification.id}, toIndex: $toIndex)';
}

/// Emitted when a notification is dropped because the queue has reached
/// [NotificationQueue.maxStackSize].
final class QueueOverflowed extends NotificationEvent {
  const QueueOverflowed({
    required this.queue,
    required this.dropped,
  });

  /// The queue that overflowed.
  final NotificationQueue queue;

  /// The notification that was dropped.
  final NotificationWidget dropped;

  @override
  String toString() => 'QueueOverflowed(position: ${queue.position.name}, '
      'dropped: ${dropped.id})';
}

/// Emitted when a [NotificationWidget] is successfully snoozed.
final class NotificationSnoozed extends NotificationEvent {
  const NotificationSnoozed({
    required this.notification,
    required this.duration,
  });

  /// The notification that was snoozed.
  @override
  final NotificationWidget notification;

  /// The duration for which the notification was snoozed.
  final Duration duration;

  @override
  String toString() => 'NotificationSnoozed(id: ${notification.id}, '
      'duration: ${duration.inSeconds}s)';
}

/// Emitted when a [NotificationWidget] is pinned.
final class NotificationPinned extends NotificationEvent {
  const NotificationPinned({required this.notification});

  /// The notification that was pinned.
  @override
  final NotificationWidget notification;

  @override
  String toString() => 'NotificationPinned(id: ${notification.id})';
}

/// Emitted when a [NotificationWidget] is unpinned.
final class NotificationUnpinned extends NotificationEvent {
  const NotificationUnpinned({required this.notification});

  /// The notification that was unpinned.
  @override
  final NotificationWidget notification;

  @override
  String toString() => 'NotificationUnpinned(id: ${notification.id})';
}

/// Emitted when a custom action is triggered on a [NotificationWidget].
final class NotificationCustomActionTriggered extends NotificationEvent {
  const NotificationCustomActionTriggered({
    required this.notification,
    required this.actionName,
  });

  /// The notification on which the action was triggered.
  @override
  final NotificationWidget notification;

  /// The name of the custom action that was triggered.
  final String actionName;

  @override
  String toString() =>
      'NotificationCustomActionTriggered(id: ${notification.id}, '
      'actionName: $actionName)';
}

// ── Group events ────────────────────────────────────────────────────────────

/// Emitted when the user expands a collapsed notification group
/// (i.e., taps the bundle pill to reveal all members).
final class NotificationGroupExpanded extends NotificationEvent {
  const NotificationGroupExpanded({
    required this.groupKey,
    required this.position,
    required this.count,
  });

  /// The shared group key of the expanded bundle.
  final String groupKey;

  /// The queue position the bundle belongs to.
  final QueuePosition position;

  /// The number of notifications in the group at the time of expansion.
  final int count;

  @override
  String toString() => 'NotificationGroupExpanded(key: $groupKey, '
      'position: ${position.name}, count: $count)';
}

/// Emitted when the user collapses an expanded notification group
/// (i.e., taps the bundle pill to hide excess members).
final class NotificationGroupCollapsed extends NotificationEvent {
  const NotificationGroupCollapsed({
    required this.groupKey,
    required this.position,
    required this.count,
  });

  /// The shared group key of the collapsed bundle.
  final String groupKey;

  /// The queue position the bundle belongs to.
  final QueuePosition position;

  /// The number of notifications in the group at the time of collapse.
  final int count;

  @override
  String toString() => 'NotificationGroupCollapsed(key: $groupKey, '
      'position: ${position.name}, count: $count)';
}

/// Emitted when all members of a notification group are dismissed at once
/// via [QueueCoordinator.dismissGroup].
final class NotificationGroupDismissed extends NotificationEvent {
  const NotificationGroupDismissed({
    required this.groupKey,
    required this.position,
  });

  /// The shared group key of the dismissed bundle.
  final String groupKey;

  /// The queue position the bundle belonged to.
  final QueuePosition position;

  @override
  String toString() => 'NotificationGroupDismissed(key: $groupKey, '
      'position: ${position.name})';
}

/// Emitted when a queue position is permanently relocated at runtime.
final class QueuePositionRelocated extends NotificationEvent {
  const QueuePositionRelocated({
    required this.from,
    required this.to,
    this.permanent = true,
  });

  /// The original queue position before relocation.
  final QueuePosition from;

  /// The new queue position destination.
  final QueuePosition to;

  /// Whether this relocation permanently redirected future queue traffic.
  final bool permanent;

  @override
  String toString() => 'QueuePositionRelocated(from: ${from.name}, '
      'to: ${to.name}, permanent: $permanent)';
}

/// Emitted when a channel's default queue route is updated at runtime.
@Deprecated('Use QueuePositionRelocated instead.')
final class NotificationChannelRouteUpdated extends NotificationEvent {
  const NotificationChannelRouteUpdated({
    required this.channelName,
    required this.oldPosition,
    required this.newPosition,
  });

  /// The name of the channel whose route was updated.
  final String channelName;

  /// The original queue position before updates.
  final QueuePosition oldPosition;

  /// The new queue position route.
  final QueuePosition newPosition;

  @override
  String toString() => 'NotificationChannelRouteUpdated(channel: $channelName, '
      'from: ${oldPosition.name}, to: ${newPosition.name})';
}
