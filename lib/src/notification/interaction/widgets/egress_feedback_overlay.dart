part of 'widgets.dart';

/// Renders card-centric visual feedback during directional dismiss gestures,
/// applying dynamic angular tilt, progressive opacity falloff, scale
/// reduction, and viscous resistance along non-egress axes.
@internal
class EgressFeedbackOverlay extends StatelessWidget {
  const EgressFeedbackOverlay({
    required this.gestureState,
    required this.behavior,
    required this.position,
    required this.child,
    this.startData,
    super.key,
  });

  /// The active gesture state machine stream.
  final ValueListenable<GestureState> gestureState;

  /// The dismiss behavior governing egress trajectories and physics.
  final Dismiss behavior;

  /// The anchor position of the parent queue.
  final QueuePosition position;

  /// Drag start metadata including initial pointer and widget bounds.
  final DragStartData? startData;

  /// The notification card child.
  final Widget child;

  @override
  Widget build(final BuildContext context) =>
      ValueListenableBuilder<GestureState>(
        valueListenable: gestureState,
        builder: (final context, final state, final _) {
          double progress = 0.0;
          Offset relativeOffset = Offset.zero;
          bool passedThreshold = false;

          if (state is GestureDismissing) {
            progress = state.progress;
            relativeOffset = state.relativeDisplacement;
            passedThreshold = state.passedThreshold;
          }

          final egress = behavior.effectiveEgress;
          final dampedOffset =
              egress.applyViscousDamping(relativeOffset, position);
          final deltaCorrection = dampedOffset - relativeOffset;

          final cardSize = startData?.widgetSize ??
              (context.findRenderObject() as RenderBox?)?.size ??
              const Size(320.0, 80.0);
          final cardWidth = cardSize.width > 0 ? cardSize.width : 320.0;

          // 1. Dynamic Angular Tilt (Swerve Physics)
          final double tiltAngle;
          if (behavior.enableTilt && cardWidth > 0) {
            final normalizedDx = (dampedOffset.dx / cardWidth).clamp(-1.0, 1.0);
            // +/- 10 degrees maximum tilt
            tiltAngle = normalizedDx * (10.0 * pi / 180.0);
          } else {
            tiltAngle = 0.0;
          }

          // 2. Progressive Opacity Falloff (1.0 -> 0.65)
          final double opacity =
              (1.0 - (progress.clamp(0.0, 1.0) * 0.35)).clamp(0.20, 1.0);

          // 3. Progressive Scale Reduction (1.0 -> 0.95)
          final double scale =
              (1.0 - (progress.clamp(0.0, 1.0) * 0.05)).clamp(0.90, 1.0);

          return Transform.translate(
            offset: deltaCorrection,
            child: Transform.rotate(
              angle: tiltAngle,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: passedThreshold
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (behavior.dismissColor ??
                                        Theme.of(context).colorScheme.error)
                                    .withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          )
                        : null,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      );
}
