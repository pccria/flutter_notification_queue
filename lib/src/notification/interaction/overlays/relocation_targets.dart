part of 'overlays.dart';

/// Renders destination-centric landing docks for candidate queue positions
/// during `Relocate` and `ReorderAndRelocate` drag gestures.
///
/// For unmounted or empty destination queues, each candidate renders an
/// on-location card-footprint landing pad aligned with its resolved screen dock
/// coordinates ([dockRects]). Docks dynamically reorder along the z-axis so
/// whichever target is hovered or engaged always paints on top, while
/// intersecting idle siblings smoothly recede.
class RelocationTargets extends StatelessWidget {
  const RelocationTargets({
    required this.currentPosition,
    required this.targets,
    required this.screenSize,
    required this.gestureState,
    required this.threshold,
    this.dockRects = const {},
    this.suppressedPositions = const {},
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    super.key,
  });

  /// The set of available positions for relocation.
  final Set<QueuePosition> targets;

  /// The current position of the notification queue (excluded from targets).
  final QueuePosition currentPosition;

  /// The dimensions of the screen.
  final Size screenSize;

  /// Live gesture state listenable for computing per-target proximity hover.
  final ValueListenable<GestureState> gestureState;

  /// The engagement threshold in pixels (fallback when [dockRects] lacks an
  /// entry).
  final double threshold;

  /// Nominal/de-overlapped global screen-space card-footprint rects for each
  /// candidate queue position.
  final Map<QueuePosition, Rect> dockRects;

  /// Candidate queue positions whose coarse dock should be suppressed (for
  /// instance because a mounted stack already renders slot-level feedback).
  final Set<QueuePosition> suppressedPositions;

  /// Corner radius matching the dragged card style.
  final BorderRadius borderRadius;

  @override
  Widget build(final BuildContext context) =>
      ValueListenableBuilder<GestureState>(
        valueListenable: gestureState,
        builder: (final context, final state, final child) {
          final pointer = state.pointerPosition;
          final entries = <({
            QueuePosition position,
            Rect? dockRect,
            bool isTargeted,
            double progress,
            double zScore,
          })>[];

          for (final position in targets) {
            if (position == currentPosition ||
                suppressedPositions.contains(position)) {
              continue;
            }

            if (state case GestureRearranging(:final target)) {
              if (target is SlotTarget && target.position == position) {
                continue;
              }
            }

            final dockRect = dockRects[position];
            final (isTargeted, progress) = _evaluateDockEngagement(
              position: position,
              state: state,
              pointer: pointer,
              dockRect: dockRect,
            );
            final zScore = (isTargeted ? 10.0 : 0.0) + progress;

            entries.add(
              (
                position: position,
                dockRect: dockRect,
                isTargeted: isTargeted,
                progress: progress,
                zScore: zScore,
              ),
            );
          }

          // Dynamic Z-axis sort: idle first, engaged above, targeted on top.
          entries.sort((final a, final b) => a.zScore.compareTo(b.zScore));

          final activeEntry = entries
              .where((final e) => e.isTargeted || e.progress >= 0.45)
              .lastOrNull;

          return Stack(
            fit: StackFit.passthrough,
            children: [
              for (final entry in entries)
                _buildEntry(
                  entry: entry,
                  activeEntry: activeEntry,
                ),
            ],
          );
        },
      );

  Widget _buildEntry({
    required final ({
      QueuePosition position,
      Rect? dockRect,
      bool isTargeted,
      double progress,
      double zScore,
    }) entry,
    required final ({
      QueuePosition position,
      Rect? dockRect,
      bool isTargeted,
      double progress,
      double zScore,
    })? activeEntry,
  }) {
    var siblingDimFactor = 1.0;
    if (activeEntry != null && activeEntry.position != entry.position) {
      final overlapsActive = activeEntry.dockRect != null &&
          entry.dockRect != null &&
          activeEntry.dockRect!.inflate(16).overlaps(entry.dockRect!);
      siblingDimFactor = overlapsActive ? 0.25 : 0.62;
    }

    final dockWidget = _LandingDock(
      position: entry.position,
      isTargeted: entry.isTargeted,
      progress: entry.progress,
      dimFactor: siblingDimFactor,
      borderRadius: borderRadius,
    );

    final dockRect = entry.dockRect;
    if (dockRect != null && !dockRect.isEmpty) {
      return Positioned.fromRect(
        key: ValueKey('dock_${entry.position.name}'),
        rect: dockRect,
        child: dockWidget,
      );
    }

    return Align(
      key: ValueKey('dock_${entry.position.name}'),
      alignment: entry.position.alignment,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 160,
            maxWidth: 260,
            minHeight: 64,
            maxHeight: 84,
          ),
          child: dockWidget,
        ),
      ),
    );
  }

  (bool, double) _evaluateDockEngagement({
    required final QueuePosition position,
    required final GestureState state,
    required final Offset? pointer,
    required final Rect? dockRect,
  }) {
    if (state case GestureRearranging(:final target)) {
      if (target is QueueTarget && target.position == position) {
        return (true, target.progress);
      }
      if (pointer == null) {
        return (false, 0.0);
      }
      return (false, _proximityProgress(pointer, position, dockRect));
    }

    if (state
        case GestureRelocating(
          :final hoveredQueuePosition,
          :final progress,
        )) {
      if (hoveredQueuePosition == position) {
        return (true, progress > 0.0 ? progress : 1.0);
      }
      if (pointer == null) {
        return (false, 0.0);
      }
      return (false, _proximityProgress(pointer, position, dockRect));
    }

    if (pointer == null) {
      return (false, 0.0);
    }
    return (false, _proximityProgress(pointer, position, dockRect));
  }

  double _proximityProgress(
    final Offset pointer,
    final QueuePosition position,
    final Rect? dockRect,
  ) {
    if (dockRect != null && !dockRect.isEmpty) {
      final dx = max(
        0.0,
        max(dockRect.left - pointer.dx, pointer.dx - dockRect.right),
      );
      final dy = max(
        0.0,
        max(dockRect.top - pointer.dy, pointer.dy - dockRect.bottom),
      );
      final distToEdge = Offset(dx, dy).distance;
      final approachRange = max(threshold, 96.0);
      return (1.0 - (distToEdge / approachRange)).clamp(0.0, 1.0);
    }

    final zone = PositionDropZone(position: position);
    final invThreshold = threshold > 0 ? 1.0 / threshold : 1.0;
    return zone.calculateProgress(pointer, screenSize, invThreshold);
  }
}

