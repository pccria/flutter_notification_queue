part of 'notification_queue.dart';

/// Decorative halo surrounding a mounted target queue when an external dragged
/// notification hovers over one of its slots.
class _QueueExternalHalo extends StatefulWidget {
  const _QueueExternalHalo({
    required this.progress,
    required this.style,
    required this.visible,
    this.position,
  });

  final double progress;
  final QueueStyle style;
  final bool visible;
  final QueuePosition? position;

  @override
  State<_QueueExternalHalo> createState() => _QueueExternalHaloState();
}

class _QueueExternalHaloState extends State<_QueueExternalHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.visible) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant final _QueueExternalHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.visible && oldWidget.visible) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final resolved = NotificationTheme.resolveWith(context, widget.style);
    final accent = resolved.color;
    final committed = widget.progress >= 0.75;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (final context, final child) {
            final pulse = 0.65 + 0.35 * _pulseController.value;
            final alpha =
                widget.visible ? (committed ? 0.36 : 0.20) * pulse : 0.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: resolved.borderRadius.add(
                        const BorderRadius.all(Radius.circular(6)),
                      ),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: widget.visible
                              ? (committed ? 0.72 : 0.36) * pulse
                              : 0.0,
                        ),
                        width: committed ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: alpha),
                          blurRadius: committed ? 24 : 16,
                          spreadRadius: committed ? 4 : 1,
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.visible && widget.position != null)
                  Positioned(
                    top: -12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: widget.visible ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: committed
                                ? const Color(0xFF2E7D32)
                                : accent.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                committed
                                    ? Icons.check_circle_outline
                                    : Icons.move_to_inbox,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                committed
                                    ? 'Drop in ${widget.position!.displayName}'
                                    : 'Relocate to '
                                        '${widget.position!.displayName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Visual slot surface rendered inside an opened external drop gap between
/// cards (or at the tail slot) of a mounted destination queue.
class _ExternalDropGapWidget extends StatefulWidget {
  const _ExternalDropGapWidget({
    required this.style,
    required this.progress,
    required this.verticalDirection,
  });

  final QueueStyle style;
  final double progress;
  final VerticalDirection verticalDirection;

  @override
  State<_ExternalDropGapWidget> createState() => _ExternalDropGapWidgetState();
}

class _ExternalDropGapWidgetState extends State<_ExternalDropGapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    final resolved = NotificationTheme.resolveWith(context, widget.style);
    final accent = resolved.color;
    final surfaceTint = theme.colorScheme.surface;
    final p = widget.progress.clamp(0.0, 1.0);
    final isCommitted = p >= 0.75;
    final isEngaged = p >= 0.40;
    final borderRadius = resolved.borderRadius is BorderRadius
        ? resolved.borderRadius as BorderRadius
        : BorderRadius.circular(12);

    return IgnorePointer(
      child: Semantics(
        label: 'Drop slot for incoming notification',
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (final context, final child) {
            final pulse = 0.55 + 0.45 * _pulseController.value;
            final borderAlpha = isCommitted
                ? 0.90
                : isEngaged
                    ? 0.65
                    : 0.42 * pulse;
            final fillAlpha = isCommitted
                ? 0.24
                : isEngaged
                    ? 0.16
                    : 0.08 + (0.05 * _pulseController.value);

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.92, end: 1.0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (final context, final enterScale, final child) =>
                  Transform.scale(
                scale: enterScale,
                child: child,
              ),
              child: CustomPaint(
                painter: DashedRRectBorderPainter(
                  borderRadius: borderRadius,
                  color: accent.withValues(alpha: borderAlpha),
                  strokeWidth: isCommitted ? 2.0 : 1.5,
                  dashed: !isEngaged,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      colors: [
                        Color.alphaBlend(
                          accent.withValues(alpha: fillAlpha),
                          surfaceTint.withValues(alpha: 0.65),
                        ),
                        Color.alphaBlend(
                          accent.withValues(alpha: fillAlpha * 0.65),
                          surfaceTint.withValues(alpha: 0.50),
                        ),
                      ],
                    ),
                    boxShadow: isCommitted
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutBack,
                      scale: isCommitted
                          ? 1.15
                          : isEngaged
                              ? 1.0
                              : 0.85,
                      child: Icon(
                        isCommitted
                            ? Icons.add_task_rounded
                            : widget.verticalDirection == VerticalDirection.down
                                ? Icons.south_rounded
                                : Icons.north_rounded,
                        size: 20,
                        color: accent.withValues(
                          alpha: isCommitted ? 0.95 : 0.72,
                        ),
                      ),
                    ),
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
