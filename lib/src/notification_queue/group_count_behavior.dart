import 'package:flutter/foundation.dart';

/// Defines the counting and formatting strategy for grouped notification
/// bundles.
///
/// In grouped notifications, the toggle pill displays a count label indicating
/// the volume of notifications bundled together. This sealed hierarchy allows
/// configuring whether the count reflects:
/// - [HiddenCount] — `+N` representing the additional hidden cards
///   behind the visible representative card (default, e.g. `+2`).
/// - [TotalCount] — `N` representing the total number of notifications
///   in the bundle (e.g. `3`).
/// - [CustomCount] — developer-provided formatting callback.
/// - [NoCount] — suppresses the numerical count label entirely.
///
/// Both [HiddenCount] and [TotalCount] support capping large counts via
/// [maxCount] (e.g. formatting as `+99+` or `99+`) and determining whether
/// un-rendered backlog items in the pending queue are counted via
/// [includePending].
@immutable
sealed class GroupCountBehavior {
  /// Creates a group count behavior configuration.
  const GroupCountBehavior({
    this.maxCount = 99,
    this.includePending = true,
  });

  /// The maximum count displayed before truncation with an overflow indicator.
  ///
  /// For example, with `maxCount = 99`, an item count of `150` displays as
  /// `+99+` for [HiddenCount] or `99+` for [TotalCount].
  final int maxCount;

  /// Whether to include un-rendered pending notifications waiting in the
  /// queue backlog that share this group key, in addition to active visible
  /// cards.
  ///
  /// When `true` (default), the count reflects the total volume of messages
  /// in the group, including items awaiting free slots in the queue.
  /// When `false`, the count considers only active cards in the stack.
  final bool includePending;

  /// Returns the formatted count label for the bundle, or `null` if no count
  /// label should be rendered.
  String? format({
    required final int totalCount,
    required final int hiddenCount,
  });
}

/// Formats the group count as `+N`, displaying the count of additional hidden
/// notifications stacked behind the visible representative card.
///
/// Example: In a group of 3 notifications, displays `+2`.
@immutable
final class HiddenCount extends GroupCountBehavior {
  /// Creates a [HiddenCount] behavior displaying additional stacked items.
  const HiddenCount({
    super.maxCount = 99,
    super.includePending = true,
    this.prefix = '+',
    this.overflowSuffix = '+',
  });

  /// Prefix prepended to the count number. Defaults to `'+'`.
  final String prefix;

  /// Suffix appended when the count exceeds [maxCount]. Defaults to `'+'`.
  final String overflowSuffix;

  @override
  String? format({
    required final int totalCount,
    required final int hiddenCount,
  }) {
    if (hiddenCount > maxCount) {
      return '$prefix$maxCount$overflowSuffix';
    }
    return '$prefix$hiddenCount';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is HiddenCount &&
          runtimeType == other.runtimeType &&
          maxCount == other.maxCount &&
          includePending == other.includePending &&
          prefix == other.prefix &&
          overflowSuffix == other.overflowSuffix;

  @override
  int get hashCode => Object.hash(
        maxCount,
        includePending,
        prefix,
        overflowSuffix,
      );
}

/// Formats the group count as `N`, displaying the total number of notifications
/// in the group bundle, including the representative card.
///
/// Example: In a group of 3 notifications, displays `3`.
@immutable
final class TotalCount extends GroupCountBehavior {
  /// Creates a [TotalCount] behavior displaying total bundle size.
  const TotalCount({
    super.maxCount = 99,
    super.includePending = true,
    this.prefix = '',
    this.overflowSuffix = '+',
  });

  /// Prefix prepended to the count number. Defaults to `''`.
  final String prefix;

  /// Suffix appended when the count exceeds [maxCount]. Defaults to `'+'`.
  final String overflowSuffix;

  @override
  String? format({
    required final int totalCount,
    required final int hiddenCount,
  }) {
    if (totalCount > maxCount) {
      return '$prefix$maxCount$overflowSuffix';
    }
    return '$prefix$totalCount';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is TotalCount &&
          runtimeType == other.runtimeType &&
          maxCount == other.maxCount &&
          includePending == other.includePending &&
          prefix == other.prefix &&
          overflowSuffix == other.overflowSuffix;

  @override
  int get hashCode => Object.hash(
        maxCount,
        includePending,
        prefix,
        overflowSuffix,
      );
}

/// Formats the group count using a custom developer-provided callback.
@immutable
final class CustomCount extends GroupCountBehavior {
  /// Creates a [CustomCount] behavior using [formatter].
  const CustomCount({
    required this.formatter,
    super.maxCount = 99,
    super.includePending = true,
  });

  /// Formatter callback receiving the resolved `totalCount`, `hiddenCount`,
  /// and `isOverflow` indicator.
  final String? Function({
    required int totalCount,
    required int hiddenCount,
    required bool isOverflow,
  }) formatter;

  @override
  String? format({
    required final int totalCount,
    required final int hiddenCount,
  }) {
    final isOverflow = hiddenCount > maxCount || totalCount > maxCount;
    return formatter(
      totalCount: totalCount,
      hiddenCount: hiddenCount,
      isOverflow: isOverflow,
    );
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CustomCount &&
          runtimeType == other.runtimeType &&
          maxCount == other.maxCount &&
          includePending == other.includePending &&
          formatter == other.formatter;

  @override
  int get hashCode => Object.hash(maxCount, includePending, formatter);
}

/// Suppresses the numerical count label on the bundle toggle pill, showing
/// only the next-in-line preview or action label without a number.
@immutable
final class NoCount extends GroupCountBehavior {
  /// Creates a [NoCount] behavior that suppresses numerical count labels.
  const NoCount() : super(maxCount: 0, includePending: false);

  @override
  String? format({
    required final int totalCount,
    required final int hiddenCount,
  }) =>
      null;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is NoCount && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
