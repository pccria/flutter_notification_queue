part of 'plugins.dart';

/// Gesture plugin implementing snooze behavior.
class SnoozeGesturePlugin extends NotificationGesturePlugin {
  const SnoozeGesturePlugin({required this.behavior});

  final Snooze behavior;

  @override
  void onDragStart(final DragGestureContext ctx) {
    final position = ctx.notification.queue.position;
    ctx.notification.effectiveCoordinator.bringToFront(position);
    ctx.notification.key.currentState?.ditchDismissTimer();
    ctx.overlayPortalController.show();
  }

  @override
  void onDragUpdate(
    final DragGestureContext ctx,
    final DragUpdateDetails details,
  ) {
    // Intent tracking handled by host FSM
  }

  @override
  void onDragEnd(
    final DragGestureContext ctx,
    final DraggableDetails details,
  ) {
    final pointer = ctx.fsm.pointerPosition ?? details.offset;
    final position = ctx.notification.queue.position;
    final zones = ctx.getZones(behavior, position);
    final isHit = zones.any(
      (final z) => z.isHit(
        pointer,
        ctx.screenSize,
        behavior.thresholdInPixels.toDouble(),
      ),
    );
    if (isHit) {
      HapticFeedback.mediumImpact();
      ctx.notification.effectiveCoordinator.snoozeWidget(
        ctx.notification,
        behavior.duration,
      );
    }
    ctx.notification.key.currentState?.initDismissTimer();
    ctx.overlayPortalController.hide();
  }

  @override
  Widget buildFeedback(final DragGestureContext ctx) {
    final pointer = ctx.fsm.pointerPosition;
    final position = ctx.notification.queue.position;
    final zones = ctx.getZones(behavior, position);
    final passedThreshold = switch (ctx.fsm.value) {
      GestureDismissing(:final passedThreshold) => passedThreshold,
      _ => ctx.passedThreshold(pointer, behavior.thresholdInPixels, zones),
    };

    return OverlayPortal(
      controller: ctx.overlayPortalController,
      overlayChildBuilder: (final context) => LayoutBuilder(
        builder: (final context, final constraints) => SnoozeTargets(
          screenSize: constraints.biggest,
          threshold: behavior.thresholdInPixels.toDouble(),
          zones: zones.cast<EdgeDropZone>(),
          gestureState: ctx.gestureState,
        ),
      ),
      child: SnoozeFeedbackOverlay(
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
}
