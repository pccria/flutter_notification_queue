import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../bloc/notification_bloc.dart';
import '../bloc/setup_bloc.dart';
import '../models/channel_setup.dart';
import '../studio_theme.dart';

/// A reactive, live in-place preview of the current notification draft.
///
/// Reflects the exact 3-gear cascading theme resolution:
/// 1. **Queue Style**: Filled, Outlined, Flat, and glassmorphic opacity.
/// 2. **Channel Theme**: Color, icon, typography.
/// 3. **Notification Overrides**: Title, message, priority, accent tint,
///    action.
///
/// Operates purely as a presentational sandbox with zero dismiss timers
/// and zero queue side-effects.
class LiveCardPreview extends StatelessWidget {
  const LiveCardPreview({
    required this.setupState,
    required this.draft,
    super.key,
  });

  final SetupState setupState;
  final NotificationDraft draft;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;
    final isDark = StudioTheme.isDark;

    // Resolve channel setup
    final channelSetup = setupState.setup.channels[draft.channelName] ??
        const ChannelSetup(name: 'default');
    final channel = channelSetup.toNotificationChannel();

    // Resolve target position and relocation
    final coordinator = NotificationScope.maybeCoordinatorOf(context);
    final targetPosition = draft.positionOverride ??
        channelSetup.position ??
        setupState.activeQueuePosition;
    final effectivePosition =
        coordinator?.configuration.getEffectiveQueuePosition(targetPosition) ??
            targetPosition;
    final isRelocated = effectivePosition != targetPosition;

    // Resolve queue setup & style
    final queueSetup = setupState.setup.queues[effectivePosition] ??
        setupState.setup.queues[targetPosition];
    final queueStyle = queueSetup?.toQueueStyle() ?? const FilledQueueStyle();

    // Resolve theme cascade
    final theme = NotificationTheme.resolveWith(
      context,
      queueStyle,
      null,
      channel,
      draft.accentColorOverride,
    );

    final styleName = switch (queueStyle) {
      FilledQueueStyle() =>
        queueStyle.opacity < 1.0 ? 'FILLED (GLASS)' : 'FILLED',
      OutlinedQueueStyle() =>
        queueStyle.opacity < 1.0 ? 'OUTLINE (GLASS)' : 'OUTLINE',
      FlatQueueStyle() => queueStyle.opacity < 1.0 ? 'FLAT (GLASS)' : 'FLAT',
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
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
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE CARD PREVIEW',
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
                    _Badge(
                      label: styleName,
                      color: colorScheme.primary,
                    ),
                    _Badge(
                      label: isRelocated
                          ? '${targetPosition.name.toUpperCase()} ➔ '
                              '${effectivePosition.name.toUpperCase()}'
                          : targetPosition.name.toUpperCase(),
                      color: isRelocated ? Colors.amber : colorScheme.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // ── Preview Viewport (Checker / Ambient Canvas) ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: _CardCanvas(
              theme: theme,
              draft: draft,
              channelSetup: channelSetup,
              channel: channel,
            ),
          ),

          // ── Bottom Action Toolbar ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: Text(
                      defaultTargetPlatform == TargetPlatform.macOS
                          ? 'FIRE DRAFT (⌘↵)'
                          : 'FIRE DRAFT (Ctrl+↵)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    onPressed: () {
                      context.read<NotificationBloc>().add(const FirePreview());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Reset Draft to Defaults',
                  child: IconButton.outlined(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    onPressed: () {
                      context.read<NotificationBloc>().add(const ResetDraft());
                    },
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

// ── Preview Card Canvas ─────────────────────────────────────────────────────

class _CardCanvas extends StatelessWidget {
  const _CardCanvas({
    required this.theme,
    required this.draft,
    required this.channelSetup,
    required this.channel,
  });

  final NotificationTheme theme;
  final NotificationDraft draft;
  final ChannelSetup channelSetup;
  final NotificationChannel channel;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedColor = theme.backgroundColor.withValues(
      alpha: theme.opacity.clamp(0.0, 1.0),
    );

    final cardContent = Padding(
      padding: theme.padding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Icon + Title + Priority/Permanent Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconTheme(
                data: theme.iconTheme ??
                    IconThemeData(
                      color: theme.foregroundColor,
                      size: 18,
                    ),
                child: channelSetup.iconPreset.toWidget() ??
                    channel.defaultIcon ??
                    Icon(
                      Icons.notifications_outlined,
                      size: 18,
                      color: theme.foregroundColor,
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draft.title.isEmpty ? 'Notification' : draft.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleTextStyle ??
                      TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.foregroundColor,
                      ),
                ),
              ),
              if (draft.priority != null) ...[
                const SizedBox(width: 6),
                _PriorityBadge(priority: draft.priority!),
              ],
              if (draft.permanent) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, size: 9, color: Colors.amber),
                      SizedBox(width: 3),
                      Text(
                        'PINNED',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Message Body
          Text(
            draft.message.isEmpty ? 'Message body...' : draft.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.messageTextStyle ??
                TextStyle(
                  fontSize: 12,
                  color: theme.foregroundColor.withValues(alpha: 0.82),
                  height: 1.35,
                ),
          ),

          // Action Button (if configured)
          if (draft.actionStyle == NotificationActionStyle.button) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.foregroundColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.foregroundColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  draft.actionLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: theme.foregroundColor,
                  ),
                ),
              ),
            ),
          ],

          // Auto-dismiss countdown bar indicator
          if (!draft.permanent && draft.dismissSeconds != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 0.65,
                minHeight: 2.5,
                backgroundColor: theme.foregroundColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.foregroundColor.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Apply Material & Optional Blur for Glassmorphism
    final isGlass = theme.opacity < 1.0;

    return Container(
      decoration: BoxDecoration(
        // Checker background to make glassmorphism instantly apparent
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E222D), const Color(0xFF151821)]
              : [const Color(0xFFE2E6EE), const Color(0xFFD6DBE4)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      alignment: Alignment.center,
      child: ClipPath(
        clipper: theme.shape != null ? _ShapeClipper(theme.shape!) : null,
        child: isGlass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  shape: theme.shape,
                  color: resolvedColor,
                  elevation: theme.elevation,
                  shadowColor: theme.shadowColor,
                  child: cardContent,
                ),
              )
            : Material(
                shape: theme.shape,
                color: resolvedColor,
                elevation: theme.elevation,
                shadowColor: theme.shadowColor,
                child: cardContent,
              ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper(this.shape);
  final ShapeBorder shape;

  @override
  Path getClip(final Size size) =>
      shape.getOuterPath(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  bool shouldReclip(covariant final _ShapeClipper oldClipper) =>
      oldClipper.shape != shape;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      );
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final NotificationPriority priority;

  @override
  Widget build(final BuildContext context) {
    final color = switch (priority) {
      NotificationPriority.low => Colors.blue,
      NotificationPriority.normal => Colors.green,
      NotificationPriority.high => Colors.orange,
      NotificationPriority.critical => Colors.redAccent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        priority.name.toUpperCase(),
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
