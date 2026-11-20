import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/notification_bloc.dart';
import '../bloc/setup_bloc.dart';
import 'configurator/channel_section.dart';
import 'configurator/preview_section.dart';
import 'configurator/queue_section.dart';
import 'configurator/scenarios_section.dart';
import 'configurator/system_options_section.dart';

/// The left-side configurator panel with four collapsible sections:
/// 1. **Queues** — add/remove/edit queue setups per position (with position map)
/// 2. **Channels** — manage notification channels
/// 3. **Preview** — compose and fire test notifications
/// 4. **Scenarios** — one-click realistic demo flows
/// The sub-tabs available in mobile mode for the configurator.
enum ConfigSubTab {
  queues('Queues', Icons.view_quilt_outlined),
  channels('Channels', Icons.tune_outlined),
  preview('Draft', Icons.send_outlined),
  scenarios('Scenarios', Icons.bolt_outlined),
  options('Options', Icons.settings_outlined);

  const ConfigSubTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The configurator panel.
///
/// On **desktop**, displays collapsible sections simultaneously.
/// On **mobile**, renders a segmented sub-bar for instant, scroll-free access.
class ConfiguratorPanel extends StatefulWidget {
  const ConfiguratorPanel({super.key});

  @override
  State<ConfiguratorPanel> createState() => _ConfiguratorPanelState();
}

class _ConfiguratorPanelState extends State<ConfiguratorPanel> {
  ConfigSubTab _selectedSubTab = ConfigSubTab.queues;

  @override
  Widget build(final BuildContext context) => LayoutBuilder(
        builder: (final context, final constraints) {
          final isMobile = constraints.maxWidth < 480;

          return BlocBuilder<SetupBloc, SetupState>(
            builder: (final context, final setupState) =>
                BlocBuilder<NotificationBloc, NotificationDraft>(
              builder: (final context, final draft) {
                if (isMobile) {
                  return Column(
                    children: [
                      _buildMobileSubBar(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          children: [
                            _buildMobileContent(setupState, draft),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return _buildDesktopContent(
                  constraints.maxWidth,
                  setupState,
                  draft,
                );
              },
            ),
          );
        },
      );

  Widget _buildMobileSubBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ConfigSubTab.values.map((final tab) {
            final isSelected = _selectedSubTab == tab;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => setState(() => _selectedSubTab = tab),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.16)
                        : colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 13,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(
    final double maxWidth,
    final SetupState setupState,
    final NotificationDraft draft,
  ) {
    final queuesSection = _StudioExpansionSection(
      title: 'QUEUES',
      icon: Icons.view_quilt_outlined,
      initiallyExpanded: true,
      child: QueueSection(setupState: setupState),
    );

    final channelsSection = _StudioExpansionSection(
      title: 'CHANNELS',
      icon: Icons.tune_outlined,
      initiallyExpanded: true,
      child: ChannelSection(setupState: setupState),
    );

    final optionsSection = _StudioExpansionSection(
      title: 'SYSTEM OPTIONS',
      icon: Icons.settings_outlined,
      initiallyExpanded: false,
      child: SystemOptionsSection(setupState: setupState),
    );

    final draftSection = _StudioExpansionSection(
      title: 'NOTIFICATION DRAFT',
      icon: Icons.send_outlined,
      initiallyExpanded: true,
      child: PreviewSection(
        setupState: setupState,
        draft: draft,
      ),
    );

    const scenariosSection = _StudioExpansionSection(
      title: 'SCENARIOS',
      icon: Icons.bolt_outlined,
      initiallyExpanded: false,
      child: ScenariosSection(),
    );

    final dividerColor =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.22);

    // ── Ultra-Wide Mode (≥ 1200px): 3-Column Studio Command Center ──
    if (maxWidth >= 1200) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Col 1: Spatial Architecture & System Options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 24),
              children: [
                queuesSection,
                optionsSection,
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          // Col 2: Channel Chromatics & Styles
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
              children: [
                channelsSection,
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          // Col 3: Dispatch Playground & Scenarios
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 24),
              children: [
                draftSection,
                scenariosSection,
              ],
            ),
          ),
        ],
      );
    }

    // ── Dual-Workbench Mode (≥ 660px): 2 Side-by-Side Coordinated Panes ──
    if (maxWidth >= 660) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Pane: Setup & Architecture (Queues, Channels, Options)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 24),
              children: [
                queuesSection,
                channelsSection,
                optionsSection,
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          // Right Pane: Playground & Dispatch (Draft, Scenarios)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 24),
              children: [
                draftSection,
                scenariosSection,
              ],
            ),
          ),
        ],
      );
    }

    // ── Standard Sidebar Mode (< 660px): Single-Column Accordion ──
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      children: [
        queuesSection,
        channelsSection,
        optionsSection,
        draftSection,
        scenariosSection,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMobileContent(
    final SetupState setupState,
    final NotificationDraft draft,
  ) =>
      switch (_selectedSubTab) {
        ConfigSubTab.queues => QueueSection(setupState: setupState),
        ConfigSubTab.channels => ChannelSection(setupState: setupState),
        ConfigSubTab.preview => PreviewSection(
            setupState: setupState,
            draft: draft,
          ),
        ConfigSubTab.scenarios => const ScenariosSection(),
        ConfigSubTab.options => SystemOptionsSection(setupState: setupState),
      };
}

/// A premium collapsible card section used throughout the configurator panel.
///
/// Features surface elevations, crisp subtle borders, and an icon badge.
class _StudioExpansionSection extends StatelessWidget {
  const _StudioExpansionSection({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Override the divider that ExpansionTile normally inserts
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 3,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: colorScheme.primary),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            iconColor: colorScheme.primary,
            collapsedIconColor: colorScheme.onSurface.withValues(alpha: 0.4),
            children: [child],
          ),
        ),
      ),
    );
  }
}
