part of 'plugins.dart';

/// Gesture plugin implementing pin behavior.
class PinGesturePlugin extends NotificationGesturePlugin {
  const PinGesturePlugin({required this.behavior});

  final Pin behavior;

  @override
  void onDragStart(final DragGestureContext ctx) {
    final position = ctx.notification.queue.position;
    ctx.notification.effectiveCoordinator.bringToFront(position);
    ctx.notification.key.currentState?.ditchDismissTimer();
    ctx.dragOffsetPairNotifier.value = OffsetPair(
      local: Offset.zero,
      global: ctx.dragStartData?.pointerPosition ?? Offset.zero,
    );
    ctx.overlayPortalController.show();
  }

  @override
  void onDragUpdate(
    final DragGestureContext ctx,
    final DragUpdateDetails details,
  ) {
    ctx.dragOffsetPairNotifier.value = OffsetPair(
      local: details.delta,
      global: details.globalPosition,
    );
  }

  @override
  void onDragEnd(
    final DragGestureContext ctx,
    final DraggableDetails details,
  ) {
    final pointer = ctx.dragOffsetPairNotifier.value?.global;
    final position = ctx.notification.queue.position;
    if (pointer != null) {
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
        final isCurrentlyPinned = ctx.notification.isPinned;
        if (isCurrentlyPinned) {
          ctx.notification.effectiveCoordinator.unpinWidget(ctx.notification);
        } else {
          ctx.notification.effectiveCoordinator.pinWidget(ctx.notification);
        }
      }
    }
    ctx.dragOffsetPairNotifier.value = null;
    ctx.notification.key.currentState?.initDismissTimer();
    ctx.overlayPortalController.hide();
  }

  @override
  Widget buildFeedback(
    final DragGestureContext ctx,
    final OffsetPair? offsetPair,
  ) {
    final pointer = offsetPair?.global;
    final position = ctx.notification.queue.position;
    final zones = ctx.getZones(behavior, position);
    final passedThreshold = ctx.passedThreshold(
      pointer,
      behavior.thresholdInPixels,
      zones,
    );

    return OverlayPortal(
      controller: ctx.overlayPortalController,
      overlayChildBuilder: (final context) => LayoutBuilder(
        builder: (final context, final constraints) => PinTargets(
          screenSize: constraints.biggest,
          threshold: behavior.thresholdInPixels.toDouble(),
          zones: zones.cast<EdgeDropZone>(),
          pointerPositionNotifier: ctx.dragOffsetPairNotifier,
          isPinned: ctx.notification.isPinned,
        ),
      ),
      child: PinFeedbackOverlay(
        passedThreshold: passedThreshold,
        dragOffset: pointer,
        thresholdInPixels: behavior.thresholdInPixels,
        screenSize: ctx.screenSize,
        startData: ctx.dragStartData,
        zones: zones.cast<EdgeDropZone>(),
        springPhysics: behavior.springPhysics,
        isPinned: ctx.notification.isPinned,
        child: ctx.notification,
      ),
    );
  }
}
