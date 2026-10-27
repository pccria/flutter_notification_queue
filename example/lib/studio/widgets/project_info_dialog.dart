import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal dialog displaying comprehensive project metadata, version info,
/// core architectural features, and documentation links.
class ProjectInfoDialog extends StatelessWidget {
  const ProjectInfoDialog({
    required this.version,
    super.key,
  });

  /// The version string dynamically loaded from pubspec.yaml.
  final String? version;

  /// Helper to launch external URLs safely.
  static Future<void> _launchUrl(final String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } on Object catch (_) {
      try {
        await launchUrl(uri);
      } on Object catch (_) {}
    }
  }

  /// Displays the info dialog modally.
  static void show(final BuildContext context, {final String? version}) {
    showDialog<void>(
      context: context,
      builder: (final context) => ProjectInfoDialog(version: version),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayVersion =
        version != null && version!.isNotEmpty ? 'v$version' : 'v0.5.0';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Bar ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'FlutterNotificationQueue',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  displayVersion,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'BSD 3-Clause License • Pure Dart & Flutter Engine',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // ── Scrollable Body ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Text
                      Text(
                        'FNQ is a production-grade, overlay-based spatial '
                        'notification engine for Flutter applications. '
                        'It cleanly separates message payloads from spatial '
                        'placement, channel themes, and state management.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Key Capabilities Section
                      Text(
                        'KEY CAPABILITIES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _CapabilityTile(
                        icon: Icons.grid_view_rounded,
                        title: 'Spatial Position Routing',
                        description:
                            '9-anchor layout model governing max stack '
                            'limits, physics, and dynamic queue positions.',
                      ),
                      const SizedBox(height: 8),
                      const _CapabilityTile(
                        icon: Icons.gesture_rounded,
                        title: 'Intent-First Gestures',
                        description:
                            'Interactive drag gestures for Dismiss, Reorder, '
                            'Relocate, Snooze, and Pinning.',
                      ),
                      const SizedBox(height: 8),
                      const _CapabilityTile(
                        icon: Icons.layers_outlined,
                        title: 'Notification Bundling & Decks',
                        description:
                            'Grouping decks with customizable stack offsets, '
                            'peek card previews, and unravel transitions.',
                      ),
                      const SizedBox(height: 8),
                      const _CapabilityTile(
                        icon: Icons.shield_outlined,
                        title: 'Priority Triage & Backpressure',
                        description:
                            'Queue overflow strategies, preemption rules, '
                            'and capacity backpressure management.',
                      ),
                      const SizedBox(height: 8),
                      const _CapabilityTile(
                        icon: Icons.bolt_outlined,
                        title: 'Contextless Architecture',
                        description:
                            'State ownership decoupled from BuildContext '
                            'via OverlayPortal and QueueCoordinator.',
                      ),
                      const SizedBox(height: 24),

                      // Links & Documentation Section
                      Text(
                        'LINKS & RESOURCES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LinkChip(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Pub.dev Package',
                            onTap: () => _launchUrl(
                              'https://pub.dev/packages/flutter_notification_queue',
                            ),
                          ),
                          _LinkChip(
                            icon: Icons.menu_book_outlined,
                            label: 'API Reference',
                            onTap: () => _launchUrl(
                              'https://pccria.github.io/flutter_notification_queue/api/',
                            ),
                          ),
                          _LinkChip(
                            icon: Icons.code_rounded,
                            label: 'GitHub Repository',
                            onTap: () => _launchUrl(
                              'https://github.com/pccria/flutter_notification_queue',
                            ),
                          ),
                          _LinkChip(
                            icon: Icons.bug_report_outlined,
                            label: 'Issue Tracker',
                            onTap: () => _launchUrl(
                              'https://github.com/pccria/flutter_notification_queue/issues',
                            ),
                          ),
                          _LinkChip(
                            icon: Icons.favorite_border_rounded,
                            label: 'Sponsor Project',
                            accent: true,
                            onTap: () => _launchUrl(
                              'https://github.com/sponsors/pccria',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer Bar ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.03),
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Crafted by Pooria Askari',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.3,
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

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = accent ? Colors.pinkAccent : colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
