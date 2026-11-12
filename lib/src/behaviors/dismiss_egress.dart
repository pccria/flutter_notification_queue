part of 'behaviors.dart';

/// Defines directional pathways and spatial boundary policies along which a
/// notification card can be dismissed via swipe or fling gestures.
///
/// Unlike screen-edge drop zones which require dragging across large distances
/// to the display bezels, [DismissEgress] evaluates relative displacement and
/// velocity flick momentum along allowable directional tracks.
///
/// Available egress policies:
/// - [DismissEgress.horizontal] / [DismissEgressHorizontal] — swipe left or
///   right (default)
/// - [DismissEgress.natural] / [DismissEgressNatural] — contextual exit matching
///   the queue's screen position
/// - [DismissEgress.outward] / [DismissEgressOutward] — swipe strictly outward
///   toward the nearest display bezel
/// - [DismissEgress.cross] / [DismissEgressCross] — natural vertical egress
///   combined with horizontal swiping
/// - [DismissEgress.any] / [DismissEgressAny] — omnidirectional flick or drag
///   away from rest origin
///
/// Example:
/// ```dart
/// NotificationQueue(
///   position: QueuePosition.topCenter,
///   dragBehavior: Dismiss(
///     egress: const DismissEgress.natural(),
///     dismissThreshold: 0.35,
///     escapeVelocity: 550.0,
///   ),
/// )
/// ```
sealed class DismissEgress {
  const DismissEgress();

  /// Dismisses via horizontal swipe along either the left or right egress
  /// tracks.
  const factory DismissEgress.horizontal({
    final bool allowLeft,
    final bool allowRight,
  }) = DismissEgressHorizontal;

  /// Dismisses along the natural egress direction corresponding to the queue's
  /// spatial anchor on the screen.
  ///
  /// * Top queues ([QueuePosition.topLeft], [QueuePosition.topCenter],
  ///   [QueuePosition.topRight]): Swiping **upward** commits dismissal (plus
  ///   outward horizontal egress for corner queues).
  /// * Bottom queues ([QueuePosition.bottomLeft], [QueuePosition.bottomCenter],
  ///   [QueuePosition.bottomRight]): Swiping **downward** commits dismissal
  ///   (plus outward horizontal egress for corner queues).
  /// * Center queues ([QueuePosition.centerLeft], [QueuePosition.centerRight]):
  ///   Swiping **outward** toward the nearest screen bezel commits dismissal.
  const factory DismissEgress.natural() = DismissEgressNatural;

  /// Dismisses strictly outward toward the nearest display bezel based on the
  /// queue's screen position.
  ///
  /// * Left-aligned queues ([QueuePosition.topLeft],
  ///   [QueuePosition.centerLeft], [QueuePosition.bottomLeft]): Swiping
  ///   **leftward** commits dismissal.
  /// * Right-aligned queues ([QueuePosition.topRight],
  ///   [QueuePosition.centerRight], [QueuePosition.bottomRight]): Swiping
  ///   **rightward** commits dismissal.
  /// * Center-aligned queues ([QueuePosition.topCenter],
  ///   [QueuePosition.bottomCenter]): Both leftward and rightward swipes are
  ///   permitted.
  const factory DismissEgress.outward() = DismissEgressOutward;

  /// Dismisses along either the queue's natural vertical egress direction or
  /// either horizontal direction (Android Heads-Up notification model).
  ///
  /// * For top queues: Swiping **up**, **left**, or **right** dismisses.
  /// * For bottom queues: Swiping **down**, **left**, or **right** dismisses.
  /// * For center queues: Swiping **left** or **right** dismisses.
  const factory DismissEgress.cross() = DismissEgressCross;

  /// Dismisses when flicked or dragged past the threshold in any direction
  /// away from the queue origin.
  const factory DismissEgress.any() = DismissEgressAny;

