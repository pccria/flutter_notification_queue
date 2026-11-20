import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../bloc/setup_bloc.dart';
import '../models/queue_setup.dart';
import '../studio_theme.dart';

/// A 3×3 visual grid representing all 9 [QueuePosition] slots on the screen.
///
/// Fully upgraded with premium infographic-style overlays:
/// - **Spatial Canvas Lines**: Real-time dotted link lines connect Masters
///   to their Slaves dynamically behind the cells.
/// - **Dashed Slave Borders**: Custom-painted dashed lines depict dependent,
///   slave relocation targets.
/// - **Vibrant, High-Contrast Typography**: Hand-tuned dark/light adaptive
///   shades with 14px bold codes (TL, TC, etc.) for instant legibility.
class QueuePositionMap extends StatelessWidget {
  const QueuePositionMap({
    required this.queues,
    required this.selectedPosition,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  /// The active queue setups keyed by position.
  final Map<QueuePosition, QueueSetup> queues;

  /// Currently selected / active queue for editing.
  final QueuePosition selectedPosition;

  /// Called when the user taps an active cell to switch to it.
  final ValueChanged<QueuePosition> onSelect;

  /// Called when the user taps an empty cell to add a queue there.
  final ValueChanged<QueuePosition> onAdd;

  /// Called when the user taps the close button on an active cell.
  final ValueChanged<QueuePosition> onRemove;

  // Logical layout matching QueuePosition enum row/col.
  static const _grid = [
    [QueuePosition.topLeft, QueuePosition.topCenter, QueuePosition.topRight],
    [
      QueuePosition.centerLeft,
      null, // center (unused)
      QueuePosition.centerRight,
    ],
    [
      QueuePosition.bottomLeft,
      QueuePosition.bottomCenter,
      QueuePosition.bottomRight,
    ],
  ];

  Color _getPositionColor(final QueuePosition p, final ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return switch (p) {
      QueuePosition.topLeft =>
        isDark ? Colors.blue.shade300 : Colors.blue.shade700,
      QueuePosition.topCenter =>
        isDark ? Colors.indigo.shade300 : Colors.indigo.shade700,
      QueuePosition.topRight =>
        isDark ? Colors.purple.shade300 : Colors.purple.shade700,
      QueuePosition.centerLeft =>
        isDark ? Colors.green.shade300 : Colors.green.shade700,
      QueuePosition.centerRight =>
        isDark ? Colors.teal.shade300 : Colors.teal.shade700,
      QueuePosition.bottomLeft =>
        isDark ? Colors.orange.shade300 : Colors.orange.shade800,
      QueuePosition.bottomCenter =>
        isDark ? Colors.amber.shade400 : Colors.amber.shade900,
      QueuePosition.bottomRight =>
        isDark ? Colors.deepOrange.shade300 : Colors.deepOrange.shade800,
    };
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;
    final activePositions = queues.keys.toSet();

    // Compile relocation targets (slaves)
    final slavePositions =
        queues.values.expand((final q) => q.relocateTargets).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCREEN LAYOUT OVERVIEW',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.6,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.all(6),
              child: Stack(
                children: [
                  // ── Canvas-drawn Infographic Connection Lines ──
                  Positioned.fill(
                    child: CustomPaint(
                      painter: QueueConnectionsPainter(
                        queues: queues,
                        colorScheme: colorScheme,
                        getPositionColor: _getPositionColor,
                      ),
                    ),
                  ),
                  // ── 3x3 Grid Layout ──
                  Column(
                    children: _grid.asMap().entries.map((final rowEntry) {
                      final rowIndex = rowEntry.key;
                      final row = rowEntry.value;
                      return Padding(
                        padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : 4),
                        child: Row(
                          children: row.asMap().entries.map((final colEntry) {
                            final colIndex = colEntry.key;
                            final position = colEntry.value;

                            if (position == null) {
                              // Center dead zone
                              return Expanded(
                                child: Container(
                                  height: 52,
                                  margin: EdgeInsets.only(
                                    left: colIndex == 0 ? 0 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.03,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '···',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.2,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Find which master owns this slave, if any
                            QueuePosition? masterPosition;
                            for (final entry in queues.entries) {
                              if (entry.value.relocateTargets
                                  .contains(position)) {
                                masterPosition = entry.key;
                                break;
                              }
                            }

                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: colIndex == 0 ? 0 : 4,
                                ),
                                child: _PositionCell(
                                  position: position,
                                  isActive: activePositions.contains(position),
                                  isSlave: slavePositions.contains(position),
                                  isSelected: selectedPosition == position,
                                  masterPosition: masterPosition,
                                  canRemove: activePositions.length > 1,
                                  getPositionColor: _getPositionColor,
                                  onSelect: onSelect,
                                  onAdd: onAdd,
                                  onRemove: onRemove,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Active (Master)',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade300
                      : Colors.blue.shade700,
                  isDashed: true,
                ),
                const SizedBox(width: 4),
                Text(
                  'Relocated (Slave)',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  bordered: true,
                ),
                const SizedBox(width: 4),
                Text(
                  'Empty (+ to Add)',
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _PositionCell extends StatelessWidget {
  const _PositionCell({
    required this.position,
    required this.isActive,
    required this.isSlave,
    required this.isSelected,
    required this.masterPosition,
    required this.canRemove,
    required this.getPositionColor,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
  });

  final QueuePosition position;
  final bool isActive;
  final bool isSlave;
  final bool isSelected;
  final QueuePosition? masterPosition;
  final bool canRemove;
  final Color Function(QueuePosition, ColorScheme) getPositionColor;
  final ValueChanged<QueuePosition> onSelect;
  final ValueChanged<QueuePosition> onAdd;
  final ValueChanged<QueuePosition> onRemove;

  String _shortCode(final QueuePosition p) => switch (p) {
        QueuePosition.topLeft => 'TL',
        QueuePosition.topCenter => 'TC',
        QueuePosition.topRight => 'TR',
        QueuePosition.centerLeft => 'CL',
        QueuePosition.centerRight => 'CR',
        QueuePosition.bottomLeft => 'BL',
        QueuePosition.bottomCenter => 'BC',
        QueuePosition.bottomRight => 'BR',
      };

  String _description(final QueuePosition p) => switch (p) {
        QueuePosition.topLeft => 'Top Left',
        QueuePosition.topCenter => 'Top Center',
        QueuePosition.topRight => 'Top Right',
        QueuePosition.centerLeft => 'Mid Left',
        QueuePosition.centerRight => 'Mid Right',
        QueuePosition.bottomLeft => 'Btm Left',
        QueuePosition.bottomCenter => 'Btm Center',
        QueuePosition.bottomRight => 'Btm Right',
      };

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;

    final Color bg;
    final Color border;
    final Color textColor;

    final groupColor = getPositionColor(position, colorScheme);
    final masterColor = masterPosition != null
        ? getPositionColor(masterPosition!, colorScheme)
        : null;

    if (isSelected && isActive) {
      bg = groupColor;
      border = groupColor;
      textColor = bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    } else if (isActive) {
      bg = groupColor.withValues(alpha: 0.16);
      border = groupColor.withValues(alpha: 0.95);
      textColor = groupColor;
    } else if (isSlave && masterPosition != null) {
      final mColor = masterColor ?? colorScheme.secondary;
      bg = mColor.withValues(alpha: 0.08);
      border = mColor.withValues(alpha: 0.6);
      textColor = mColor;
    } else {
      bg = colorScheme.onSurface.withValues(alpha: 0.06);
      border = colorScheme.outlineVariant.withValues(alpha: 0.5);
      textColor = colorScheme.onSurface.withValues(alpha: 0.6);
    }

    final tooltipMessage = isSlave && masterPosition != null
        ? '${_description(position)} '
            '(Slave of ${_description(masterPosition!)})'
        : _description(position);

    final activeCount = context.select<SetupBloc, int>((final bloc) {
      final win = bloc.state.activeWindow;
      if (!win.isMounted || !win.controller.isAttached) {
        return 0;
      }
      return win.controller.activeNotifications
          .where((final n) => n.queue.position == position)
          .length;
    });

    final isPaused = context.select<SetupBloc, bool>((final bloc) {
      final win = bloc.state.activeWindow;
      return win.isPaused;
    });

    return Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: () {
          if (isActive) {
            onSelect(position);
          } else if (!isSlave) {
            onAdd(position);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: isSlave && !isActive
                ? null
                : Border.all(
                    color: border,
                    width: isSelected && isActive ? 2 : 1,
                  ),
          ),
          child: Stack(
            children: [
              // ── Dashed Slave Border Custom Paint ──
              if (isSlave && !isActive)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _DashedBorderPainter(
                        color: border,
                        borderRadius: 8.0,
                      ),
                    ),
                  ),
                ),
              // ── Live Occupancy Count Dot (Spatial Radar) ──
              if (isActive && activeCount > 0)
                Positioned(
                  top: 3,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black.withValues(alpha: 0.35)
                          : groupColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.5)
                            : groupColor,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$activeCount',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                  ),
                ),
              if (isActive && isPaused)
                Positioned(
                  bottom: 3,
                  left: 4,
                  child: Text(
                    '⏸',
                    style: TextStyle(
                      fontSize: 8,
                      color: isSelected
                          ? Colors.white
                          : colorScheme.error.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _shortCode(position),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isActive)
                      Text(
                        isSelected ? 'EDITING' : 'ACTIVE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: textColor.withValues(alpha: 0.95),
                        ),
                      )
                    else if (isSlave && masterPosition != null)
                      Text(
                        'SLAVE → ${_shortCode(masterPosition!)}',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: textColor.withValues(alpha: 0.95),
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 11,
                            color: textColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'ADD',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (isActive && canRemove)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onRemove(position),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.black.withValues(alpha: 0.15)
                            : colorScheme.error.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 9,
                        color: isSelected
                            ? textColor.withValues(alpha: 0.8)
                            : colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws clean, dotted relationship link vectors between masters and slaves.
class QueueConnectionsPainter extends CustomPainter {
  QueueConnectionsPainter({
    required this.queues,
    required this.colorScheme,
    required this.getPositionColor,
  });

  final Map<QueuePosition, QueueSetup> queues;
  final ColorScheme colorScheme;
  final Color Function(QueuePosition, ColorScheme) getPositionColor;

  @override
  void paint(final Canvas canvas, final Size size) {
    final cellWidth = (size.width - 8) / 3;
    final cellHeight = (size.height - 8) / 3;

    Offset getCellCenter(final QueuePosition p) {
      final (row, col) = _getPositionGridCoords(p);
      final x = col * (cellWidth + 4) + cellWidth / 2;
      final y = row * (cellHeight + 4) + cellHeight / 2;
      return Offset(x, y);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (final entry in queues.entries) {
      final master = entry.key;
      final slaves = entry.value.relocateTargets;
      if (slaves.isEmpty) {
        continue;
      }

      final masterColor = getPositionColor(master, colorScheme);
      final masterCenter = getCellCenter(master);

      for (final slave in slaves) {
        final slaveCenter = getCellCenter(slave);

        paint.color = masterColor.withValues(alpha: 0.45);
        _drawDashedLine(canvas, masterCenter, slaveCenter, paint);

        final anchorPaint = Paint()
          ..color = masterColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(slaveCenter, 3.5, anchorPaint);
      }
    }
  }

  void _drawDashedLine(
    final Canvas canvas,
    final Offset p1,
    final Offset p2,
    final Paint paint,
  ) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final distance = (p2 - p1).distance;
    final direction = (p2 - p1) / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final remaining = distance - drawn;
      final length = remaining < dashWidth ? remaining : dashWidth;
      canvas.drawLine(
        p1 + direction * drawn,
        p1 + direction * (drawn + length),
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }

  (int, int) _getPositionGridCoords(final QueuePosition p) => switch (p) {
        QueuePosition.topLeft => (0, 0),
        QueuePosition.topCenter => (0, 1),
        QueuePosition.topRight => (0, 2),
        QueuePosition.centerLeft => (1, 0),
        QueuePosition.centerRight => (1, 2),
        QueuePosition.bottomLeft => (2, 0),
        QueuePosition.bottomCenter => (2, 1),
        QueuePosition.bottomRight => (2, 2),
      };

  @override
  bool shouldRepaint(
    covariant final QueueConnectionsPainter oldDelegate,
  ) =>
      queues != oldDelegate.queues || colorScheme != oldDelegate.colorScheme;
}

/// Paints a zero-dependency dashed border outline around a box.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.borderRadius});

  final Color color;
  final double borderRadius;

  // Cache to avoid recalculating the path on every frame of animation/resize.
  static final Map<_CacheKey, Path> _pathCache = {};

  @override
  void paint(final Canvas canvas, final Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final key = _CacheKey(size, borderRadius);
    var dashedPath = _pathCache[key];

    if (dashedPath == null) {
      // Keep cache size bounded to prevent memory leaks during resizing.
      if (_pathCache.length > 50) {
        _pathCache.clear();
      }

      final path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(borderRadius),
          ),
        );

      dashedPath = Path();
      const dashWidth = 3.5;
      const dashSpace = 2.5;

      for (final PathMetric metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final len = metric.length - distance;
          final drawLength = len < dashWidth ? len : dashWidth;
          dashedPath.addPath(
            metric.extractPath(distance, distance + drawLength),
            Offset.zero,
          );
          distance += dashWidth + dashSpace;
        }
      }
      _pathCache[key] = dashedPath;
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant final _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || borderRadius != oldDelegate.borderRadius;
}

@immutable
class _CacheKey {
  const _CacheKey(this.size, this.borderRadius);

  final Size size;
  final double borderRadius;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is _CacheKey &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          borderRadius == other.borderRadius;

  @override
  int get hashCode => Object.hash(size, borderRadius);
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    this.bordered = false,
    this.isDashed = false,
  });

  final Color color;
  final bool bordered;
  final bool isDashed;

  @override
  Widget build(final BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: isDashed ? null : color,
          shape: BoxShape.circle,
          border: isDashed
              ? Border.all(color: color, style: BorderStyle.solid, width: 1.5)
              : (bordered
                  ? Border.all(
                      color: StudioTheme.colorScheme.outlineVariant,
                    )
                  : null),
        ),
      );
}
