part of 'zones.dart';

/// Sealed representation of a resolved drop target during a drag gesture.
@immutable
sealed class DropTarget {
  const DropTarget();
}

/// A specific insertion slot target in a queue (either the home queue or a
/// remote candidate queue).
@immutable
final class SlotTarget extends DropTarget {
  const SlotTarget({
    required this.position,
    required this.gapIndex,
    required this.progress,
  });

  /// The target queue position.
  final QueuePosition position;

  /// The 0-based gap/slot index within the queue
  /// (0 <= gapIndex <= visibleCount).
  final int gapIndex;

  /// Proximity progress in `[0.0, 1.0]` toward the slot anchor.
  final double progress;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is SlotTarget &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          gapIndex == other.gapIndex &&
          (progress - other.progress).abs() < 0.001;

  @override
  int get hashCode => Object.hash(position, gapIndex);

  @override
  String toString() =>
      'SlotTarget(position: ${position.name}, gapIndex: $gapIndex, '
      'progress: ${progress.toStringAsFixed(2)})';
}

/// A coarse whole-queue drop target (e.g. an empty queue or landing dock).
@immutable
final class QueueTarget extends DropTarget {
  const QueueTarget(this.position, {this.progress = 1.0});

  /// The target queue position.
  final QueuePosition position;

  /// Proximity / engagement progress in `[0.0, 1.0]`.
  final double progress;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is QueueTarget &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          (progress - other.progress).abs() < 0.001;

  @override
  int get hashCode => position.hashCode;

  @override
  String toString() => 'QueueTarget(position: ${position.name}, progress: '
      '${progress.toStringAsFixed(2)})';
}

/// Indicates the pointer is drifting in open space with no active drop target.
@immutable
final class NoTarget extends DropTarget {
  const NoTarget();

  @override
  bool operator ==(final Object other) =>
      identical(this, other) || other is NoTarget;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NoTarget()';
}

/// Spatial snapshot of a mounted queue captured at drag lift-off.
@immutable
class QueueGeometrySnapshot {
  const QueueGeometrySnapshot({
    required this.position,
    required this.containerRect,
    required this.cardRects,
    required this.gapAnchors,
    required this.verticalDirection,
    required this.cardSpacing,
    required this.maxStackSize,
    this.layoutVersion = 0,
  });

  /// The queue position for this geometry.
  final QueuePosition position;

  /// Screen-space bounding rect of the queue container.
  final Rect containerRect;

  /// Screen-space bounding rects for each visible card in stack order.
  final List<Rect> cardRects;

  /// Screen-space anchor coordinates for each inter-card gap (0..N).
  final List<Offset> gapAnchors;

  /// Growth direction of the queue stack.
  final VerticalDirection verticalDirection;

  /// Spacing between consecutive cards.
  final double cardSpacing;

  /// Maximum visible stack capacity for this queue.
  final int maxStackSize;

  /// Monotonic snapshot version from `QueueWidgetState` to detect mid-drag
  /// mutations.
  final int layoutVersion;

  /// The number of visible cards in this queue.
  int get visibleCount => cardRects.length;

  /// Computes gap anchor coordinates for [cardRects] within [containerRect].
  static List<Offset> computeGapAnchors({
    required final Rect containerRect,
    required final List<Rect> cardRects,
    required final VerticalDirection verticalDirection,
    required final double cardSpacing,
  }) {
    if (cardRects.isEmpty) {
      return [containerRect.center];
    }

    final anchors = <Offset>[];
    final centerX = containerRect.center.dx;

    if (verticalDirection == VerticalDirection.down) {
      // Gap 0 is at the top of the first card
      anchors.add(Offset(centerX, cardRects.first.top));

      // Inter-card gaps
      for (int i = 0; i < cardRects.length - 1; i++) {
        final midY = (cardRects[i].bottom + cardRects[i + 1].top) / 2;
        anchors.add(Offset(centerX, midY));
      }

      // Gap N is at the bottom of the last card
      anchors.add(Offset(centerX, cardRects.last.bottom));
    } else {
      // For VerticalDirection.up: index 0 is at the bottom
      anchors.add(Offset(centerX, cardRects.first.bottom));

      for (int i = 0; i < cardRects.length - 1; i++) {
        final midY = (cardRects[i].top + cardRects[i + 1].bottom) / 2;
        anchors.add(Offset(centerX, midY));
      }

      anchors.add(Offset(centerX, cardRects.last.top));
    }

    return anchors;
  }
}

