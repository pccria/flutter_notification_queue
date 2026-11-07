import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../../bloc/notification_bloc.dart';
import '../../bloc/setup_bloc.dart';
import '../../studio_theme.dart';
import '../../widgets/live_card_preview.dart';
import '../../widgets/live_stage_radar.dart';
import '../../widgets/resolution_inspector.dart';
import '../../widgets/studio_dropdown_tile.dart';
import '../../widgets/studio_section_header.dart';
import '../../widgets/studio_slider_tile.dart';
import '../../widgets/studio_text_field.dart';
import '../../widgets/studio_toggle_tile.dart';

class PreviewSection extends StatelessWidget {
  const PreviewSection({
    required this.setupState,
    required this.draft,
    super.key,
  });

  final SetupState setupState;
  final NotificationDraft draft;

  @override
  Widget build(final BuildContext context) {
    final channelNames = setupState.setup.channels.keys.toList();
    final colorScheme = StudioTheme.colorScheme;

    final channelSetup = setupState.setup.channels[draft.channelName];
    final targetPosition = draft.positionOverride ??
        channelSetup?.position ??
        setupState.activeQueuePosition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LIVE DRAFT CARD PREVIEW ──
        LiveCardPreview(
          setupState: setupState,
          draft: draft,
        ),
        const SizedBox(height: 16),

        _RoutingPipelineBadge(
          channelName: draft.channelName,
          targetPosition: targetPosition,
          isOverridden: draft.positionOverride != null,
        ),
        const SizedBox(height: 10),

        // ── Cascade Resolution Inspector (Gears) ──
        ResolutionInspector(
          setupState: setupState,
          draft: draft,
        ),
        const SizedBox(height: 12),

        // ── Channel Selector ──
        if (channelNames.isNotEmpty)
          StudioDropdownTile<String>(
            label: 'SELECT CHANNEL',
            value: channelNames.contains(draft.channelName)
                ? draft.channelName
                : channelNames.first,
            items: channelNames,
            itemLabel: (final e) => e.toUpperCase(),
            onChanged: (final v) =>
                context.read<NotificationBloc>().add(SelectPreviewChannel(v!)),
          ),
        if (!channelNames.contains(draft.channelName))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 14,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Channel "${draft.channelName}" not configured. '
                    'NFQ will use the system default fallback.',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // ── Dispatch Target Position ──
        StudioDropdownTile<QueuePosition?>(
          label: 'DISPATCH TARGET POSITION (targetPosition)',
          value: draft.positionOverride,
          items: const [null, ...QueuePosition.values],
          itemLabel: (final e) =>
              e == null ? 'CHANNEL DEFAULT' : e.name.toUpperCase(),
          onChanged: (final v) =>
              context.read<NotificationBloc>().add(SelectPreviewPosition(v)),
        ),
        const SizedBox(height: 12),

        // ── Priority ──
        StudioDropdownTile<NotificationPriority?>(
          label: 'PRIORITY TRIAGE',
          value: draft.priority,
          items: const [null, ...NotificationPriority.values],
          itemLabel: (final e) =>
              e == null ? 'CHANNEL DEFAULT' : e.name.toUpperCase(),
          onChanged: (final v) =>
              context.read<NotificationBloc>().add(UpdatePriority(v)),
        ),
        const SizedBox(height: 12),

        // ── Content ──
        StudioTextField(
          label: 'NOTIFICATION TITLE',
          initial: draft.title,
          onChanged: (final v) =>
              context.read<NotificationBloc>().add(UpdateTitle(v)),
        ),
        const SizedBox(height: 12),
        StudioTextField(
          label: 'MESSAGE BODY',
          initial: draft.message,
          maxLines: 3,
          onChanged: (final v) =>
              context.read<NotificationBloc>().add(UpdateMessage(v)),
        ),
        // ── Gear 2: Notification Accent Tint Override (Experimental) ──
        _NotificationAccentOverrideTile(
          draft: draft,
          setupState: setupState,
        ),
        const SizedBox(height: 12),
        StudioToggleTile(
          label: 'PERMANENT (STAYS UNTIL DISMISSED)',
          value: draft.permanent,
          onChanged: (final v) => context.read<NotificationBloc>().add(
                UpdatePermanent(permanent: v),
              ),
        ),
        const SizedBox(height: 12),

        // ── Action ──
        StudioDropdownTile<NotificationActionStyle>(
          label: 'ACTION TYPE',
          value: draft.actionStyle,
          items: NotificationActionStyle.values,
          itemLabel: (final e) => e.name.toUpperCase(),
          onChanged: (final v) => context
              .read<NotificationBloc>()
              .add(UpdateNotificationActionStyle(v!)),
        ),
        if (draft.actionStyle == NotificationActionStyle.button) ...[
          const SizedBox(height: 12),
          StudioTextField(
            label: 'BUTTON LABEL',
            initial: draft.actionLabel,
            onChanged: (final v) =>
                context.read<NotificationBloc>().add(UpdateActionLabel(v)),
          ),
        ],
        if (draft.actionStyle == NotificationActionStyle.onTap)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tapping anywhere on the notification fires the action.',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // ── Auto-Dismiss ──
        StudioSliderTile(
          label: draft.dismissSeconds == null
              ? 'AUTO-DISMISS: PERMANENT'
              : 'AUTO-DISMISS: ${draft.dismissSeconds}s',
          value: (draft.dismissSeconds ?? 0).toDouble(),
          min: 0,
          max: 30,
          divisions: 30,
          onChanged: (final v) => context.read<NotificationBloc>().add(
                UpdateDismissDuration(v == 0 ? null : v.round()),
              ),
        ),
        if (draft.dismissSeconds == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: colorScheme.secondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Permanent — user must dismiss manually. '
                  'Requires a dismiss gesture or close button.',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // ── Cockpit Firing Hint ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Draft armed. Fire via Top Cockpit or ⌘↵ / Ctrl+Enter',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── LIVE STAGE RADAR & STATUS ──
        LiveStageRadar(setupState: setupState),
        const SizedBox(height: 20),

        // ── Programmatic Control ──
        _ProgrammaticControls(setupState: setupState),
      ],
    );
  }
}

