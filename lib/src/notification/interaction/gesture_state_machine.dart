library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:logd/logd.dart';

import '../../enums/enums.dart';

/// The reactive states of a notification drag-gesture transaction.
@immutable
sealed class GestureState {
  const GestureState();

  /// The current tracking global offset coordinates of the pointer, if active.
  Offset? get pointerPosition => switch (this) {
        GestureIdle() => null,
        GestureLifted(:final pointerPosition) => pointerPosition,
        GestureReordering(:final pointerPosition) => pointerPosition,
        GestureRelocating(:final pointerPosition) => pointerPosition,
        GestureDismissing(:final pointerPosition) => pointerPosition,
        GestureSettling() => null,
      };
}

/// The notification is stationary, resting in its queue stack.
final class GestureIdle extends GestureState {
  const GestureIdle();

  @override
  bool operator ==(final Object other) =>
      identical(this, other) || other is GestureIdle;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'GestureIdle()';
}

/// The gesture is initiated (lifted), capturing bounds and pointer coordinates.
final class GestureLifted extends GestureState {
  const GestureLifted({
    required this.pointerPosition,
    required this.cardRect,
    required this.containerRect,
  });

  @override
  final Offset pointerPosition;
  final Rect cardRect;
  final Rect containerRect;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is GestureLifted &&
          runtimeType == other.runtimeType &&
          pointerPosition == other.pointerPosition &&
          cardRect == other.cardRect &&
          containerRect == other.containerRect;

  @override
  int get hashCode => Object.hash(pointerPosition, cardRect, containerRect);

  @override
  String toString() =>
      'GestureLifted(pointerPosition: $pointerPosition, cardRect: $cardRect, '
      'containerRect: $containerRect)';
}

/// Actively reordering the notification card within its home queue stack slots.
final class GestureReordering extends GestureState {
  const GestureReordering({
    required this.pointerPosition,
    required this.cardRect,
    required this.containerRect,
    required this.targetSlotIndex,
    required this.progress,
  });

  @override
  final Offset pointerPosition;
  final Rect cardRect;
  final Rect containerRect;
  final int? targetSlotIndex;
  final double progress;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is GestureReordering &&
          runtimeType == other.runtimeType &&
          pointerPosition == other.pointerPosition &&
          cardRect == other.cardRect &&
          containerRect == other.containerRect &&
          targetSlotIndex == other.targetSlotIndex &&
          progress == other.progress;

  @override
  int get hashCode => Object.hash(
        pointerPosition,
        cardRect,
        containerRect,
        targetSlotIndex,
        progress,
      );

  @override
  String toString() => 'GestureReordering(pointerPosition: $pointerPosition, '
      'cardRect: $cardRect, containerRect: $containerRect, '
      'targetSlotIndex: $targetSlotIndex, progress: $progress)';
}

/// Actively relocating the notification card to alternative screen positions.
final class GestureRelocating extends GestureState {
  const GestureRelocating({
    required this.pointerPosition,
    required this.cardRect,
    required this.containerRect,
    required this.hoveredQueuePosition,
  });

  @override
  final Offset pointerPosition;
  final Rect cardRect;
  final Rect containerRect;
  final QueuePosition? hoveredQueuePosition;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is GestureRelocating &&
          runtimeType == other.runtimeType &&
          pointerPosition == other.pointerPosition &&
          cardRect == other.cardRect &&
          containerRect == other.containerRect &&
          hoveredQueuePosition == other.hoveredQueuePosition;

  @override
  int get hashCode => Object.hash(
        pointerPosition,
        cardRect,
        containerRect,
        hoveredQueuePosition,
      );

  @override
  String toString() => 'GestureRelocating(pointerPosition: $pointerPosition, '
      'cardRect: $cardRect, containerRect: $containerRect, '
      'hoveredQueuePosition: $hoveredQueuePosition)';
}

/// Actively dismissing or performing directional swipe action on the card.
final class GestureDismissing extends GestureState {
  const GestureDismissing({
    required this.pointerPosition,
    required this.cardRect,
    required this.passedThreshold,
  });

  @override
  final Offset pointerPosition;
  final Rect cardRect;
  final bool passedThreshold;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is GestureDismissing &&
          runtimeType == other.runtimeType &&
          pointerPosition == other.pointerPosition &&
          cardRect == other.cardRect &&
          passedThreshold == other.passedThreshold;

  @override
  int get hashCode => Object.hash(pointerPosition, cardRect, passedThreshold);

  @override
  String toString() => 'GestureDismissing(pointerPosition: $pointerPosition, '
      'cardRect: $cardRect, passedThreshold: $passedThreshold)';
}

/// The pointer has been released. The card is settling into its final
/// position via physics-based snap-back animations or transitioning to a
/// new queue.
final class GestureSettling extends GestureState {
  const GestureSettling({
    required this.originOffset,
    required this.targetOffset,
    required this.velocity,
  });

  final Offset originOffset;
  final Offset targetOffset;
  final Velocity velocity;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is GestureSettling &&
          runtimeType == other.runtimeType &&
          originOffset == other.originOffset &&
          targetOffset == other.targetOffset &&
          velocity == other.velocity;

  @override
  int get hashCode => Object.hash(originOffset, targetOffset, velocity);

  @override
  String toString() => 'GestureSettling(originOffset: $originOffset, '
      'targetOffset: $targetOffset, velocity: $velocity)';
}

