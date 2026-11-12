part of 'plugins.dart';

/// Defines the operational and rendering contract for all gestural
/// interactions.
abstract class NotificationGesturePlugin {
  const NotificationGesturePlugin();

  /// Invoked when the drag gesture transaction is initiated.
  void onDragStart(final DragGestureContext ctx);

  /// Invoked upon active movement updates of the pointer.
  void onDragUpdate(
    final DragGestureContext ctx,
    final DragUpdateDetails details,
  );

  /// Invoked when the pointer is released.
  void onDragEnd(
    final DragGestureContext ctx,
    final DraggableDetails details,
  );

  /// Generates the visual feedback and reactive overlays wrapping the dragged
  /// card.
  Widget buildFeedback(final DragGestureContext ctx);
}

int? _resolveSlotIndex(
  final List<SlotDropZone> zones,
  final int? targetSlot,
) {
  if (targetSlot == null) {
    return null;
  }
  final index = zones.indexWhere((final z) => z.targetIndex == targetSlot);
  return index >= 0 ? index : null;
}

Map<QueuePosition, Rect> _computeCandidateDockRects(
  final DragGestureContext ctx,
  final Set<QueuePosition> positions,
) {
  final coordinator = ctx.notification.effectiveCoordinator;
  final homePosition = ctx.notification.queue.position;
  final screenSize = ctx.screenSize;
  final baseSize = ctx.fsm.cardRect.size.height > 0
      ? ctx.fsm.cardRect.size
      : (ctx.dragStartData?.widgetSize ?? const Size(280, 76));

  return resolveCandidateDockRects(
    homePosition: homePosition,
    candidatePositions: positions,
    screenSize: screenSize,
    cardSize: baseSize,
    viewPadding: ctx.viewPadding,
    mountedSnapshots: ctx.dropSnapshots ?? const {},
    marginForPosition: (final pos) =>
        coordinator.configuration.getQueue(pos).margin,
    maxWidthForPosition: (final pos) =>
        coordinator.configuration.getQueue(pos).maxWidth,
  );
}

bool _didDiscreteTargetChange(
  final DropTarget previous,
  final DropTarget current,
) =>
    switch ((previous, current)) {
      (NoTarget(), NoTarget()) => false,
      (
        SlotTarget(position: final p1, gapIndex: final g1),
        SlotTarget(position: final p2, gapIndex: final g2),
      ) =>
        p1 != p2 || g1 != g2,
      (
        QueueTarget(position: final p1),
        QueueTarget(position: final p2),
      ) =>
        p1 != p2,
      _ => current is! NoTarget,
    };
