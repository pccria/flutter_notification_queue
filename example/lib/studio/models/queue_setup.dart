import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart'
    show BorderRadius, EdgeInsets, EdgeInsetsGeometry;
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

/// The count calculation and formatting strategy to apply to grouped bundles.
enum GroupCountType {
  /// Displays `+N` representing the additional hidden cards stacked behind
  /// the visible representative card (e.g. `+2`).
  hiddenCount(
    'Hidden Count (+N)',
    '+N (cards hidden behind representative)',
  ),

  /// Displays `N` representing the total volume of bundled items,
  /// including the representative card (e.g. `3`).
  totalCount(
    'Total Count (N)',
    'N (total items in the group bundle)',
  ),

  /// Suppresses the numerical count, rendering only the title/preview
  /// or action label.
  noCount(
    'No Count',
    'Suppresses numerical count',
  );

  const GroupCountType(this.label, this.description);
  final String label;
  final String description;
}

/// The directional egress options available for dismiss gestures in NFQ Studio.
enum DismissEgressOption {
  horizontal(
    'Horizontal (Left / Right)',
    'Universal mobile & desktop swipe left or right.',
  ),
  natural(
    'Natural (Relative to Queue)',
    'Contextual egress: Up for top queues, Down for bottom queues.',
  ),
  outward(
    'Outward (Toward Display Edge)',
    'Only allows swiping outward toward the closest display bezel.',
  ),
  cross(
    'Cross (Vertical Egress + Horizontal)',
    'Android heads-up HUD style: swiping up/down or sideways dismisses.',
  ),
  any(
    'Any Direction (Omnidirectional)',
    'Fling or drag in any direction away from the card origin.',
  );

  const DismissEgressOption(this.label, this.description);
  final String label;
  final String description;

  DismissEgress toEgress() => switch (this) {
        horizontal => const DismissEgress.horizontal(),
        natural => const DismissEgress.natural(),
        outward => const DismissEgress.outward(),
        cross => const DismissEgress.cross(),
        any => const DismissEgress.any(),
      };
}

/// The immutable setup for a single [NotificationQueue].
///
/// Does **not** include `position` — that's the map key in `StudioSetup`.
/// Extends [Equatable] for free change detection.
class QueueSetup extends Equatable {
  const QueueSetup({
    this.styleType = FilledQueueStyle,
    this.opacity = 0.7,
    this.elevation = 3.0,
    this.borderRadius = 8.0,
    this.padding,
    this.borderWidth,
    this.transitionType = SlideTransitionStrategy,
    this.maxStackSize = 3,
    this.spacing = 4.0,
    this.verticalMargin = 8.0,
    this.horizontalMargin = 36.0,
    this.dragBehaviorType = Dismiss,
    this.dragDismissEgress = DismissEgressOption.horizontal,
    this.dragDismissThreshold = 0.40,
    this.dragEscapeVelocity = 600.0,
    this.dragDismissEnableTilt = true,
    this.dragDismissShowUnderlay = true,
    this.dragDismissZone,
    this.dragSnoozeSeconds = 5,
    this.longPressBehaviorType = Disabled,
    this.longPressDismissEgress = DismissEgressOption.horizontal,
    this.longPressDismissThreshold = 0.40,
    this.longPressEscapeVelocity = 600.0,
    this.longPressDismissEnableTilt = true,
    this.longPressDismissShowUnderlay = true,
    this.longPressDismissZone,
    this.longPressSnoozeSeconds = 5,
    this.relocateTargets = const {},
    this.relocatePermanent = false,
    this.closeButtonBehaviorType = AlwaysVisible,
    this.tapBehaviorType = TapToDismiss,
    this.maxWidth,
    this.groupingEnabled = false,
    this.groupingThreshold = 2,
    this.groupingCountType = GroupCountType.hiddenCount,
    this.groupingCountMaxCount = 9,
    this.groupingCountIncludePending = true,
    this.groupingMaxLayers = 2,
    this.groupingSwipeDismiss = false,
  });

  // ── Style ──
  final Type styleType;
  final double opacity;
  final double elevation;
  final double borderRadius;
  final double? padding;
  final double? borderWidth;

  // ── Animation ──
  final Type transitionType;

  // ── Stack ──
  final int maxStackSize;
  final double spacing;
  final double verticalMargin;
  final double horizontalMargin;
  final double? maxWidth;

