part of 'notification_queue.dart';

sealed class _QueueRenderBlock {
  const _QueueRenderBlock();
}

class _SingleItemBlock extends _QueueRenderBlock {
  const _SingleItemBlock(this.item);
  final _NotificationItemState item;
}

class _GroupBlock extends _QueueRenderBlock {
  const _GroupBlock(this.groupKey, this.items);
  final String groupKey;
  final List<_NotificationItemState> items;
}

class _GroupWidget extends StatefulWidget {
  const _GroupWidget({
    required this.queueWidgetState,
    required this.groupKey,
    required this.items,
    required this.isExpanded,
    required this.isLastBlock,
    required this.onToggle,
    super.key,
  });

  final QueueWidgetState queueWidgetState;
  final String groupKey;
  final List<_NotificationItemState> items;
  final bool isExpanded;
  final bool isLastBlock;
  final VoidCallback onToggle;

  @override
  State<_GroupWidget> createState() => _GroupWidgetState();
}

class _GroupWidgetState extends State<_GroupWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansionController;

  _NotificationItemState get representative =>
      widget.queueWidgetState._groupRepresentative(widget.items);

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isExpanded ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant final _GroupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expansionController.forward();
      } else {
        _expansionController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  Widget _buildTogglePill(final BuildContext context, final double progress) {
    final rep = representative;
    final hiddenItems = widget.items.where((final i) => i != rep).toList();
    final queue = widget.queueWidgetState.widget.queue;
    final verticalDirection = queue.verticalDirection;

    final resolvedTheme =
        NotificationTheme.resolveWith(context, queue.style, rep.widget);
    final theme = Theme.of(context);
    final fg = resolvedTheme.foregroundColor;

    // UX-03: next-in-line preview — title + truncated message.
    final nextItem = hiddenItems.isNotEmpty ? hiddenItems.first : null;
    final nextTitle = nextItem?.widget.title;
    final nextMessage = nextItem?.widget.message;

    final countBehavior = queue.groupingBehavior.countBehavior;
    final pendingCount = countBehavior.includePending
        ? widget.queueWidgetState.countPendingForGroup(widget.groupKey)
        : 0;
    final totalCount = widget.items.length + pendingCount;
    final hiddenCount = totalCount - 1;

    final badgeLabel = countBehavior.format(
      totalCount: totalCount,
      hiddenCount: hiddenCount,
    );

    final collapsedOpacity = (1.0 - progress * 2.0).clamp(0.0, 1.0);
    final expandedOpacity = (progress * 2.0 - 1.0).clamp(0.0, 1.0);

    final a11yLabel = widget.isExpanded
        ? 'Collapse notification group for channel ${widget.groupKey}'
        : 'Grouped notifications: ${widget.items.length} items for channel '
            '${widget.groupKey}';
    final a11yHint = 'Double tap or press Enter to '
        '${widget.isExpanded ? "collapse" : "expand"} group stack';

    return Semantics(
      button: true,
      label: a11yLabel,
      hint: a11yHint,
      onTap: widget.onToggle,
      child: Focus(
        onKeyEvent: (final node, final event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onToggle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
        onTap: widget.onToggle,
        onLongPress: widget.onToggle, // accessibility: long-press also toggles
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: resolvedTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: resolvedTheme.color.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: collapsedOpacity,
                    child: IgnorePointer(
                      ignoring: collapsedOpacity < 0.5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (nextTitle != null) ...[
                            Text(
                              nextTitle,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (nextMessage != null) ...[
                              Text(
                                '  ·  ',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: fg.withValues(alpha: 0.5),
                                ),
                              ),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 120),
                                child: Text(
                                  nextMessage,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: fg.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (badgeLabel != null) const SizedBox(width: 6),
                          ] else if (badgeLabel == null) ...[
                            Text(
                              nextMessage ?? 'Group',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (badgeLabel != null)
                            Text(
                              badgeLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: expandedOpacity,
                    child: IgnorePointer(
                      ignoring: expandedOpacity < 0.5,
                      child: Text(
                        'Collapse',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              RotationTransition(
                turns: Tween<double>(
                  begin:
                      verticalDirection == VerticalDirection.down ? 0.0 : 0.5,
                  end: verticalDirection == VerticalDirection.down ? 0.5 : 0.0,
                ).animate(_expansionController),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  @override
  Widget build(final BuildContext context) {
    final queue = widget.queueWidgetState.widget.queue;
    final alignment =
        queue.verticalDirection == VerticalDirection.down ? -1.0 : 1.0;

    return AnimatedBuilder(
      animation: _expansionController,
      builder: (final context, final child) {
        final visibleItems = widget.items.where((final item) {
          if (item.status == _ItemStatus.exiting) {
            return true;
          }
          if (widget.isExpanded || _expansionController.value > 0.0) {
            return true;
          }
          final rep = representative;
          if (item == rep) {
            return true;
          }
          if (widget.queueWidgetState._activeDragGroupKey == widget.groupKey) {
            final repIdx = widget.items.indexOf(rep);
            final peekIdx = queue.verticalDirection == VerticalDirection.up
                ? repIdx + 1
                : repIdx - 1;
            if (peekIdx >= 0 && peekIdx < widget.items.length) {
              return item == widget.items[peekIdx];
            }
          }
          return false;
        }).toList();

        final outerSpacing = widget.isLastBlock ? 0.0 : queue.spacing;

        final progress = _expansionController.value;

        return Padding(
          padding: EdgeInsets.only(
            bottom: queue.verticalDirection == VerticalDirection.down
                ? outerSpacing
                : 0,
            top: queue.verticalDirection == VerticalDirection.up
                ? outerSpacing
                : 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            verticalDirection: queue.verticalDirection,
            mainAxisAlignment: queue.mainAxisAlignment,
            crossAxisAlignment: queue.crossAxisAlignment,
            children: [
              for (final item in visibleItems)
                KeyedSubtree(
                  key: ValueKey(item.widget.id),
                  child: _buildGroupItem(
                    context,
                    item,
                    visibleItems,
                    alignment,
                    queue,
                  ),
                ),
              if (progress > 0.0)
                SizeTransition(
                  sizeFactor: _expansionController,
                  axis: Axis.vertical,
                  child: FadeTransition(
                    opacity: _expansionController,
                    child: Padding(
                      padding: queue.verticalDirection == VerticalDirection.down
                          ? const EdgeInsets.only(top: 12.0, bottom: 4.0)
                          : const EdgeInsets.only(bottom: 12.0, top: 4.0),
                      child: Center(
                        child: _buildTogglePill(context, progress),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupItem(
    final BuildContext context,
    final _NotificationItemState item,
    final List<_NotificationItemState> visibleItems,
    final double alignment,
    final NotificationQueue queue,
  ) {
    final isLast = item == visibleItems.last;
    final spacing = (widget.isExpanded && !isLast) ? queue.spacing : 0.0;

    final globalVisibleIndex =
        widget.queueWidgetState.visibleIndexOf(item.widget.id);

    Widget itemWidget = widget.queueWidgetState._buildSingleNotificationCard(
      item: item,
      spacing: spacing,
      visibleIndex: globalVisibleIndex,
    );

    final rep = representative;
    final isExpanded = widget.isExpanded;

    if (item == rep) {
      final isDraggingRep =
          widget.queueWidgetState._activeDragGroupKey == widget.groupKey;
      final timerEnabled = !isDraggingRep;
      itemWidget = NotificationTimerScope(
        enabled: timerEnabled,
        child: itemWidget,
      );

      itemWidget = TweenAnimationBuilder<double>(
        key: item.entranceKey,
        tween: Tween(begin: 0.96, end: 1.0),
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        builder: (final ctx, final scale, final child) =>
            Transform.scale(scale: scale, child: child),
        child: itemWidget,
      );

      final hiddenItems = widget.items.where((final i) => i != rep).toList();

      final progress = _expansionController.value;
      final showTogglePill = progress == 0.0;

      final behavior = queue.groupingBehavior;
      final maxLayers = behavior.maxStackedLayers;
      final stepOffset = behavior.stackStepOffset;
      final collapsedExtraSpace = 32.0 + (maxLayers * stepOffset);
      final extraSpace = collapsedExtraSpace * (1.0 - progress);

      itemWidget = _GroupBundleWidget(
        notification: item.widget,
        count: widget.items.length,
        expansionProgress: _expansionController,
        hiddenItems: hiddenItems,
        onToggle: widget.onToggle,
        style: queue.style,
        verticalDirection: queue.verticalDirection,
        togglePill: showTogglePill ? _buildTogglePill(context, progress) : null,
        extraSpace: extraSpace,
        child: itemWidget,
      );
    } else {
      final isPeek = widget.queueWidgetState
          ._isPeekItem(item, widget.groupKey, widget.items);
      if (isPeek) {
        itemWidget = NotificationTimerScope(
          enabled: false,
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (final ctx, final t, final child) => Opacity(
                opacity: 0.55 * t,
                child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
              child: itemWidget,
            ),
          ),
        );
      } else {
        final timerEnabled = isExpanded;
        itemWidget = NotificationTimerScope(
          enabled: timerEnabled,
          child: SizeTransition(
            sizeFactor: _expansionController.drive(
              CurveTween(curve: Curves.fastOutSlowIn),
            ),
            alignment: Alignment(-1.0, alignment),
            child: FadeTransition(
              opacity: _expansionController.drive(
                CurveTween(
                  curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                ),
              ),
              child: itemWidget,
            ),
          ),
        );
      }
    }

    return itemWidget;
  }
}

class _GroupBundleWidget extends AnimatedWidget {
  const _GroupBundleWidget({
    required final Animation<double> expansionProgress,
    required this.child,
    required this.count,
    required this.hiddenItems,
    required this.onToggle,
    required this.style,
    required this.verticalDirection,
    required this.notification,
    required this.togglePill,
    required this.extraSpace,
  }) : super(listenable: expansionProgress);

  Animation<double> get expansionProgress => listenable as Animation<double>;

  final Widget child;
  final int count;
  final List<_NotificationItemState> hiddenItems;
  final VoidCallback onToggle;
  final QueueStyle style;
  final VerticalDirection verticalDirection;
  final NotificationWidget notification;
  final Widget? togglePill;
  final double extraSpace;

  @override
  Widget build(final BuildContext context) {
    final progress = expansionProgress.value;
    final behavior = notification.queue.groupingBehavior;
    final maxLayers = behavior.maxStackedLayers;
    final stepOffset = behavior.stackStepOffset;
    final scaleMultiplier = behavior.stackScaleMultiplier;

    final backgroundLayers = <Widget>[];
    if (progress < 1.0) {
      final availableCount = count - 1;
      final layersToRender = min(availableCount, maxLayers);

      for (int i = layersToRender; i > 0; i--) {
        final layerScale = 1.0 - (i * scaleMultiplier) * (1.0 - progress);
        final layerOpacity =
            (0.9 - i * 0.25).clamp(0.0, 1.0) * (1.0 - progress);
        final currentShift = i * stepOffset * (1.0 - progress);

        final double? top;
        final double? bottom;
        if (verticalDirection == VerticalDirection.down) {
          top = currentShift;
          bottom = extraSpace - currentShift;
        } else {
          top = extraSpace - currentShift;
          bottom = currentShift;
        }

        backgroundLayers.add(
          Positioned(
            left: i * 8.0 * (1.0 - progress),
            right: i * 8.0 * (1.0 - progress),
            top: top,
            bottom: bottom,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onToggle,
                behavior: HitTestBehavior.opaque,
                child: _buildLayer(context, layerScale, layerOpacity),
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      alignment: verticalDirection == VerticalDirection.down
          ? Alignment.topCenter
          : Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        ...backgroundLayers,
        Padding(
          padding: EdgeInsets.only(
            bottom:
                verticalDirection == VerticalDirection.down ? extraSpace : 0,
            top: verticalDirection == VerticalDirection.up ? extraSpace : 0,
          ),
          child: child,
        ),
        if (togglePill != null)
          Positioned(
            bottom: verticalDirection == VerticalDirection.down ? 4.0 : null,
            top: verticalDirection == VerticalDirection.up ? 4.0 : null,
            child: togglePill!,
          ),
      ],
    );
  }

  Widget _buildLayer(
    final BuildContext context,
    final double scale,
    final double opacity,
  ) {
    final resolvedTheme =
        NotificationTheme.resolveWith(context, style, notification);
    final cardColor = resolvedTheme.backgroundColor;

    final border = resolvedTheme.border;
    final isUniform = border == null || border.isUniform;

    Widget child = const SizedBox.expand();
    if (border != null && !isUniform) {
      child = Container(
        decoration: BoxDecoration(
          border: border,
        ),
        child: child,
      );
    }

    final container = Container(
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: resolvedTheme.opacity * opacity),
        borderRadius: resolvedTheme.borderRadius,
        border: isUniform ? border : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08 * opacity),
            blurRadius: resolvedTheme.elevation * opacity,
            offset: Offset(0, resolvedTheme.elevation * 0.5 * opacity),
          ),
        ],
      ),
      child: isUniform
          ? child
          : ClipRRect(
              borderRadius: resolvedTheme.borderRadius,
              child: child,
            ),
    );

    return Transform.scale(
      scaleX: scale,
      scaleY: 1.0,
      alignment: verticalDirection == VerticalDirection.down
          ? Alignment.topCenter
          : Alignment.bottomCenter,
      child: container,
    );
  }
}
