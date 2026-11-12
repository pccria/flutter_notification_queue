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
