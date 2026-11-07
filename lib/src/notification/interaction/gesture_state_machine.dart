library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:logd/logd.dart';

import '../../enums/enums.dart';

/// The reactive states of a notification drag-gesture transaction.
enum GestureState {
  /// The notification is stationary, resting in its queue stack.
  idle,

  /// The gesture is initiated (lifted), applying dynamic scaling and haptics,
  /// but the pointer has not yet crossed threshold boundaries.
  lifted,

  /// Actively reordering the notification card within its home queue stack
  /// slots.
  reordering,

  /// Actively relocating the notification card to alternative screen
  /// positions.
  relocating,

  /// The pointer has been released. The card is settling into its final
  /// position via physics-based snap-back animations or transitioning to a
  /// new queue.
  settling,
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
  }) : super(GestureState.idle);

  /// The initial interaction behavior.
  final QueueNotificationBehavior initialBehavior;

  /// The initial queue position of the notification.
  final QueuePosition initialPosition;

  /// Threshold in pixels to escape the source queue and enter Relocation.
  final double escapeThreshold;

  /// The current tracking global offset coordinates of the pointer.
  Offset? _pointerPosition;
  Offset? get pointerPosition => _pointerPosition;

  /// The starting widget bounds rect (captured at lift-off).
  Rect? _sourceWidgetRect;

  static final _logger = Logger.get('fnq.Notification.FSM');

  /// Resets the FSM to idle.
  void reset() {
    _pointerPosition = null;
    _sourceWidgetRect = null;
    value = GestureState.idle;
  }

  /// Signals that a drag transaction has officially started (lift-off).
  void lift({
    required final Offset pointerStart,
    required final Rect widgetRect,
  }) {
    _pointerPosition = pointerStart;
    _sourceWidgetRect = widgetRect;
    value = GestureState.lifted;

    _logger.debug('Gesture lifted at $pointerStart, bounds: $widgetRect');
  }

  /// Processes active pointer updates and drives state changes.
  void update({
    required final Offset delta,
    required final Offset globalPosition,
  }) {
    if (value == GestureState.idle || value == GestureState.settling) {
      return;
    }

    _pointerPosition = globalPosition;

    // Resolve state transitions based on behavior rules
    final behavior = initialBehavior;

    if (behavior is Dismiss) {
      // Unified tracking for dismiss gestures
      value = GestureState.reordering;
    } else if (behavior is Relocate) {
      value = GestureState.relocating;
    } else if (behavior is Reorder) {
      value = GestureState.reordering;
    } else if (behavior is ReorderAndRelocate) {
      // Escape boundary logic: check if the pointer has drifted past the
      // expanded boundary
      final sourceRect = _sourceWidgetRect;
      if (sourceRect != null) {
        final expandedRect = sourceRect.inflate(escapeThreshold);
        final isInside = expandedRect.contains(globalPosition);

        if (isInside) {
          if (value != GestureState.reordering) {
            value = GestureState.reordering;
            _logger.debug('FSM transitioned to Reordering (inside queue)');
          }
        } else {
          if (value != GestureState.relocating) {
            value = GestureState.relocating;
            _logger.debug('FSM transitioned to Relocating (escaped queue)');
          }
        }
      } else {
        value = GestureState.reordering;
      }
    }
  }

  /// Signals that the pointer has been released and snap-back or commit
  /// calculations have begun.
  void settle() {
    if (value == GestureState.idle) {
      return;
    }
    value = GestureState.settling;
    _logger.debug('Gesture entering Settle state');
  }

  /// Computes the active stretch scaling factor for visual widgets during
  /// drags.
  ///
  /// Provides progressive feedback as the pointer moves.
  double getActiveScale(final double maxScale) {
    if (value == GestureState.idle) {
      return 1.0;
    }
    if (value == GestureState.lifted) {
      return 1.02;
    }
    return maxScale;
  }
}
