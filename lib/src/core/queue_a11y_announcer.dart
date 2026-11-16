part of 'core.dart';

/// Encapsulates live region screen-reader announcements for notifications.
///
/// Inspects [NotificationA11yOptions] and the notification's resolved priority
/// to dispatch appropriate speech events to [SemanticsService].
@internal
final class QueueA11yAnnouncer {
  /// Creates a [QueueA11yAnnouncer].
  const QueueA11yAnnouncer();

  /// Evaluates and broadcasts a screen-reader announcement for [notification].
  void announce(
    final NotificationWidget notification, {
    required final NotificationA11yOptions options,
  }) {
    if (!options.enableLiveRegions) {
      return;
    }
    final priority = notification.resolvedPriority;
    if (priority < options.announcePriorityThreshold) {
      return;
    }
    final title = notification.title;
    final message = notification.message;
    final announcement =
        title != null && title.isNotEmpty ? '$title: $message' : message;
    final assertiveness = priority == NotificationPriority.critical
        ? Assertiveness.assertive
        : Assertiveness.polite;

    final view = PlatformDispatcher.instance.implicitView ??
        PlatformDispatcher.instance.views.firstOrNull;
    if (view != null) {
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          announcement,
          TextDirection.ltr,
          assertiveness: assertiveness,
        ),
      );
    }
  }
}