/// Resolves non-overlapping card-footprint dock rects for candidate queue
/// positions, partitioning crowded horizontal bands on narrow screens and
/// steering clear of mounted non-empty notification stacks.
Map<QueuePosition, Rect> resolveCandidateDockRects({
  required final QueuePosition homePosition,
  required final Set<QueuePosition> candidatePositions,
  required final Size screenSize,
  required final Size cardSize,
  final EdgeInsets viewPadding = EdgeInsets.zero,
  final Map<QueuePosition, QueueGeometrySnapshot> mountedSnapshots = const {},
  final EdgeInsetsGeometry Function(QueuePosition)? marginForPosition,
  final double? Function(QueuePosition)? maxWidthForPosition,
}) {
  final dockHeight = cardSize.height > 0 ? cardSize.height : 76.0;
  final result = <QueuePosition, Rect>{};
  final unmountedOrEmpty = <QueuePosition>[];

  // 1. Compute base nominal rects for every candidate (!= homePosition)
  for (final pos in candidatePositions) {
    if (pos == homePosition) {
      continue;
    }
    final maxAllowedWidth = Utils.horizontalConstraintsForWidth(
      screenSize.width,
      maxWidthForPosition?.call(pos),
    ).maxWidth;
    final dockWidth = cardSize.width > 0
        ? math.min(cardSize.width, maxAllowedWidth)
        : math.min(280.0, maxAllowedWidth);
    final margin = marginForPosition?.call(pos) ?? EdgeInsets.zero;

    result[pos] = Utils.nominalAlignedRect(
      alignment: pos.alignment,
      screenSize: screenSize,
      childSize: Size(dockWidth, dockHeight),
      viewPadding: viewPadding,
      margin: margin,
    );

    final snap = mountedSnapshots[pos];
    if (snap == null || snap.cardRects.isEmpty) {
      unmountedOrEmpty.add(pos);
    }
  }

  // 2. Partition crowded horizontal bands (top, center, bottom) so sibling
  // docks never render illegible overlapping stacks on narrow viewports.
  const double bandGutter = 10.0;
  for (final bandY in [-1, 0, 1]) {
    final bandPositions = unmountedOrEmpty.where((final p) {
      final alignY = (p.alignment as Alignment).y;
      final bucket = alignY < -0.5 ? -1 : (alignY > 0.5 ? 1 : 0);
      return bucket == bandY;
    }).toList()
      ..sort(
        (final a, final b) => (a.alignment as Alignment)
            .x
            .compareTo((b.alignment as Alignment).x),
      );

    if (bandPositions.length <= 1) {
      continue;
    }

    var hasCrowding = false;
    for (int i = 0; i < bandPositions.length - 1; i++) {
      final a = result[bandPositions[i]]!;
      final b = result[bandPositions[i + 1]]!;
      if (a.right + bandGutter > b.left) {
        hasCrowding = true;
        break;
      }
    }
    if (!hasCrowding) {
      continue;
    }

    final safeLeft = viewPadding.left + 12.0;
    final safeRight = screenSize.width - viewPadding.right - 12.0;
    final availableW = math.max(120.0, safeRight - safeLeft);
    final count = bandPositions.length;
    final slotW = math.max(
      64.0,
      (availableW - bandGutter * (count - 1)) / count,
    );

    for (int i = 0; i < count; i++) {
      final pos = bandPositions[i];
      final old = result[pos]!;
      final x = safeLeft + i * (slotW + bandGutter);
      result[pos] = Rect.fromLTWH(x, old.top, slotW, dockHeight);
    }
  }

  // 3. Shift unmounted docks clear of any mounted non-empty queue stack.
  final mountedRects = <Rect>[
    for (final entry in mountedSnapshots.entries)
      if (entry.key != homePosition &&
          entry.value.cardRects.isNotEmpty &&
          !entry.value.containerRect.isEmpty)
        entry.value.containerRect,
  ];

  const double stackGap = 8.0;
  final minY = viewPadding.top + stackGap;
  final maxY = screenSize.height - viewPadding.bottom - dockHeight - stackGap;

  for (final pos in unmountedOrEmpty) {
    var rect = result[pos]!;
    final alignY = (pos.alignment as Alignment).y;
    for (final blocker in mountedRects) {
      if (!rect.overlaps(blocker)) {
        continue;
      }
      if (alignY > 0.5) {
        final candidateTop = blocker.top - dockHeight - stackGap;
        if (candidateTop >= minY) {
          rect = Rect.fromLTWH(rect.left, candidateTop, rect.width, dockHeight);
        }
      } else {
        final candidateTop = blocker.bottom + stackGap;
        if (candidateTop <= maxY) {
          rect = Rect.fromLTWH(rect.left, candidateTop, rect.width, dockHeight);
        } else {
          final fallbackTop = blocker.top - dockHeight - stackGap;
          if (fallbackTop >= minY) {
            rect = Rect.fromLTWH(
              rect.left,
              fallbackTop,
              rect.width,
              dockHeight,
            );
          }
        }
      }
    }
    result[pos] = rect;
  }

  return result;
}

