part of 'overlays.dart';

class IntentTargets extends StatelessWidget {
  const IntentTargets({
    required this.screenSize,
    required this.threshold,
    required this.zones,
    required this.gestureState,
    required this.icon,
    required this.activeColor,
    required this.label,
    super.key,
  });

  final double threshold;
  final Size screenSize;
  final List<EdgeDropZone> zones;
  final ValueListenable<GestureState> gestureState;
  final IconData icon;
  final Color activeColor;
  final String label;

  @override
  Widget build(final BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Stack(
              children: [
                for (final zone in zones)
                  _EdgeAura(
                    zone: zone,
                    gestureState: gestureState,
                    screenSize: screenSize,
                    threshold: threshold,
                  ),
              ],
            ),
          ),
          IgnorePointer(
            child: Stack(
              children: [
                for (final zone in zones)
                  _PositionedZoneWrapper(
                    zone: zone,
                    screenSize: screenSize,
                    threshold: threshold,
                    gestureState: gestureState,
                    icon: icon,
                    activeColor: activeColor,
                  ),
              ],
            ),
          ),
        ],
      );
}

class _PositionedZoneWrapper extends StatelessWidget {
  const _PositionedZoneWrapper({
    required this.zone,
    required this.screenSize,
    required this.threshold,
    required this.gestureState,
    required this.icon,
    required this.activeColor,
  });

  final EdgeDropZone zone;
  final Size screenSize;
  final double threshold;
  final ValueListenable<GestureState> gestureState;
  final IconData icon;
  final Color activeColor;

  @override
  Widget build(final BuildContext context) {
    final bool isVertical = zone.axis == Axis.vertical;
    final Alignment alignment = zone.alignment;

    return Positioned(
      left: (isVertical && alignment == Alignment.centerLeft) ? 0 : null,
      right: (isVertical && alignment == Alignment.centerRight) ? 0 : null,
      top: (!isVertical && alignment == Alignment.topCenter)
          ? 0
          : (isVertical ? 0 : null),
      bottom: (!isVertical && alignment == Alignment.bottomCenter) ? 0 : null,
      width: isVertical ? threshold : screenSize.width,
      height: isVertical ? screenSize.height : threshold,
      child: _IntentFeedbackZone(
        zone: zone,
        screenSize: screenSize,
        threshold: threshold,
        gestureState: gestureState,
        icon: icon,
        activeColor: activeColor,
      ),
    );
  }
}

class _IntentFeedbackZone extends StatelessWidget {
  const _IntentFeedbackZone({
    required this.zone,
    required this.screenSize,
    required this.threshold,
    required this.gestureState,
    required this.icon,
    required this.activeColor,
  });

  final EdgeDropZone zone;
  final Size screenSize;
  final double threshold;
  final ValueListenable<GestureState> gestureState;
  final IconData icon;
  final Color activeColor;

