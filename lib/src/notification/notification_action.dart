part of 'notification.dart';

/// Creates an action for [NotificationWidget].
///
/// [NotificationWidget] **will be dismissed**
/// after [onPressed] callback is executed.
/// ```
/// NotificationAction.button(
///       label: 'Text',
///       onPressed: () {},
///       )
/// ```
/// creates a **button** in the *content of the notification* and
/// ```
/// NotificationAction.onTap(
///       onPressed: () {},
///       )
/// ```
/// executes [onPressed] callback *on notification tap*.
class NotificationAction {
  const NotificationAction._({
    required this.label,
    required this.onPressed,
    required this.type,
    this.focusNode,
  });

  /// Creates a buttoned action
  factory NotificationAction.button({
    required final String label,
    required final void Function() onPressed,
    final FocusNode? focusNode,
  }) =>
      NotificationAction._(
        label: label,
        onPressed: onPressed,
        type: NotificationActionType.button,
        focusNode: focusNode,
      );

  /// Action Label text
  final String? label;

  /// Action onPressed callback
  final void Function() onPressed;

  /// Action type of [NotificationActionType]
  final NotificationActionType type;

  /// Optional [FocusNode] for keyboard focus traversal.
  final FocusNode? focusNode;
}

/// Type of action for [NotificationWidget].
enum NotificationActionType {
  button,
}