  // ── Gestures ──
  final Type dragBehaviorType;
  final DismissEgressOption dragDismissEgress;
  final double dragDismissThreshold;
  final double dragEscapeVelocity;
  final bool dragDismissEnableTilt;
  final bool dragDismissShowUnderlay;
  final DismissZone? dragDismissZone;
  final int dragSnoozeSeconds;
  final Type longPressBehaviorType;
  final DismissEgressOption longPressDismissEgress;
  final double longPressDismissThreshold;
  final double longPressEscapeVelocity;
  final bool longPressDismissEnableTilt;
  final bool longPressDismissShowUnderlay;
  final DismissZone? longPressDismissZone;
  final int longPressSnoozeSeconds;
  final Set<QueuePosition> relocateTargets;
  final bool relocatePermanent;
  final Type closeButtonBehaviorType;

  // ── Tap ──
  final Type tapBehaviorType;

  // ── Grouping ──
  final bool groupingEnabled;
  final int groupingThreshold;
  final GroupCountType groupingCountType;
  final int groupingCountMaxCount;
  final bool groupingCountIncludePending;
  final int groupingMaxLayers;
  final bool groupingSwipeDismiss;

  /// Whether this queue is in an invalid relocation state (Relocate behavior
  /// selected but no targets chosen). Empty targets cause library crashes.
  bool get hasRelocationError =>
      (dragBehaviorType == Relocate ||
          longPressBehaviorType == Relocate ||
          dragBehaviorType == ReorderAndRelocate ||
          longPressBehaviorType == ReorderAndRelocate) &&
      relocateTargets.isEmpty;

  QueueSetup copyWith({
    final Type? styleType,
    final double? opacity,
    final double? elevation,
    final double? borderRadius,
    final double? padding,
    final bool clearPadding = false,
    final double? borderWidth,
    final bool clearBorderWidth = false,
    final Type? transitionType,
    final int? maxStackSize,
    final double? spacing,
    final double? verticalMargin,
    final double? horizontalMargin,
    final Type? dragBehaviorType,
    final DismissEgressOption? dragDismissEgress,
    final double? dragDismissThreshold,
    final double? dragEscapeVelocity,
    final bool? dragDismissEnableTilt,
    final bool? dragDismissShowUnderlay,
    final DismissZone? dragDismissZone,
    final bool clearDragDismissZone = false,
    final int? dragSnoozeSeconds,
    final Type? longPressBehaviorType,
    final DismissEgressOption? longPressDismissEgress,
    final double? longPressDismissThreshold,
    final double? longPressEscapeVelocity,
    final bool? longPressDismissEnableTilt,
    final bool? longPressDismissShowUnderlay,
    final DismissZone? longPressDismissZone,
    final bool clearLongPressDismissZone = false,
    final int? longPressSnoozeSeconds,
    final Set<QueuePosition>? relocateTargets,
    final bool? relocatePermanent,
    final Type? closeButtonBehaviorType,
    final Type? tapBehaviorType,
    final double? maxWidth,
    final bool clearMaxWidth = false,
    final bool? groupingEnabled,
    final int? groupingThreshold,
    final GroupCountType? groupingCountType,
    final int? groupingCountMaxCount,
    final bool? groupingCountIncludePending,
    final int? groupingMaxLayers,
    final bool? groupingSwipeDismiss,
  }) =>
      QueueSetup(
        styleType: styleType ?? this.styleType,
        opacity: opacity ?? this.opacity,
        elevation: elevation ?? this.elevation,
        borderRadius: borderRadius ?? this.borderRadius,
        padding: clearPadding ? null : (padding ?? this.padding),
        borderWidth:
            clearBorderWidth ? null : (borderWidth ?? this.borderWidth),
        transitionType: transitionType ?? this.transitionType,
        maxStackSize: maxStackSize ?? this.maxStackSize,
        spacing: spacing ?? this.spacing,
        verticalMargin: verticalMargin ?? this.verticalMargin,
        horizontalMargin: horizontalMargin ?? this.horizontalMargin,
        dragBehaviorType: dragBehaviorType ?? this.dragBehaviorType,
        dragDismissEgress: dragDismissEgress ?? this.dragDismissEgress,
        dragDismissThreshold: dragDismissThreshold ?? this.dragDismissThreshold,
        dragEscapeVelocity: dragEscapeVelocity ?? this.dragEscapeVelocity,
        dragDismissEnableTilt:
            dragDismissEnableTilt ?? this.dragDismissEnableTilt,
        dragDismissShowUnderlay:
            dragDismissShowUnderlay ?? this.dragDismissShowUnderlay,
        dragDismissZone: clearDragDismissZone
            ? null
            : (dragDismissZone ?? this.dragDismissZone),
        dragSnoozeSeconds: dragSnoozeSeconds ?? this.dragSnoozeSeconds,
        longPressBehaviorType:
            longPressBehaviorType ?? this.longPressBehaviorType,
        longPressDismissEgress:
            longPressDismissEgress ?? this.longPressDismissEgress,
        longPressDismissThreshold:
            longPressDismissThreshold ?? this.longPressDismissThreshold,
        longPressEscapeVelocity:
            longPressEscapeVelocity ?? this.longPressEscapeVelocity,
        longPressDismissEnableTilt:
            longPressDismissEnableTilt ?? this.longPressDismissEnableTilt,
        longPressDismissShowUnderlay:
            longPressDismissShowUnderlay ?? this.longPressDismissShowUnderlay,
        longPressDismissZone: clearLongPressDismissZone
            ? null
            : (longPressDismissZone ?? this.longPressDismissZone),
        longPressSnoozeSeconds:
            longPressSnoozeSeconds ?? this.longPressSnoozeSeconds,
        relocateTargets: relocateTargets ?? this.relocateTargets,
        relocatePermanent: relocatePermanent ?? this.relocatePermanent,
        closeButtonBehaviorType:
            closeButtonBehaviorType ?? this.closeButtonBehaviorType,
        tapBehaviorType: tapBehaviorType ?? this.tapBehaviorType,
        maxWidth: clearMaxWidth ? null : (maxWidth ?? this.maxWidth),
        groupingEnabled: groupingEnabled ?? this.groupingEnabled,
        groupingThreshold: groupingThreshold ?? this.groupingThreshold,
        groupingCountType: groupingCountType ?? this.groupingCountType,
        groupingCountMaxCount:
            groupingCountMaxCount ?? this.groupingCountMaxCount,
        groupingCountIncludePending:
            groupingCountIncludePending ?? this.groupingCountIncludePending,
        groupingMaxLayers: groupingMaxLayers ?? this.groupingMaxLayers,
        groupingSwipeDismiss: groupingSwipeDismiss ?? this.groupingSwipeDismiss,
      );

