part of 'plugins.dart';

/// Gesture plugin implementing list stack reordering behavior.
class ReorderGesturePlugin extends NotificationGesturePlugin {
  const ReorderGesturePlugin({required this.behavior});

  final Reorder behavior;

  @override
  void onDragStart(final DragGestureContext ctx) {
    final position = ctx.notification.queue.position;
    final queueKey =
        ctx.notification.effectiveCoordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;
    final itemCount = queueState?.itemCount ?? 1;
    final currentIndex = queueState?.indexOf(ctx.notification) ?? 0;

    ctx.notification.effectiveCoordinator.bringToFront(position);
    ctx.notification.key.currentState?.ditchDismissTimer();
    queueState?.startDragReorder(ctx.notification.id, currentIndex);
    ctx
      ..activeZoneIndex = null
      ..activeReorderZones = zonesFromSlots(itemCount, currentIndex)
      ..overlayPortalController.show();
  }

  @override
  void onDragUpdate(
    final DragGestureContext ctx,
    final DragUpdateDetails details,
  ) {
    if (ctx.fsm.value case GestureReordering(:final targetSlotIndex?)) {
      final position = ctx.notification.queue.position;
      final queueKey =
          ctx.notification.effectiveCoordinator.getWidgetKey(position);
      queueKey.currentState?.updateDragTarget(targetSlotIndex);
    }
  }

  @override
  void onDragEnd(
    final DragGestureContext ctx,
    final DraggableDetails details,
  ) {
    final position = ctx.notification.queue.position;
    final queueKey =
        ctx.notification.effectiveCoordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;
    queueState?.endDragReorder();

    final pointer = ctx.fsm.pointerPosition ?? details.offset;
    final zones = ctx.activeReorderZones ?? [];
    final passedThreshold = ctx.passedThreshold(
      pointer,
      behavior.thresholdInPixels,
      zones,
    );
    if (passedThreshold) {
      final nearestZoneIdx = ctx.nearestZoneIndexWithHysteresis(pointer, zones);
      if (nearestZoneIdx != null) {
        HapticFeedback.mediumImpact();
        ctx.notification.effectiveCoordinator.reorderWidget(
          ctx.notification,
          zones[nearestZoneIdx].targetIndex,
        );
      }
    }
    ctx
      ..activeReorderZones = null
      ..activeZoneIndex = null;
    ctx.notification.key.currentState?.initDismissTimer();
    ctx.overlayPortalController.hide();
  }

  @override
  Widget buildFeedback(final DragGestureContext ctx) {
    final pointer = ctx.fsm.pointerPosition;
    final position = ctx.notification.queue.position;
    final queueKey =
        ctx.notification.effectiveCoordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;
    final currentIndex = queueState?.indexOf(ctx.notification) ?? 0;

    final zones = ctx.activeReorderZones ?? [];
    final passedThreshold = ctx.passedThreshold(
      pointer,
      behavior.thresholdInPixels,
      zones,
    );
    final (nearestProgress, int? targetSlot) = switch (ctx.fsm.value) {
      GestureReordering(:final progress, :final targetSlotIndex) => (
          progress,
          targetSlotIndex,
        ),
      _ => (0.0, null),
    };
    final nearestIndex = _resolveSlotIndex(zones, targetSlot);

    return OverlayPortal(
      controller: ctx.overlayPortalController,
      overlayChildBuilder: (final context) => LayoutBuilder(
        builder: (final context, final constraints) => ReorderTargets(
          draggedIndex: currentIndex,
          zones: zones,
          itemKeys: queueState?.itemGlobalKeys ?? [],
          passedThreshold: passedThreshold,
          nearestIndex: nearestIndex,
          gestureState: ctx.gestureState,
          ghostChild: ctx.buildDummyGhost(
            ctx.dragStartData?.widgetSize ?? Size.zero,
          ),
        ),
      ),
      child: LiftedFeedback(
        passedThreshold: passedThreshold,
        nearestProgress: nearestProgress,
        widgetSize: ctx.dragStartData?.widgetSize ?? Size.zero,
        springPhysics: behavior.springPhysics,
        fsm: ctx.fsm,
        child: ctx.notification,
      ),
    );
  }
}
