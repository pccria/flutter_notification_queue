part of 'widgets.dart';

/// Ephemeral flight animation that coasts the dismissed notification card
/// off-screen along its release trajectory, preserving velocity and momentum.
@internal
class EgressFlightOverlay extends StatefulWidget {
  const EgressFlightOverlay({
    required this.startOffset,
    required this.velocity,
    required this.cardSize,
    required this.position,
    required this.behavior,
    required this.child,
    required this.onComplete,
    super.key,
  });

  /// The global position of the top-left of the card at the instant of release.
  final Offset startOffset;

  /// The release velocity vector of the gesture.
  final Velocity velocity;

  /// The physical dimensions of the card.
  final Size cardSize;

  /// The anchor position of the parent queue.
  final QueuePosition position;

  /// The dismiss behavior governing egress and tilt.
  final Dismiss behavior;

  /// The notification card widget being flung.
  final Widget child;

  /// Callback invoked when the flight animation completes and the card is
  /// fully off-screen.
  final VoidCallback onComplete;

  @override
  State<EgressFlightOverlay> createState() => _EgressFlightOverlayState();
}

class _EgressFlightOverlayState extends State<EgressFlightOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    final vel = widget.velocity.pixelsPerSecond;
    final cardW = widget.cardSize.width > 0 ? widget.cardSize.width : 320.0;
    final cardH = widget.cardSize.height > 0 ? widget.cardSize.height : 80.0;

    // Determine primary exit direction
    final bool isHorizontal = vel.dx.abs() >= vel.dy.abs();
    final bool exitPositive = isHorizontal ? vel.dx >= 0 : vel.dy >= 0;

    // Approximate screen bounds
    final flutterView = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = flutterView.physicalSize / flutterView.devicePixelRatio;

    final Offset targetOffset;
    final double remainingDistance;

    if (isHorizontal) {
      if (exitPositive) {
        remainingDistance = (screenSize.width - widget.startOffset.dx) + 80.0;
        targetOffset = Offset(
          screenSize.width + cardW + 40.0,
          widget.startOffset.dy + (vel.dy * 0.15),
        );
      } else {
        remainingDistance = widget.startOffset.dx + cardW + 80.0;
        targetOffset = Offset(
          -cardW - 40.0,
          widget.startOffset.dy + (vel.dy * 0.15),
        );
      }
    } else {
      if (exitPositive) {
        remainingDistance = (screenSize.height - widget.startOffset.dy) + 80.0;
        targetOffset = Offset(
          widget.startOffset.dx + (vel.dx * 0.15),
          screenSize.height + cardH + 40.0,
        );
      } else {
        remainingDistance = widget.startOffset.dy + cardH + 80.0;
        targetOffset = Offset(
          widget.startOffset.dx + (vel.dx * 0.15),
          -cardH - 40.0,
        );
      }
    }

    final speed = max(vel.distance, 800.0);
    final calculatedDurationMs =
        ((remainingDistance / speed) * 1000).clamp(120.0, 180.0).toInt();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: calculatedDurationMs),
    );

    _offsetAnimation = Tween<Offset>(
      begin: widget.startOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInQuad),
    );

    _opacityAnimation = Tween<double>(
      begin: 0.70,
      end: 0.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    final double initialTilt;
    if (widget.behavior.enableTilt && cardW > 0) {
      final normalizedDx =
          ((targetOffset.dx - widget.startOffset.dx) / cardW).clamp(-1.0, 1.0);
      initialTilt = normalizedDx * (10.0 * pi / 180.0);
    } else {
      initialTilt = 0.0;
    }

    _rotationAnimation = Tween<double>(
      begin: initialTilt,
      end: initialTilt * 1.3,
    ).animate(_controller);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 0.88,
    ).animate(_controller);

    _controller.forward().then((final _) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (final context, final _) => Positioned(
          left: _offsetAnimation.value.dx,
          top: _offsetAnimation.value.dy,
          width: widget.cardSize.width,
          height: widget.cardSize.height,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      );
}
