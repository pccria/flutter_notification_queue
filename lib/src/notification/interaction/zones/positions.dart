part of 'zones.dart';

/// A [DropZone] that accepts a drop when the pointer is within `threshold`
/// pixels of the [position]'s anchor on screen.
///
/// Unlike [EdgeDropZone], which measures distance to a screen boundary line,
/// [PositionDropZone] measures radial distance from a point — making it the
/// correct primitive for screen-position-based drop targets (e.g., Relocate).
final class PositionDropZone extends DropZone {
  const PositionDropZone({
    required this.position,
    this.isNatural = false,
  });

  /// The queue position this zone represents.
  final QueuePosition position;

  /// Whether this zone is a "home" position for the current queue.
  ///
  /// Home positions use a stricter proximity threshold to prevent accidental
  /// re-drops back onto the queue's own position.
  final bool isNatural;

  /// Computes the anchor point of this zone in global screen coordinates.
  ///
  /// The anchor is derived from the position's [QueuePosition.alignment],
  /// mapping the normalized [-1, 1] alignment axes to screen pixels.
  Offset _anchor(final Size screenSize) {
    final alignment = position.alignment as Alignment;
    return Offset(
      (alignment.x + 1.0) / 2.0 * screenSize.width,
      (alignment.y + 1.0) / 2.0 * screenSize.height,
    );
  }

  /// Returns a normalized proximity value in `[0.0, 1.0]`.
  ///
  /// `0.0` = pointer is farther than `threshold` from the anchor.
  /// `1.0` = pointer is exactly on the anchor.
  double calculateProgress(
    final Offset pointer,
    final Size screenSize,
    final double inverseThreshold,
  ) {
    final distance = (_anchor(screenSize) - pointer).distance;
    return (1.0 - (distance * inverseThreshold)).clamp(0.0, 1.0);
  }

  @override
  bool isHit(
    final Offset pointer,
    final Size screenSize,
    final double threshold,
  ) {
    final progress = calculateProgress(pointer, screenSize, 1.0 / threshold);
    return _ThresholdPolicies.evaluate(progress, isNatural: isNatural);
  }
}
