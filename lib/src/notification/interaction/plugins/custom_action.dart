part of 'plugins.dart';

/// Gesture plugin implementing custom action behavior.
class CustomActionGesturePlugin extends NotificationGesturePlugin {
  const CustomActionGesturePlugin({required this.behavior});

  final CustomAction behavior;

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
        final notificationQueue = ctx.notification.queue;
        final key = ctx.notification.effectiveCoordinator
            .getWidgetKey(notificationQueue.position);
        if (key.currentState != null) {
          key.currentState!.remove(ctx.notification);
        }
        ctx.notification.effectiveCoordinator.triggerCustomAction(
          ctx.notification,
          behavior.actionName,
        );
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
        builder: (final context, final constraints) => CustomActionTargets(
          screenSize: constraints.biggest,
          threshold: behavior.thresholdInPixels.toDouble(),
          zones: zones.cast<EdgeDropZone>(),
          pointerPositionNotifier: ctx.dragOffsetPairNotifier,
          actionName: behavior.actionName,
        ),
      ),
      child: CustomActionFeedbackOverlay(
        passedThreshold: passedThreshold,
        dragOffset: pointer,
        thresholdInPixels: behavior.thresholdInPixels,
        screenSize: ctx.screenSize,
        startData: ctx.dragStartData,
        zones: zones.cast<EdgeDropZone>(),
        springPhysics: behavior.springPhysics,
        actionName: behavior.actionName,
        child: ctx.notification,
      ),
    );
  }
}
