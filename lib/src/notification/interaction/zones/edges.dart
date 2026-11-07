part of 'zones.dart';

/// A sealed [DropZone] that monitors proximity to a physical screen edge.
///
/// Engagement is determined by how close the global pointer is to the edge
/// relative to a configurable threshold. The [isNatural] flag applies a
/// stricter hysteresis policy for "home" edges — the edge(s) the queue
/// naturally sits against — to prevent accidental triggers.
sealed class EdgeDropZone extends DropZone {
  const EdgeDropZone({this.isNatural = false});

  /// Whether this zone is a "home" edge for the current queue position.
  ///
  /// Natural edges require a deeper pull (70% of threshold) before engaging,
  /// preventing hair-trigger activation when the queue is already pushed
  /// against that boundary.
  final bool isNatural;

  /// The main axis orientation of the engagement feedback bar.
  Axis get axis;

  /// The screen alignment corresponding to this edge.
  Alignment get alignment;

  /// Returns a normalized progress value in `[0.0, 1.0]` representing how
  /// far the pointer has entered this zone.
  ///
  /// A value of `0.0` means the pointer is outside the zone. A value of
  /// `1.0` means the pointer has reached the screen edge itself.
  double calculateProgress(
    final Offset pointer,
    final Size screenSize,
    final double inverseThreshold,
  );

  /// Returns `true` when the pointer is considered to have committed
  /// to this zone, according to the [_ThresholdPolicies] for [isNatural].
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

// ─── EdgeDropZone Subclasses ───────────────────────────────────────────────

final class LeftEdgeDropZone extends EdgeDropZone {
  const LeftEdgeDropZone({super.isNatural});

  @override
  Axis get axis => Axis.vertical;

  @override
  Alignment get alignment => Alignment.centerLeft;

  @override
  double calculateProgress(
    final Offset pointer,
    final Size screenSize,
    final double inverseThreshold,
  ) =>
      (pointer.dx < screenSize.width * 0.5)
          ? (1.0 - (pointer.dx * inverseThreshold)).clamp(0.0, 1.0)
          : 0.0;
}

final class RightEdgeDropZone extends EdgeDropZone {
  const RightEdgeDropZone({super.isNatural});

  @override
  Axis get axis => Axis.vertical;

  @override
  Alignment get alignment => Alignment.centerRight;

  @override
  double calculateProgress(
    final Offset pointer,
    final Size screenSize,
    final double inverseThreshold,
  ) =>
      (pointer.dx > screenSize.width * 0.5)
          ? (1.0 - ((screenSize.width - pointer.dx) * inverseThreshold))
              .clamp(0.0, 1.0)
          : 0.0;
}

final class TopEdgeDropZone extends EdgeDropZone {
  const TopEdgeDropZone({super.isNatural});

  @override
  Axis get axis => Axis.horizontal;

  @override
  Alignment get alignment => Alignment.topCenter;

  @override
  double calculateProgress(
    final Offset pointer,
    final Size screenSize,
    final double inverseThreshold,
  ) =>
      (pointer.dy < screenSize.height * 0.5)
          ? (1.0 - (pointer.dy * inverseThreshold)).clamp(0.0, 1.0)
          : 0.0;
}

final class BottomEdgeDropZone extends EdgeDropZone {
  const BottomEdgeDropZone({super.isNatural});

  @override
  Axis get axis => Axis.horizontal;

  @override
  Alignment get alignment => Alignment.bottomCenter;

  @override
  double calculateProgress(
    final Offset pointer,
    final Size screenSize,
    final double inverseThreshold,
  ) =>
      (pointer.dy > screenSize.height * 0.5)
          ? (1.0 - ((screenSize.height - pointer.dy) * inverseThreshold))
              .clamp(0.0, 1.0)
          : 0.0;
}

// ─── Threshold Policies ────────────────────────────────────────────────────

abstract final class _ThresholdPolicies {
  const _ThresholdPolicies._();

  static bool evaluate(
    final double progress, {
    required final bool isNatural,
  }) {
    if (isNatural) {
      return progress >= 0.7;
    }
    return progress > 0.01;
  }
}