  @override
  Widget build(final BuildContext context) =>
      ValueListenableBuilder<GestureState>(
        valueListenable: gestureState,
        builder: (final context, final state, final child) {
          final pointerOffset = state.pointerPosition;
          double progress = 0.0;

          if (pointerOffset != null) {
            progress = zone.calculateProgress(
              pointerOffset,
              screenSize,
              1.0 / threshold,
            );
          }

          final bool isHit = pointerOffset != null &&
              zone.isHit(pointerOffset, screenSize, threshold);

          if (pointerOffset == null) {
            return const SizedBox.shrink();
          }

          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          final bool isDark = Theme.of(context).brightness == Brightness.dark;

          final Color baseColor = isHit
              ? activeColor.withValues(alpha: 0.6)
              : colorScheme.onSurface.withValues(alpha: 0.1);

          final double blur = isHit ? 0.0 : (progress * 15.0);
          final double borderRadius = isHit ? 0.0 : 24.0;

          final isVertical = zone.axis == Axis.vertical;
          final alignment = zone.alignment;

          final double handleOpacity = (1.0 - (progress * 5.0)).clamp(0.0, 1.0);
          final double barOpacity = (progress * 5.0).clamp(0.0, 1.0);

          Offset gradientAlignment = Offset.zero;
          final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final local = renderBox.globalToLocal(pointerOffset);
            gradientAlignment = Offset(
              ((local.dx / renderBox.size.width) * 2 - 1).clamp(-1.0, 1.0),
              ((local.dy / renderBox.size.height) * 2 - 1).clamp(-1.0, 1.0),
            );
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Stack(
              alignment: alignment,
              children: [
                if (!isHit)
                  Opacity(
                    opacity: handleOpacity,
                    child: Center(
                      child: _IntentIdleHandle(
                        isVertical: isVertical,
                        alignment: alignment,
                        gradientAlignment: gradientAlignment,
                        icon: icon,
                      ),
                    ),
                  ),
                Opacity(
                  opacity: isHit ? 1.0 : barOpacity,
                  child: ClipRRect(
                    borderRadius: _calculateBorderRadius(
                      alignment,
                      borderRadius,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        width: isVertical
                            ? (threshold * (isHit ? 1.0 : progress))
                            : null,
                        height: !isVertical
                            ? (threshold * (isHit ? 1.0 : progress))
                            : null,
                        decoration: BoxDecoration(
                          color: baseColor,
                          gradient: isHit
                              ? RadialGradient(
                                  center: Alignment(
                                    gradientAlignment.dx,
                                    gradientAlignment.dy,
                                  ),
                                  radius: 1.2,
                                  colors: [
                                    activeColor.withValues(alpha: 0.8),
                                    activeColor.withValues(alpha: 0.5),
                                  ],
                                )
                              : null,
                          border: Border.all(
                            color: colorScheme.onSurface
                                .withValues(alpha: isDark ? 0.2 : 0.1),
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (progress > 0.05)
                  Positioned(
                    left: isVertical
                        ? (alignment == Alignment.centerLeft
                            ? (threshold * progress - 24)
                            : null)
                        : null,
                    right: isVertical
                        ? (alignment == Alignment.centerRight
                            ? (threshold * progress - 24)
                            : null)
                        : null,
                    top: !isVertical
                        ? (alignment == Alignment.topCenter
                            ? (threshold * progress - 24)
                            : null)
                        : null,
                    bottom: !isVertical
                        ? (alignment == Alignment.bottomCenter
                            ? (threshold * progress - 24)
                            : null)
                        : null,
                    child: Transform.translate(
                      offset: Offset(
                        gradientAlignment.dx * 16,
                        gradientAlignment.dy * 16,
                      ),
                      child: Opacity(
                        opacity: (progress * 2).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.5 + (progress * 0.5),
                          child: Icon(
                            icon,
                            color: isHit ? Colors.white : colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  BorderRadius _calculateBorderRadius(
    final Alignment alignment,
    final double radius,
  ) {
    if (radius <= 0) {
      return BorderRadius.zero;
    }

    return BorderRadius.only(
      topLeft: (alignment == Alignment.bottomCenter ||
              alignment == Alignment.centerRight)
          ? Radius.circular(radius)
          : Radius.zero,
      topRight: (alignment == Alignment.bottomCenter ||
              alignment == Alignment.centerLeft)
          ? Radius.circular(radius)
          : Radius.zero,
      bottomLeft: (alignment == Alignment.topCenter ||
              alignment == Alignment.centerRight)
          ? Radius.circular(radius)
          : Radius.zero,
      bottomRight: (alignment == Alignment.topCenter ||
              alignment == Alignment.centerLeft)
          ? Radius.circular(radius)
          : Radius.zero,
    );
  }
}

class _IntentIdleHandle extends StatefulWidget {
  const _IntentIdleHandle({
    required this.isVertical,
    required this.alignment,
    required this.gradientAlignment,
    required this.icon,
  });

  final bool isVertical;
  final Alignment alignment;
  final Offset gradientAlignment;
  final IconData icon;

  @override
  State<_IntentIdleHandle> createState() => _IntentIdleHandleState();
}

class _IntentIdleHandleState extends State<_IntentIdleHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final isVertical = widget.isVertical;
    final alignment = widget.alignment;

    final borderRadius = BorderRadius.only(
      topLeft: (alignment == Alignment.centerRight ||
              alignment == Alignment.bottomCenter)
          ? const Radius.circular(20)
          : Radius.zero,
      topRight: (alignment == Alignment.centerLeft ||
              alignment == Alignment.bottomCenter)
          ? const Radius.circular(20)
          : Radius.zero,
      bottomLeft: (alignment == Alignment.centerRight ||
              alignment == Alignment.topCenter)
          ? const Radius.circular(20)
          : Radius.zero,
      bottomRight: (alignment == Alignment.centerLeft ||
              alignment == Alignment.topCenter)
          ? const Radius.circular(20)
          : Radius.zero,
    );

    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    return FadeTransition(
      opacity: Tween(begin: 0.15, end: 0.4).animate(_pulseController),
      child: Transform.translate(
        offset: Offset(
          widget.gradientAlignment.dx * 10,
          widget.gradientAlignment.dy * 10,
        ),
        child: Container(
          width: isVertical ? 24 : 60,
          height: isVertical ? 60 : 24,
          decoration: BoxDecoration(
            color: colorScheme.onSurface,
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16,
            color: colorScheme.surface,
          ),
        ),
      ),
    );
  }
}

class SnoozeTargets extends StatelessWidget {
  const SnoozeTargets({
    required this.screenSize,
    required this.threshold,
    required this.zones,
    required this.gestureState,
    super.key,
  });

  final double threshold;
  final Size screenSize;
  final List<EdgeDropZone> zones;
  final ValueListenable<GestureState> gestureState;

  @override
  Widget build(final BuildContext context) => IntentTargets(
        screenSize: screenSize,
        threshold: threshold,
        zones: zones,
        gestureState: gestureState,
        icon: Icons.snooze_rounded,
        activeColor: Colors.orange,
        label: 'SNOOZE',
      );
}

class PinTargets extends StatelessWidget {
  const PinTargets({
    required this.screenSize,
    required this.threshold,
    required this.zones,
    required this.gestureState,
    required this.isPinned,
    super.key,
  });

  final double threshold;
  final Size screenSize;
  final List<EdgeDropZone> zones;
  final ValueListenable<GestureState> gestureState;
  final bool isPinned;

  @override
  Widget build(final BuildContext context) => IntentTargets(
        screenSize: screenSize,
        threshold: threshold,
        zones: zones,
        gestureState: gestureState,
        icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        activeColor: Colors.blue,
        label: isPinned ? 'UNPIN' : 'PIN',
      );
}

class CustomActionTargets extends StatelessWidget {
  const CustomActionTargets({
    required this.screenSize,
    required this.threshold,
    required this.zones,
    required this.gestureState,
    required this.actionName,
    super.key,
  });

  final double threshold;
  final Size screenSize;
  final List<EdgeDropZone> zones;
  final ValueListenable<GestureState> gestureState;
  final String actionName;

  @override
  Widget build(final BuildContext context) => IntentTargets(
        screenSize: screenSize,
        threshold: threshold,
        zones: zones,
        gestureState: gestureState,
        icon: Icons.bolt_rounded,
        activeColor: Colors.purple,
        label: actionName.toUpperCase(),
      );
}

class IntentFeedbackOverlay extends StatefulWidget {
  const IntentFeedbackOverlay({
    required this.passedThreshold,
    required this.dragOffset,
    required this.thresholdInPixels,
    required this.screenSize,
    required this.startData,
    required this.zones,
    required this.springPhysics,
    required this.activeColor,
    required this.labelText,
    required this.child,
    this.fsm,
    super.key,
  });

  final bool passedThreshold;
  final Offset? dragOffset;
  final int thresholdInPixels;
  final Size screenSize;
  final DragStartData? startData;
  final List<EdgeDropZone> zones;
  final SpringPhysicsConfiguration springPhysics;
  final Color activeColor;
  final String labelText;
  final Widget child;
  final GestureStateMachine? fsm;

  @override
  State<IntentFeedbackOverlay> createState() => _IntentFeedbackOverlayState();
}

class _IntentFeedbackOverlayState extends State<IntentFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sinkingController;
  double? _lastTargetScale;

  @override
  void initState() {
    super.initState();
    _sinkingController = AnimationController(
      vsync: this,
      lowerBound: 0.5,
      upperBound: 1.5,
    );
    widget.fsm?.addListener(_onFsmChanged);
    _animateToTarget();
  }

  void _onFsmChanged() {
    _animateToTarget();
  }

  @override
  void didUpdateWidget(covariant final IntentFeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fsm != widget.fsm) {
      oldWidget.fsm?.removeListener(_onFsmChanged);
      widget.fsm?.addListener(_onFsmChanged);
    }
    if (oldWidget.passedThreshold != widget.passedThreshold ||
        oldWidget.fsm != widget.fsm) {
      _animateToTarget();
    }
  }

  void _animateToTarget() {
    final double defaultTarget = widget.passedThreshold ? 0.85 : 1.0;
    final double targetScale = widget.fsm?.getActiveScale(1.0) ?? defaultTarget;
    if (_lastTargetScale == targetScale) {
      return;
    }
    _lastTargetScale = targetScale;

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
    widget.fsm?.removeListener(_onFsmChanged);
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
    final startData = widget.startData;
    if (widget.dragOffset != null && startData != null) {
      correction = _calculateMagnetCorrection(
        dragOffset: widget.dragOffset!,
        startData: startData,
        lockedZone: lockedZone,
      );
    }

    final double opacity = 1.0 - (proximityProgress * 0.5);
    final double baseScale = 1.0 - (proximityProgress * 0.08);
    final double sinkingBlur = widget.passedThreshold ? 4.0 : 0.0;

    final themeData = Theme.of(context);

    final cardContent = ColorFiltered(
      colorFilter: widget.passedThreshold
          ? ColorFilter.mode(
              widget.activeColor.withValues(alpha: 0.15),
              BlendMode.color,
            )
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
                                color: themeData.colorScheme.surface.withValues(
                                  alpha: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: widget.activeColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.activeColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.labelText,
                                style: TextStyle(
                                  color: widget.activeColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.8,
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

class SnoozeFeedbackOverlay extends StatelessWidget {
  const SnoozeFeedbackOverlay({
    required this.passedThreshold,
    required this.dragOffset,
    required this.thresholdInPixels,
    required this.screenSize,
    required this.startData,
    required this.zones,
    required this.springPhysics,
    required this.child,
    this.fsm,
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
  final GestureStateMachine? fsm;

  @override
  Widget build(final BuildContext context) => IntentFeedbackOverlay(
        passedThreshold: passedThreshold,
        dragOffset: dragOffset,
        thresholdInPixels: thresholdInPixels,
        screenSize: screenSize,
        startData: startData,
        zones: zones,
        springPhysics: springPhysics,
        activeColor: Colors.orange,
        labelText: 'RELEASE TO SNOOZE',
        fsm: fsm,
        child: child,
      );
}

class PinFeedbackOverlay extends StatelessWidget {
  const PinFeedbackOverlay({
    required this.passedThreshold,
    required this.dragOffset,
    required this.thresholdInPixels,
    required this.screenSize,
    required this.startData,
    required this.zones,
    required this.springPhysics,
    required this.isPinned,
    required this.child,
    this.fsm,
    super.key,
  });

  final bool passedThreshold;
  final Offset? dragOffset;
  final int thresholdInPixels;
  final Size screenSize;
  final DragStartData? startData;
  final List<EdgeDropZone> zones;
  final SpringPhysicsConfiguration springPhysics;
  final bool isPinned;
  final Widget child;
  final GestureStateMachine? fsm;

  @override
  Widget build(final BuildContext context) => IntentFeedbackOverlay(
        passedThreshold: passedThreshold,
        dragOffset: dragOffset,
        thresholdInPixels: thresholdInPixels,
        screenSize: screenSize,
        startData: startData,
        zones: zones,
        springPhysics: springPhysics,
        activeColor: Colors.blue,
        labelText: isPinned ? 'RELEASE TO UNPIN' : 'RELEASE TO PIN',
        fsm: fsm,
        child: child,
      );
}

class CustomActionFeedbackOverlay extends StatelessWidget {
  const CustomActionFeedbackOverlay({
    required this.passedThreshold,
    required this.dragOffset,
    required this.thresholdInPixels,
    required this.screenSize,
    required this.startData,
    required this.zones,
    required this.springPhysics,
    required this.actionName,
    required this.child,
    this.fsm,
    super.key,
  });

  final bool passedThreshold;
  final Offset? dragOffset;
  final int thresholdInPixels;
  final Size screenSize;
  final DragStartData? startData;
  final List<EdgeDropZone> zones;
  final SpringPhysicsConfiguration springPhysics;
  final String actionName;
  final Widget child;
  final GestureStateMachine? fsm;

  @override
  Widget build(final BuildContext context) => IntentFeedbackOverlay(
        passedThreshold: passedThreshold,
        dragOffset: dragOffset,
        thresholdInPixels: thresholdInPixels,
        screenSize: screenSize,
        startData: startData,
        zones: zones,
        springPhysics: springPhysics,
        activeColor: Colors.purple,
        labelText: 'RELEASE TO ${actionName.toUpperCase()}',
        fsm: fsm,
        child: child,
      );
}