class _ProgrammaticControls extends StatefulWidget {
  const _ProgrammaticControls({required this.setupState});

  final SetupState setupState;

  @override
  State<_ProgrammaticControls> createState() => _ProgrammaticControlsState();
}

class _ProgrammaticControlsState extends State<_ProgrammaticControls> {
  AppNotification? _activeDemo;
  QueuePosition? _activePosition;
  bool _isPinned = false;

  void _fireDemo() {
    final id = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    final channelName = widget.setupState.setup.channels.keys.first;
    final channel = widget.setupState.setup.channels[channelName];
    final pos = channel?.position ?? widget.setupState.activeQueuePosition;
    final n = AppNotification(
      id: id,
      title: 'Programmatic Demo',
      message: 'Keep an eye on me! I can be snoozed, pinned, or relocated.',
      channelName: channelName,
      dismissDuration: const Duration(seconds: 20),
    );
    NotificationScope.of(context).show(n);
    setState(() {
      _activeDemo = n;
      _activePosition = pos;
      _isPinned = false;
    });
  }

  void _dismissDemo() {
    if (_activeDemo != null) {
      NotificationScope.of(context).dismiss(_activeDemo!);
      setState(() {
        _activeDemo = null;
        _activePosition = null;
        _isPinned = false;
      });
    }
  }

  void _snoozeDemo() {
    if (_activeDemo != null) {
      NotificationScope.of(context).snooze(
        _activeDemo!,
        const Duration(seconds: 5),
      );
    }
  }

