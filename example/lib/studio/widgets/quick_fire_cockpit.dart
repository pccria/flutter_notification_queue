import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../bloc/notification_bloc.dart';
import '../bloc/setup_bloc.dart';
import '../models/queue_setup.dart';
import '../studio_theme.dart';

/// A persistent, tactile quick-action toolbar that allows developers to
/// fire the current draft, quick presets, bursts, or clear the stage
/// from anywhere in NFQ Studio without scrolling.
class QuickFireCockpit extends StatelessWidget {
  const QuickFireCockpit({super.key});

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;
    final isDark = StudioTheme.isDark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.92)
            : colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        children: [
          // ── Primary Action: Fire Draft ──
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FIRE DRAFT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    defaultTargetPlatform == TargetPlatform.macOS
                        ? '⌘↵'
                        : 'Ctrl+↵',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () =>
                context.read<NotificationBloc>().add(const FirePreview()),
          ),
          const SizedBox(width: 10),

          VerticalDivider(
            width: 1,
            indent: 4,
            endIndent: 4,
            color: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 10),

          // ── Quick Presets ──
          _CockpitChip(
            label: 'Info',
            icon: Icons.info_outline,
            accentColor: const Color(0xFF51B4F9),
            onTap: () => _fireQuickPreset(
              context,
              channelName: 'info',
              title: 'System Information',
              message: 'Background synchronization completed cleanly.',
            ),
          ),
          const SizedBox(width: 6),
          _CockpitChip(
            label: 'Success',
            icon: Icons.check_circle_outline,
            accentColor: const Color(0xFF2D7512),
            onTap: () => _fireQuickPreset(
              context,
              channelName: 'success',
              title: 'Payment Confirmed',
              message: 'Invoice #1084 settled for \$140.00.',
            ),
          ),
          const SizedBox(width: 6),
          _CockpitChip(
            label: 'Warning',
            icon: Icons.warning_amber_rounded,
            accentColor: const Color(0xFFC97725),
            onTap: () => _fireQuickPreset(
              context,
              channelName: 'warning',
              title: 'Storage Warning',
              message: 'Disk volume reached 92% capacity.',
            ),
          ),
          const SizedBox(width: 6),
          _CockpitChip(
            label: 'Critical',
            icon: Icons.error_outline,
            accentColor: const Color(0xFFD03332),
            onTap: () => _fireQuickPreset(
              context,
              channelName: 'error',
              priority: NotificationPriority.high,
              title: 'Database Outage',
              message: 'Connection pool exhausted on replica 2.',
            ),
          ),
          const SizedBox(width: 6),
          _CockpitChip(
            label: 'Pinned',
            icon: Icons.push_pin_outlined,
            accentColor: const Color(0xFF8B5CF6),
            onTap: () => _fireQuickPreset(
              context,
              channelName: 'info',
              permanent: true,
              title: 'Update In Progress',
              message: 'Applying firmware update 2.4.0. Stays until dismissed.',
            ),
          ),
          const SizedBox(width: 10),

          VerticalDivider(
            width: 1,
            indent: 4,
            endIndent: 4,
            color: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 10),

          // ── Stacking & Stress Test ──
          _CockpitChip(
            label: 'Burst 3x',
            icon: Icons.auto_awesome_motion_rounded,
            accentColor: const Color(0xFFEC4899),
            onTap: () => _fireBurst(context),
          ),
          const SizedBox(width: 6),
          _CockpitChip(
            label: 'Group 4x',
            icon: Icons.layers_outlined,
            accentColor: const Color(0xFF0EA5E9),
            onTap: () => _fireGroupBurst(context),
          ),
          const SizedBox(width: 6),

          // ── Stage Utility: Clear All ──
          IconButton(
            icon: const Icon(Icons.clear_all_rounded, size: 18),
            tooltip: 'Dismiss all active notifications',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
            onPressed: () {
              context.read<SetupBloc>().controller.dismissAll();
            },
          ),
        ],
      ),
    );
  }

  static void _fireQuickPreset(
    final BuildContext context, {
    required final String channelName,
    required final String title,
    required final String message,
    final NotificationPriority? priority,
    final bool permanent = false,
  }) {
    final setupBloc = context.read<SetupBloc>();
    final channelSetup = setupBloc.state.setup.channels[channelName];
    final targetPosition =
        channelSetup?.position ?? setupBloc.state.activeQueuePosition;

    setupBloc.controller.show(
      AppNotification(
        title: title,
        message: message,
        channelName: channelName,
        priority: priority,
        permanent: permanent,
        dismissDuration: permanent ? null : const Duration(seconds: 5),
      ),
      targetPosition: targetPosition,
    );
  }

  static void _fireBurst(final BuildContext context) {
    final setupBloc = context.read<SetupBloc>();
    final targetPosition = setupBloc.state.activeQueuePosition;

    final samples = [
      ('Synchronizing cache...', 'info'),
      ('Validated integrity hashes', 'success'),
      ('Live reload triggered', 'warning'),
    ];

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      Timer(Duration(milliseconds: i * 160), () {
        setupBloc.controller.show(
          AppNotification(
            title: 'Burst alert #${i + 1}',
            message: sample.$1,
            channelName: sample.$2,
            dismissDuration: const Duration(seconds: 6),
          ),
          targetPosition: targetPosition,
        );
      });
    }
  }

  static void _fireGroupBurst(final BuildContext context) {
    final setupBloc = context.read<SetupBloc>();
    final targetPosition = setupBloc.state.activeQueuePosition;

    final currentQueue =
        setupBloc.state.setup.queues[targetPosition] ?? const QueueSetup();
    if (!currentQueue.groupingEnabled) {
      setupBloc.add(
        AddQueue(
          targetPosition,
          currentQueue.copyWith(
            groupingEnabled: true,
            groupingThreshold: 2,
          ),
        ),
      );
    }

    final messages = [
      'Hey, are you free this afternoon?',
      'Updates on the design sprint ready.',
      'Review moved to Friday!',
      'Let me know if you need the deck.',
    ];

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      Timer(Duration(milliseconds: i * 160), () {
        setupBloc.controller.show(
          AppNotification(
            title: 'Alice',
            message: msg,
            channelName: 'chat',
            dismissDuration: const Duration(seconds: 30),
          ),
          targetPosition: targetPosition,
        );
      });
    }
  }

  /// Opens the Quick-Fire Cockpit as an adaptive bottom sheet on mobile
  /// screens.
  static Future<void> showModal(final BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (final _) => const _QuickFireBottomSheet(),
      );
}