/// Pure spatial resolver that resolves the active [DropTarget] given the
/// current pointer coordinate, queue geometry snapshots, and hysteresis state.
DropTarget resolveTarget({
  required final Offset pointer,
  required final QueuePosition homePosition,
  required final Map<QueuePosition, QueueGeometrySnapshot> snapshots,
  required final DropTarget previousTarget,
  final Set<QueuePosition> candidatePositions = const {},
  final Map<QueuePosition, Rect> candidateDockRects = const {},
  final Size? screenSize,
  final double escapeThreshold = 48.0,
  final double incomingHeight = 80.0,
  final bool allowHomeReorder = true,
  final bool allowSlotTargeting = true,
}) {
  final homeSnapshot = snapshots[homePosition];
  final isPointerInHome =
      homeSnapshot != null && homeSnapshot.containerRect.contains(pointer);

  // 1. If slot targeting is allowed (e.g. ReorderAndRelocate):
  //    Check candidate remote mounted non-empty queues for slot gaps
  if (allowSlotTargeting) {
    for (var pass = 0; pass < 2; pass++) {
      SlotTarget? bestRemoteTarget;
      double bestRemoteScore = double.infinity;

      for (final entry in snapshots.entries) {
        if (entry.key == homePosition) {
          continue;
        }
        final snapshot = entry.value;
        if (snapshot.cardRects.isEmpty || snapshot.containerRect.isEmpty) {
          continue;
        }

        final wasLockedHere = previousTarget is SlotTarget &&
            previousTarget.position == snapshot.position;
        if (pass == 1 && !wasLockedHere) {
          continue;
        }

        if (isPointerInHome &&
            homeSnapshot.containerRect.overlaps(snapshot.containerRect)) {
          final homeDx =
              (pointer.dx - homeSnapshot.containerRect.center.dx).abs();
          final remoteDx =
              (pointer.dx - snapshot.containerRect.center.dx).abs();
          final homeBias = previousTarget is SlotTarget &&
                  previousTarget.position == homePosition
              ? 24.0
              : 12.0;
          if (homeDx - homeBias <= remoteDx) {
            continue;
          }
        }

        var hitRect = snapshot.containerRect;
        if (wasLockedHere) {
          final extraTail = incomingHeight + snapshot.cardSpacing;
          hitRect = snapshot.verticalDirection == VerticalDirection.down
              ? Rect.fromLTRB(
                  hitRect.left,
                  hitRect.top,
                  hitRect.right,
                  hitRect.bottom + extraTail,
                )
              : Rect.fromLTRB(
                  hitRect.left,
                  hitRect.top - extraTail,
                  hitRect.right,
                  hitRect.bottom,
                );
          if (pass == 1) {
            hitRect = hitRect.inflate(escapeThreshold * 0.5);
          }
        }

        if (hitRect.contains(pointer)) {
          final previousGap = wasLockedHere ? previousTarget.gapIndex : null;
          final gapIndex = _findNearestGap(
            pointer,
            snapshot.gapAnchors,
            previousGapIndex: previousGap,
          );
          final anchor = snapshot.gapAnchors[gapIndex];
          final distance = (pointer.dy - anchor.dy).abs();
          final progress = (1.0 - (distance / 80.0)).clamp(0.0, 1.0);

          var score =
              (pointer.dx - snapshot.containerRect.center.dx).abs() * 0.5 +
                  (pointer - anchor).distance;
          if (wasLockedHere) {
            score -= 20.0;
          }
          if (score < bestRemoteScore) {
            bestRemoteScore = score;
            bestRemoteTarget = SlotTarget(
              position: snapshot.position,
              gapIndex: gapIndex,
              progress: progress,
            );
          }
        }
      }

      if (bestRemoteTarget != null) {
        return bestRemoteTarget;
      }
    }
  } else {
    // Whole-queue targeting for Relocate:
    // Check candidate remote mounted non-empty queues for whole-queue hover
    QueueTarget? bestMountedTarget;
    double bestMountedScore = double.infinity;

    for (final entry in snapshots.entries) {
      if (entry.key == homePosition) {
        continue;
      }
      final snapshot = entry.value;
      if (snapshot.cardRects.isEmpty || snapshot.containerRect.isEmpty) {
        continue;
      }
      final wasLockedHere = previousTarget is QueueTarget &&
          previousTarget.position == snapshot.position;
      final stickyBias = wasLockedHere ? 18.0 : 0.0;
      final hitRect = wasLockedHere
          ? snapshot.containerRect.inflate(escapeThreshold * 0.5)
          : snapshot.containerRect;

      if (hitRect.contains(pointer)) {
        final distToCenter = (pointer - snapshot.containerRect.center).distance;
        final maxDim = snapshot.containerRect.shortestSide > 0
            ? snapshot.containerRect.shortestSide
            : 64.0;
        final centerFactor =
            (1.0 - (distToCenter / (maxDim * 1.4))).clamp(0.0, 1.0);
        final progress = 0.72 + 0.28 * centerFactor;
        final score = distToCenter - stickyBias;
        if (score < bestMountedScore) {
          bestMountedScore = score;
          bestMountedTarget = QueueTarget(
            snapshot.position,
            progress: progress,
          );
        }
      }
    }

    if (bestMountedTarget != null) {
      return bestMountedTarget;
    }
  }

  // 2. Check home queue with hysteresis (only if allowSlotTargeting &&
  //    allowHomeReorder)
  if (allowSlotTargeting &&
      allowHomeReorder &&
      homeSnapshot != null &&
      !homeSnapshot.containerRect.isEmpty) {
    final isInside = homeSnapshot.containerRect.contains(pointer);
    final isHysteresis = previousTarget is SlotTarget &&
        previousTarget.position == homePosition &&
        homeSnapshot.containerRect.inflate(escapeThreshold).contains(pointer);

    if (isInside || isHysteresis) {
      final slotIndex = homeSnapshot.cardRects.isNotEmpty
          ? _findNearestCardSlot(pointer, homeSnapshot.cardRects)
          : 0;
      final anchor = homeSnapshot.cardRects.isNotEmpty
          ? homeSnapshot.cardRects[slotIndex].center
          : homeSnapshot.containerRect.center;
      final distance = (pointer.dy - anchor.dy).abs();
      final progress = (1.0 - (distance / 80.0)).clamp(0.0, 1.0);
      return SlotTarget(
        position: homePosition,
        gapIndex: slotIndex,
        progress: progress,
      );
    }
  }

  // 3. Check for coarse whole-queue drop targets on candidate positions
  // (empty or unmounted). Rank by nearest dock center so intersecting regions
  // never lock out underlying targets.
  QueueTarget? bestDockTarget;
  double bestDockScore = double.infinity;

  for (final position in candidatePositions) {
    if (position == homePosition) {
      continue;
    }

    final wasLockedHere =
        previousTarget is QueueTarget && previousTarget.position == position;
    final stickyBias = wasLockedHere ? 18.0 : 0.0;

    final dockRect = candidateDockRects[position];
    if (dockRect != null && !dockRect.isEmpty) {
      final hitMargin = wasLockedHere ? 20.0 : 10.0;
      if (dockRect.inflate(hitMargin).contains(pointer)) {
        final maxDim = dockRect.shortestSide > 0 ? dockRect.shortestSide : 64.0;
        final distToCenter = (pointer - dockRect.center).distance;
        final centerFactor =
            (1.0 - (distToCenter / (maxDim * 1.4))).clamp(0.0, 1.0);
        final progress = 0.72 + 0.28 * centerFactor;
        final score = distToCenter - stickyBias;
        if (score < bestDockScore) {
          bestDockScore = score;
          bestDockTarget = QueueTarget(position, progress: progress);
        }
        continue;
      }
    }

    if (screenSize != null) {
      final zone = PositionDropZone(position: position);
      if (zone.isHit(pointer, screenSize, escapeThreshold)) {
        final progress = zone.calculateProgress(
          pointer,
          screenSize,
          1.0 / (escapeThreshold > 0 ? escapeThreshold : 1.0),
        );
        final score = (1.0 - progress) * escapeThreshold - stickyBias;
        if (score < bestDockScore) {
          bestDockScore = score;
          bestDockTarget = QueueTarget(position, progress: progress);
        }
      }
    }
  }

  if (bestDockTarget != null) {
    return bestDockTarget;
  }

  // 4. Check for coarse whole-queue drop targets on empty mounted queues
  QueueTarget? bestEmptyTarget;
  double bestEmptyScore = double.infinity;
  for (final entry in snapshots.entries) {
    if (entry.key == homePosition) {
      continue;
    }
    final snapshot = entry.value;
    if (snapshot.cardRects.isEmpty &&
        snapshot.containerRect.inflate(escapeThreshold).contains(pointer)) {
      final dist = (pointer - snapshot.containerRect.center).distance;
      final progress =
          (1.0 - (dist / (escapeThreshold + 40.0))).clamp(0.35, 1.0);
      final wasLocked = previousTarget is QueueTarget &&
          previousTarget.position == snapshot.position;
      final score = dist - (wasLocked ? 18.0 : 0.0);
      if (score < bestEmptyScore) {
        bestEmptyScore = score;
        bestEmptyTarget = QueueTarget(snapshot.position, progress: progress);
      }
    }
  }

  return bestEmptyTarget ?? const NoTarget();
}

int _findNearestGap(
  final Offset pointer,
  final List<Offset> anchors, {
  final int? previousGapIndex,
}) {
  if (anchors.isEmpty) {
    return 0;
  }
  const double gravityWell = 14.0;
  int nearest = 0;
  double minDistance = double.infinity;
  for (int i = 0; i < anchors.length; i++) {
    var dist = (pointer.dy - anchors[i].dy).abs();
    if (i == previousGapIndex) {
      dist -= gravityWell;
    }
    if (dist < minDistance) {
      minDistance = dist;
      nearest = i;
    }
  }
  return nearest;
}

int _findNearestCardSlot(final Offset pointer, final List<Rect> cardRects) {
  if (cardRects.isEmpty) {
    return 0;
  }
  int nearest = 0;
  double minDistance = double.infinity;
  for (int i = 0; i < cardRects.length; i++) {
    final dist = (pointer.dy - cardRects[i].center.dy).abs();
    if (dist < minDistance) {
      minDistance = dist;
      nearest = i;
    }
  }
  return nearest;
}
