part of 'zones.dart';

/// The abstract base for all spatial drop zones in a drag-and-drop interaction.
///
/// A [DropZone] represents a region of the screen that can receive a dragged
/// notification widget, transitioning through states (idle → engaged →
/// committed) as the pointer moves.
///
/// The hierarchy is intentionally open for extension:
///
/// ```
/// DropZone              (abstract — any spatial target for a drag drop)
/// └── EdgeDropZone      (sealed — a screen-edge, engaged by proximity)
///     ├── LeftEdgeDropZone
///     ├── RightEdgeDropZone
///     ├── TopEdgeDropZone
///     └── BottomEdgeDropZone
/// ```
// ignore: one_member_abstracts
abstract class DropZone {
  const DropZone();

  /// Returns `true` when the pointer is considered to have committed to this
  /// zone (i.e. the drop should be accepted).
  bool isHit(
    final Offset pointer,
    final Size screenSize,
    final double threshold,
  );
}