  void _togglePinDemo() {
    if (_activeDemo == null) {
      return;
    }
    final scope = NotificationScope.of(context);
    if (_isPinned) {
      scope.unpin(_activeDemo!);
      setState(() => _isPinned = false);
    } else {
      scope.pin(_activeDemo!);
      setState(() => _isPinned = true);
    }
  }

  void _relocateDemo() {
    if (_activeDemo == null) {
      return;
    }

    final queues = widget.setupState.setup.queues.keys.toList();
    if (queues.length < 2) {
      return;
    }

    // Find a queue that is different from current
    final currentPos = _activePosition ?? queues.first;
    final targetPos = queues.firstWhere(
      (final q) => q != currentPos,
      orElse: () => queues.last,
    );

    NotificationScope.of(context).relocate(_activeDemo!, targetPos);
    setState(() {
      _activePosition = targetPos;
    });
  }

  @override
  Widget build(final BuildContext context) {
    final queues = widget.setupState.setup.queues.keys.toList();
    final canRelocate = queues.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudioSectionHeader(title: 'PROGRAMMATIC CONTROL'),
        const SizedBox(height: 12),
        if (_activeDemo == null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.code),
              label: const Text('FIRE PROGRAMMATIC DEMO'),
              onPressed: _fireDemo,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: StudioTheme.colorScheme.error,
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('DISMISS'),
                onPressed: _dismissDemo,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFB7185), // rose/snooze color
                ),
                icon: const Icon(Icons.snooze_rounded, size: 16),
                label: const Text('SNOOZE 5s'),
                onPressed: _snoozeDemo,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B), // amber
                ),
                icon: Icon(
                  _isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  size: 16,
                ),
                label: Text(_isPinned ? 'UNPIN' : 'PIN'),
                onPressed: _togglePinDemo,
              ),
              if (canRelocate)
                OutlinedButton.icon(
                  icon: const Icon(Icons.multiple_stop, size: 16),
                  label: const Text('RELOCATE'),
                  onPressed: _relocateDemo,
                ),
            ],
          ),
      ],
    );
  }
}

class _NotificationAccentOverrideTile extends StatelessWidget {
  const _NotificationAccentOverrideTile({
    required this.draft,
    required this.setupState,
  });

  final NotificationDraft draft;
  final SetupState setupState;

  static const _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Rose
    Color(0xFF06B6D4), // Cyan
    Color(0xFF8B5CF6), // Purple
  ];

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;
    final hasOverride = draft.accentColorOverride != null;
    final channelSetup = setupState.setup.channels[draft.channelName];
    final channelAccent = channelSetup?.theme?.color ??
        channelSetup?.color ??
        colorScheme.primary;
    final effectiveAccent = draft.accentColorOverride ?? channelAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: effectiveAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: effectiveAccent.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasOverride
                      ? 'ACCENT TINT (EXPERIMENTAL): ACTIVE'
                      : 'ACCENT TINT: INHERITED FROM #${draft.channelName}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (hasOverride)
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Reset to channel accent',
                  onPressed: () => context
                      .read<NotificationBloc>()
                      .add(const UpdateAccentColorOverride(null)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final color in _palette) ...[
                InkWell(
                  onTap: () => context
                      .read<NotificationBloc>()
                      .add(UpdateAccentColorOverride(color)),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: draft.accentColorOverride == color
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (draft.accentColorOverride == color)
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutingPipelineBadge extends StatelessWidget {
  const _RoutingPipelineBadge({
    required this.channelName,
    required this.targetPosition,
    required this.isOverridden,
  });

  final String channelName;
  final QueuePosition targetPosition;
  final bool isOverridden;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alt_route_rounded,
            size: 13,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '#$channelName',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isOverridden
                      ? const Color(0xFFEC4899)
                      : const Color(0xFF10B981))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: (isOverridden
                        ? const Color(0xFFEC4899)
                        : const Color(0xFF10B981))
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              targetPosition.name.toUpperCase() +
                  (isOverridden ? ' (OVERRIDE)' : ''),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: isOverridden
                    ? const Color(0xFFEC4899)
                    : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
