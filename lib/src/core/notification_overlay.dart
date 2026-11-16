part of 'core.dart';

/// The rendering surface for the notification system.
///
/// Mounts notifications into the widget tree using a dual rendering strategy:
///
/// 1. **OverlayPortal** — when an [Overlay] ancestor exists (e.g. used as a
///    child inside [MaterialApp]), notifications are rendered via
///    [OverlayPortal] for proper layering above all app content.
///
/// 2. **Stack fallback** — when no [Overlay] ancestor exists (e.g. used in
///    [MaterialApp.builder] where the Navigator's Overlay is a descendant),
///    a [Stack] with a local [Overlay] is used instead.
///
/// ## Integration
///
/// Users attach notifications via [NotificationScope]:
/// ```dart
/// MaterialApp(
///   builder: (context, child) => NotificationScope(
///     controller: controller,
///     child: child!,
///   ),
/// );
/// ```
class NotificationOverlay extends StatefulWidget {
  const NotificationOverlay({
    required this.child,
    this.coordinator,
    this.useRootOverlay = true,
    super.key,
  });

  /// The app's root widget (e.g., [MaterialApp]).
  final Widget child;

  /// Optional explicit queue coordinator instance.
  /// If null, falls back to context's [NotificationScope].
  final QueueCoordinator? coordinator;

  /// Whether the overlay portal should mount into the root [Overlay] or the
  /// nearest ancestor [Overlay].
  ///
  /// Defaults to `true` (standard full-window layering). Set to `false` when
  /// embedding within an isolated virtual viewport, multi-tenant frame, or
  /// container with its own local [Overlay].
  final bool useRootOverlay;

  /// Static router method for use in [MaterialApp.builder].
  ///
  /// Usage:
  /// ```dart
  /// MaterialApp(
  ///   builder: NotificationOverlay.router,
  /// );
  /// ```
  static Widget router(final BuildContext context, final Widget? child) =>
      NotificationOverlay(
        child: child ?? const SizedBox.shrink(),
      );

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with CoordinatorResolver<NotificationOverlay> {
  final OverlayPortalController _overlayPortalController =
      OverlayPortalController();
  QueueCoordinator? _attachedCoordinator;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCoordinator();
  }

  @override
  void didUpdateWidget(final NotificationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateCoordinator();
  }

  void _updateCoordinator() {
    final resolved = resolveCoordinator(
      explicitCoordinator: widget.coordinator,
      callerName: 'NotificationOverlay',
    );
    if (_attachedCoordinator != resolved) {
      _attachedCoordinator?.detach();
      _attachedCoordinator = resolved;
      _attachedCoordinator!.attach(_overlayPortalController);
    }
  }

