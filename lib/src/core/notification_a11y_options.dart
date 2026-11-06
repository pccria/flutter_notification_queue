part of 'core.dart';

/// Configuration options for accessibility (a11y), screen reader live
/// announcements, and keyboard focus traversal across the notification queue.
@immutable
class NotificationA11yOptions {
  /// Creates accessibility options.
  const NotificationA11yOptions({
    this.enableLiveRegions = true,
    this.announcePriorityThreshold = NotificationPriority.normal,
    this.focusShortcut = const SingleActivator(
      LogicalKeyboardKey.keyN,
      alt: true,
    ),
    this.enableKeyboardDismiss = true,
    this.dismissKey = LogicalKeyboardKey.delete,
    this.escapeDismissesFocused = true,
    this.restoreFocusOnExit = true,
    this.globalEscapeDismiss = true,
  });

  /// Whether screen reader live announcements are triggered on notification
  /// arrival.
  ///
  /// Defaults to `true`.
  final bool enableLiveRegions;

  /// Minimum priority level required to trigger screen reader announcements.
  ///
  /// Notifications with priority lower than [announcePriorityThreshold] will
  /// not trigger screen reader speech. Defaults to
  /// [NotificationPriority.normal].
  final NotificationPriority announcePriorityThreshold;

  /// Keyboard shortcut to transfer focus from the active application to the
  /// notification stack.
  ///
  /// Defaults to `Alt + N` (`Option + N` on macOS). Set to `null` to disable
  /// shortcut-based focus transfer.
  final ShortcutActivator? focusShortcut;

  /// Whether keyboard keys ([dismissKey] and [LogicalKeyboardKey.escape])
  /// dismiss the focused notification card.
  ///
  /// Defaults to `true`.
  final bool enableKeyboardDismiss;

  /// Primary keyboard key that dismisses the currently focused notification.
  ///
  /// Defaults to [LogicalKeyboardKey.delete].
  final LogicalKeyboardKey dismissKey;

  /// Whether pressing Escape while a notification card is focused dismisses it.
  ///
  /// Defaults to `true`.
  final bool escapeDismissesFocused;

  /// Whether focus returns to the previously focused application element after
  /// exiting or dismissing notifications via keyboard.
  ///
  /// Defaults to `true`.
  final bool restoreFocusOnExit;

  /// Whether an unhandled Escape key globally dismisses the newest notification
  /// when no notification card has focus.
  ///
  /// Defaults to `true`.
  final bool globalEscapeDismiss;

  /// Creates a copy of this options object with the given fields replaced.
  NotificationA11yOptions copyWith({
    final bool? enableLiveRegions,
    final NotificationPriority? announcePriorityThreshold,
    final ShortcutActivator? focusShortcut,
    final bool? enableKeyboardDismiss,
    final LogicalKeyboardKey? dismissKey,
    final bool? escapeDismissesFocused,
    final bool? restoreFocusOnExit,
    final bool? globalEscapeDismiss,
  }) =>
      NotificationA11yOptions(
        enableLiveRegions: enableLiveRegions ?? this.enableLiveRegions,
        announcePriorityThreshold:
            announcePriorityThreshold ?? this.announcePriorityThreshold,
        focusShortcut: focusShortcut ?? this.focusShortcut,
        enableKeyboardDismiss:
            enableKeyboardDismiss ?? this.enableKeyboardDismiss,
        dismissKey: dismissKey ?? this.dismissKey,
        escapeDismissesFocused:
            escapeDismissesFocused ?? this.escapeDismissesFocused,
        restoreFocusOnExit: restoreFocusOnExit ?? this.restoreFocusOnExit,
        globalEscapeDismiss: globalEscapeDismiss ?? this.globalEscapeDismiss,
      );

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is NotificationA11yOptions &&
          runtimeType == other.runtimeType &&
          enableLiveRegions == other.enableLiveRegions &&
          announcePriorityThreshold == other.announcePriorityThreshold &&
          focusShortcut == other.focusShortcut &&
          enableKeyboardDismiss == other.enableKeyboardDismiss &&
          dismissKey == other.dismissKey &&
          escapeDismissesFocused == other.escapeDismissesFocused &&
          restoreFocusOnExit == other.restoreFocusOnExit &&
          globalEscapeDismiss == other.globalEscapeDismiss;

  @override
  int get hashCode => Object.hash(
        enableLiveRegions,
        announcePriorityThreshold,
        focusShortcut,
        enableKeyboardDismiss,
        dismissKey,
        escapeDismissesFocused,
        restoreFocusOnExit,
        globalEscapeDismiss,
      );
}