  // ── Library Mapping Helpers ──

  EdgeInsetsGeometry? get _padding =>
      padding != null ? EdgeInsets.all(padding!) : null;

  /// Builds the [QueueStyle] for this setup.
  QueueStyle toQueueStyle() {
    if (styleType == FlatQueueStyle) {
      return FlatQueueStyle(
        opacity: opacity,
        elevation: elevation,
        borderRadius: _borderRadius,
        padding: _padding,
        borderWidth: borderWidth ?? 4.0,
      );
    }
    if (styleType == OutlinedQueueStyle) {
      return OutlinedQueueStyle(
        opacity: opacity,
        elevation: elevation,
        borderRadius: _borderRadius,
        padding: _padding,
        borderWidth: borderWidth ?? 1.0,
      );
    }
    return FilledQueueStyle(
      opacity: opacity,
      elevation: elevation,
      borderRadius: _borderRadius,
      padding: _padding,
      borderWidth: borderWidth ?? 1.0,
    );
  }

  /// Builds the [NotificationTransition] for this setup.
  NotificationTransition toTransition() {
    if (transitionType == FadeTransitionStrategy) {
      return const FadeTransitionStrategy();
    }
    if (transitionType == ScaleTransitionStrategy) {
      return const ScaleTransitionStrategy();
    }
    return const SlideTransitionStrategy();
  }

  /// Builds the [DragBehavior] from [dragBehaviorType].
  DragBehavior toDragBehavior(final QueuePosition position) {
    if (dragBehaviorType == Dismiss) {
      if (dragDismissZone != null) {
        return Dismiss(zones: dragDismissZone);
      }
      return Dismiss(
        egress: dragDismissEgress.toEgress(),
        dismissThreshold: dragDismissThreshold,
        escapeVelocity: dragEscapeVelocity,
        enableTilt: dragDismissEnableTilt,
        showUnderlay: dragDismissShowUnderlay,
      );
    }
    if (dragBehaviorType == Snooze) {
      return Snooze(duration: Duration(seconds: dragSnoozeSeconds));
    }
    if (dragBehaviorType == Pin) {
      return const Pin();
    }
    if (dragBehaviorType == Relocate) {
      return relocateTargets.isEmpty
          ? const Disabled()
          : Relocate.to(relocateTargets, permanent: relocatePermanent);
    }
    if (dragBehaviorType == ReorderAndRelocate) {
      return relocateTargets.isEmpty
          ? const Disabled()
          : ReorderAndRelocate.to(
              positions: relocateTargets,
              permanent: relocatePermanent,
            );
    }
    if (dragBehaviorType == Reorder) {
      return const Reorder();
    }
    return const Disabled();
  }

