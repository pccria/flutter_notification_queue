library;

import 'package:flutter/widgets.dart';

import '../../enums/enums.dart';
import '../../models/offset_pair.dart';
import '../notification.dart' show NotificationWidget;
import 'drag_start_data.dart';
import 'zones/zones.dart';

export 'drag_start_data.dart';

/// The facade interface through which gesture plugins interact with host
/// widget state.
///
/// Plugins depend on [DragGestureContext] instead of
/// `DraggableTransitionsState` directly.
abstract interface class DragGestureContext {
  /// The [NotificationWidget] being dragged.
  NotificationWidget get notification;

  /// Total screen size available in the current context.
  Size get screenSize;

  /// Geometry details captured at pointer down / drag start.
  DragStartData? get dragStartData;

  /// Active list of reorder zones created during a reorder transaction.
  List<SlotDropZone>? get activeReorderZones;
  set activeReorderZones(final List<SlotDropZone>? value);

  /// Index of the currently highlighted zone with hysteresis.
  int? get activeZoneIndex;
  set activeZoneIndex(final int? value);

  /// Controller for managing active overlay portal visibility.
  OverlayPortalController get overlayPortalController;

  /// Notifier delivering offset updates during drag.
  ValueNotifier<OffsetPair?> get dragOffsetPairNotifier;

  /// Derives drop zones for the given behavior and queue position.
  List<DropZone> getZones(
    final QueueNotificationBehavior behavior,
    final QueuePosition position,
  );

  /// Checks if global pointer has passed threshold for any zone.
  bool passedThreshold(
    final Offset? globalOffset,
    final int thresholdInPixels,
    final List<DropZone> zones,
  );

  /// Computes nearest zone index incorporating hysteresis.
  int? nearestZoneIndexWithHysteresis(
    final Offset? pointer,
    final List<SlotDropZone> zones,
  );

  /// Computes nearest zone progress.
  double nearestZoneProgress(
    final Offset? pointer,
    final List<DropZone> zones,
  );

  /// Builds placeholder dummy ghost widget.
  Widget buildDummyGhost(final Size size);
}
