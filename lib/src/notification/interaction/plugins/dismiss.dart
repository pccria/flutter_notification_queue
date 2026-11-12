part of 'plugins.dart';

/// Gesture plugin implementing swipe-to-dismiss behavior.
class DismissGesturePlugin extends NotificationGesturePlugin {
  const DismissGesturePlugin({required this.behavior});

  final Dismiss behavior;

  @override
  void onDragStart(final DragGestureContext ctx) {
    final position = ctx.notification.queue.position;
    ctx.notification.effectiveCoordinator.bringToFront(position);
    ctx.notification.key.currentState?.pauseDismissTimer();
    if (behavior.zones != null) {
      ctx.overlayPortalController.show();
    }
  }

  @override
  void onDragUpdate(
    final DragGestureContext ctx,
    final DragUpdateDetails details,
  ) {
    // Dismiss tracking handled by host FSM
  }

  @override
  void onDragEnd(
    final DragGestureContext ctx,
    final DraggableDetails details,
  ) {
    if (behavior.zones != null) {
      final pointer = ctx.fsm.pointerPosition ?? details.offset;
      final position = ctx.notification.queue.position;
      final zones = ctx.getZones(behavior, position);

      final isLegacyHit = zones.any(
        (final z) => z.isHit(
          pointer,
          ctx.screenSize,
          behavior.thresholdInPixels.toDouble(),
        ),
      );

      if (isLegacyHit) {
        if (ctx.notification.isPinned) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.mediumImpact();
          ctx.notification.key.currentState
              ?.dismiss(reason: DismissReason.userSwipe);
        }
      }
      ctx.overlayPortalController.hide();
    }
    ctx.notification.key.currentState?.unfocus();
  }

  @override
  Widget buildFeedback(final DragGestureContext ctx) {
    final pointer = ctx.fsm.pointerPosition;
    final position = ctx.notification.queue.position;

    if (behavior.zones != null) {
      final zones = ctx.getZones(behavior, position);
      final passedThreshold = switch (ctx.fsm.value) {
        GestureDismissing(:final passedThreshold) => passedThreshold,
        _ => ctx.passedThreshold(pointer, behavior.thresholdInPixels, zones),
      };

      return OverlayPortal(
        controller: ctx.overlayPortalController,
        overlayChildBuilder: (final context) => LayoutBuilder(
          builder: (final context, final constraints) => DismissalTargets(
            screenSize: constraints.biggest,
            threshold: behavior.thresholdInPixels.toDouble(),
            zones: zones.cast<EdgeDropZone>(),
            gestureState: ctx.gestureState,
          ),
        ),
        child: DismissFeedbackOverlay(
          passedThreshold: passedThreshold,
          dragOffset: pointer,
          thresholdInPixels: behavior.thresholdInPixels,
          screenSize: ctx.screenSize,
          startData: ctx.dragStartData,
          zones: zones.cast<EdgeDropZone>(),
          springPhysics: behavior.springPhysics,
          fsm: ctx.fsm,
          child: ctx.notification,
        ),
      );
    }

    return EgressFeedbackOverlay(
      gestureState: ctx.gestureState,
      behavior: behavior,
      position: position,
      startData: ctx.dragStartData,
      child: ctx.notification,
    );
  }
}