/// A state machine that drives notification drag-gesture transactions.
///
/// Fully decouples the gestural physics and state tracking logic from the
/// rendering tree, exposing a reactive [ValueNotifier] interface.
class GestureStateMachine extends ValueNotifier<GestureState> {
  GestureStateMachine({
    required this.initialBehavior,
    required this.initialPosition,
    this.escapeThreshold = 80.0,
  })  : _activeBehavior = initialBehavior,
        super(const GestureIdle());

  /// The initial interaction behavior.
  final QueueNotificationBehavior initialBehavior;

  /// The active behavior for the current drag transaction.
  QueueNotificationBehavior _activeBehavior;
  QueueNotificationBehavior get activeBehavior => _activeBehavior;

  /// The initial queue position of the notification.
  final QueuePosition initialPosition;

  /// Threshold in pixels to escape the source queue and enter Relocation.
  final double escapeThreshold;

  /// The current tracking global offset coordinates of the pointer.
  Offset? _pointerPosition;
  Offset? get pointerPosition => _pointerPosition;

  /// The starting card bounds rect (captured at lift-off).
  Rect _cardRect = Rect.zero;
  Rect get cardRect => _cardRect;

  /// The starting container bounds rect (captured at lift-off).
  Rect _containerRect = Rect.zero;
  Rect get containerRect => _containerRect;

  static final _logger = Logger.get('fnq.Notification.FSM');

  /// Resets the FSM to idle.
  void reset() {
    _cardRect = Rect.zero;
    _containerRect = Rect.zero;
    _pointerPosition = null;
    _activeBehavior = initialBehavior;
    value = const GestureIdle();
  }

  /// Signals that a drag transaction has officially started (lift-off).
  void lift({
    required final Offset pointerStart,
    required final Rect cardRect,
    required final Rect containerRect,
    final QueueNotificationBehavior? behavior,
  }) {
    _activeBehavior = behavior ?? initialBehavior;
    _cardRect = cardRect;
    _containerRect = containerRect;
    _pointerPosition = pointerStart;
    value = GestureLifted(
      pointerPosition: pointerStart,
      cardRect: cardRect,
      containerRect: containerRect,
    );

    _logger.debug(
      'Gesture lifted at $pointerStart, card: $cardRect, '
      'container: $containerRect',
    );
  }

  /// Processes active pointer updates and drives state changes.
  void update({
    required final Offset delta,
    required final Offset globalPosition,
    final int? targetSlotIndex,
    final double? progress,
    final QueuePosition? hoveredQueuePosition,
    final bool? passedThreshold,
  }) {
    if (value is GestureIdle || value is GestureSettling) {
      return;
    }

    _pointerPosition = globalPosition;

    final behavior = _activeBehavior;

    if (behavior is Dismiss ||
        behavior is Snooze ||
        behavior is Pin ||
        behavior is CustomAction) {
      final currentPassedThreshold = passedThreshold ??
          (value is GestureDismissing &&
              (value as GestureDismissing).passedThreshold);
      value = GestureDismissing(
        pointerPosition: globalPosition,
        cardRect: _cardRect,
        passedThreshold: currentPassedThreshold,
      );
    } else if (behavior is Relocate) {
      value = GestureRelocating(
        pointerPosition: globalPosition,
        cardRect: _cardRect,
        containerRect: _containerRect,
        hoveredQueuePosition: hoveredQueuePosition,
      );
    } else if (behavior is Reorder) {
      value = GestureReordering(
        pointerPosition: globalPosition,
        cardRect: _cardRect,
        containerRect: _containerRect,
        targetSlotIndex: targetSlotIndex,
        progress: progress ?? 0.0,
      );
    } else if (behavior is ReorderAndRelocate) {
      final activeEscape = identical(behavior, initialBehavior)
          ? escapeThreshold
          : behavior.escapeThresholdInPixels;
      // Escape boundary logic: check if pointer has escaped container boundary
      final isInside =
          _containerRect.inflate(activeEscape).contains(globalPosition);

      if (isInside) {
        if (value is! GestureReordering) {
          _logger.debug('FSM transitioned to Reordering (inside container)');
        }
        value = GestureReordering(
          pointerPosition: globalPosition,
          cardRect: _cardRect,
          containerRect: _containerRect,
          targetSlotIndex: targetSlotIndex,
          progress: progress ?? 0.0,
        );
      } else {
        if (value is! GestureRelocating) {
          _logger.debug('FSM transitioned to Relocating (escaped container)');
        }
        value = GestureRelocating(
          pointerPosition: globalPosition,
          cardRect: _cardRect,
          containerRect: _containerRect,
          hoveredQueuePosition: hoveredQueuePosition,
        );
      }
    }
  }

  /// Signals that the pointer has been released and snap-back or commit
  /// calculations have begun.
  void settle({
    final Offset originOffset = Offset.zero,
    final Offset targetOffset = Offset.zero,
    final Velocity velocity = Velocity.zero,
  }) {
    if (value is GestureIdle) {
      return;
    }
    value = GestureSettling(
      originOffset: originOffset,
      targetOffset: targetOffset,
      velocity: velocity,
    );
    _logger.debug('Gesture entering Settle state');
  }

  /// Computes the active stretch scaling factor for visual widgets during
  /// drags.
  ///
  /// Provides progressive feedback as the pointer moves.
  double getActiveScale(final double maxScale) => switch (value) {
        GestureIdle() => 1.0,
        GestureLifted() => 1.02,
        GestureReordering() => maxScale,
        GestureRelocating() => maxScale,
        GestureDismissing(:final passedThreshold) =>
          passedThreshold ? 0.85 : maxScale,
        GestureSettling() => 1.0,
      };
}