class _LandingDock extends StatefulWidget {
  const _LandingDock({
    required this.position,
    required this.isTargeted,
    required this.progress,
    required this.dimFactor,
    required this.borderRadius,
  });

  final QueuePosition position;
  final bool isTargeted;
  final double progress;
  final double dimFactor;
  final BorderRadius borderRadius;

  @override
  State<_LandingDock> createState() => _LandingDockState();
}

class _LandingDockState extends State<_LandingDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;

    final committed = widget.isTargeted;
    final engaged = !committed && widget.progress >= 0.25;
    final activeColor = committed ? Colors.green : primary;

    final double baseScale = committed
        ? 1.03
        : engaged
            ? 1.01
            : widget.dimFactor < 0.5
                ? 0.92
                : 0.97;

    return IgnorePointer(
      child: Semantics(
        label: '${widget.position.displayName} drop zone',
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (final context, final child) {
            final pulse = 0.65 + 0.35 * _pulseController.value;
            final borderAlpha = committed
                ? 0.95
                : engaged
                    ? 0.72
                    : 0.42 * pulse;
            final bgAlpha = committed
                ? 0.24
                : engaged
                    ? 0.16
                    : 0.08;
            final surfaceAlpha = committed
                ? 0.90
                : engaged
                    ? 0.80
                    : 0.62;

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              opacity: widget.dimFactor,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: baseScale,
                child: CustomPaint(
                  painter: DashedRRectBorderPainter(
                    borderRadius: widget.borderRadius,
                    color: activeColor.withValues(alpha: borderAlpha),
                    strokeWidth: committed ? 2.0 : 1.5,
                    dashed: !committed,
                  ),
                  child: LayoutBuilder(
                    builder: (final context, final constraints) {
                      final w = constraints.maxWidth;
                      final compact = w < 190;
                      final stacked = w < 112;

                      final icon = Icon(
                        committed
                            ? Icons.check_circle_rounded
                            : Icons.move_to_inbox_rounded,
                        size: committed ? 20 : (stacked ? 16 : 18),
                        color: committed
                            ? activeColor
                            : onSurface.withValues(
                                alpha: engaged ? 0.88 : 0.68,
                              ),
                      );
                      final label = Text(
                        committed && !compact
                            ? 'Drop · ${widget.position.displayName}'
                            : widget.position.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: (stacked
                                ? theme.textTheme.labelSmall
                                : theme.textTheme.labelMedium)
                            ?.copyWith(
                          fontSize: stacked ? 10.5 : null,
                          color: committed
                              ? activeColor
                              : onSurface.withValues(
                                  alpha: engaged ? 0.94 : 0.76,
                                ),
                          fontWeight:
                              committed ? FontWeight.w700 : FontWeight.w600,
                          letterSpacing: 0.15,
                        ),
                      );

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: stacked ? 6 : (compact ? 10 : 14),
                          vertical: stacked ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: widget.borderRadius,
                          color: Color.alphaBlend(
                            activeColor.withValues(alpha: bgAlpha),
                            surface.withValues(alpha: surfaceAlpha),
                          ),
                          boxShadow: [
                            if (committed || engaged)
                              BoxShadow(
                                color: activeColor.withValues(
                                  alpha: committed ? 0.30 : 0.16,
                                ),
                                blurRadius: committed ? 20 : 12,
                                spreadRadius: committed ? 2 : 0,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Center(
                          child: stacked
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    icon,
                                    const SizedBox(height: 2),
                                    label,
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    icon,
                                    const SizedBox(width: 6),
                                    Flexible(child: label),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
