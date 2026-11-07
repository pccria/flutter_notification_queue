part of 'zones.dart';

/// A [DropZone] that accepts a drop when the pointer is within `threshold`
/// pixels of an inter-notification slot anchor.
///
/// Unlike [PositionDropZone] (which derives its anchor from static enum data),
/// [SlotDropZone] anchors are computed dynamically from rendered widget
/// positions and must be set by the feedback layer via [setTargetBounds] after
/// layout — they cannot be derived at construction time.
final class SlotDropZone extends DropZone {
  SlotDropZone({
    required this.targetIndex,
    this.isNatural = false,
  });

  /// The stack index where the dragged notification would be inserted if
  /// dropped on this slot.
  final int targetIndex;

  /// Whether this slot represents the notification's current position.
  ///
  /// Home slots use a stricter proximity threshold to prevent accidental
  /// on-the-spot re-drops immediately after a drag starts.
  final bool isNatural;

  Rect? _targetBounds;

  /// Sets the screen-space bounding box for this slot.
  ///
  /// Must be called by the feedback widget after layout, once the rendered
  /// dimensions of the target notification are known.
  void setTargetBounds(final Rect bounds) => _targetBounds = bounds;

  /// Returns the current spatial bounds, or null if not yet set.
  Rect? get targetBounds => _targetBounds;

  /// Returns the dead-center point of the target bounds, or null.
  Offset? get anchor => _targetBounds?.center;

  /// Returns a normalized proximity value in `[0.0, 1.0]`.
  ///
  /// `0.0` = pointer is farther than `threshold` from the anchor (or bounds
  /// are unset). `1.0` = pointer is exactly on the anchor.
  double calculateProgress(
    final Offset pointer,
    final double inverseThreshold,
  ) {
    if (anchor == null) {
      return 0.0;
    }
    final distance = (anchor! - pointer).distance;
    return (1.0 - (distance * inverseThreshold)).clamp(0.0, 1.0);
  }

  @override
  bool isHit(
    final Offset pointer,
    final Size screenSize,
    final double threshold,
  ) {
    final progress = calculateProgress(pointer, 1.0 / threshold);
    return _ThresholdPolicies.evaluate(progress, isNatural: isNatural);
  }
}