class _QuickFireBottomSheet extends StatelessWidget {
  const _QuickFireBottomSheet();

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'QUICK FIRE COCKPIT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Primary: Fire Current Draft
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text(
              'FIRE CURRENT DRAFT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              context.read<NotificationBloc>().add(const FirePreview());
            },
          ),
          const SizedBox(height: 16),
          Text(
            'PRESET SCENARIOS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 8),
          // Presets Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MobilePresetButton(
                label: 'Info Alert',
                icon: Icons.info_outline,
                color: const Color(0xFF51B4F9),
                onTap: () {
                  Navigator.of(context).pop();
                  QuickFireCockpit._fireQuickPreset(
                    context,
                    channelName: 'info',
                    title: 'System Information',
                    message: 'Background synchronization completed.',
                  );
                },
              ),
              _MobilePresetButton(
                label: 'Success Alert',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2D7512),
                onTap: () {
                  Navigator.of(context).pop();
                  QuickFireCockpit._fireQuickPreset(
                    context,
                    channelName: 'success',
                    title: 'Payment Confirmed',
                    message: 'Invoice #1084 settled for \$140.00.',
                  );
                },
              ),
              _MobilePresetButton(
                label: 'Storage Warning',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFC97725),
                onTap: () {
                  Navigator.of(context).pop();
                  QuickFireCockpit._fireQuickPreset(
                    context,
                    channelName: 'warning',
                    title: 'Storage Warning',
                    message: 'Disk volume reached 92% capacity.',
                  );
                },
              ),
              _MobilePresetButton(
                label: 'Critical Outage',
                icon: Icons.error_outline,
                color: const Color(0xFFD03332),
                onTap: () {
                  Navigator.of(context).pop();
                  QuickFireCockpit._fireQuickPreset(
                    context,
                    channelName: 'error',
                    priority: NotificationPriority.high,
                    title: 'Database Outage',
                    message: 'Connection pool exhausted on replica 2.',
                  );
                },
              ),
              _MobilePresetButton(
                label: 'Pinned Update',
                icon: Icons.push_pin_outlined,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.of(context).pop();
                  QuickFireCockpit._fireQuickPreset(
                    context,
                    channelName: 'info',
                    permanent: true,
                    title: 'Update In Progress',
                    message: 'Firmware update 2.4.0 active.',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stress & Utility
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.auto_awesome_motion_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'Burst 3x',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    QuickFireCockpit._fireBurst(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.layers_outlined,
                    size: 16,
                  ),
                  label: const Text(
                    'Group 4x',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    QuickFireCockpit._fireGroupBurst(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text(
                    'Dismiss All',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.read<SetupBloc>().controller.dismissAll();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobilePresetButton extends StatelessWidget {
  const _MobilePresetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CockpitChip extends StatelessWidget {
  const _CockpitChip({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = StudioTheme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
