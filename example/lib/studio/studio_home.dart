import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import 'bloc/notification_bloc.dart';
import 'bloc/setup_bloc.dart';
import 'bloc/studio_bloc.dart';
import 'panels/code_editor_panel.dart';
import 'panels/configurator_panel.dart';
import 'panels/event_log_panel.dart';
import 'studio_theme.dart';
import 'widgets/overlay/studio_overlay_host.dart';
import 'widgets/pane_splitter.dart';
import 'widgets/project_info_dialog.dart';
import 'widgets/quick_fire_cockpit.dart';

/// The root layout for NFQ Studio.
///
/// Features a transparent pass-through HUD overlay layer ([StudioOverlayHost])
/// mounted over the interactive Studio application workbench.
class StudioHome extends StatelessWidget {
  const StudioHome({super.key});

  @override
  Widget build(final BuildContext context) => const Stack(
        fit: StackFit.expand,
        children: [
          _StudioShell(),
          StudioOverlayHost(),
        ],
      );
}

class _StudioShell extends StatefulWidget {
  const _StudioShell();

  @override
  State<_StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<_StudioShell> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(final KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!isCtrlOrCmd) {
      return false;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      context.read<NotificationBloc>().add(const FirePreview());
      return true;
    }
    if (key == LogicalKeyboardKey.keyE) {
      context.read<StudioBloc>().add(const ToggleCodeEditor());
      return true;
    }
    if (key == LogicalKeyboardKey.keyL) {
      context.read<StudioBloc>().add(const ToggleEventLog());
      return true;
    }