  /// Clamps and damps displacement along a forbidden axis using a rubber-band
  /// resistance curve.
  ///
  /// Uses an asymptotic rational function:
  /// `damped = sign(d) * max * (1 - 1 / (1 + |d| / max))`
  ///
  /// This guarantees continuous, smooth damping that asymptotically approaches
  /// [maxDisplacement] without abrupt clipping or velocity discontinuities.
  static double dampAxis(
    final double displacement, {
    final double maxDisplacement = 32.0,
  }) {
    if (displacement == 0) {
      return 0.0;
    }
    final sign = displacement < 0 ? -1.0 : 1.0;
    final abs = displacement.abs();
    return sign * maxDisplacement * (1.0 - 1.0 / (1.0 + abs / maxDisplacement));
  }

  /// Determines whether the directional [vector] (such as a drag displacement
  /// offset or velocity vector) aligns with an allowed egress trajectory for a
  /// notification anchored at [position].
  bool allowsVector(final Offset vector, final QueuePosition position);

  /// Applies viscous elastic damping to the raw displacement [offset] based on
  /// whether the directional movement is permitted by this egress policy for
  /// a notification anchored at [position].
  ///
  /// Allowed axes maintain 1:1 direct tracking, while forbidden axes are
  /// progressively damped with a tactile rubber-band curve.
  Offset applyViscousDamping(
    final Offset offset,
    final QueuePosition position,
  );

  /// Calculates normalized dismissal progress along allowable egress vectors,
  /// where `1.0` represents the commit threshold.
  ///
  /// Returns `0.0` if the displacement does not align with an allowable egress
  /// trajectory.
  double calculateProgress({
    required final Offset offset,
    required final Size cardSize,
    required final QueuePosition position,
    final double distanceFraction = 0.40,
  }) {
    if (!allowsVector(offset, position)) {
      return 0.0;
    }
    final effectiveWidth = cardSize.width > 0 ? cardSize.width : 300.0;
    final effectiveHeight = cardSize.height > 0 ? cardSize.height : 80.0;
    final isHorizontal = offset.dx.abs() >= offset.dy.abs();

    if (isHorizontal) {
      final target = effectiveWidth * distanceFraction;
      return target > 0 ? (offset.dx.abs() / target) : 0.0;
    } else {
      final target = effectiveHeight * distanceFraction;
      return target > 0 ? (offset.dy.abs() / target) : 0.0;
    }
  }

  /// Evaluates whether the user's gesture satisfies either the relative
  /// displacement threshold or the escape velocity threshold along an allowable
  /// egress trajectory.
  ///
  /// Returns `true` if:
  /// 1. The ballistic release [velocity] exceeds [escapeVelocity] in an allowed
  ///    direction, OR
  /// 2. The relative travel along an allowed axis exceeds [distanceFraction] of
  ///    the card's dimension.
  bool isCommit({
    required final Offset offset,
    required final Velocity velocity,
    required final Size cardSize,
    required final QueuePosition position,
    final double distanceFraction = 0.40,
    final double escapeVelocity = 600.0,
  }) {
    final effectiveWidth = cardSize.width > 0 ? cardSize.width : 300.0;
    final effectiveHeight = cardSize.height > 0 ? cardSize.height : 80.0;
    final velPixels = velocity.pixelsPerSecond;

    // 1. Velocity Fling Evaluation (Priority Throw)
    if (velPixels.distance >= escapeVelocity &&
        allowsVector(velPixels, position)) {
      return true;
    }

    // 2. Relative Displacement Evaluation
    if (!allowsVector(offset, position)) {
      return false;
    }

    final isHorizontal = offset.dx.abs() >= offset.dy.abs();
    if (isHorizontal) {
      final ratio = offset.dx.abs() / effectiveWidth;
      return ratio >= distanceFraction;
    } else {
      final ratio = offset.dy.abs() / effectiveHeight;
      return ratio >= distanceFraction;
    }
  }
}

