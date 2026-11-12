part of 'plugins.dart';

/// Gesture plugin implementing hybrid reorder-relocate behavior.
class ReorderRelocateGesturePlugin extends NotificationGesturePlugin {
  const ReorderRelocateGesturePlugin({required this.behavior});

  final ReorderAndRelocate behavior;

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
    final position = ctx.notification.queue.position;
    final queueKey =
        ctx.notification.effectiveCoordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;

    if (queueState != null) {
      // Escape condition is evaluated exclusively inside the FSM
      switch (ctx.fsm.value) {
        case GestureRelocating():
          queueState.clearDragTarget();
        case GestureReordering(:final targetSlotIndex?):
          queueState.updateDragTarget(targetSlotIndex);
        default:
          break;
      }
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

    bool relocated = false;
    final pointer = ctx.fsm.pointerPosition ?? details.offset;
    final reorderZones = ctx.activeReorderZones ?? [];
    final passedThreshold = ctx.passedThreshold(
      pointer,
      behavior.thresholdInPixels,
      reorderZones,
    );

    if (passedThreshold) {
      final nearestZoneIdx =
          ctx.nearestZoneIndexWithHysteresis(pointer, reorderZones);
      if (nearestZoneIdx != null) {
        HapticFeedback.mediumImpact();
        ctx.notification.effectiveCoordinator.reorderWidget(
          ctx.notification,
          reorderZones[nearestZoneIdx].targetIndex,
        );
      }
    } else {
      final relocateZones = ctx
          .getZones(
            behavior,
            position,
          )
          .cast<PositionDropZone>();

      final hitPosition = relocateZones
          .where(
            (final z) => z.isHit(
              pointer,
              ctx.screenSize,
              behavior.thresholdInPixels.toDouble(),
            ),
          )
          .firstOrNull;

      if (hitPosition != null) {
        HapticFeedback.mediumImpact();
        ctx.notification.effectiveCoordinator
            .relocateWidget(ctx.notification, hitPosition.position);
        relocated = true;
      }
    }
    ctx
      ..activeReorderZones = null
      ..activeZoneIndex = null;
    if (!relocated) {
      ctx.notification.key.currentState?.initDismissTimer();
    }
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

    final state = ctx.fsm.value;
    final isRelocating = state is GestureRelocating;

    final zones = ctx.activeReorderZones ?? [];
    final passedThreshold = ctx.passedThreshold(
      pointer,
      behavior.thresholdInPixels,
      zones,
    );
    final (nearestProgress, int? targetSlot) = switch (state) {
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
        builder: (final context, final constraints) => isRelocating
            ? RelocationTargets(
                targets: behavior.positions,
                currentPosition: position,
                screenSize: constraints.biggest,
                gestureState: ctx.gestureState,
                threshold: behavior.thresholdInPixels.toDouble(),
              )
            : ReorderTargets(
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
        child: isRelocating
            ? AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                opacity: state.hoveredQueuePosition != null ? 0.3 : 1.0,
                child: ctx.notification,
              )
            : ctx.notification,
      ),
    );
  }
}