    return false;
  }

  @override
  Widget build(final BuildContext context) => LayoutBuilder(
        builder: (final context, final constraints) {
          final isNarrow = constraints.maxWidth < 1100;
          final colorScheme = Theme.of(context).colorScheme;

          return Scaffold(
            appBar: AppBar(
              title: BlocBuilder<SetupBloc, SetupState>(
                builder: (final context, final setupState) =>
                    SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isNarrow ? 'NFQ' : 'NFQ STUDIO',
                        style: TextStyle(
                          letterSpacing: isNarrow ? 1.2 : 3,
                          fontWeight: FontWeight.w900,
                          fontSize: isNarrow ? 16 : 18,
                        ),
                      ),
                      if (constraints.maxWidth >= 600) ...[
                        const SizedBox(width: 6),
                        const _VersionBadge(),
                      ],
                      if (isNarrow && setupState.windows.length > 1) ...[
                        const SizedBox(width: 8),
                        _MobileWorkspacePill(setupState: setupState),
                      ],
                      if (!isNarrow) ...[
                        const SizedBox(width: 16),
                        _DesktopWorkspaceBar(setupState: setupState),
                      ],
                    ],
                  ),
                ),
              ),
              centerTitle: false,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
              elevation: 0,
              actions: [
                if (isNarrow) ...[
                  // Mobile Primary CTA: Fire Draft
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 15),
                    label: const Text(
                      'FIRE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    onPressed: () => context
                        .read<NotificationBloc>()
                        .add(const FirePreview()),
                  ),
                  const SizedBox(width: 4),
                  // Mobile Presets Launcher
                  Tooltip(
                    message: 'Quick Presets',
                    child: IconButton(
                      icon: const Icon(Icons.flash_on_outlined, size: 20),
                      onPressed: () => QuickFireCockpit.showModal(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  // Desktop Pane Toggles
                  BlocBuilder<StudioBloc, StudioState>(
                    builder: (final context, final state) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PaneToggleAction(
                          icon: Icons.code,
                          label: 'CODE',
                          isOpen: state.isCodeEditorOpen,
                          tooltip: state.isCodeEditorOpen
                              ? 'Collapse Code Editor (Ctrl+E)'
                              : 'Expand Code Editor (Ctrl+E)',
                          onPressed: () => context
                              .read<StudioBloc>()
                              .add(const ToggleCodeEditor()),
                        ),
                        const SizedBox(width: 4),
                        _PaneToggleAction(
                          icon: Icons.stream_rounded,
                          label: 'EVENTS',
                          isOpen: state.isEventLogOpen,
                          tooltip: state.isEventLogOpen
                              ? 'Collapse Event Stream (Ctrl+L)'
                              : 'Expand Event Stream (Ctrl+L)',
                          onPressed: () => context
                              .read<StudioBloc>()
                              .add(const ToggleEventLog()),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 1,
                          height: 18,
                          color: colorScheme.onSurface.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
                if (isNarrow && constraints.maxWidth < 450) ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'More Options',
                    onSelected: (final value) {
                      if (value == 'theme') {
                        context.read<StudioBloc>().add(const ToggleTheme());
                      } else if (value == 'info') {
                        ProjectInfoDialog.show(context);
                      } else if (value == 'split') {
                        context.read<StudioBloc>().add(const ToggleSplitView());
                      }
                    },
                    itemBuilder: (final context) => [
                      PopupMenuItem(
                        value: 'split',
                        child: Row(
                          children: [
                            const Icon(Icons.splitscreen_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              context.read<StudioBloc>().state.isSplitView
                                  ? 'Single Mode'
                                  : 'Dual Split Mode',
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'theme',
                        child: Row(
                          children: [
                            Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('Toggle Theme'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'info',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Project Info'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  IconButton(
                    onPressed: () => ProjectInfoDialog.show(context),
                    icon: const Icon(Icons.info_outline, size: 20),
                    tooltip: 'About & Project Info',
                  ),
                  BlocBuilder<StudioBloc, StudioState>(
                    builder: (final context, final state) => IconButton(
                      onPressed: () {
                        context.read<StudioBloc>().add(const ToggleTheme());
                      },
                      icon: Icon(
                        state.themeMode == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 20,
                      ),
                      tooltip: 'Toggle Theme',
                    ),
                  ),
                ],
                const SizedBox(width: 6),
              ],
            ),
            body: Stack(
              children: [
                const _StudioBackground(),
                SafeArea(
                  child: Column(
                    children: [
                      if (!isNarrow) const QuickFireCockpit(),
                      Expanded(
                        child: isNarrow
                            ? _narrowLayout()
                            : _wideLayout(constraints.maxWidth),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isNarrow
                ? BottomNavigationBar(
                    currentIndex: _tabIndex,
                    onTap: (final i) => setState(() => _tabIndex = i),
                    backgroundColor: StudioTheme.colorScheme.surface,
                    selectedItemColor: StudioTheme.colorScheme.primary,
                    unselectedItemColor: StudioTheme.colorScheme.onSurface
                        .withValues(alpha: 0.38),
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.tune),
                        label: 'Configure',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.code),
                        label: 'Code',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.stream_rounded),
                        label: 'Events',
                      ),
                    ],
                  )
                : null,
          );
        },
      );

  Widget _wideLayout(final double totalWidth) =>
      BlocBuilder<StudioBloc, StudioState>(
        builder: (final context, final state) {
          final availableWidth = totalWidth - 40.0;
          final maxCode = (availableWidth * 0.45).clamp(
            StudioState.minCodeEditorWidth,
            StudioState.maxCodeEditorWidth,
          );
          final effectiveCodeWidth = state.codeEditorWidth.clamp(
            StudioState.minCodeEditorWidth,
            maxCode,
          );

          final remainingAfterCode = availableWidth -
              (state.isCodeEditorOpen ? effectiveCodeWidth : 28.0);
          final maxEvent = remainingAfterCode.clamp(
            StudioState.minEventLogWidth,
            StudioState.maxEventLogWidth,
          );
          final effectiveEventWidth = state.eventLogWidth.clamp(
            StudioState.minEventLogWidth,
            maxEvent,
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Main Workbench: Full Multi-Column Configurator ──
              const Expanded(
                child: ConfiguratorPanel(),
              ),

              // ── Code Editor Pane & Splitter ──
              if (state.isCodeEditorOpen) ...[
                PaneSplitter(
                  tooltip:
                      'Drag to resize / Double-click to collapse Code Editor',
                  onDoubleClick: () => context
                      .read<StudioBloc>()
                      .add(const ToggleCodeEditor(open: false)),
                  onDragDelta: (final delta) {
                    context.read<StudioBloc>().add(
                          ResizeCodeEditor(
                            delta: delta,
                            totalWidth: totalWidth,
                          ),
                        );
                  },
                ),
                SizedBox(
                  width: effectiveCodeWidth,
                  child: const CodeEditorPanel(),
                ),
              ] else ...[
                CollapsedPaneRail(
                  icon: Icons.code,
                  label: 'CODE',
                  tooltip: 'Expand Code Editor',
                  onExpand: () => context
                      .read<StudioBloc>()
                      .add(const ToggleCodeEditor(open: true)),
                  onDragExpand: (final delta) {
                    if (delta < 0) {
                      context.read<StudioBloc>().add(
                            ResizeCodeEditor(
                              delta: delta,
                              totalWidth: totalWidth,
                            ),
                          );
                    }
                  },
                ),
              ],

              // ── Event Stream Pane & Splitter ──
              if (state.isEventLogOpen) ...[
                PaneSplitter(
                  tooltip:
                      'Drag to resize / Double-click to collapse Event Stream',
                  onDoubleClick: () => context
                      .read<StudioBloc>()
                      .add(const ToggleEventLog(open: false)),
                  onDragDelta: (final delta) {
                    context.read<StudioBloc>().add(
                          ResizeEventLog(
                            delta: delta,
                            totalWidth: totalWidth,
                          ),
                        );
                  },
                ),
                SizedBox(
                  width: effectiveEventWidth,
                  child: const EventLogPanel(),
                ),
              ] else ...[
                CollapsedPaneRail(
                  icon: Icons.stream_rounded,
                  label: 'EVENTS',
                  tooltip: 'Expand Event Stream',
                  onExpand: () => context
                      .read<StudioBloc>()
                      .add(const ToggleEventLog(open: true)),
                  onDragExpand: (final delta) {
                    if (delta < 0) {
                      context.read<StudioBloc>().add(
                            ResizeEventLog(
                              delta: delta,
                              totalWidth: totalWidth,
                            ),
                          );
                    }
                  },
                ),
              ],
            ],
          );
        },
      );

  Widget _narrowLayout() => IndexedStack(
        index: _tabIndex,
        children: const [
          ConfiguratorPanel(),
          CodeEditorPanel(),
          EventLogPanel(),
        ],
      );
}

class _DesktopWorkspaceBar extends StatelessWidget {
  const _DesktopWorkspaceBar({required this.setupState});

  final SetupState setupState;

  @override
  Widget build(final BuildContext context) {
    final windows = setupState.windows.values.toList();
    final activeId = setupState.activeWindowId;

    return BlocBuilder<StudioBloc, StudioState>(
      builder: (final context, final studioState) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...windows.map((final win) {
                  final isFocused = win.id == activeId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context
                        .read<SetupBloc>()
                        .add(SelectActiveWindow(win.id)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? win.accentColor.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFocused
                              ? win.accentColor.withValues(alpha: 0.6)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: win.accentColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            win.title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isFocused ? FontWeight.w800 : FontWeight.w600,
                              color: isFocused
                                  ? win.accentColor
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (windows.length == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      tooltip: 'Add Scope B (Beta)',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        context.read<SetupBloc>().add(const AddVirtualWindow());
                        context
                            .read<StudioBloc>()
                            .add(const ToggleSplitView(enabled: true));
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (windows.length > 1) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: studioState.isSplitView
                      ? const Color(0xFF8B5CF6)
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.3),
                ),
              ),
              icon: Icon(
                studioState.isSplitView
                    ? Icons.splitscreen_rounded
                    : Icons.fullscreen_rounded,
                size: 14,
                color: studioState.isSplitView ? const Color(0xFF8B5CF6) : null,
              ),
              label: Text(
                studioState.isSplitView ? 'Split View' : 'Single View',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color:
                      studioState.isSplitView ? const Color(0xFF8B5CF6) : null,
                ),
              ),
              onPressed: () =>
                  context.read<StudioBloc>().add(const ToggleSplitView()),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileWorkspacePill extends StatelessWidget {
  const _MobileWorkspacePill({required this.setupState});

  final SetupState setupState;

  @override
  Widget build(final BuildContext context) {
    final active = setupState.activeWindow;
    return Material(
      color: active.accentColor.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active.accentColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final nextId =
              setupState.activeWindowId == 'win_1' ? 'win_2' : 'win_1';
          context.read<SetupBloc>().add(SelectActiveWindow(nextId));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active.accentColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                setupState.activeWindowId == 'win_1' ? 'Alpha' : 'Beta',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active.accentColor,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.swap_horiz_rounded,
                size: 11,
                color: active.accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaneToggleAction extends StatelessWidget {
  const _PaneToggleAction({
    required this.icon,
    required this.label,
    required this.isOpen,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isOpen;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOpen
                ? colorScheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOpen
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isOpen
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isOpen ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.8,
                  color: isOpen
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioBackground extends StatelessWidget {
  const _StudioBackground();

  @override
  Widget build(final BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: [
              StudioTheme.colorScheme.surface,
              StudioTheme.theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      StudioTheme.colorScheme.primary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(final BuildContext context) => GestureDetector(
        onTap: () => ProjectInfoDialog.show(
          context,
          version: NotificationController.version,
        ),
        child: Text(
          'v${NotificationController.version}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            letterSpacing: 0.5,
          ),
        ),
      );
}