/// Dismisses via horizontal swipe along either the left or right egress tracks.
///
/// This is the universal mobile and desktop default.
final class DismissEgressHorizontal extends DismissEgress {
  const DismissEgressHorizontal({
    this.allowLeft = true,
    this.allowRight = true,
  });

  /// Whether swiping leftward is an allowable egress trajectory.
  final bool allowLeft;

  /// Whether swiping rightward is an allowable egress trajectory.
  final bool allowRight;

  @override
  bool allowsVector(final Offset vector, final QueuePosition position) {
    if (vector.dx == 0) {
      return false;
    }
    // Must be primarily horizontal movement
    if (vector.dx.abs() < vector.dy.abs() * 0.75) {
      return false;
    }
    if (vector.dx < 0 && allowLeft) {
      return true;
    }
    if (vector.dx > 0 && allowRight) {
      return true;
    }
    return false;
  }

  @override
  Offset applyViscousDamping(
    final Offset offset,
    final QueuePosition position,
  ) {
    final dx = offset.dx;
    final effectiveDx = (dx < 0 && allowLeft) || (dx > 0 && allowRight)
        ? dx
        : DismissEgress.dampAxis(dx);
    final effectiveDy = DismissEgress.dampAxis(offset.dy);
    return Offset(effectiveDx, effectiveDy);
  }
}

/// Dismisses along the natural egress direction corresponding to the queue's
/// spatial anchor on the screen.
///
/// For top queues, swiping upward exits off the top edge. For bottom queues,
/// swiping downward exits off the bottom edge. Corner queues also permit
/// outward horizontal egress toward the nearest side bezel.
final class DismissEgressNatural extends DismissEgress {
  const DismissEgressNatural();

  @override
  bool allowsVector(final Offset vector, final QueuePosition position) {
    if (vector.distanceSquared == 0) {
      return false;
    }

    final dx = vector.dx;
    final dy = vector.dy;
    final isHorizontalDominant = dx.abs() >= dy.abs();

    return switch (position) {
      QueuePosition.topLeft =>
        (dy < 0 && !isHorizontalDominant) || (dx < 0 && isHorizontalDominant),
      QueuePosition.topCenter => dy < 0 && dy.abs() >= dx.abs() * 0.5,
      QueuePosition.topRight =>
        (dy < 0 && !isHorizontalDominant) || (dx > 0 && isHorizontalDominant),
      QueuePosition.bottomLeft =>
        (dy > 0 && !isHorizontalDominant) || (dx < 0 && isHorizontalDominant),
      QueuePosition.bottomCenter => dy > 0 && dy.abs() >= dx.abs() * 0.5,
      QueuePosition.bottomRight =>
        (dy > 0 && !isHorizontalDominant) || (dx > 0 && isHorizontalDominant),
      QueuePosition.centerLeft => dx < 0 && dx.abs() >= dy.abs() * 0.5,
      QueuePosition.centerRight => dx > 0 && dx.abs() >= dy.abs() * 0.5,
    };
  }

  @override
  Offset applyViscousDamping(
    final Offset offset,
    final QueuePosition position,
  ) {
    final dx = offset.dx;
    final dy = offset.dy;

    final (allowDx, allowDy) = switch (position) {
      QueuePosition.topLeft => (dx < 0, dy < 0),
      QueuePosition.topCenter => (false, dy < 0),
      QueuePosition.topRight => (dx > 0, dy < 0),
      QueuePosition.bottomLeft => (dx < 0, dy > 0),
      QueuePosition.bottomCenter => (false, dy > 0),
      QueuePosition.bottomRight => (dx > 0, dy > 0),
      QueuePosition.centerLeft => (dx < 0, false),
      QueuePosition.centerRight => (dx > 0, false),
    };

    final effectiveDx = allowDx ? dx : DismissEgress.dampAxis(dx);
    final effectiveDy = allowDy ? dy : DismissEgress.dampAxis(dy);
    return Offset(effectiveDx, effectiveDy);
  }
}

