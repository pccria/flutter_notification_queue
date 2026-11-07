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
    final position = ctx.notification.queue.position;
    final queueKey =
        ctx.notification.effectiveCoordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;

    if (queueState != null) {
      final box = queueState.listRenderBox;
      bool isEscaped = false;
      if (box != null) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final inflatedRect = rect.inflate(behavior.escapeThresholdInPixels);
        isEscaped = !inflatedRect.contains(pointer);
      }

      if (isEscaped) {
        queueState.clearDragTarget();
      } else {
        final zones = ctx.activeReorderZones ?? [];
        final nearestIndex = ctx.nearestZoneIndexWithHysteresis(pointer, zones);
        if (nearestIndex != null) {
          final targetIdx = zones[nearestIndex].targetIndex;
          queueState.updateDragTarget(targetIdx);
        }
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
    final pointer = ctx.dragOffsetPairNotifier.value?.global;
    if (pointer != null) {
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
    }
    ctx.activeReorderZones = null;
    ctx.dragOffsetPairNotifier.value = null;
    ctx.activeZoneIndex = null;
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
    final queueKey =
        ctx.notification.effectiveCoordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;
    final currentIndex = queueState?.indexOf(ctx.notification) ?? 0;

    bool isEscaped = false;
    if (pointer != null && queueState != null) {
      final box = queueState.listRenderBox;
      if (box != null) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final inflatedRect = rect.inflate(behavior.escapeThresholdInPixels);
        isEscaped = !inflatedRect.contains(pointer);
      }
    }

    if (isEscaped) {
      final relocateZones = ctx.getZones(
        behavior,
        position,
      );
      final passedThreshold = ctx.passedThreshold(
        pointer,
        behavior.thresholdInPixels,
        relocateZones,
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
    } else {
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
}
