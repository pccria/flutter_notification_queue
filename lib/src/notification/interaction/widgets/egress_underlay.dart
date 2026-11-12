part of 'widgets.dart';

/// Renders a behind-the-card reveal channel inside the queue slot while the
/// notification is being actively dragged.
@internal
class EgressUnderlay extends StatelessWidget {
  const EgressUnderlay({
    required this.gestureState,
    required this.behavior,
    required this.position,
    this.cardSize,
    super.key,
  });

  /// Reactive gesture state driving underlay progress.
  final ValueListenable<GestureState> gestureState;

  /// The dismiss behavior governing visual style and thresholds.
  final Dismiss behavior;

  /// The anchor position of the parent queue.
  final QueuePosition position;

  /// The dimensions of the card being dragged.
  final Size? cardSize;

  @override
  Widget build(final BuildContext context) =>
      ValueListenableBuilder<GestureState>(
        valueListenable: gestureState,
        builder: (final context, final state, final _) {
          if (!behavior.showUnderlay) {
            return const SizedBox.shrink();
          }

          double progress = 0.0;
          Offset relativeOffset = Offset.zero;
          bool passedThreshold = false;

          if (state is GestureDismissing) {
            progress = state.progress;
            relativeOffset = state.relativeDisplacement;
            passedThreshold = state.passedThreshold;
          }

          if (progress <= 0.05 && relativeOffset.distance < 10) {
            return const SizedBox.shrink();
          }

          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final dismissColor = behavior.dismissColor ?? colorScheme.error;

          final isHorizontal =
              relativeOffset.dx.abs() >= relativeOffset.dy.abs();
          final Alignment glyphAlignment;
          if (isHorizontal) {
            glyphAlignment = relativeOffset.dx > 0
                ? Alignment.centerLeft
                : Alignment.centerRight;
          } else {
            glyphAlignment = relativeOffset.dy > 0
                ? Alignment.topCenter
                : Alignment.bottomCenter;
          }

          final double glyphScale =
              passedThreshold ? 1.15 : (0.4 + (progress.clamp(0.0, 1.0) * 0.6));
          final double bgAlpha =
              passedThreshold ? 0.20 : (progress.clamp(0.0, 1.0) * 0.12);

          return Container(
            width: cardSize?.width,
            height: cardSize?.height,
            alignment: glyphAlignment,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: dismissColor.withValues(alpha: bgAlpha),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dismissColor.withValues(
                  alpha: passedThreshold
                      ? 0.40
                      : (progress * 0.20).clamp(0.0, 0.20),
                ),
                width: 1.0,
              ),
            ),
            child: Transform.scale(
              scale: glyphScale,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: passedThreshold
                      ? dismissColor
                      : colorScheme.onSurfaceVariant,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: passedThreshold
                        ? dismissColor
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  child:
                      behavior.dismissIcon ?? const Icon(Icons.close_rounded),
                ),
              ),
            ),
          );
        },
      );
}
