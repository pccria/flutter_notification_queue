part of 'plugins.dart';

/// Gesture plugin implementing queue relocation behavior.
///
/// Operates on a whole-queue container model: dragging a card allows moving it
/// to another queue position as a whole bucket, preserving the destination
/// queue's internal sorting, grouping, and priority triage policies.
class RelocateGesturePlugin extends NotificationGesturePlugin {
  const RelocateGesturePlugin({required this.behavior});

  final Relocate behavior;

  @override
  void onDragStart(final DragGestureContext ctx) {
    final position = ctx.notification.queue.position;
    ctx.notification.effectiveCoordinator
      ..bringToFront(position)
      ..setInteractionFocus(source: position);
    ctx.notification.key.currentState?.pauseDismissTimer();
    ctx.overlayPortalController.show();

    // Capture geometry snapshots across candidate remote queues at lift-off
    final snapshots = <QueuePosition, QueueGeometrySnapshot>{};
    final coordinator = ctx.notification.effectiveCoordinator;
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
      escapeThreshold: behavior.thresholdInPixels.toDouble(),
      incomingHeight: cardHeight,
      allowHomeReorder: false,
      allowSlotTargeting: false,
    );

    if (_didDiscreteTargetChange(previousTarget, target)) {
      HapticFeedback.selectionClick();
    }

    // Update dynamic Z-axis focus across active queues
    final focusTarget = switch (target) {
      QueueTarget(:final position) => position,
      SlotTarget(:final position) => position,
      NoTarget() => null,
    };
    coordinator.setInteractionFocus(source: position, target: focusTarget);

    // Sync remote queue container hover feedback
    if (target is QueueTarget && target.position != position) {
      final remoteState =
          coordinator.getWidgetKey(target.position).currentState;
      remoteState?.previewExternalHover(
        progress: target.progress,
        pointer: pointer,
        incomingGroupKey: ctx.notification.resolvedGroupKey,
      );
      for (final otherPos in behavior.positions) {
        if (otherPos != position && otherPos != target.position) {
          coordinator.getWidgetKey(otherPos).currentState?.clearExternalDrop();
        }
      }
    } else {
      for (final remotePos in behavior.positions) {
        if (remotePos != position) {
          coordinator.getWidgetKey(remotePos).currentState?.clearExternalDrop();
        }
      }
    }

    // Drive FSM with resolved target
    ctx.fsm.update(
      delta: details.delta,
      globalPosition: pointer,
      target: target,
    );
  }

  @override
  void onDragEnd(
    final DragGestureContext ctx,
    final DraggableDetails details,
  ) {
    final position = ctx.notification.queue.position;
    final coordinator = ctx.notification.effectiveCoordinator
      ..clearInteractionFocus();

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
        escapeThreshold: behavior.thresholdInPixels.toDouble(),
        incomingHeight: cardHeight,
        allowHomeReorder: false,
        allowSlotTargeting: false,
      );
    }

    if (target is QueueTarget && target.position != position) {
      HapticFeedback.mediumImpact();
      coordinator.relocateWidget(
        ctx.notification,
        target.position,
        permanent: behavior.permanent,
      );
      moved = true;
    }

    // Fallback: If not committed through GestureRearranging, check candidate
    // position drop zones
    if (!moved) {
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
      if (hitPosition != null && hitPosition.position != position) {
        HapticFeedback.mediumImpact();
        coordinator.relocateWidget(
          ctx.notification,
          hitPosition.position,
          permanent: behavior.permanent,
        );
        moved = true;
      }
    }

    ctx
      ..dropSnapshots = null
      ..candidateDockRects = null;
    ctx.notification.key.currentState?.unfocus();
    if (!moved) {
      ctx.notification.key.currentState?.initDismissTimer();
    }
    ctx.overlayPortalController.hide();
  }

  @override
  Widget buildFeedback(final DragGestureContext ctx) {
    final position = ctx.notification.queue.position;
    final state = ctx.fsm.value;

    final isRelocatingLocked = switch (state) {
      GestureRearranging(:final target) => target is QueueTarget &&
          target.position != position &&
          target.progress >= 0.72,
      _ => false,
    };

    final nearestProgress = switch (state) {
      GestureRearranging(:final target) => switch (target) {
          QueueTarget(:final progress) => progress,
          SlotTarget(:final progress) => progress,
          NoTarget() => 0.0,
        },
      GestureRelocating(:final progress) => progress,
      _ => 0.0,
    };

    const passedThreshold = false;

    final suppressedPositions = <QueuePosition>{
      if (ctx.dropSnapshots != null)
        for (final entry in ctx.dropSnapshots!.entries)
          if (entry.key != position && entry.value.cardRects.isNotEmpty)
            entry.key,
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
          dockRects: ctx.candidateDockRects ?? const {},
          suppressedPositions: suppressedPositions,
        ),
      ),
      child: LiftedFeedback(
        passedThreshold: passedThreshold,
        nearestProgress: nearestProgress,
        isRelocatingTarget: isRelocatingLocked,
        widgetSize: ctx.dragStartData?.widgetSize ?? Size.zero,
        springPhysics: behavior.springPhysics,
        fsm: ctx.fsm,
        child: ctx.notification,
      ),
    );
  }
}
