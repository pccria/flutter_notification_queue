part of 'plugins.dart';

/// Gesture plugin implementing queue relocation behavior.
class RelocateGesturePlugin extends NotificationGesturePlugin {
  const RelocateGesturePlugin({required this.behavior});

  final Relocate behavior;

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
    // Relocation tracking handled by host FSM
  }

  @override
  void onDragEnd(
    final DragGestureContext ctx,
    final DraggableDetails details,
  ) {
    final pointer = ctx.fsm.pointerPosition ?? details.offset;
    final position = ctx.notification.queue.position;
    bool relocated = false;
    final zones = ctx.getZones(behavior, position);
    final hitZone = zones
        .cast<PositionDropZone>()
        .where(
          (final z) => z.isHit(
            pointer,
            ctx.screenSize,
            behavior.thresholdInPixels.toDouble(),
          ),
        )
        .firstOrNull;
    if (hitZone != null) {
      HapticFeedback.mediumImpact();
      ctx.notification.effectiveCoordinator
          .relocateWidget(ctx.notification, hitZone.position);
      relocated = true;
    }
    if (!relocated) {
      ctx.notification.key.currentState?.initDismissTimer();
    }
    ctx.overlayPortalController.hide();
  }

  @override
  Widget buildFeedback(final DragGestureContext ctx) {
    final pointer = ctx.fsm.pointerPosition;
    final position = ctx.notification.queue.position;
    final zones = ctx.getZones(behavior, position);
    final passedThreshold = switch (ctx.fsm.value) {
      GestureRelocating(:final hoveredQueuePosition) =>
        hoveredQueuePosition != null,
      _ => ctx.passedThreshold(pointer, behavior.thresholdInPixels, zones),
    };

    return OverlayPortal(
      controller: ctx.overlayPortalController,
      overlayChildBuilder: (final context) => LayoutBuilder(
        builder: (final context, final constraints) => RelocationTargets(
          targets: behavior.positions,
          currentPosition: position,
          screenSize: constraints.biggest,
          gestureState: ctx.gestureState,
          threshold: behavior.thresholdInPixels.toDouble(),
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOut,
        opacity: passedThreshold ? 0.3 : 1.0,
        child: ctx.notification,
      ),
    );
  }
}
