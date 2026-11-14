part of 'enums.dart';

/// Represents reasons why a notification auto-dismiss countdown timer may be
/// paused.
enum TimerPauseReason {
  /// The notification card is being actively dragged or settled.
  drag,

  /// A mouse cursor is hovering over the notification card.
  hover,

  /// A touch pointer is currently held down on the card.
  touchHold,

  /// The notification card is expanded by the user to read full content.
  expanded,

  /// The accessibility or context menu popup is currently open.
  contextMenu,

  /// The notification is pinned.
  pinned,
}
