part of 'behaviors.dart';

/// The default distance (in pixels) from the screen edge required to trigger
/// a drag behavior (relocate or dismiss).
///
/// Defaults to 50 logical pixels.
const int kDefaultQueueDragBehaviorThreshold = 50;

// Phantom markers (internal, not exposed to users)
class OnDrag {}

class OnLongPress {}

sealed class QueueNotificationBehavior<T> {
  const QueueNotificationBehavior({
    required this.thresholdInPixels,
    this.springPhysics = const SpringPhysicsConfiguration.premium(),
  }) : assert(
          thresholdInPixels >= kDefaultQueueDragBehaviorThreshold,
          'thresholdInPixels must be greater than '
          'kDefaultQueueBehaviorThreshold Pixels',
        );

  /// Pixels left from the edge of the screen to trigger the behavior.
  final int thresholdInPixels;

  /// Configuration for physical spring simulations during snap-back.
  final SpringPhysicsConfiguration springPhysics;
}

/// Relocates the notification to the specified positions.
///
/// Moves the notification to the specified positions when the notification
/// is dragged to the edge of the screen.
final class Relocate<T> extends QueueNotificationBehavior<T> {
  const Relocate._({
    required this.positions,
    this.permanent = false,
    super.thresholdInPixels = kDefaultQueueDragBehaviorThreshold,
    super.springPhysics = const SpringPhysicsConfiguration.premium(),
  });

  factory Relocate.to(
    final Set<QueuePosition> positions, {
    final bool permanent = false,
    final SpringPhysicsConfiguration springPhysics =
        const SpringPhysicsConfiguration.premium(),
  }) {
    if (positions.isEmpty) {
      throw ArgumentError.value(
        positions,
        'positions',
        'positions must not be empty',
      );
    }
    return Relocate._(
      positions: positions,
      permanent: permanent,
      springPhysics: springPhysics,
    );
  }

  final Set<QueuePosition> positions;

  /// Whether relocating to a new position permanently redirects the queue
  /// and migrates remaining notifications to the new destination.
  final bool permanent;
}

/// Dismisses the notification via directional swipe or ballistic fling
/// gestures.
///
/// Dismisses the notification when dragged or flicked past the displacement
/// or escape velocity thresholds along allowed egress pathways configured by
/// [egress].
final class Dismiss<T> extends QueueNotificationBehavior<T> {
  const Dismiss({
    super.thresholdInPixels = kDefaultQueueDragBehaviorThreshold,
    super.springPhysics = const SpringPhysicsConfiguration.premium(),
    this.egress = const DismissEgress.horizontal(),
    this.dismissThreshold = 0.40,
    this.escapeVelocity = 600.0,
    this.enableTilt = true,
    this.showUnderlay = true,
    this.dismissIcon,
    this.dismissColor,
    @Deprecated('Use egress instead. Will be removed in 0.8.0.') this.zones,
  });

  /// The directional egress policy that determines the trajectories and
  /// boundaries along which the notification card can be dismissed.
  ///
  /// Defaults to [DismissEgress.horizontal].
  final DismissEgress egress;

  /// The fraction of the card dimension (width or height) that the user must
  /// drag past to commit dismissal if release velocity is below
  /// [escapeVelocity].
  ///
  /// Defaults to `0.40` (40% of the card's dimension).
  final double dismissThreshold;

  /// The minimum ballistic release velocity in logical pixels per second
  /// that commits dismissal regardless of displacement distance.
  ///
  /// Defaults to `600.0` px/s.
  final double escapeVelocity;

  /// Whether the card tilts dynamically during horizontal dragging.
  ///
  /// Defaults to `true`.
  final bool enableTilt;

  /// Whether an egress underlay channel reveals behind the card in the vacated
  /// slot as the user drags.
  ///
  /// Defaults to `true`.
  final bool showUnderlay;

  /// An optional custom icon or widget to render inside the egress underlay
  /// channel. If null, a clean close icon is used.
  final Widget? dismissIcon;

  /// An optional custom accent color for the egress underlay channel. If null,
  /// the ambient theme's error color is used.
  final Color? dismissColor;

  /// The legacy zones where the notification can be dismissed.
  @Deprecated('Use egress instead. Will be removed in 0.8.0.')
  final DismissZone? zones;

  /// Resolves the effective egress policy, preserving backward compatibility
  /// with legacy [zones] if explicitly passed.
  DismissEgress get effectiveEgress => switch (zones) {
        DismissZone.sideEdges => const DismissEgress.horizontal(),
        DismissZone.naturalDirection => const DismissEgress.natural(),
        null => egress,
      };
}

/// Reorders the notification within its current queue.
///
/// When the user drags the notification, slot targets appear between all
/// notifications in the stack. Dropping onto a slot moves this notification
/// to that index.
final class Reorder<T> extends QueueNotificationBehavior<T> {
  const Reorder({
    super.thresholdInPixels = kDefaultQueueDragBehaviorThreshold,
    super.springPhysics = const SpringPhysicsConfiguration.premium(),
  });
}

final class ReorderAndRelocate<T> extends QueueNotificationBehavior<T> {
  const ReorderAndRelocate._({
    required this.positions,
    this.permanent = false,
    super.thresholdInPixels = kDefaultQueueDragBehaviorThreshold,
    super.springPhysics = const SpringPhysicsConfiguration.premium(),
    this.escapeThresholdInPixels = 80.0,
  });

  factory ReorderAndRelocate.to({
    required final Set<QueuePosition> positions,
    final bool permanent = false,
    final double escapeThresholdInPixels = 80.0,
    final SpringPhysicsConfiguration springPhysics =
        const SpringPhysicsConfiguration.premium(),
  }) {
    if (positions.isEmpty) {
      throw ArgumentError.value(
        positions,
        'positions',
        'positions must not be empty',
      );
    }
    return ReorderAndRelocate._(
      positions: positions,
      permanent: permanent,
      escapeThresholdInPixels: escapeThresholdInPixels,
      springPhysics: springPhysics,
    );
  }

  final Set<QueuePosition> positions;

  /// Whether relocating to a new position permanently redirects the queue
  /// and migrates remaining notifications to the new destination.
  final bool permanent;

  /// Pixels beyond the source queue's rendered bounding box at which the
  /// system switches from Reorder to Relocate mode.
  final double escapeThresholdInPixels;
}

final class Disabled<T> extends QueueNotificationBehavior<T> {
  const Disabled()
      : super(
          thresholdInPixels: kDefaultQueueDragBehaviorThreshold,
          springPhysics: const SpringPhysicsConfiguration(),
        );
}

typedef LongPressDragBehavior = QueueNotificationBehavior<OnLongPress>;
typedef DragBehavior = QueueNotificationBehavior<OnDrag>;