  /// Builds the [LongPressDragBehavior] from [longPressBehaviorType].
  LongPressDragBehavior toLongPressBehavior(final QueuePosition position) {
    if (longPressBehaviorType == Dismiss) {
      if (longPressDismissZone != null) {
        return Dismiss(zones: longPressDismissZone);
      }
      return Dismiss(
        egress: longPressDismissEgress.toEgress(),
        dismissThreshold: longPressDismissThreshold,
        escapeVelocity: longPressEscapeVelocity,
        enableTilt: longPressDismissEnableTilt,
        showUnderlay: longPressDismissShowUnderlay,
      );
    }
    if (longPressBehaviorType == Snooze) {
      return Snooze(duration: Duration(seconds: longPressSnoozeSeconds));
    }
    if (longPressBehaviorType == Pin) {
      return const Pin();
    }
    if (longPressBehaviorType == Relocate) {
      return relocateTargets.isEmpty
          ? const Disabled()
          : Relocate.to(relocateTargets, permanent: relocatePermanent);
    }
    if (longPressBehaviorType == ReorderAndRelocate) {
      return relocateTargets.isEmpty
          ? const Disabled()
          : ReorderAndRelocate.to(
              positions: relocateTargets,
              permanent: relocatePermanent,
            );
    }
    if (longPressBehaviorType == Reorder) {
      return const Reorder();
    }
    return const Disabled();
  }

  /// Builds the [QueueCloseButtonBehavior].
  QueueCloseButtonBehavior toCloseButtonBehavior() {
    if (closeButtonBehaviorType == VisibleOnHover) {
      return const VisibleOnHover();
    }
    if (closeButtonBehaviorType == Hidden) {
      return const Hidden();
    }
    return const AlwaysVisible();
  }

  /// Builds the [TapBehavior] from [tapBehaviorType].
  TapBehavior toTapBehavior() {
    if (tapBehaviorType == TapToExpand) {
      return const TapToExpand();
    }
    if (tapBehaviorType == TapToAct) {
      return TapToAct(
        onTap: () => debugPrint('[Studio] TapToAct fired'),
      );
    }
    if (tapBehaviorType == TapDisabled) {
      return const TapDisabled();
    }
    return const TapToDismiss();
  }

  /// Builds a [NotificationQueue] at the given [position].
  NotificationQueue toNotificationQueue(final QueuePosition position) =>
      NotificationQueue(
        position: position,
        style: toQueueStyle(),
        transition: toTransition(),
        maxStackSize: maxStackSize,
        spacing: spacing,
        margin: EdgeInsets.symmetric(
          vertical: verticalMargin,
          horizontal: horizontalMargin,
        ),
        dragBehavior: toDragBehavior(position),
        longPressDragBehavior: toLongPressBehavior(position),
        closeButtonBehavior: toCloseButtonBehavior(),
        tapBehavior: toTapBehavior(),
        maxWidth: maxWidth,
        groupingBehavior: QueueGroupingBehavior(
          enabled: groupingEnabled,
          maxBeforeGrouping: groupingThreshold,
          maxStackedLayers: groupingMaxLayers,
          enableGroupSwipeDismiss: groupingSwipeDismiss,
          countBehavior: switch (groupingCountType) {
            GroupCountType.hiddenCount => HiddenCount(
                maxCount: groupingCountMaxCount,
                includePending: groupingCountIncludePending,
              ),
            GroupCountType.totalCount => TotalCount(
                maxCount: groupingCountMaxCount,
                includePending: groupingCountIncludePending,
              ),
            GroupCountType.noCount => const NoCount(),
          },
        ),
      );

  BorderRadius get _borderRadius => BorderRadius.circular(borderRadius);

  @override
  List<Object?> get props => [
        styleType,
        opacity,
        elevation,
        borderRadius,
        padding,
        borderWidth,
        transitionType,
        maxStackSize,
        spacing,
        verticalMargin,
        horizontalMargin,
        dragBehaviorType,
        dragDismissEgress,
        dragDismissThreshold,
        dragEscapeVelocity,
        dragDismissEnableTilt,
        dragDismissShowUnderlay,
        dragDismissZone,
        dragSnoozeSeconds,
        longPressBehaviorType,
        longPressDismissEgress,
        longPressDismissThreshold,
        longPressEscapeVelocity,
        longPressDismissEnableTilt,
        longPressDismissShowUnderlay,
        longPressDismissZone,
        longPressSnoozeSeconds,
        relocateTargets,
        relocatePermanent,
        closeButtonBehaviorType,
        tapBehaviorType,
        maxWidth,
        groupingEnabled,
        groupingThreshold,
        groupingCountType,
        groupingCountMaxCount,
        groupingCountIncludePending,
        groupingMaxLayers,
        groupingSwipeDismiss,
      ];
}
