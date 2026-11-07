part of 'notification.dart';

/// Represents an in-app notification payload to be enqueued and displayed.
///
/// [AppNotification] is a pure, immutable data object that encapsulates the
/// content (title, message, icon), visual overrides (accent color), interaction
/// behaviors (tap), and routing metadata (channel, priority)
/// for a single notification.
///
/// Unlike UI widgets, [AppNotification] has no UI dependencies, requires no
/// [BuildContext], and performs no direct side effects. It represents the
/// *intent* to show a notification. Pass instances to a
/// `NotificationController` or dispatch them via
/// `NotificationScope.of(context)`.
///
/// ## Basic Usage
///
/// ```dart
/// final notification = AppNotification(
///   id: 'order-123',
///   message: 'Your order #123 has been confirmed.',
///   title: 'Order Confirmed',
///   channelName: 'orders',
///   priority: NotificationPriority.high,
///   dismissDuration: const Duration(seconds: 5),
/// );
///
/// // Dispatch via controller or context
/// controller.show(notification);
/// ```
///
/// See also:
///  * [NotificationChannel], which defines channel-level defaults for
///    notifications.
///  * [NotificationPriority], which determines triage ranking in the queue.
///  * [TapBehavior], which defines tap interaction.
@immutable
class AppNotification {
  /// Creates an immutable [AppNotification] payload.
  ///
  /// The [message] parameter is required and represents the main text body.
  ///
  /// Use [channelName] to route the notification through a specific registered
  /// [NotificationChannel] (defaults to `'default'`).
  ///
  /// Set [accentColor] to apply content-driven color highlights
  /// (e.g. status tags or brand colors). Channel-wide theming should be
  /// configured via [NotificationChannel.theme].
  ///
  /// Set [permanent] to `true` to keep the notification on screen until
  /// explicitly dismissed by the user or programmatically.
  const AppNotification({
    required this.message,
    this.id,
    this.title,
    this.channelName = 'default',
    this.priority,
    this.tapBehavior,
    this.groupKey,
    this.icon,
    this.accentColor,
    this.dismissDuration,
    this.permanent = false,
    this.builder,
    this.action,
  });

  /// The main message text body of the notification.
  final String message;

  /// Optional unique identifier for this notification.
  ///
  /// If `null`, a unique ID is automatically generated when enqueued.
  final String? id;

  /// Optional header title text shown above the [message].
  final String? title;

  /// Name of the target [NotificationChannel] for default settings and routing.
  ///
  /// Defaults to `'default'`. If the specified channel is not registered,
  /// fallbacks from the global default channel are applied.
  final String channelName;

  /// Optional priority rank override for queue triage and backpressure.
  ///
  /// When `null`, defaults to the priority defined on the
  /// [NotificationChannel].
  final NotificationPriority? priority;

  /// Per-notification override for tap interaction behavior.
  ///
  /// When set, this takes precedence over the queue's default [TapBehavior],
  /// allowing individual urgent or critical notifications to enforce custom
  /// interaction policies.
  final TapBehavior? tapBehavior;

  /// Optional grouping key for bundling notifications into stack pills.
  ///
  /// Notifications sharing the same [groupKey] will be collapsed together.
  /// If `null`, grouping falls back to [channelName].
  final String? groupKey;

  /// Leading icon widget displayed beside the [message].
  ///
  /// If `null`, falls back to the icon defined on the target
  /// [NotificationChannel].
  final Widget? icon;

  /// Optional experimental accent color override.
  ///
  /// When provided, this tint color takes precedence over the channel's
  /// theme accent color solely for content-driven color accents (e.g. status
  /// tags, brand colors). To maintain design system consistency, full theme
  /// tokens (typography, borders, elevation) should be configured on
  /// [NotificationChannel].
  @experimental
  final Color? accentColor;

  /// Auto-dismiss timer duration for this notification.
  ///
  /// When `null` and [permanent] is `false`, the notification uses the default
  /// dismiss duration from its [NotificationChannel].
  final Duration? dismissDuration;

  /// Whether the notification stays on screen indefinitely until dismissed.
  ///
  /// Setting [permanent] to `true` overrides any [dismissDuration] settings.
  final bool permanent;

  /// Custom builder for customizing the card indicator or stack appearance.
  final NotificationBuilder? builder;

  /// Action button or tap callback configuration attached to the card.
  final NotificationAction? action;

  /// Internal conversion helper to adapt [AppNotification] to
  /// [NotificationWidget] for rendering pipeline compatibility during v0.3.0.
  @internal
  NotificationWidget toWidget([
    final ConfigurationManager? configuration,
    final QueueCoordinator? coordinator,
    final QueuePosition? targetPosition,
  ]) =>
      NotificationWidget(
        message: message,
        id: id,
        channelName: channelName,
        title: title,
        position: targetPosition,
        action: action,
        tapBehavior: tapBehavior,
        icon: icon,
        accentColor: accentColor,
        dismissDuration: dismissDuration,
        permanent: permanent,
        builder: builder,
        priority: priority,
        groupKey: groupKey,
        configuration: configuration,
        coordinator: coordinator,
      );

  /// Creates a copy of this [AppNotification] with the given fields replaced.
  AppNotification copyWith({
    final String? id,
    final String? title,
    final String? message,
    final String? channelName,
    final NotificationPriority? priority,
    final TapBehavior? tapBehavior,
    final String? groupKey,
    final Widget? icon,
    final Color? accentColor,
    final Duration? dismissDuration,
    final bool? permanent,
    final NotificationBuilder? builder,
    final NotificationAction? action,
  }) =>
      AppNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        channelName: channelName ?? this.channelName,
        priority: priority ?? this.priority,
        tapBehavior: tapBehavior ?? this.tapBehavior,
        groupKey: groupKey ?? this.groupKey,
        icon: icon ?? this.icon,
        accentColor: accentColor ?? this.accentColor,
        dismissDuration: dismissDuration ?? this.dismissDuration,
        permanent: permanent ?? this.permanent,
        builder: builder ?? this.builder,
        action: action ?? this.action,
      );

  /// Internal conversion helper to create a [NotificationEntry] from this
  /// intent.
  @internal
  NotificationEntry toEntry() {
    final widget = toWidget();
    return NotificationEntry(
      blueprint: widget,
      queue: widget.queue,
    );
  }

  @override
  String toString() => 'AppNotification('
      'id: $id, '
      'channelName: $channelName, '
      'title: $title, '
      'message: $message, '
      'priority: $priority, '
      'groupKey: $groupKey)';
}
