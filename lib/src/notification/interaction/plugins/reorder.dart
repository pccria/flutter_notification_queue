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
      ..dragOffsetPairNotifier.value = OffsetPair(
        local: Offset.zero,
        global: ctx.dragStartData?.pointerPosition ?? Offset.zero,
      )
      ..overlayPortalController.show();
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
    final pointer = details.globalPosition;
    final zones = ctx.activeReorderZones ?? [];
    final nearestIndex = ctx.nearestZoneIndexWithHysteresis(pointer, zones);
    if (nearestIndex != null) {
      final targetIdx = zones[nearestIndex].targetIndex;
      final position = ctx.notification.queue.position;
      final queueKey =
          ctx.notification.effectiveCoordinator.getWidgetKey(position);
      queueKey.currentState?.updateDragTarget(targetIdx);
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

    final pointer = ctx.dragOffsetPairNotifier.value?.global;
    if (pointer != null) {
      final zones = ctx.activeReorderZones ?? [];
      final passedThreshold = ctx.passedThreshold(
        pointer,
        behavior.thresholdInPixels,
        zones,
      );
      if (passedThreshold) {
        final nearestZoneIdx =
            ctx.nearestZoneIndexWithHysteresis(pointer, zones);
        if (nearestZoneIdx != null) {
          HapticFeedback.mediumImpact();
          ctx.notification.effectiveCoordinator.reorderWidget(
            ctx.notification,
            zones[nearestZoneIdx].targetIndex,
          );
        }
      }
    }
    ctx.activeReorderZones = null;
    ctx.dragOffsetPairNotifier.value = null;
    ctx.activeZoneIndex = null;
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
    final nearestProgress = ctx.nearestZoneProgress(pointer, zones);
    final nearestIndex = ctx.nearestZoneIndexWithHysteresis(pointer, zones);

    return OverlayPortal(
      controller: ctx.overlayPortalController,
      overlayChildBuilder: (final context) => LayoutBuilder(
        builder: (final context, final constraints) => ReorderTargets(
          draggedIndex: currentIndex,
          zones: zones,
          itemKeys: queueState?.itemGlobalKeys ?? [],
          passedThreshold: passedThreshold,
          nearestIndex: nearestIndex,
          pointerPositionNotifier: ctx.dragOffsetPairNotifier,
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
        child: ctx.notification,
      ),
    );
  }
}
