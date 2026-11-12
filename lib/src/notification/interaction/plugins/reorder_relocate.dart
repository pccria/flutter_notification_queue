part of 'plugins.dart';

/// Gesture plugin implementing hybrid reorder-relocate behavior with
/// fine-grained cross-queue slot targeting.
class ReorderRelocateGesturePlugin extends NotificationGesturePlugin {
  const ReorderRelocateGesturePlugin({required this.behavior});

  final ReorderAndRelocate behavior;

  @override
  void onDragStart(final DragGestureContext ctx) {
    final position = ctx.notification.queue.position;
    final coordinator = ctx.notification.effectiveCoordinator;
    final queueKey = coordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;
    final itemCount = queueState?.itemCount ?? 1;
    final currentIndex = queueState?.indexOf(ctx.notification) ?? 0;

    coordinator
      ..bringToFront(position)
      ..setInteractionFocus(source: position, target: position);
    ctx.notification.key.currentState?.pauseDismissTimer();
    queueState?.startDragReorder(ctx.notification.id, currentIndex);
    ctx
      ..activeZoneIndex = null
      ..activeReorderZones = zonesFromSlots(itemCount, currentIndex)
      ..overlayPortalController.show();

    // Capture geometry snapshots across home and candidate queues at lift-off
    final snapshots = <QueuePosition, QueueGeometrySnapshot>{};
    if (queueState != null) {
      snapshots[position] = queueState.getGeometrySnapshot();
    }
    for (final targetPos in behavior.positions) {
      if (targetPos == position) {
        continue;
      }
      final targetState = coordinator.getWidgetKey(targetPos).currentState;
      if (targetState != null) {
        snapshots[targetPos] = targetState.getGeometrySnapshot();
      }
    }
    ctx
      ..dropSnapshots = snapshots
      ..candidateDockRects = _computeCandidateDockRects(
        ctx,
        behavior.positions,
      );
  }

