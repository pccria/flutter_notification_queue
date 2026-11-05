import 'package:flutter/foundation.dart';
import 'group_count_behavior.dart';

export 'group_count_behavior.dart';

/// Configuration for aggregating notifications into stacked group bundles.
///
/// When multiple notifications share the same channel or explicit `groupKey`,
/// [QueueGroupingBehavior] consolidates them into a single visual bundle once
/// the count reaches [maxBeforeGrouping].
///
/// Key capabilities:
/// - **Configurable Count Representation**: Uses [GroupCountBehavior] to
///   control whether the group count displays `+N` hidden items
///   ([HiddenCount]), total items `N` ([TotalCount]), a minimal dot
///   ([NoCount]), or a custom label ([CustomCount]).
/// - **Peek Card Timer Stasis**: Lifting or dragging the representative card
///   reveals the peek card beneath with stasis opacity, automatically pausing
///   both cards' auto-dismiss timers during touch interaction.
/// - **Expanded View Suspension**: Pauses timers on all cards when expanded
///   into multi-card view via [pauseTimersWhenExpanded].
/// - **Atomic Bundle Dismissal**: Swiping the bundle or invoking
///   `NotificationController.dismissGroup` purges active members and pending
///   backlog items sharing the key in a single frame.
@immutable
class QueueGroupingBehavior {
  /// Creates a configuration for notification grouping.
  const QueueGroupingBehavior({
    this.enabled = false,
    this.maxBeforeGrouping = 2,
    this.maxStackedLayers = 2,
    this.stackStepOffset = 6.0,
    this.stackScaleMultiplier = 0.05,
    this.enableGroupSwipeDismiss = false,
    this.groupDismissThreshold = 0.4,
    this.pauseTimersWhenExpanded = true,
    this.countBehavior = const HiddenCount(),
  });

  /// Whether notification grouping is enabled for this queue.
  final bool enabled;

  /// Minimum number of notifications sharing the same group key before they
  /// collapse into a single visual bundle.
  final int maxBeforeGrouping;

  /// Maximum number of stacked peek layers rendered behind the representative
  /// card to convey bundle depth.
  final int maxStackedLayers;

  /// Pixel displacement offset between each stacked peek card layer.
  final double stackStepOffset;

  /// Scale reduction factor applied sequentially to each stacked peek card
  /// layer behind the representative card.
  final double stackScaleMultiplier;

  /// Whether swiping the collapsed representative card dismisses the entire
  /// group and purges its pending backlog items.
  final bool enableGroupSwipeDismiss;

  /// Drag distance threshold (fraction of card width) required to trigger
  /// group swipe dismissal.
  final double groupDismissThreshold;

  /// Whether auto-dismiss countdown timers for all cards in the group are
  /// suspended while the bundle is expanded in multi-card view.
  final bool pauseTimersWhenExpanded;

  /// The counting and formatting strategy for group bundle volume
  /// (e.g. [HiddenCount], [TotalCount], [NoCount], or [CustomCount]).
  final GroupCountBehavior countBehavior;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is QueueGroupingBehavior &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          maxBeforeGrouping == other.maxBeforeGrouping &&
          maxStackedLayers == other.maxStackedLayers &&
          stackStepOffset == other.stackStepOffset &&
          stackScaleMultiplier == other.stackScaleMultiplier &&
          enableGroupSwipeDismiss == other.enableGroupSwipeDismiss &&
          groupDismissThreshold == other.groupDismissThreshold &&
          pauseTimersWhenExpanded == other.pauseTimersWhenExpanded &&
          countBehavior == other.countBehavior;

  @override
  int get hashCode => Object.hash(
        enabled,
        maxBeforeGrouping,
        maxStackedLayers,
        stackStepOffset,
        stackScaleMultiplier,
        enableGroupSwipeDismiss,
        groupDismissThreshold,
        pauseTimersWhenExpanded,
        countBehavior,
      );
}
