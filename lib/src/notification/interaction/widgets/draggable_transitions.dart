part of 'widgets.dart';

class DraggableTransitions extends StatefulWidget {
  const DraggableTransitions({
    required this.notification,
    this.hapticFeedbackOnStart = true,
    super.key,
  });

  final NotificationWidget notification;
  final bool hapticFeedbackOnStart;

  @override
  State<DraggableTransitions> createState() => DraggableTransitionsState();
}

class DraggableTransitionsState extends State<DraggableTransitions>
    with
        SingleTickerProviderStateMixin,
        CoordinatorResolver<DraggableTransitions>
    implements DragGestureContext {
  Size get _screenSize => Utils.screenSize(context);

  List<SlotDropZone>? _activeReorderZones;

  @override
  NotificationWidget get notification => widget.notification;

  @override
  Size get screenSize => _screenSize;

  @override
  DragStartData? get dragStartData => _dragStartData;

  @override
  List<SlotDropZone>? get activeReorderZones => _activeReorderZones;

  @override
  set activeReorderZones(final List<SlotDropZone>? value) =>
      _activeReorderZones = value;

  @override
  int? get activeZoneIndex => _activeZoneIndex;

  @override
  set activeZoneIndex(final int? value) => _activeZoneIndex = value;

  @override
  OverlayPortalController get overlayPortalController =>
      _overlayPortalController;

  @override
  GestureStateMachine get fsm => _fsm;

  @override
  ValueListenable<GestureState> get gestureState => _fsm;

  @override
  List<DropZone> getZones(
    final QueueNotificationBehavior behavior,
    final QueuePosition position,
  ) =>
      _getZones(behavior, position);

  @override
  bool passedThreshold(
    final Offset? globalOffset,
    final int thresholdInPixels,
    final List<DropZone> zones,
  ) =>
      _passedThreshold(globalOffset, thresholdInPixels, zones);

  @override
  int? nearestZoneIndexWithHysteresis(
    final Offset? pointer,
    final List<SlotDropZone> zones,
  ) =>
      _nearestZoneIndexWithHysteresis(pointer, zones);

  @override
  double nearestZoneProgress(
    final Offset? pointer,
    final List<DropZone> zones,
  ) =>
      _nearestZoneProgress(pointer, zones);

  @override
  Widget buildDummyGhost(final Size size) => _buildDummyGhost(size);

  late final GestureStateMachine _fsm;

  late final AnimationController _snapBackController;
  Animation<Offset>? _snapBackAnimation;

  static final _logger = Logger.get('fnq.Notification.Draggables');

  @override
  void initState() {
    final message = 'Notification${widget.notification.key} '
        'DraggableTransition created State';
    _logger.debugBuffer
      ?..writeAll([
        message,
        'State: $this',
      ])
      ..sink();

    final dragBehavior = widget.notification.dragBehavior ??
        widget.notification.queue.dragBehavior;
    final position = widget.notification.queue.position;
    final escapeThreshold = dragBehavior is ReorderAndRelocate
        ? (dragBehavior as ReorderAndRelocate).escapeThresholdInPixels
        : 80.0;

    _fsm = GestureStateMachine(
      initialBehavior: dragBehavior,
      initialPosition: position,
      escapeThreshold: escapeThreshold,
    );

    _snapBackController = AnimationController.unbounded(
      vsync: this,
    );

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _logger.debugBuffer
      ?..writeAll([
        'Notification${widget.notification.key} DraggableTransition',
        'State: $this',
      ])
      ..sink();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _logger.debugBuffer
      ?..writeAll([
        'Disposed Notification${widget.notification.key} DraggableTransition.',
        '',
      ])
      ..sink();

    _fsm.dispose();
    if (_snapBackController.isAnimating) {
      _snapBackController.stop();
    }
    _snapBackController.dispose();
    super.dispose();
  }

  QueueCoordinator get coordinator => resolveCoordinator(
        explicitCoordinator: widget.notification.coordinator,
        callerName: 'DraggableTransitions',
      );

  int stateIndexOfThisItem() {
    final position = widget.notification.queue.position;
    final queueKey = coordinator.getWidgetKey(position);
    final queueState = queueKey.currentState;
    return queueState?.indexOf(widget.notification) ?? 0;
  }

  Widget _buildCardChild() => AnimatedBuilder(
        animation: _snapBackController,
        builder: (final context, final child) {
          final offset =
              _fsm.value is GestureSettling && _snapBackAnimation != null
                  ? _snapBackAnimation!.value
                  : Offset.zero;

          return Transform.translate(
            offset: offset,
            child: widget.notification,
          );
        },
      );

  void _startSnapBack(
    final Offset releaseOffset,
    final Velocity releaseVelocity,
  ) {
    final originalPosition = _dragStartData?.widgetPosition ?? Offset.zero;
    final finalRelativeOffset = releaseOffset - originalPosition;

    _fsm.settle(
      originOffset: releaseOffset,
      targetOffset: originalPosition,
      velocity: releaseVelocity,
    );

    final dragBehavior = widget.notification.dragBehavior ??
        widget.notification.queue.dragBehavior;
    final physics = dragBehavior.springPhysics;

    final double initialVelocity;
    final double lenSq = finalRelativeOffset.dx * finalRelativeOffset.dx +
        finalRelativeOffset.dy * finalRelativeOffset.dy;
    if (lenSq > 0.0) {
      final velocityOffset = releaseVelocity.pixelsPerSecond;
      // Project the 2D velocity onto the 1D snap-back vector
      initialVelocity = (velocityOffset.dx * finalRelativeOffset.dx +
              velocityOffset.dy * finalRelativeOffset.dy) /
          lenSq;
    } else {
      initialVelocity = 0.0;
    }

    final simulation = SpringSimulation(
      physics.toSpringDescription(),
      1.0,
      0.0,
      initialVelocity,
    );

    _snapBackAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: finalRelativeOffset,
    ).animate(_snapBackController);

    _snapBackController.animateWith(simulation).then((final _) {
      if (mounted) {
        _fsm.reset();
        widget.notification.key.currentState?.resumeDismissTimer();
      }
    });
  }

  Widget _buildDraggable({
    required final QueueNotificationBehavior behavior,
    required final bool isLongPress,
  }) {
    final plugin = behavior.resolvePlugin();

    int? originalIndex;

    void onDragStarted() {
      if (_fsm.value is GestureSettling) {
        _snapBackController.stop();
        _fsm.reset();
      }

      originalIndex = stateIndexOfThisItem();

      final renderBox = context.findRenderObject() as RenderBox?;
      final cardRect = renderBox != null
          ? (renderBox.localToGlobal(Offset.zero) & renderBox.size)
          : Rect.zero;

      final position = widget.notification.queue.position;
      final queueKey = coordinator.getWidgetKey(position);
      final queueState = queueKey.currentState;
      final listBox = queueState?.listRenderBox;
      final containerRect = listBox != null
          ? (listBox.localToGlobal(Offset.zero) & listBox.size)
          : cardRect;

      final pointerStart = _dragStartData?.pointerPosition ?? Offset.zero;

      _fsm.lift(
        pointerStart: pointerStart,
        cardRect: cardRect,
        containerRect: containerRect,
        behavior: behavior,
      );

      if (widget.hapticFeedbackOnStart) {
        HapticFeedback.lightImpact();
      }

      queueKey.currentState?.setActiveDragGroup(
        widget.notification.resolvedGroupKey,
      );

      widget.notification.key.currentState?.pauseDismissTimer();

      plugin.onDragStart(this);
    }

    void onDragUpdate(final DragUpdateDetails details) {
      _updateFsm(behavior, details);
      plugin.onDragUpdate(this, details);
    }

    void onDragEnd(final DraggableDetails details) {
      _fsm.settle(
        originOffset: details.offset,
        targetOffset: _dragStartData?.widgetPosition ?? Offset.zero,
        velocity: details.velocity,
      );
      plugin.onDragEnd(this, details);

      final currentQueuePosition = widget.notification.queue.position;
      final isExiting =
          widget.notification.key.currentState?.animationController.status ==
              AnimationStatus.reverse;
      final itemIndex = stateIndexOfThisItem();
      final isRemovedOrRelocated = itemIndex == -1;
      final isRelocated =
          isRemovedOrRelocated || currentQueuePosition != _fsm.initialPosition;
      final isReordered = !isRemovedOrRelocated &&
          originalIndex != null &&
          itemIndex != originalIndex;

      if (!isExiting &&
          !isRelocated &&
          !isReordered &&
          _dragStartData != null) {
        final originalPosition = _dragStartData!.widgetPosition;
        final releaseOffset = details.offset;
        final distance = (releaseOffset - originalPosition).distance;
        if (distance > 1.0) {
          _startSnapBack(releaseOffset, details.velocity);
        } else {
          _fsm.reset();
        }
      } else {
        _fsm.reset();
      }

      if (!isRemovedOrRelocated) {
        final position = widget.notification.queue.position;
        final queueKey = coordinator.getWidgetKey(position);
        queueKey.currentState?.setActiveDragGroup(null);
        if (_fsm.value is! GestureSettling) {
          widget.notification.key.currentState?.resumeDismissTimer();
        }
      } else {
        final originQueueKey = coordinator.getWidgetKey(_fsm.initialPosition);
        originQueueKey.currentState?.setActiveDragGroup(null);
      }
    }

    final feedback = ValueListenableBuilder<GestureState>(
      valueListenable: _fsm,
      builder: (final context, final state, final child) =>
          plugin.buildFeedback(this),
    );

    final position = widget.notification.queue.position;
    final Object data = switch (behavior) {
      Relocate() => position,
      Dismiss() => position.alignment,
      Reorder() => stateIndexOfThisItem(),
      ReorderAndRelocate() => stateIndexOfThisItem(),
      Snooze() => position.alignment,
      Pin() => position.alignment,
      CustomAction() => position.alignment,
      _ => position,
    };
    final childWhenDragging = behavior is Reorder ||
            behavior is ReorderAndRelocate
        ? ReorderPlaceholder(
            child: _buildDummyGhost(_dragStartData?.widgetSize ?? Size.zero),
          )
        : const SizedBox.shrink();

    if (isLongPress) {
      return LongPressDraggable<Object>(
        data: data,
        axis: null,
        onDragStarted: onDragStarted,
        onDragUpdate: onDragUpdate,
        onDragEnd: onDragEnd,
        maxSimultaneousDrags: 1,
        hapticFeedbackOnStart: widget.hapticFeedbackOnStart,
        hitTestBehavior: HitTestBehavior.deferToChild,
        childWhenDragging: childWhenDragging,
        feedback: feedback,
        child: draggable(),
      );
    }

    return Draggable<Object>(
      data: data,
      axis: null,
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      maxSimultaneousDrags: 1,
      hitTestBehavior: HitTestBehavior.deferToChild,
      childWhenDragging: childWhenDragging,
      feedback: feedback,
      child: _buildCardChild(),
    );
  }

  void _updateFsm(
    final QueueNotificationBehavior behavior,
    final DragUpdateDetails details,
  ) {
    final position = widget.notification.queue.position;
    final pointer = details.globalPosition;

    int? targetSlotIndex;
    double? progress;
    QueuePosition? hoveredQueuePosition;
    bool? passedThreshold;

    if (behavior is Dismiss ||
        behavior is Snooze ||
        behavior is Pin ||
        behavior is CustomAction) {
      final zones = _getZones(behavior, position);
      passedThreshold = _passedThreshold(
        pointer,
        behavior.thresholdInPixels,
        zones,
      );
    } else if (behavior is Relocate || behavior is ReorderAndRelocate) {
      final relocateZones =
          _getZones(behavior, position).cast<PositionDropZone>();
      hoveredQueuePosition = relocateZones
          .where(
            (final z) => z.isHit(
              pointer,
              _screenSize,
              behavior.thresholdInPixels.toDouble(),
            ),
          )
          .firstOrNull
          ?.position;
    }

    if (behavior is Reorder || behavior is ReorderAndRelocate) {
      final reorderZones = _activeReorderZones ?? [];
      final nearestIndex =
          _nearestZoneIndexWithHysteresis(pointer, reorderZones);
      targetSlotIndex =
          nearestIndex != null ? reorderZones[nearestIndex].targetIndex : null;
      progress = _nearestZoneProgress(pointer, reorderZones);
    }

    _fsm.update(
      delta: details.delta,
      globalPosition: pointer,
      targetSlotIndex: targetSlotIndex,
      progress: progress,
      hoveredQueuePosition: hoveredQueuePosition,
      passedThreshold: passedThreshold,
    );
  }

  // Derives the active drop zones based on the interaction behavior.
  List<DropZone> _getZones(
    final QueueNotificationBehavior behavior,
    final QueuePosition position,
  ) {
    if (behavior is Dismiss) {
      return edgesFromDismissZone(behavior.zones, position);
    } else if (behavior is Snooze) {
      return edgesFromDismissZone(DismissZone.sideEdges, position);
    } else if (behavior is Pin) {
      return edgesFromDismissZone(DismissZone.sideEdges, position);
    } else if (behavior is CustomAction) {
      return edgesFromDismissZone(DismissZone.sideEdges, position);
    } else if (behavior is Relocate) {
      return zonesFromPositions(behavior.positions, position);
    } else if (behavior is ReorderAndRelocate) {
      return zonesFromPositions(behavior.positions, position);
    }
    return [];
  }

  bool _passedThreshold(
    final Offset? globalOffset,
    final int thresholdInPixels,
    final List<DropZone> zones,
  ) {
    if (globalOffset == null) {
      return false;
    }

    for (final zone in zones) {
      if (zone.isHit(globalOffset, _screenSize, thresholdInPixels.toDouble())) {
        return true;
      }
    }
    return false;
  }

  double _nearestZoneProgress(
    final Offset? pointer,
    final List<DropZone> zones,
  ) {
    if (pointer == null) {
      return 0.0;
    }
    var best = 0.0;
    for (final zone in zones) {
      if (zone is SlotDropZone) {
        final p = zone.calculateProgress(pointer, 1.0 / 120.0);
        if (p > best) {
          best = p;
        }
      }
    }
    return best;
  }

  final OverlayPortalController _overlayPortalController =
      OverlayPortalController();

  @override
  Widget build(final BuildContext context) => Listener(
        onPointerDown: (final event) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            _dragStartData = DragStartData(
              widgetPosition: renderBox.localToGlobal(Offset.zero),
              pointerPosition: event.position,
              widgetSize: renderBox.size,
            );
          }
        },
        child: longPressWidget(),
      );

  DragStartData? _dragStartData;
  int? _activeZoneIndex;

  int? _nearestZoneIndexWithHysteresis(
    final Offset? pointer,
    final List<SlotDropZone> zones,
  ) {
    if (pointer == null || zones.isEmpty) {
      return null;
    }
    var minDistance = double.infinity;
    int? bestIndex;
    const double gravityWell = 40.0;

    for (var i = 0; i < zones.length; i++) {
      final anchor = zones[i].anchor;
      if (anchor == null) {
        continue;
      }
      double distance = (pointer - anchor).distance;
      if (i == _activeZoneIndex) {
        distance -= gravityWell;
      }
      if (distance < minDistance) {
        minDistance = distance;
        bestIndex = i;
      }
    }

    _activeZoneIndex = bestIndex;
    return bestIndex;
  }

  Widget longPressWidget() =>
      switch (widget.notification.longPressDragBehavior ??
          widget.notification.queue.longPressDragBehavior) {
        Disabled() => draggable(),
        final behavior =>
          _buildDraggable(behavior: behavior, isLongPress: true),
      };

  Widget draggable() => switch (widget.notification.dragBehavior ??
          widget.notification.queue.dragBehavior) {
        Disabled() => _buildCardChild(),
        final behavior =>
          _buildDraggable(behavior: behavior, isLongPress: false),
      };

  Widget _buildDummyGhost(final Size size) => Container(
        width: size.width > 0 ? size.width : null,
        height: size.height > 0 ? size.height : null,
        decoration: BoxDecoration(
          color: widget.notification.backgroundColor ??
              const Color(0xFF2B2C50), // Fallback to a typical dark card color
          borderRadius: BorderRadius.circular(14),
        ),
      );
}