  @override
  void onDragUpdate(
    final DragGestureContext ctx,
    final DragUpdateDetails details,
  ) {
    final position = ctx.notification.queue.position;
    final coordinator = ctx.notification.effectiveCoordinator;
    final homeState = coordinator.getWidgetKey(position).currentState;
    final pointer = details.globalPosition;

    final previousTarget = switch (ctx.fsm.value) {
      GestureRearranging(:final target) => target,
      _ => const NoTarget(),
    };

    // Lazily refresh remote snapshots if a queue mutated mid-drag
    var snapshotsChanged = false;
    final snapshots = ctx.dropSnapshots ??= {};
    for (final targetPos in behavior.positions) {
      if (targetPos == position) {
        continue;
      }
      final remoteState = coordinator.getWidgetKey(targetPos).currentState;
      if (remoteState == null) {
        if (snapshots.remove(targetPos) != null) {
          snapshotsChanged = true;
        }
      } else {
        final existing = snapshots[targetPos];
        if (existing == null ||
            existing.layoutVersion != remoteState.layoutVersion) {
          snapshots[targetPos] = remoteState.getGeometrySnapshot();
          snapshotsChanged = true;
        }
      }
    }
    if (snapshotsChanged || ctx.candidateDockRects == null) {
      ctx.candidateDockRects = _computeCandidateDockRects(
        ctx,
        behavior.positions,
      );
    }

    final cardHeight = ctx.fsm.cardRect.height > 0
        ? ctx.fsm.cardRect.height
        : (ctx.dragStartData?.widgetSize.height ?? 80.0);

    final target = resolveTarget(
      pointer: pointer,
      homePosition: position,
      snapshots: snapshots,
      previousTarget: previousTarget,
      candidatePositions: behavior.positions,
      candidateDockRects: ctx.candidateDockRects ?? const {},
      screenSize: ctx.screenSize,
      escapeThreshold: behavior.escapeThresholdInPixels,
      incomingHeight: cardHeight,
    );

    if (_didDiscreteTargetChange(previousTarget, target)) {
      HapticFeedback.selectionClick();
    }

    // Update dynamic Z-axis focus across active queues
    final focusTarget = switch (target) {
      SlotTarget(:final position) => position,
      QueueTarget(:final position) => position,
      NoTarget() => null,
    };
    coordinator.setInteractionFocus(source: position, target: focusTarget);

    // Drive FSM with resolved target
    ctx.fsm.update(
      delta: details.delta,
      globalPosition: pointer,
      target: target,
    );

    // Sync queue gap previews
    if (target is SlotTarget) {
      if (target.position == position) {
        // Home reorder gap
        homeState?.updateDragTarget(target.gapIndex);
        for (final remotePos in behavior.positions) {
          if (remotePos != position) {
            coordinator
                .getWidgetKey(remotePos)
                .currentState
                ?.clearExternalDrop();
          }
        }
      } else {
        // Remote queue slot preview
        homeState?.clearDragTarget();
        final remoteState =
            coordinator.getWidgetKey(target.position).currentState;
        remoteState?.previewExternalDrop(
          targetIndex: target.gapIndex,
          incomingHeight: cardHeight,
          progress: target.progress,
          pointer: pointer,
          incomingGroupKey: ctx.notification.resolvedGroupKey,
        );
        for (final otherPos in behavior.positions) {
          if (otherPos != position && otherPos != target.position) {
            coordinator
                .getWidgetKey(otherPos)
                .currentState
                ?.clearExternalDrop();
          }
        }
      }
    } else {
      // Clear all gap previews
      homeState?.clearDragTarget();
      for (final remotePos in behavior.positions) {
        if (remotePos != position) {
          coordinator.getWidgetKey(remotePos).currentState?.clearExternalDrop();
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
    final coordinator = ctx.notification.effectiveCoordinator;
    final homeState = coordinator.getWidgetKey(position).currentState;
    homeState?.endDragReorder();
    coordinator.clearInteractionFocus();

    for (final remotePos in behavior.positions) {
      if (remotePos != position) {
        coordinator.getWidgetKey(remotePos).currentState?.clearExternalDrop();
      }
    }

    final pointer = ctx.fsm.pointerPosition ?? details.offset;
    final state = ctx.fsm.value;
    bool moved = false;

    DropTarget? target = state is GestureRearranging ? state.target : null;
    if (target == null && ctx.dropSnapshots != null) {
      final cardHeight = ctx.fsm.cardRect.height > 0
          ? ctx.fsm.cardRect.height
          : (ctx.dragStartData?.widgetSize.height ?? 80.0);
      target = resolveTarget(
        pointer: pointer,
        homePosition: position,
        snapshots: ctx.dropSnapshots!,
        previousTarget: const NoTarget(),
        candidatePositions: behavior.positions,
        candidateDockRects: ctx.candidateDockRects ?? const {},
        screenSize: ctx.screenSize,
        escapeThreshold: behavior.escapeThresholdInPixels,
        incomingHeight: cardHeight,
      );
    }

    if (target != null) {
      if (target is SlotTarget) {
        HapticFeedback.mediumImpact();
        coordinator.moveWidget(
          ctx.notification,
          toPosition: target.position,
          targetIndex: target.gapIndex,
          permanent: behavior.permanent,
        );
        moved = true;
      } else if (target is QueueTarget) {
        HapticFeedback.mediumImpact();
        coordinator.moveWidget(
          ctx.notification,
          toPosition: target.position,
          permanent: behavior.permanent,
        );
        moved = true;
      }
    }

    // Fallback: If not committed through GestureRearranging, check reorder
    // and relocate zones
    if (!moved) {
      final reorderZones = ctx.activeReorderZones ?? [];
      final passedReorder = ctx.passedThreshold(
        pointer,
        behavior.thresholdInPixels,
        reorderZones,
      );
      if (passedReorder) {
        final nearestZoneIdx =
            ctx.nearestZoneIndexWithHysteresis(pointer, reorderZones);
        if (nearestZoneIdx != null) {
          HapticFeedback.mediumImpact();
          coordinator.reorderWidget(
            ctx.notification,
            reorderZones[nearestZoneIdx].targetIndex,
          );
          moved = true;
        }
      } else {
        final relocateZones =
            ctx.getZones(behavior, position).cast<PositionDropZone>();
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
          coordinator.relocateWidget(
            ctx.notification,
            hitPosition.position,
          );
          moved = true;
        }
      }
    }

    ctx
      ..dropSnapshots = null
      ..candidateDockRects = null
      ..activeReorderZones = null
      ..activeZoneIndex = null;
    ctx.notification.key.currentState?.unfocus();
    if (!moved) {
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
    final isRelocating = switch (state) {
      GestureRearranging(:final target) => target is QueueTarget ||
          (target is SlotTarget && target.position != position),
      GestureRelocating() => true,
      _ => false,
    };

    final zones = ctx.activeReorderZones ?? [];
    final passedThreshold = ctx.passedThreshold(
      pointer,
      behavior.thresholdInPixels,
      zones,
    );
    final (nearestProgress, int? targetSlot) = switch (state) {
      GestureRearranging(:final target) => switch (target) {
          SlotTarget(:final progress, :final gapIndex) => (progress, gapIndex),
          QueueTarget(:final progress) => (progress, null),
          NoTarget() => (0.0, null),
        },
      GestureReordering(:final progress, :final targetSlotIndex) => (
          progress,
          targetSlotIndex,
        ),
      GestureRelocating(:final progress) => (progress, null),
      _ => (0.0, null),
    };
    final nearestIndex = _resolveSlotIndex(zones, targetSlot);
    final showRelocationDocks = isRelocating ||
        (state is GestureRearranging && state.target is NoTarget);
    final suppressedPositions = <QueuePosition>{
      if (ctx.dropSnapshots != null)
        for (final entry in ctx.dropSnapshots!.entries)
          if (entry.key != position && entry.value.cardRects.isNotEmpty)
            entry.key,
    };

    final isRelocatingLocked = switch (state) {
      GestureRearranging(:final target) => target is QueueTarget ||
          (target is SlotTarget &&
              target.position != position &&
              target.progress >= 0.45),
      _ => false,
    };

    return OverlayPortal(
      controller: ctx.overlayPortalController,
      overlayChildBuilder: (final context) => LayoutBuilder(
        builder: (final context, final constraints) => showRelocationDocks
            ? RelocationTargets(
                targets: behavior.positions,
                currentPosition: position,
                screenSize: constraints.biggest,
                gestureState: ctx.gestureState,
                threshold: behavior.thresholdInPixels.toDouble(),
                dockRects: ctx.candidateDockRects ?? const {},
                suppressedPositions: suppressedPositions,
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
        isRelocatingTarget: isRelocatingLocked,
        widgetSize: ctx.dragStartData?.widgetSize ?? Size.zero,
        springPhysics: behavior.springPhysics,
        fsm: ctx.fsm,
        child: isRelocating && !isRelocatingLocked
            ? AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                opacity: 0.85,
                child: ctx.notification,
              )
            : ctx.notification,
      ),
    );
  }

  int? _resolveSlotIndex(
    final List<SlotDropZone> zones,
    final int? targetSlot,
  ) {
    if (targetSlot == null) {
      return null;
    }
    for (int i = 0; i < zones.length; i++) {
      if (zones[i].targetIndex == targetSlot) {
        return i;
      }
    }
    return null;
  }
}