/// Dismisses strictly outward toward the nearest display bezel based on the
/// queue's screen position.
///
/// Prevents throwing a left-docked notification across the entire screen to the
/// right, or a right-docked notification across to the left.
final class DismissEgressOutward extends DismissEgress {
  const DismissEgressOutward();

  @override
  bool allowsVector(final Offset vector, final QueuePosition position) {
    if (vector.dx == 0) {
      return false;
    }
    if (vector.dx.abs() < vector.dy.abs() * 0.75) {
      return false;
    }

    return switch (position) {
      QueuePosition.topLeft ||
      QueuePosition.centerLeft ||
      QueuePosition.bottomLeft =>
        vector.dx < 0,
      QueuePosition.topRight ||
      QueuePosition.centerRight ||
      QueuePosition.bottomRight =>
        vector.dx > 0,
      QueuePosition.topCenter || QueuePosition.bottomCenter => true,
    };
  }

  @override
  Offset applyViscousDamping(
    final Offset offset,
    final QueuePosition position,
  ) {
    final dx = offset.dx;
    final allowDx = switch (position) {
      QueuePosition.topLeft ||
      QueuePosition.centerLeft ||
      QueuePosition.bottomLeft =>
        dx < 0,
      QueuePosition.topRight ||
      QueuePosition.centerRight ||
      QueuePosition.bottomRight =>
        dx > 0,
      QueuePosition.topCenter || QueuePosition.bottomCenter => true,
    };
    final effectiveDx = allowDx ? dx : DismissEgress.dampAxis(dx);
    final effectiveDy = DismissEgress.dampAxis(offset.dy);
    return Offset(effectiveDx, effectiveDy);
  }
}

/// Dismisses along either the queue's natural vertical egress direction or
/// either horizontal direction (Android Heads-Up notification model).
///
/// Provides maximum ergonomic flexibility for floating top and bottom HUDs.
final class DismissEgressCross extends DismissEgress {
  const DismissEgressCross();

  @override
  bool allowsVector(final Offset vector, final QueuePosition position) {
    if (vector.distanceSquared == 0) {
      return false;
    }

    final dx = vector.dx;
    final dy = vector.dy;

    // Horizontal swipe is always allowed
    if (dx.abs() >= dy.abs() * 0.75) {
      return true;
    }

    // Vertical swipe is allowed along the natural direction
    return switch (position) {
      QueuePosition.topLeft ||
      QueuePosition.topCenter ||
      QueuePosition.topRight =>
        dy < 0,
      QueuePosition.bottomLeft ||
      QueuePosition.bottomCenter ||
      QueuePosition.bottomRight =>
        dy > 0,
      QueuePosition.centerLeft || QueuePosition.centerRight => false,
    };
  }

  @override
  Offset applyViscousDamping(
    final Offset offset,
    final QueuePosition position,
  ) {
    final dy = offset.dy;
    final allowDy = switch (position) {
      QueuePosition.topLeft ||
      QueuePosition.topCenter ||
      QueuePosition.topRight =>
        dy < 0,
      QueuePosition.bottomLeft ||
      QueuePosition.bottomCenter ||
      QueuePosition.bottomRight =>
        dy > 0,
      QueuePosition.centerLeft || QueuePosition.centerRight => false,
    };
    final effectiveDy = allowDy ? dy : DismissEgress.dampAxis(dy);
    return Offset(offset.dx, effectiveDy);
  }
}

/// Dismisses when flicked or dragged past the threshold in any direction away
/// from the queue origin.
final class DismissEgressAny extends DismissEgress {
  const DismissEgressAny();

  @override
  bool allowsVector(final Offset vector, final QueuePosition position) =>
      vector.distanceSquared > 0;

  @override
  Offset applyViscousDamping(
    final Offset offset,
    final QueuePosition position,
  ) =>
      offset;
}