  @override
  void dispose() {
    if (_overlayPortalController.isShowing) {
      _overlayPortalController.hide();
    }
    _attachedCoordinator?.detach();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final coordinator = _attachedCoordinator!;

    // Dual Strategy:
    // 1. If Overlay exists (e.g. used inside MaterialApp), use OverlayPortal.
    // 2. If Overlay is missing (e.g. used in MaterialApp.builder), use Stack.
    final hasOverlay = Overlay.maybeOf(context) != null;

    if (hasOverlay) {
      return OverlayPortal(
        controller: _overlayPortalController,
        overlayChildBuilder: (final context) => _NotificationQueueStack(
          coordinator: coordinator,
        ),
        overlayLocation: widget.useRootOverlay
            ? OverlayChildLocation.rootOverlay
            : OverlayChildLocation.nearestOverlay,
        child: widget.child,
      );
    } else {
      // When used in MaterialApp.builder, the Navigator's Overlay is a
      // descendant (inside widget.child), not an ancestor. Notification
      // widgets contain LongPressDraggable which requires an Overlay
      // ancestor. We provide a minimal one here.
      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          Positioned.fill(
            child: Overlay(
              key: ObjectKey(coordinator),
              initialEntries: [
                OverlayEntry(
                  builder: (final context) => _NotificationQueueStack(
                    coordinator: coordinator,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}

/// Renders the stack of active [NotificationQueue] widgets.
///
/// Listens to [QueueCoordinator.activeQueues] and rebuilds whenever the
/// set of active queues changes. Each active queue provides its own
/// [QueueWidget] which handles positioning, spacing, and notification
/// rendering.
class _NotificationQueueStack extends StatefulWidget {
  const _NotificationQueueStack({
    required this.coordinator,
  });

  final QueueCoordinator coordinator;

  @override
  State<_NotificationQueueStack> createState() =>
      _NotificationQueueStackState();
}

class _NotificationQueueStackState extends State<_NotificationQueueStack> {
  @override
  Widget build(final BuildContext context) =>
      ValueListenableBuilder<Map<QueuePosition, NotificationQueue>>(
        valueListenable: widget.coordinator.activeQueues,
        builder: (final context, final activeQueues, final child) {
          final hasActive = activeQueues.isNotEmpty;

          // NOTE: Do NOT call MediaQuery.paddingOf(context) here — it
          // subscribes _NotificationQueueStack to every size/insets change
          // (including window resize), which rebuilds every queue and card
          // on every resize frame. Padding is read inside performLayout
          // from the ViewPadding passed by the render system, which never
          // triggers a widget rebuild.
          final layout = CustomMultiChildLayout(
            delegate: _QueueOverlayLayoutDelegate(
              activePositions: activeQueues.keys.toList(),
              activeQueues: activeQueues,
              flutterView: View.maybeOf(context),
            ),
            children: activeQueues.values
                .map(
                  (final queue) => LayoutId(
                    key: ValueKey(queue.position),
                    id: queue.position,
                    child: QueueWidget(
                      key: widget.coordinator.getWidgetKey(queue.position),
                      queue: queue,
                      coordinator: widget.coordinator,
                      isEmbeddedInLayout: true,
                    ),
                  ),
                )
                .toList(),
          );

          if (!hasActive) {
            return layout;
          }

          return FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: layout,
          );
        },
      );
}

class _QueueOverlayLayoutDelegate extends MultiChildLayoutDelegate {
  _QueueOverlayLayoutDelegate({
    required this.activePositions,
    required this.activeQueues,
    this.flutterView,
  });

  final List<QueuePosition> activePositions;
  final Map<QueuePosition, NotificationQueue> activeQueues;
  final FlutterView? flutterView;

  EdgeInsets _viewPadding() => Utils.viewPaddingOf(flutterView);

  @override
  void performLayout(final Size size) {
    final padding = _viewPadding();

    final Map<QueuePosition, Size> childSizes = {};
    for (final position in activePositions) {
      if (hasChild(position)) {
        final queue = activeQueues[position];
        final horizontalConstraints = Utils.horizontalConstraintsForWidth(
          size.width,
          queue?.maxWidth,
        );
        final constraints = BoxConstraints(
          minWidth: 0.0,
          maxWidth: horizontalConstraints.maxWidth,
          minHeight: 0.0,
          maxHeight: size.height,
        );
        childSizes[position] = layoutChild(position, constraints);
      }
    }

    final Map<QueuePosition, Rect> nominalRects = {};
    for (final position in activePositions) {
      final childSize = childSizes[position];
      if (childSize == null) {
        continue;
      }

      final queue = activeQueues[position];
      nominalRects[position] = Utils.nominalAlignedRect(
        alignment: position.alignment,
        screenSize: size,
        childSize: childSize,
        viewPadding: padding,
        margin: queue?.margin ?? EdgeInsets.zero,
      );
    }

    final List<QueuePosition> sortedPositions = List.from(activePositions)
      ..sort((final a, final b) => a.index.compareTo(b.index));

    final Map<QueuePosition, Offset> finalOffsets = {};
    final List<Rect> placedRects = [];

    for (final position in sortedPositions) {
      final nominal = nominalRects[position];
      if (nominal == null) {
        continue;
      }

      final double currentX = nominal.left;
      double currentY = nominal.top;

      final isTopAnchored = position == QueuePosition.topLeft ||
          position == QueuePosition.topCenter ||
          position == QueuePosition.topRight;

      final isBottomAnchored = position == QueuePosition.bottomLeft ||
          position == QueuePosition.bottomCenter ||
          position == QueuePosition.bottomRight;

      final queue = activeQueues[position];
      final spacing = queue?.spacing ?? 8.0;

      var currentRect =
          Rect.fromLTWH(currentX, currentY, nominal.width, nominal.height);

      bool hasCollision = true;
      int iterations = 0;
      while (hasCollision && iterations < 10) {
        hasCollision = false;
        for (final placed in placedRects) {
          if (currentRect.overlaps(placed)) {
            hasCollision = true;
            if (isTopAnchored) {
              currentY = placed.bottom + spacing;
            } else if (isBottomAnchored) {
              currentY = placed.top - nominal.height - spacing;
            } else {
              currentY = placed.bottom + spacing;
            }
            currentRect = Rect.fromLTWH(
              currentX,
              currentY,
              nominal.width,
              nominal.height,
            );
            break;
          }
        }
        iterations++;
      }

      final minY = padding.top;
      final maxY = (size.height - padding.bottom - nominal.height)
          .clamp(minY, double.infinity);
      currentY = currentY.clamp(minY, maxY);
      currentRect = Rect.fromLTWH(
        currentX,
        currentY,
        nominal.width,
        nominal.height,
      );

      finalOffsets[position] = Offset(currentX, currentY);
      placedRects.add(currentRect);
    }

    for (final position in activePositions) {
      if (hasChild(position)) {
        final offset = finalOffsets[position] ?? Offset.zero;
        positionChild(position, offset);
      }
    }
  }

  @override
  bool shouldRelayout(
    covariant final _QueueOverlayLayoutDelegate oldDelegate,
  ) {
    if (flutterView != oldDelegate.flutterView ||
        flutterView?.viewPadding != oldDelegate.flutterView?.viewPadding ||
        flutterView?.devicePixelRatio !=
            oldDelegate.flutterView?.devicePixelRatio) {
      return true;
    }
    if (activePositions.length != oldDelegate.activePositions.length) {
      return true;
    }
    for (int i = 0; i < activePositions.length; i++) {
      if (activePositions[i] != oldDelegate.activePositions[i]) {
        return true;
      }
      final q = activeQueues[activePositions[i]];
      final oq = oldDelegate.activeQueues[activePositions[i]];
      if (q?.maxWidth != oq?.maxWidth || q?.margin != oq?.margin) {
        return true;
      }
    }
    return false;
  }
}
