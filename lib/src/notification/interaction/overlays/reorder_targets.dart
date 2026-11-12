part of 'overlays.dart';

// ---------------------------------------------------------------------------
// _ReorderOverlay
// ---------------------------------------------------------------------------

/// Full-screen overlay rendered during a reorder drag.
///
/// Owns the three-stage slot indicator logic and the anchor computation
/// lifecycle. Rebuilds whenever [gestureState] changes.
class ReorderTargets extends StatefulWidget {
  const ReorderTargets({
    required this.draggedIndex,
    required this.zones,
    required this.itemKeys,
    required this.passedThreshold,
    required this.nearestIndex,
    required this.gestureState,
    required this.ghostChild,
    super.key,
  });

  /// The original queue index of the item currently being dragged.
  final int draggedIndex;

  /// The slot zones produced by [zonesFromSlots]. Anchors are written into
  /// these zones after layout.
  final List<SlotDropZone> zones;

  /// One [GlobalKey] per active notification widget, in stack order.
  final List<GlobalKey> itemKeys;

  /// Whether the drag interaction has passed the proximity threshold.
  final bool passedThreshold;

  /// The unified nearest drop zone index.
  final int? nearestIndex;

  /// Tracks the active gesture state and pointer coordinates during drag
  /// events.
  final ValueListenable<GestureState> gestureState;

  /// Ghost notification widget shown inside the committed indicator.
  final Widget ghostChild;

  @override
  State<ReorderTargets> createState() => _ReorderTargetsState();
}

class _ReorderTargetsState extends State<ReorderTargets> {
  /// Returns the screen-space bounding box of a rendered notification widget.
  Rect? _boundsOf(final GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) {
      return null;
    }
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(final BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      bool boundsChanged = false;
      for (var i = 0; i < widget.zones.length; i++) {
        // Cache the static, unshifted boundaries exactly once.
        if (widget.zones[i].targetBounds != null) {
          continue;
        }

        Rect? bounds;
        if (i < widget.itemKeys.length) {
          bounds = _boundsOf(widget.itemKeys[i]);
        }

        if (bounds != null) {
          widget.zones[i].setTargetBounds(bounds);
          boundsChanged = true;
        }
      }
      if (boundsChanged && mounted) {
        setState(() {}); // Immediately schedule second frame to draw reticles!
      }
    });

    return ValueListenableBuilder<GestureState>(
      valueListenable: widget.gestureState,
      builder: (final context, final state, final child) {
        final pointer = state.pointerPosition;

        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.zones.length; i++)
              _SlotReticle(
                isSelfSlot: widget.zones[i].targetIndex == widget.draggedIndex,
                zone: widget.zones[i],
                pointer: pointer,
                isNearest: widget.nearestIndex == i,
                passedThreshold: widget.passedThreshold,
                ghostChild: widget.ghostChild,
              ),
          ],
        );
      },
    );
  }
}

// --------------------------------───----------------------------------------
// _SlotReticle — three-stage slot visual (formerly _SlotIndicator)
// --------------------------------───----------------------------------------

/// Visual indicator for a single reorder slot.
///
/// Animates through three stages based on pointer proximity and commit state:
///
/// | **Idle**      | Not nearest / `progress == 0` | Hairline + faded  |
/// | **Engaged**   | Nearest, `progress > 0.15`   | Blue pill + label |
/// | **Committed** | `passedThreshold`             | Green + glow      |
///
/// Drop resolution is handled by `DraggableTransitionsState` in `onDragEnd` —
/// this widget is purely visual with no callbacks.
class _SlotReticle extends StatelessWidget {
  const _SlotReticle({
    required this.isSelfSlot,
    required this.zone,
    required this.pointer,
    required this.isNearest,
    required this.passedThreshold,
    required this.ghostChild,
  });

  final bool isSelfSlot;
  final SlotDropZone zone;
  final Offset? pointer;
  final bool isNearest;
  final bool passedThreshold;

  /// Ghost notification widget shown inside the committed slot indicator,
  /// creating the magnetic-lock illusion of the card snapping into place.
  final Widget ghostChild;

  @override
  Widget build(final BuildContext context) =>
      // Reticles are now rendered live inside the sliding QueueWidget itself!
      const SizedBox.shrink();
}
