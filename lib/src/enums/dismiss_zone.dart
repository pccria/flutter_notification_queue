part of 'enums.dart';

/// Defines the legacy screen zones where the notification can be dismissed.
@Deprecated('Use DismissEgress instead. Will be removed in 0.8.0.')
enum DismissZone {
  /// The notification can be dismissed by dragging it to the left or right
  /// edges of the screen.
  ///
  /// These zones span the entire height of the screen, allowing dismissal
  /// from any vertical position.
  sideEdges,

  /// The notification can be dismissed by dragging it in the natural direction
  /// relative to its queue position.
  ///
  /// * For top positions, drag **up** to the top edge.
  /// * For bottom positions, drag **down** to the bottom edge.
  /// * For center positions, the natural direction matches the [sideEdges]
  /// behavior.
  naturalDirection,
}
