import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../bloc/setup_bloc.dart';
import '../models/virtual_window_data.dart';

/// An interactive, embedded canvas displaying live virtual application windows.
///
/// Each virtual window hosts its own [NotificationController] and an isolated
/// [NotificationScope(useRootOverlay: false)]. Notifications dispatched to a
/// target window animate and stack strictly within that window's local overlay.
///
/// Selecting a window focuses it as the active window in [SetupBloc], binding
/// the Studio Configurator and inspector tools directly to that window.
class VirtualStageCanvas extends StatelessWidget {
  const VirtualStageCanvas({super.key});

  @override
  Widget build(final BuildContext context) =>
      BlocBuilder<SetupBloc, SetupState>(
        builder: (final context, final setupState) {
          final colorScheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final windows = setupState.windows.values.toList();
          final activeId = setupState.activeWindowId;

          return Container(
            color: isDark
                ? const Color(0xFF0B0F19)
                : colorScheme.surfaceContainerLowest,
            child: Column(
              children: [
                _StageHeader(
                  windowCount: windows.length,
                  activeWindow: setupState.activeWindow,
                  onAddWindow: () =>
                      context.read<SetupBloc>().add(const AddVirtualWindow()),
                  onRemoveWindow2: () => context
                      .read<SetupBloc>()
                      .add(const RemoveVirtualWindow('win_2')),
                  onClearAll: () {
                    for (final win in setupState.windows.values) {
                      win.controller.dismissAll(clearBacklog: true);
                    }
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (final context, final constraints) {
                        if (windows.length == 1) {
                          final win1 = windows.first;
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 780,
                                maxHeight: 680,
                              ),
                              child: _VirtualWindowCard(
                                window: win1,
                                isActive: win1.id == activeId,
                                onFocus: () => context
                                    .read<SetupBloc>()
                                    .add(SelectActiveWindow(win1.id)),
                                onToggleStasis: () => context
                                    .read<SetupBloc>()
                                    .add(ToggleWindowStasis(win1.id)),
                                onToggleMount: () => context
                                    .read<SetupBloc>()
                                    .add(ToggleWindowMount(win1.id)),
                                onClear: () => context
                                    .read<SetupBloc>()
                                    .add(ClearWindow(win1.id)),
                                onClose: () {},
                              ),
                            ),
                          );
                        }

                        final win1 = windows[0];
                        final win2 = windows[1];

                        if (constraints.maxWidth >= 850) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _VirtualWindowCard(
                                  window: win1,
                                  isActive: win1.id == activeId,
                                  onFocus: () => context
                                      .read<SetupBloc>()
                                      .add(SelectActiveWindow(win1.id)),
                                  onToggleStasis: () => context
                                      .read<SetupBloc>()
                                      .add(ToggleWindowStasis(win1.id)),
                                  onToggleMount: () => context
                                      .read<SetupBloc>()
                                      .add(ToggleWindowMount(win1.id)),
                                  onClear: () => context
                                      .read<SetupBloc>()
                                      .add(ClearWindow(win1.id)),
                                  onClose: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _VirtualWindowCard(
                                  window: win2,
                                  isActive: win2.id == activeId,
                                  onFocus: () => context
                                      .read<SetupBloc>()
                                      .add(SelectActiveWindow(win2.id)),
                                  onToggleStasis: () => context
                                      .read<SetupBloc>()
                                      .add(ToggleWindowStasis(win2.id)),
                                  onToggleMount: () => context
                                      .read<SetupBloc>()
                                      .add(ToggleWindowMount(win2.id)),
                                  onClear: () => context
                                      .read<SetupBloc>()
                                      .add(ClearWindow(win2.id)),
                                  onClose: () => context
                                      .read<SetupBloc>()
                                      .add(const RemoveVirtualWindow('win_2')),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _VirtualWindowCard(
                                window: win1,
                                isActive: win1.id == activeId,
                                onFocus: () => context
                                    .read<SetupBloc>()
                                    .add(SelectActiveWindow(win1.id)),
                                onToggleStasis: () => context
                                    .read<SetupBloc>()
                                    .add(ToggleWindowStasis(win1.id)),
                                onToggleMount: () => context
                                    .read<SetupBloc>()
                                    .add(ToggleWindowMount(win1.id)),
                                onClear: () => context
                                    .read<SetupBloc>()
                                    .add(ClearWindow(win1.id)),
                                onClose: () {},
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _VirtualWindowCard(
                                window: win2,
                                isActive: win2.id == activeId,
                                onFocus: () => context
                                    .read<SetupBloc>()
                                    .add(SelectActiveWindow(win2.id)),
                                onToggleStasis: () => context
                                    .read<SetupBloc>()
                                    .add(ToggleWindowStasis(win2.id)),
                                onToggleMount: () => context
                                    .read<SetupBloc>()
                                    .add(ToggleWindowMount(win2.id)),
                                onClear: () => context
                                    .read<SetupBloc>()
                                    .add(ClearWindow(win2.id)),
                                onClose: () => context
                                    .read<SetupBloc>()
                                    .add(const RemoveVirtualWindow('win_2')),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.windowCount,
    required this.activeWindow,
    required this.onAddWindow,
    required this.onRemoveWindow2,
    required this.onClearAll,
  });

  final int windowCount;
  final VirtualWindowData activeWindow;
  final VoidCallback onAddWindow;
  final VoidCallback onRemoveWindow2;
  final VoidCallback onClearAll;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (final context, final constraints) {
          final isCompact = constraints.maxWidth < 560;
          final isVeryCompact = constraints.maxWidth < 360;
          final isUltraCompact = constraints.maxWidth < 240;

          return Row(
            children: [
              Icon(
                Icons.splitscreen_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'STAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              if (!isVeryCompact) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: windowCount > 1
                        ? const Color(0xFF6366F1).withValues(alpha: 0.16)
                        : colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: windowCount > 1
                          ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    windowCount > 1 ? '2 WINS' : '1 WIN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: windowCount > 1
                          ? const Color(0xFF818CF8)
                          : colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
              if (!isCompact) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Editing: ${activeWindow.title}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: activeWindow.accentColor,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!isUltraCompact) ...[
                if (windowCount == 1) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    icon: const Icon(Icons.add_to_photos_outlined, size: 13),
                    label: const Text(
                      '+ Win 2',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    onPressed: onAddWindow,
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 13),
                    label: const Text(
                      'Close 2',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    onPressed: onRemoveWindow2,
                  ),
                ],
                const SizedBox(width: 4),
              ],
              Tooltip(
                message: 'Dismiss all notifications',
                child: IconButton(
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  onPressed: onClearAll,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VirtualWindowCard extends StatelessWidget {
  const _VirtualWindowCard({
    required this.window,
    required this.isActive,
    required this.onFocus,
    required this.onToggleStasis,
    required this.onToggleMount,
    required this.onClear,
    required this.onClose,
  });

  final VirtualWindowData window;
  final bool isActive;
  final VoidCallback onFocus;
  final VoidCallback onToggleStasis;
  final VoidCallback onToggleMount;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onFocus,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? window.accentColor
                : colorScheme.outlineVariant.withValues(alpha: 0.28),
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: window.accentColor.withValues(alpha: 0.2),
                blurRadius: 18,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WindowChrome(
              window: window,
              isActive: isActive,
              onToggleMount: onToggleMount,
              onToggleStasis: onToggleStasis,
              onClear: onClear,
              onClose: onClose,
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
                child: window.isMounted
                    ? Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (final _) =>
                                !window.controller.isAttached
                                    ? NotificationScope(
                                        controller: window.controller,
                                        useRootOverlay: false,
                                        child: _VirtualWindowBody(
                                          window: window,
                                          isActive: isActive,
                                        ),
                                      )
                                    : _VirtualWindowBody(
                                        window: window,
                                        isActive: isActive,
                                      ),
                          ),
                        ],
                      )
                    : _UnmountedWindowPlaceholder(
                        window: window,
                        onRemount: onToggleMount,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowChrome extends StatelessWidget {
  const _WindowChrome({
    required this.window,
    required this.isActive,
    required this.onToggleMount,
    required this.onToggleStasis,
    required this.onClear,
    required this.onClose,
  });

  final VirtualWindowData window;
  final bool isActive;
  final VoidCallback onToggleMount;
  final VoidCallback onToggleStasis;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // macOS style traffic light dots
          _TrafficDot(
            color: const Color(0xFFEF4444),
            tooltip: window.id == 'win_2'
                ? 'Remove Window 2'
                : (window.isMounted ? 'Unmount Surface' : 'Mount Surface'),
            onTap: window.id == 'win_2' ? onClose : onToggleMount,
          ),
          const SizedBox(width: 6),
          _TrafficDot(
            color: const Color(0xFFF59E0B),
            tooltip: window.isPaused
                ? 'Resume Queue Timers'
                : 'Pause Queue Timers (Stasis)',
            onTap: onToggleStasis,
            child: window.isPaused
                ? const Icon(Icons.pause, size: 8, color: Colors.black87)
                : null,
          ),
          const SizedBox(width: 6),
          _TrafficDot(
            color: const Color(0xFF10B981),
            tooltip: 'Dismiss Notifications in Window',
            onTap: onClear,
          ),
          const SizedBox(width: 12),

          Icon(
            window.id == 'win_1'
                ? Icons.desktop_windows_outlined
                : Icons.web_asset_outlined,
            size: 14,
            color: window.accentColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              window.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: window.accentColor,
              ),
            ),
          ),
          const SizedBox(width: 6),

          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: window.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: window.accentColor.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                'EDITING',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: window.accentColor,
                ),
              ),
            ),

          const Spacer(),

          if (window.isPaused) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '⏸ STASIS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.child,
  });

  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(final BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 12,
            height: 12,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 3,
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
}

class _VirtualWindowBody extends StatelessWidget {
  const _VirtualWindowBody({
    required this.window,
    required this.isActive,
  });

  final VirtualWindowData window;
  final bool isActive;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final queueCount = window.setup.queues.length;
    final channelCount = window.setup.channels.length;

    return Container(
      color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mock application header
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search workspace...',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 14),
                label: const Text(
                  'Ping',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  final channelName = window.setup.channels.keys.isNotEmpty
                      ? window.setup.channels.keys.first
                      : 'info';
                  final timeStr =
                      DateTime.now().toIso8601String().substring(11, 19);
                  window.controller.show(
                    AppNotification(
                      title: 'Ping from ${window.title}',
                      message: 'Isolated window event at $timeStr',
                      channelName: channelName,
                      dismissDuration: const Duration(seconds: 4),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Active Queue & Channel Config Chips
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune,
                      size: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CONFIGURATION '
                        '($queueCount queues • $channelCount channels)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: window.setup.queues.entries.map((final e) {
                    final posName = e.key.name;
                    final max = e.value.maxStackSize;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: window.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: window.accentColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '$posName (max $max)',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: window.accentColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Simulated Workspace Feed
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _MockFeedCard(
                  icon: Icons.check_circle_outline,
                  iconColor: Color(0xFF10B981),
                  title: 'Local Overlay Isolation',
                  subtitle: 'Notifications are bound to this window only.',
                ),
                const SizedBox(height: 8),
                _MockFeedCard(
                  icon: Icons.hub_outlined,
                  iconColor: window.accentColor,
                  title: 'Dedicated NotificationController',
                  subtitle: 'Independent event stream & ticker lifecycle.',
                ),
                const SizedBox(height: 8),
                const _MockFeedCard(
                  icon: Icons.speed_rounded,
                  iconColor: Color(0xFFF59E0B),
                  title: 'Stasis Timer Freezing',
                  subtitle: 'Pause queue without blocking sibling windows.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockFeedCard extends StatelessWidget {
  const _MockFeedCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
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

class _UnmountedWindowPlaceholder extends StatelessWidget {
  const _UnmountedWindowPlaceholder({
    required this.window,
    required this.onRemount,
  });

  final VirtualWindowData window;
  final VoidCallback onRemount;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.power_off_rounded,
            size: 36,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          Text(
            '${window.title} Unmounted',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Coordinator disposed cleanly. 0 orphan tickers active.',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Remount Surface'),
            onPressed: onRemount,
          ),
        ],
      ),
    );
  }
}
