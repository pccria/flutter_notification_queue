import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../bloc/setup_bloc.dart';
import '../studio_theme.dart';

/// A reactive spatial radar that reflects the live runtime status of the
/// notification stage:
/// - **Active Notifications**: What is rendered on screen per position.
/// - **Queue Depth**: How many items are waiting in the backlog.
/// - **Relocated Queues**: Live display of permanent relocations.
/// - **Live Stream Subscription**: Automatically updates on any stage event.
class LiveStageRadar extends StatefulWidget {
  const LiveStageRadar({
    required this.setupState,
    super.key,
  });

  final SetupState setupState;

  @override
  State<LiveStageRadar> createState() => _LiveStageRadarState();
}

class _LiveStageRadarState extends State<LiveStageRadar> {
  StreamSubscription<NotificationEvent>? _eventSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resubscribe();
  }

  @override
  void didUpdateWidget(final LiveStageRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.setupState.activeWindowId !=
            oldWidget.setupState.activeWindowId ||
        widget.setupState.controller != oldWidget.setupState.controller) {
      _resubscribe();
    }
  }

  void _resubscribe() {
    _eventSub?.cancel();
    final scope =
        NotificationScope.maybeOf(context) ?? widget.setupState.controller;
    _eventSub = scope.events.listen((final _) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final controller =
        NotificationScope.maybeOf(context) ?? widget.setupState.controller;
    final colorScheme = StudioTheme.colorScheme;
    final isDark = StudioTheme.isDark;

    final activeNotifications = controller.activeNotifications;
    final pendingNotifications = controller.pendingNotifications;

    // Count active items per position
    final activeCounts = <QueuePosition, int>{};
    for (final n in activeNotifications) {
      activeCounts[n.queue.position] =
          (activeCounts[n.queue.position] ?? 0) + 1;
    }

    // Count pending items per position
    final pendingCounts = <QueuePosition, int>{};
    for (final n in pendingNotifications) {
      pendingCounts[n.queue.position] =
          (pendingCounts[n.queue.position] ?? 0) + 1;
    }

    // Check relocations
    final relocations = <QueuePosition, QueuePosition>{};
    for (final pos in QueuePosition.values) {
      final effective = controller.getEffectiveQueuePosition(pos);
      if (effective != pos) {
        relocations[pos] = effective;
      }
    }

    final totalActive = activeNotifications.length;
    final totalPending = pendingNotifications.length;
    final totalRelocated = relocations.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(isActive: totalActive > 0),
                    const SizedBox(width: 8),
                    Text(
                      'STAGE RADAR & LIVE STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _StatBadge(
                      icon: Icons.layers_outlined,
                      label: '$totalActive Active',
                      color:
                          totalActive > 0 ? Colors.green : colorScheme.outline,
                    ),
                    _StatBadge(
                      icon: Icons.hourglass_empty_rounded,
                      label: '+$totalPending Queued',
                      color:
                          totalPending > 0 ? Colors.amber : colorScheme.outline,
                    ),
                    if (totalRelocated > 0)
                      _StatBadge(
                        icon: Icons.alt_route_rounded,
                        label: '$totalRelocated Relocated',
                        color: Colors.blueAccent,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ── 3×3 Spatial Radar Grid ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: _SpatialRadarGrid(
              activeCounts: activeCounts,
              pendingCounts: pendingCounts,
              relocations: relocations,
              totalActive: totalActive,
              totalPending: totalPending,
            ),
          ),

          // ── Quick Controls Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text(
                        'DISMISS NEWEST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: totalActive > 0
                          ? () => (NotificationScope.maybeOf(context) ??
                                  widget.setupState.controller)
                              .dismissNewest()
                          : null,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.clear_all_rounded, size: 14),
                      label: const Text(
                        'DISMISS ALL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: totalActive > 0
                          ? () => (NotificationScope.maybeOf(context) ??
                                  widget.setupState.controller)
                              .dismissAll()
                          : null,
                    ),
                  ],
                ),
                Text(
                  totalActive == 0
                      ? 'Stage empty'
                      : '$totalActive cards active',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3×3 Spatial Radar Grid ──────────────────────────────────────────────────

class _SpatialRadarGrid extends StatelessWidget {
  const _SpatialRadarGrid({
    required this.activeCounts,
    required this.pendingCounts,
    required this.relocations,
    required this.totalActive,
    required this.totalPending,
  });

  final Map<QueuePosition, int> activeCounts;
  final Map<QueuePosition, int> pendingCounts;
  final Map<QueuePosition, QueuePosition> relocations;
  final int totalActive;
  final int totalPending;

  static const _layout = [
    [QueuePosition.topLeft, QueuePosition.topCenter, QueuePosition.topRight],
    [QueuePosition.centerLeft, null, QueuePosition.centerRight],
    [
      QueuePosition.bottomLeft,
      QueuePosition.bottomCenter,
      QueuePosition.bottomRight,
    ],
  ];

  @override
  Widget build(final BuildContext context) => Table(
        children: _layout
            .map(
              (final row) => TableRow(
                children: row.map((final pos) {
                  if (pos == null) {
                    return _CenterStageHud(
                      totalActive: totalActive,
                      totalPending: totalPending,
                    );
                  }
                  final active = activeCounts[pos] ?? 0;
                  final pending = pendingCounts[pos] ?? 0;
                  final relocatedTo = relocations[pos];
                  return _RadarCell(
                    position: pos,
                    activeCount: active,
                    pendingCount: pending,
                    relocatedTo: relocatedTo,
                  );
                }).toList(),
              ),
            )
            .toList(),
      );
}

class _RadarCell extends StatelessWidget {
  const _RadarCell({
    required this.position,
    required this.activeCount,
    required this.pendingCount,
    this.relocatedTo,
  });

  final QueuePosition position;
  final int activeCount;
  final int pendingCount;
  final QueuePosition? relocatedTo;

  String _code(final QueuePosition p) => switch (p) {
        QueuePosition.topLeft => 'TL',
        QueuePosition.topCenter => 'TC',
        QueuePosition.topRight => 'TR',
        QueuePosition.centerLeft => 'CL',
        QueuePosition.centerRight => 'CR',
        QueuePosition.bottomLeft => 'BL',
        QueuePosition.bottomCenter => 'BC',
        QueuePosition.bottomRight => 'BR',
      };

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActive = activeCount > 0;
    final hasPending = pendingCount > 0;
    final isRelocated = relocatedTo != null;

    final cellColor = hasActive
        ? Colors.green.withValues(alpha: isDark ? 0.16 : 0.1)
        : isRelocated
            ? Colors.blueAccent.withValues(alpha: isDark ? 0.12 : 0.08)
            : colorScheme.surface.withValues(alpha: isDark ? 0.35 : 0.5);

    final borderColor = hasActive
        ? Colors.green.withValues(alpha: 0.45)
        : isRelocated
            ? Colors.blueAccent.withValues(alpha: 0.35)
            : colorScheme.outlineVariant.withValues(alpha: 0.18);

    return Container(
      margin: const EdgeInsets.all(3.5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _code(position),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: hasActive
                      ? Colors.green
                      : isRelocated
                          ? Colors.blueAccent
                          : colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              if (hasActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          if (hasActive || hasPending) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasActive)
                  Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                if (hasPending) ...[
                  const SizedBox(width: 3),
                  Text(
                    '+$pendingCount',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ] else if (isRelocated) ...[
            Text(
              '➔ ${_code(relocatedTo!)}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ] else ...[
            Text(
              'idle',
              style: TextStyle(
                fontSize: 9,
                color: colorScheme.onSurface.withValues(alpha: 0.28),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CenterStageHud extends StatelessWidget {
  const _CenterStageHud({
    required this.totalActive,
    required this.totalPending,
  });

  final int totalActive;
  final int totalPending;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(3.5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.radar_rounded,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 2),
          Text(
            'STAGE',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.isActive});
  final bool isActive;

  @override
  Widget build(final BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.grey,
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      );
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
}
