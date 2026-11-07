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
    bool relocated = false;
    if (pointer != null) {
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
    }
    ctx.dragOffsetPairNotifier.value = null;
    if (!relocated) {
      ctx.notification.key.currentState?.initDismissTimer();
    }
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
        builder: (final context, final constraints) => RelocationTargets(
          targets: behavior.positions,
          currentPosition: position,
          screenSize: constraints.biggest,
          pointerPositionNotifier: ctx.dragOffsetPairNotifier,
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
