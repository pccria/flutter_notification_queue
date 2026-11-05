import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../../bloc/setup_bloc.dart';
import '../../models/channel_setup.dart';
import '../../models/queue_setup.dart';
import '../../studio_theme.dart';
import '../../widgets/queue_position_map.dart';
import '../../widgets/studio_dropdown_tile.dart';
import '../../widgets/studio_section_header.dart';
import '../../widgets/studio_slider_tile.dart';
import '../../widgets/studio_toggle_tile.dart';
import '../../widgets/style_archetype_selector.dart';
import 'relocation_selector.dart';

/// A section that manages the creation, deletion, and configuration of
/// [NotificationQueue] instances.
///
/// It provides a high-level selector for active queues and handles the "Add
/// Queue" logic, enforcing the rule that only "unused" positions (neither
/// Masters nor Slaves) can be configured.
class QueueSection extends StatelessWidget {
  const QueueSection({
    required this.setupState,
    super.key,
  });

  final SetupState setupState;

  @override
  Widget build(final BuildContext context) {
    final activeQueue =
        setupState.setup.queues[setupState.activeQueuePosition] ??
            const QueueSetup();

    final allSlaves = setupState.setup.queues.values
        .expand((final q) => q.relocateTargets)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${setupState.setup.queues.length} ACTIVE POSITION(S)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: StudioTheme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                size: 18,
                color: StudioTheme.colorScheme.primary,
              ),
              tooltip: 'Add queue position',
              onPressed: () {
                final availablePositions = QueuePosition.values
                    .where(
                      (final p) =>
                          !setupState.setup.queues.containsKey(p) &&
                          !allSlaves.contains(p),
                    )
                    .toList();
                if (availablePositions.length == 1) {
                  context
                      .read<SetupBloc>()
                      .add(AddQueue(availablePositions.first));
                } else {
                  _showAddQueueDialog(context);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── 9-Cell Position Map ──
        QueuePositionMap(
          queues: setupState.setup.queues,
          selectedPosition: setupState.activeQueuePosition,
          onSelect: (final pos) =>
              context.read<SetupBloc>().add(SelectActiveQueue(pos)),
          onAdd: (final pos) => context.read<SetupBloc>().add(AddQueue(pos)),
          onRemove: (final pos) => _showConfirmDeleteDialog(
            context,
            pos,
            setupState.setup.channels.values.toList(),
            () => context.read<SetupBloc>().add(RemoveQueue(pos)),
          ),
        ),
        const SizedBox(height: 16),
        _QueueEditor(
          position: setupState.activeQueuePosition,
          setup: activeQueue,
        ),
      ],
    );
  }

  /// Shows a dialog to select a new queue position to configure.
  ///
  /// Only positions that are not currently Masters (already have a queue)
  /// and are not Slaves (relocation targets for other queues) are shown.
  void _showAddQueueDialog(final BuildContext context) {
    final allSlaves = setupState.setup.queues.values
        .expand((final q) => q.relocateTargets)
        .toSet();
    showDialog(
      context: context,
      builder: (final ctx) => AlertDialog(
        title: const Text('Add Queue Position'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: QueuePosition.values
              .where(
                (final p) =>
                    !setupState.setup.queues.containsKey(p) &&
                    !allSlaves.contains(p),
              )
              .map(
                (final p) => ListTile(
                  title: Text(p.name.toUpperCase()),
                  onTap: () {
                    context.read<SetupBloc>().add(AddQueue(p));
                    Navigator.pop(ctx);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

enum _QueueCategory {
  anatomy,
  gestures,
  stacking,
}

/// A specialized editor for a single [QueueSetup], organized into
/// focused categories: Anatomy & Bounds, Gestures & Interaction,
/// and Stacking & Grouping.
class _QueueEditor extends StatefulWidget {
  const _QueueEditor({
    required this.position,
    required this.setup,
  });

  final QueuePosition position;
  final QueueSetup setup;

  @override
  State<_QueueEditor> createState() => _QueueEditorState();
}

class _QueueEditorState extends State<_QueueEditor> {
  _QueueCategory _selectedCategory = _QueueCategory.anatomy;

  static const _behaviorTypes = [
    Disabled,
    Dismiss,
    Snooze,
    Pin,
    Reorder,
    Relocate,
    ReorderAndRelocate,
  ];
  static const _closeButtonTypes = [AlwaysVisible, VisibleOnHover, Hidden];
  static const _transitionTypes = [
    SlideTransitionStrategy,
    FadeTransitionStrategy,
    ScaleTransitionStrategy,
  ];
  static const _tapBehaviorTypes = [
    TapToDismiss,
    TapToExpand,
    TapToAct,
    TapDisabled,
  ];

  String _formatBehaviorType(final Type t) => switch (t) {
        == Disabled => 'DISABLED',
        == Dismiss => 'DISMISS',
        == Snooze => 'SNOOZE',
        == Pin => 'PIN',
        == Reorder => 'REORDER',
        == Relocate => 'RELOCATE',
        == ReorderAndRelocate => 'REORDER & RELOCATE',
        _ => t.toString().toUpperCase(),
      };

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;
    final studioSetup = context.watch<SetupBloc>().state.setup;
    final otherQueuesSlaves = studioSetup.queues.entries
        .where((final entry) => entry.key != widget.position)
        .expand((final entry) => entry.value.relocateTargets)
        .toSet();
    final activePositions = studioSetup.queues.keys.toSet();
    final channels = studioSetup.channels.values.toList();
    final setup = widget.setup;
    final position = widget.position;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_input_component,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${position.name.toUpperCase()} CONFIGURATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (activePositions.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    onPressed: () => _showConfirmDeleteDialog(
                      context,
                      position,
                      channels,
                      () =>
                          context.read<SetupBloc>().add(RemoveQueue(position)),
                    ),
                    tooltip: 'Remove queue',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Category navigation pills ──
            Row(
              children: _QueueCategory.values.map((final cat) {
                final isSelected = _selectedCategory == cat;
                final (label, icon) = switch (cat) {
                  _QueueCategory.anatomy => (
                      'Anatomy',
                      Icons.aspect_ratio_rounded,
                    ),
                  _QueueCategory.gestures => (
                      'Gestures',
                      Icons.touch_app_outlined,
                    ),
                  _QueueCategory.stacking => (
                      'Stacking',
                      Icons.layers_outlined,
                    ),
                };
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.16)
                              : colorScheme.onSurface.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.35)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 13,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 24),
            switch (_selectedCategory) {
              _QueueCategory.anatomy => _buildAnatomyCategory(
                  context,
                  position,
                  setup,
                ),
              _QueueCategory.gestures => _buildGesturesCategory(
                  context,
                  position,
                  setup,
                  activePositions,
                  otherQueuesSlaves,
                ),
              _QueueCategory.stacking => _buildStackingCategory(
                  context,
                  position,
                  setup,
                ),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildAnatomyCategory(
    final BuildContext context,
    final QueuePosition position,
    final QueueSetup setup,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StyleArchetypeSelector(
            label: 'BASELINE STYLE ARCHETYPE',
            badgeLabel: 'QUEUE BASELINE',
            selectedType: setup.styleType,
            showInheritDefault: false,
            onChanged: (final v) {
              if (v != null) {
                final defaultRadius = v == FlatQueueStyle ? 0.0 : 8.0;
                context.read<SetupBloc>().add(
                      UpdateQueue(
                        position,
                        setup.copyWith(
                          styleType: v,
                          borderRadius: defaultRadius,
                        ),
                      ),
                    );
              }
            },
          ),
          const SizedBox(height: 16),

          // ── Queue Container Geometry (QueueStyle) ──
          const StudioSectionHeader(title: 'CONTAINER GEOMETRY (QUEUE STYLE)'),
          StudioSliderTile(
            label: 'CORNER RADIUS (PX)',
            value: setup.borderRadius,
            min: 0,
            max: 24,
            divisions: 24,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(borderRadius: v),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          StudioSliderTile(
            label: 'ELEVATION (SHADOW DEPTH)',
            value: setup.elevation,
            min: 0,
            max: 12,
            divisions: 12,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(elevation: v),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          StudioSliderTile(
            label: 'BORDER STROKE WIDTH (PX)',
            value: setup.borderWidth ??
                (setup.styleType == FlatQueueStyle ? 4.0 : 1.0),
            min: 0,
            max: 8,
            divisions: 16,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(borderWidth: v),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          StudioSliderTile(
            label: 'CONTAINER OPACITY',
            value: setup.opacity,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(
                      opacity: double.parse(v.toStringAsFixed(2)),
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          StudioToggleTile(
            label: 'CUSTOM CARD PADDING',
            value: setup.padding != null,
            onChanged: (final enable) {
              context.read<SetupBloc>().add(
                    UpdateQueue(
                      position,
                      setup.copyWith(
                        padding: enable ? 8.0 : null,
                        clearPadding: !enable,
                      ),
                    ),
                  );
            },
          ),
          if (setup.padding != null) ...[
            const SizedBox(height: 12),
            StudioSliderTile(
              label: 'CARD INTERNAL PADDING (PX)',
              value: setup.padding!,
              min: 0,
              max: 24,
              divisions: 24,
              onChanged: (final v) => context.read<SetupBloc>().add(
                    UpdateQueue(
                      position,
                      setup.copyWith(padding: v),
                    ),
                  ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Bounds & Strategy ──
          const StudioSectionHeader(title: 'BOUNDS & TRANSITION'),
          StudioToggleTile(
            label: 'CUSTOM MAX WIDTH',
            value: setup.maxWidth != null,
            onChanged: (final enable) {
              context.read<SetupBloc>().add(
                    UpdateQueue(
                      position,
                      setup.copyWith(
                        maxWidth: enable ? 360.0 : null,
                        clearMaxWidth: !enable,
                      ),
                    ),
                  );
            },
          ),
          if (setup.maxWidth != null) ...[
            const SizedBox(height: 12),
            StudioSliderTile(
              label: 'MAX CARD WIDTH (PX)',
              value: setup.maxWidth!,
              min: 200,
              max: 600,
              divisions: 40,
              onChanged: (final v) => context.read<SetupBloc>().add(
                    UpdateQueue(
                      position,
                      setup.copyWith(maxWidth: v),
                    ),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          StudioDropdownTile<Type>(
            label: 'TRANSITION STRATEGY',
            value: setup.transitionType,
            items: _transitionTypes,
            itemLabel: (final t) => switch (t) {
              == SlideTransitionStrategy => 'SLIDE',
              == FadeTransitionStrategy => 'FADE',
              == ScaleTransitionStrategy => 'SCALE',
              _ =>
                t.toString().replaceAll('TransitionStrategy', '').toUpperCase(),
            },
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(transitionType: v),
                  ),
                ),
          ),
        ],
      );

  Widget _buildGesturesCategory(
    final BuildContext context,
    final QueuePosition position,
    final QueueSetup setup,
    final Set<QueuePosition> activePositions,
    final Set<QueuePosition> otherQueuesSlaves,
  ) {
    final colorScheme = StudioTheme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setup.dragBehaviorType == setup.longPressBehaviorType &&
            setup.dragBehaviorType != Disabled) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.secondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Both gestures are set to '
                    '${_formatBehaviorType(setup.dragBehaviorType)}. '
                    'You might want to use different behaviors for better '
                    'interaction.',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        StudioDropdownTile<Type>(
          label: 'DRAG BEHAVIOR',
          value: setup.dragBehaviorType,
          items: _behaviorTypes.where((final e) {
            if (e == Relocate || e == ReorderAndRelocate) {
              return activePositions.length < QueuePosition.values.length ||
                  setup.dragBehaviorType == e;
            }
            return true;
          }).toList(),
          itemLabel: _formatBehaviorType,
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(dragBehaviorType: v),
                ),
              ),
        ),
        if (setup.dragBehaviorType == Relocate ||
            setup.dragBehaviorType == ReorderAndRelocate) ...[
          const SizedBox(height: 12),
          RelocationSelector(
            selected: setup.relocateTargets,
            activePositions: activePositions,
            otherQueuesSlaves: otherQueuesSlaves,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(relocateTargets: v),
                  ),
                ),
          ),
          const SizedBox(height: 8),
          StudioToggleTile(
            label: 'PERMANENT QUEUE RELOCATION',
            value: setup.relocatePermanent,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(relocatePermanent: v),
                  ),
                ),
          ),
        ],
        if (setup.dragBehaviorType == Dismiss) ...[
          const SizedBox(height: 12),
          StudioDropdownTile<DismissZone>(
            label: 'DRAG DISMISS ZONE',
            value: setup.dragDismissZone,
            items: DismissZone.values,
            itemLabel: (final e) => switch (e) {
              DismissZone.sideEdges => 'SIDE EDGES (LEFT / RIGHT)',
              DismissZone.naturalDirection => 'NATURAL DIRECTION (UP / DOWN)',
            },
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(dragDismissZone: v),
                  ),
                ),
          ),
        ],
        if (setup.dragBehaviorType == Snooze) ...[
          const SizedBox(height: 12),
          StudioSliderTile(
            label: 'DRAG SNOOZE DURATION: ${setup.dragSnoozeSeconds}s',
            value: setup.dragSnoozeSeconds.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(dragSnoozeSeconds: v.round()),
                  ),
                ),
          ),
        ],
        const SizedBox(height: 12),
        StudioDropdownTile<Type>(
          label: 'LONG PRESS DRAG BEHAVIOR',
          value: setup.longPressBehaviorType,
          items: _behaviorTypes.where((final e) {
            if (e == Relocate || e == ReorderAndRelocate) {
              return activePositions.length < QueuePosition.values.length ||
                  setup.longPressBehaviorType == e;
            }
            return true;
          }).toList(),
          itemLabel: _formatBehaviorType,
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(longPressBehaviorType: v),
                ),
              ),
        ),
        if (setup.longPressBehaviorType == Relocate ||
            setup.longPressBehaviorType == ReorderAndRelocate) ...[
          const SizedBox(height: 12),
          RelocationSelector(
            selected: setup.relocateTargets,
            activePositions: activePositions,
            otherQueuesSlaves: otherQueuesSlaves,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(relocateTargets: v),
                  ),
                ),
          ),
          const SizedBox(height: 8),
          StudioToggleTile(
            label: 'PERMANENT QUEUE RELOCATION',
            value: setup.relocatePermanent,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(relocatePermanent: v),
                  ),
                ),
          ),
        ],
        if (setup.longPressBehaviorType == Dismiss) ...[
          const SizedBox(height: 12),
          StudioDropdownTile<DismissZone>(
            label: 'LONG PRESS DISMISS ZONE',
            value: setup.longPressDismissZone,
            items: DismissZone.values,
            itemLabel: (final e) => switch (e) {
              DismissZone.sideEdges => 'SIDE EDGES (LEFT / RIGHT)',
              DismissZone.naturalDirection => 'NATURAL DIRECTION (UP / DOWN)',
            },
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(longPressDismissZone: v),
                  ),
                ),
          ),
        ],
        if (setup.longPressBehaviorType == Snooze) ...[
          const SizedBox(height: 12),
          StudioSliderTile(
            label: 'LONG-PRESS SNOOZE: ${setup.longPressSnoozeSeconds}s',
            value: setup.longPressSnoozeSeconds.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(longPressSnoozeSeconds: v.round()),
                  ),
                ),
          ),
        ],
        const SizedBox(height: 12),
        StudioDropdownTile<Type>(
          label: 'CLOSE BUTTON VISIBILITY',
          value: setup.closeButtonBehaviorType,
          items: _closeButtonTypes,
          itemLabel: (final e) => switch (e) {
            == AlwaysVisible => 'ALWAYS VISIBLE',
            == VisibleOnHover => 'VISIBLE ON HOVER',
            == Hidden => 'HIDDEN',
            _ => e.toString().toUpperCase(),
          },
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(closeButtonBehaviorType: v),
                ),
              ),
        ),
        const SizedBox(height: 12),
        StudioDropdownTile<Type>(
          label: 'TAP BEHAVIOR',
          value: setup.tapBehaviorType,
          items: _tapBehaviorTypes,
          itemLabel: (final e) => switch (e) {
            == TapToDismiss => 'DISMISS',
            == TapToExpand => 'EXPAND / COLLAPSE',
            == TapToAct => 'ACT (CALLBACK)',
            == TapDisabled => 'DISABLED',
            _ => e.toString().toUpperCase(),
          },
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(tapBehaviorType: v),
                ),
              ),
        ),
        if (setup.tapBehaviorType == TapToAct) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code_rounded,
                  size: 13,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'In production, supply a TapToAct(onTap: fn) '
                    'callback on the queue or per-notification.',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStackingCategory(
    final BuildContext context,
    final QueuePosition position,
    final QueueSetup setup,
  ) {
    final colorScheme = StudioTheme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stack Geometry & Margins ──
        const StudioSectionHeader(title: 'STACK SPACING & MARGINS'),
        StudioSliderTile(
          label: 'INTER-CARD SPACING (PX)',
          value: setup.spacing,
          min: 0,
          max: 24,
          divisions: 24,
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(spacing: v),
                ),
              ),
        ),
        const SizedBox(height: 12),
        StudioSliderTile(
          label: 'VERTICAL SCREEN MARGIN (PX)',
          value: setup.verticalMargin,
          min: 0,
          max: 64,
          divisions: 32,
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(verticalMargin: v),
                ),
              ),
        ),
        const SizedBox(height: 12),
        StudioSliderTile(
          label: 'HORIZONTAL SCREEN MARGIN (PX)',
          value: setup.horizontalMargin,
          min: 0,
          max: 64,
          divisions: 32,
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(horizontalMargin: v),
                ),
              ),
        ),
        const SizedBox(height: 12),
        StudioSliderTile(
          label: 'MAX VISIBLE NOTIFICATIONS',
          value: setup.maxStackSize.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          onChanged: (final v) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(maxStackSize: v.round()),
                ),
              ),
        ),
        const SizedBox(height: 16),

        // ── Bundling & Grouping ──
        const StudioSectionHeader(title: 'GROUPING & BUNDLING'),
        StudioToggleTile(
          label: 'ENABLE BUNDLING',
          value: setup.groupingEnabled,
          onChanged: (final enable) => context.read<SetupBloc>().add(
                UpdateQueue(
                  position,
                  setup.copyWith(groupingEnabled: enable),
                ),
              ),
        ),
        if (setup.groupingEnabled) ...[
          const SizedBox(height: 12),
          StudioSliderTile(
            label: 'BUNDLE AFTER (N CARDS)',
            value: setup.groupingThreshold.toDouble(),
            min: 2,
            max: 10,
            divisions: 8,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(groupingThreshold: v.round()),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          StudioDropdownTile<GroupCountType>(
            label: 'GROUP COUNT STRATEGY',
            value: setup.groupingCountType,
            items: GroupCountType.values,
            itemLabel: (final type) => type.label,
            onChanged: (final type) {
              if (type != null) {
                context.read<SetupBloc>().add(
                      UpdateQueue(
                        position,
                        setup.copyWith(groupingCountType: type),
                      ),
                    );
              }
            },
          ),
          if (setup.groupingCountType != GroupCountType.noCount) ...[
            const SizedBox(height: 12),
            StudioToggleTile(
              label: 'COUNT BACKLOG PENDING',
              value: setup.groupingCountIncludePending,
              onChanged: (final v) => context.read<SetupBloc>().add(
                    UpdateQueue(
                      position,
                      setup.copyWith(groupingCountIncludePending: v),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            StudioSliderTile(
              label: 'MAX COUNT CAP (OVERFLOW: '
                  '${setup.groupingCountMaxCount})',
              value: setup.groupingCountMaxCount.toDouble(),
              min: 5,
              max: 99,
              divisions: 94,
              onChanged: (final v) => context.read<SetupBloc>().add(
                    UpdateQueue(
                      position,
                      setup.copyWith(groupingCountMaxCount: v.round()),
                    ),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          _GroupCountLivePreview(setup: setup),
          const SizedBox(height: 14),
          StudioToggleTile(
            label: 'PAUSE TIMERS WHEN EXPANDED',
            value: setup.groupingPauseTimers,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(groupingPauseTimers: v),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          StudioSliderTile(
            label: 'STACK DEPTH LAYERS (${setup.groupingMaxLayers})',
            value: setup.groupingMaxLayers.toDouble(),
            min: 1,
            max: 4,
            divisions: 3,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(groupingMaxLayers: v.round()),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          StudioToggleTile(
            label: 'SWIPE DISMISS WHOLE BUNDLE',
            value: setup.groupingSwipeDismiss,
            onChanged: (final v) => context.read<SetupBloc>().add(
                  UpdateQueue(
                    position,
                    setup.copyWith(groupingSwipeDismiss: v),
                  ),
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.secondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.layers_outlined,
                    size: 13,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cards sharing the same channelName (or groupKey) '
                    'collapse into a bundle once their count reaches the '
                    'threshold. Swipe the visible card — only that one '
                    'exits. Hidden members’ timers are suspended while '
                    'off-screen.',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _DismissGroupButton(position: position),
        ] else ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'When bundling is disabled, notifications stack '
                    'individually up to the Max Visible limit set in '
                    'Anatomy & Bounds.',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A compact action button in the GROUPING section that calls
/// [NotificationController.dismissGroup] for the 'chat'
/// channel group key.
///
/// Demonstrates the explicit bulk-dismiss API introduced in G-03.
class _DismissGroupButton extends StatelessWidget {
  const _DismissGroupButton({required this.position});

  final QueuePosition position;

  /// The group key used by the Chat Burst / Group Dismiss scenarios.
  static const _defaultGroupKey = 'chat';

  @override
  Widget build(final BuildContext context) => SizedBox(
        width: double.infinity,
        child: Tooltip(
          message: "Calls coordinator.dismissGroup('$_defaultGroupKey') — "
              'clears the entire bundle atomically.',
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF06B6D4)
                  : const Color(0xFF0E7490),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF06B6D4)
                    : const Color(0xFF0E7490),
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF06B6D4)
                      : const Color(0xFF0E7490))
                  .withValues(alpha: 0.06),
            ),
            icon: const Icon(Icons.layers_clear_outlined, size: 14),
            label: const Text('DISMISS ACTIVE GROUP'),
            onPressed: () => NotificationScope.of(context).dismissGroup(
              _defaultGroupKey,
            ),
          ),
        ),
      );
}

/// A validation dialog to confirm removal of a queue position, warning about
/// any affected channels.
void _showConfirmDeleteDialog(
  final BuildContext context,
  final QueuePosition position,
  final List<ChannelSetup> channels,
  final VoidCallback onConfirm,
) {
  final colorScheme = StudioTheme.colorScheme;
  final affectedChannels = channels
      .where((final c) => c.position == position)
      .map((final c) => c.name.toUpperCase())
      .toList();

  showDialog(
    context: context,
    builder: (final ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text('Delete Queue Position?'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to remove the queue at '
            '${position.name.toUpperCase()}?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'This will delete its configuration, and any notifications routed '
            'here will fallback to the remaining active queues.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          if (affectedChannels.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'AFFECTED CHANNELS:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 4),
            ...affectedChannels.map(
              (final name) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 12,
                      color: colorScheme.error.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cancel',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

/// An interactive widget in QueueSection that renders a live preview of the
/// group toggle pill based on current [GroupCountType] and settings.
class _GroupCountLivePreview extends StatefulWidget {
  const _GroupCountLivePreview({required this.setup});

  final QueueSetup setup;

  @override
  State<_GroupCountLivePreview> createState() => _GroupCountLivePreviewState();
}

class _GroupCountLivePreviewState extends State<_GroupCountLivePreview> {
  bool _simulateOverflow = false;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sampleTotal = _simulateOverflow ? 120 : 3;
    final sampleHidden = sampleTotal - 1;

    final countBehavior = switch (widget.setup.groupingCountType) {
      GroupCountType.hiddenCount => HiddenCount(
          maxCount: widget.setup.groupingCountMaxCount,
          includePending: widget.setup.groupingCountIncludePending,
        ),
      GroupCountType.totalCount => TotalCount(
          maxCount: widget.setup.groupingCountMaxCount,
          includePending: widget.setup.groupingCountIncludePending,
        ),
      GroupCountType.noCount => const NoCount(),
    };

    final badgeLabel = countBehavior.format(
      totalCount: sampleTotal,
      hiddenCount: sampleHidden,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.12)
            : colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview_outlined,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE BADGE PILL PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() {
                  _simulateOverflow = !_simulateOverflow;
                }),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _simulateOverflow
                        ? colorScheme.primary.withValues(alpha: 0.2)
                        : colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _simulateOverflow ? '120 items (overflow)' : '3 items',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _simulateOverflow
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Alice',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.textTheme.labelSmall?.color
                          ?.withValues(alpha: 0.5),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      'Meeting update...',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.labelSmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badgeLabel != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
