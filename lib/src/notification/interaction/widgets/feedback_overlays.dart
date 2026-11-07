part of 'widgets.dart';

/// A sophisticated overlay that handles the physical transformation of the
/// Notification Widget during dismissal and relocation interactions.
class DismissFeedbackOverlay extends StatefulWidget {
  const DismissFeedbackOverlay({
    required this.passedThreshold,
    required this.dragOffset,
    required this.thresholdInPixels,
    required this.screenSize,
    required this.startData,
    required this.zones,
    required this.springPhysics,
    required this.child,
    super.key,
  });

  final bool passedThreshold;
  final Offset? dragOffset;
  final int thresholdInPixels;
  final Size screenSize;
  final DragStartData? startData;
  final List<EdgeDropZone> zones;
  final SpringPhysicsConfiguration springPhysics;
  final Widget child;

  @override
  State<DismissFeedbackOverlay> createState() => _DismissFeedbackOverlayState();
}

class _DismissFeedbackOverlayState extends State<DismissFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sinkingController;

  @override
  void initState() {
    super.initState();
    _sinkingController = AnimationController(
      vsync: this,
      lowerBound: 0.5,
      upperBound: 1.5,
    );
    _animateToTarget();
  }

  @override
  void didUpdateWidget(covariant final DismissFeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passedThreshold != widget.passedThreshold) {
      _animateToTarget();
    }
  }

  void _animateToTarget() {
    final double targetScale = widget.passedThreshold ? 0.85 : 1.0;

    final simulation = SpringSimulation(
      widget.springPhysics.toSpringDescription(),
      _sinkingController.value,
      targetScale,
      0.0,
    );

    _sinkingController.animateWith(simulation);
  }

  @override
  void dispose() {
    _sinkingController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    EdgeDropZone? lockedZone;
    double proximityProgress = 0.0;

    if (widget.dragOffset != null) {
      final List<double> progressList = [];
      double maxProgress = 0.0;
      EdgeDropZone? maxZone;

      for (final zone in widget.zones) {
        final progress = zone.calculateProgress(
          widget.dragOffset!,
          widget.screenSize,
          1.0 / widget.thresholdInPixels,
        );
        progressList.add(progress);

        if (progress >= 1.0 && (lockedZone == null || progress > maxProgress)) {
          lockedZone = zone;
        }

        if (progress > maxProgress) {
          maxProgress = progress;
          maxZone = zone;
        }
      }
      proximityProgress = progressList.isEmpty ? 0.0 : progressList.reduce(max);

      if (widget.passedThreshold && lockedZone == null) {
        lockedZone = maxZone;
      }
    }

    Offset correction = Offset.zero;
    if (widget.dragOffset != null && widget.startData != null) {
      correction = _calculateMagnetCorrection(
        dragOffset: widget.dragOffset!,
        startData: widget.startData!,
        lockedZone: lockedZone,
      );
    }

    final double opacity = 1.0 - (proximityProgress * 0.5);
    final double baseScale = 1.0 - (proximityProgress * 0.08);
    final double sinkingBlur = widget.passedThreshold ? 4.0 : 0.0;

    final themeData = Theme.of(context);
    final onSurface = themeData.colorScheme.onSurface;

    final cardContent = ColorFiltered(
      colorFilter: widget.passedThreshold
          ? ColorUtils.grayscaleFilter
          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.passedThreshold
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: sinkingBlur,
                  sigmaY: sinkingBlur,
                ),
                child: widget.child,
              )
            : widget.child,
      ),
    );

    return Transform.translate(
      offset: correction,
      child: AnimatedBuilder(
        animation: _sinkingController,
        builder: (final context, final child) {
          final currentScale = baseScale * _sinkingController.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: currentScale,
                  alignment: lockedZone?.alignment ?? Alignment.center,
                  child: cardContent,
                ),
              ),
              if (widget.passedThreshold)
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    opacity: 1.0,
                    child: Transform.scale(
                      scale: currentScale,
                      alignment: lockedZone?.alignment ?? Alignment.center,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: themeData.colorScheme.surface
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: onSurface.withValues(alpha: 0.1),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                'RELEASE TO DISMISS',
                                style: TextStyle(
                                  color: onSurface.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Offset _calculateMagnetCorrection({
    required final Offset dragOffset,
    required final DragStartData startData,
    required final EdgeDropZone? lockedZone,
  }) {
    final Offset nominalTopLeft = dragOffset - startData.touchOffset;

    double x = nominalTopLeft.dx
        .clamp(0.0, widget.screenSize.width - startData.widgetSize.width);
    double y = nominalTopLeft.dy
        .clamp(0.0, widget.screenSize.height - startData.widgetSize.height);

    if (widget.passedThreshold && lockedZone != null) {
      final double barSize = widget.thresholdInPixels.toDouble();
      final Alignment align = lockedZone.alignment;

      if (align.x == -1.0) {
        x = barSize;
      }
      if (align.x == 1.0) {
        x = widget.screenSize.width - startData.widgetSize.width - barSize;
      }
      if (align.y == -1.0) {
        y = barSize;
      }
      if (align.y == 1.0) {
        y = widget.screenSize.height - startData.widgetSize.height - barSize;
      }
    }

    return Offset(x, y) - nominalTopLeft;
  }
}

class ReorderPlaceholder extends StatefulWidget {
  const ReorderPlaceholder({required this.child, super.key});

  final Widget child;

  @override
  State<ReorderPlaceholder> createState() => _ReorderPlaceholderState();
}

class _ReorderPlaceholderState extends State<ReorderPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => AnimatedBuilder(
        animation: _pulse,
        builder: (final context, final child) {
          final opacity = 0.35 + _pulse.value * 0.25;
          return Opacity(
            opacity: opacity,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(opacity: 0.35, child: widget.child),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      opacity: opacity,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.opacity});

  final double opacity;

  static Path? _cachedPath;
  static Size? _cachedSize;

  @override
  void paint(final Canvas canvas, final Size size) {
    const radius = Radius.circular(12);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (_cachedPath == null || _cachedSize != size) {
      _cachedSize = size;
      _cachedPath = _buildDashedPath(size, radius);
    }

    canvas.drawPath(_cachedPath!, paint);
  }

  Path _buildDashedPath(final Size size, final Radius radius) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      radius,
    );
    final sourcePath = Path()..addRRect(rrect);
    final dashedPath = Path();
    const dashWidth = 6.0;
    const dashSpace = 4.0;

    final metrics = sourcePath.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length);
        dashedPath.addPath(
          metric.extractPath(distance, end as double),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(final _DashedBorderPainter old) => old.opacity != opacity;
}

/// Wraps the dragged notification to give it a "lifted" appearance
/// under continuous spring physics.
class LiftedFeedback extends StatefulWidget {
  const LiftedFeedback({
    required this.child,
    required this.passedThreshold,
    required this.nearestProgress,
    required this.widgetSize,
    required this.springPhysics,
    super.key,
  });

  final Widget child;
  final bool passedThreshold;
  final double nearestProgress;
  final Size widgetSize;
  final SpringPhysicsConfiguration springPhysics;

  @override
  State<LiftedFeedback> createState() => _LiftedFeedbackState();
}

class _LiftedFeedbackState extends State<LiftedFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.5,
      upperBound: 1.5,
    );
    _animateToTarget();
  }

  @override
  void didUpdateWidget(covariant final LiftedFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passedThreshold != widget.passedThreshold ||
        oldWidget.nearestProgress != widget.nearestProgress) {
      _animateToTarget();
    }
  }

  void _animateToTarget() {
    final bool engaged = widget.nearestProgress > 0.3;
    final double targetScale = widget.passedThreshold
        ? 0.96
        : engaged
            ? 1.06
            : 1.04;

    final simulation = SpringSimulation(
      widget.springPhysics.toSpringDescription(),
      _controller.value,
      targetScale,
      0.0,
    );

    _controller.animateWith(simulation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final bool engaged = widget.nearestProgress > 0.3;
    final double opacity = widget.passedThreshold ? 0.5 : 1.0;

    final Color glowColor = widget.passedThreshold
        ? Colors.green
        : engaged
            ? Colors.blue
            : Colors.transparent;

    final double glowSpread = widget.passedThreshold
        ? 4.0
        : engaged
            ? 2.0
            : 0.0;

    final Color shadowColor = Colors.black.withValues(alpha: 0.25);
    final double shadowBlur = widget.passedThreshold ? 4.0 : 20.0;
    final double shadowSpread = widget.passedThreshold ? 0.0 : 4.0;
    final Offset shadowOffset =
        widget.passedThreshold ? const Offset(0, 2) : const Offset(0, 8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (final context, final child) => Transform.scale(
        scale: _controller.value,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: widget.widgetSize.width > 0 ? widget.widgetSize.width : null,
            height:
                widget.widgetSize.height > 0 ? widget.widgetSize.height : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                  offset: shadowOffset,
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: engaged ? 0.45 : 0.0),
                  blurRadius: 24,
                  spreadRadius: glowSpread,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(
                  widget.passedThreshold
                      ? _kDesatMatrix
                      : engaged
                          ? _kSlightDesatMatrix
                          : _kIdentityMatrix,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Identity matrix — no color change.
const List<double> _kIdentityMatrix = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

// 50% desaturation — engaged (approaching a slot).
const List<double> _kSlightDesatMatrix = [
  0.67, 0.21, 0.07, 0, 0, //
  0.17, 0.72, 0.07, 0, 0,
  0.17, 0.21, 0.57, 0, 0,
  0.00, 0.00, 0.00, 1, 0,
];

// ~80% desaturation — committed (will drop on release).
const List<double> _kDesatMatrix = [
  0.33, 0.34, 0.33, 0, 0, //
  0.33, 0.34, 0.33, 0, 0,
  0.33, 0.34, 0.33, 0, 0,
  0.00, 0.00, 0.00, 1, 0,
];
