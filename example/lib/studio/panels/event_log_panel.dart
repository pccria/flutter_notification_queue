import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../bloc/studio_bloc.dart';

/// Filter categories for the event log stream.
enum EventLogFilter {
  all('All'),
  flow('Flow'),
  actions('Actions'),
  alerts('Alerts');

  const EventLogFilter(this.label);
  final String label;
}

/// A live event log that subscribes to [NotificationScope] events and
/// displays the last `_maxEvents` lifecycle events in real time with
/// filtering, active counter, and tap-to-inspect deep diagnostics.
class EventLogPanel extends StatefulWidget {
  const EventLogPanel({super.key});

  @override
  State<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends State<EventLogPanel> {
  static const _maxEvents = 100;

  final _events = <_LogEntry>[];
  final _activeIds = <String>{};
  StreamSubscription<NotificationEvent>? _sub;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  EventLogFilter _currentFilter = EventLogFilter.all;
  bool _searchOpen = false;
  String _searchQuery = '';
  _LogEntry? _selectedEntry;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    final scope = NotificationScope.of(context);
    final history = scope.getHistory();
    _events.clear();
    _activeIds.clear();

    for (final event in history.reversed) {
      _processEvent(event, recordOnly: true);
    }
    _sub = scope.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _processEvent(
    final NotificationEvent event, {
    required final bool recordOnly,
  }) {
    switch (event) {
      case NotificationQueued(:final notification):
        _activeIds.add(notification.id);
      case NotificationDismissed(:final notification):
        _activeIds.remove(notification.id);
      case QueueOverflowed(:final dropped):
        _activeIds.remove(dropped.id);
      case NotificationGroupDismissed():
        break;
      default:
        break;
    }

    final entry = _LogEntry(event: event, time: DateTime.now());
    if (recordOnly) {
      _events.add(entry);
    } else {
      _events.insert(0, entry);
      if (_events.length > _maxEvents) {
        _events.removeLast();
      }
    }
  }

  void _onEvent(final NotificationEvent event) {
    setState(() {
      _processEvent(event, recordOnly: false);
    });
  }

  bool _matchesFilter(final NotificationEvent event) {
    switch (_currentFilter) {
      case EventLogFilter.all:
        return true;
      case EventLogFilter.flow:
        return event is NotificationQueued ||
            event is NotificationDismissed ||
            event is NotificationRelocated ||
            event is NotificationReordered;
      case EventLogFilter.actions:
        return event is NotificationTapped ||
            event is NotificationCustomActionTriggered ||
            event is NotificationPinned ||
            event is NotificationUnpinned ||
            event is NotificationSnoozed ||
            event is NotificationGroupExpanded ||
            event is NotificationGroupCollapsed ||
            event is NotificationGroupDismissed;
      case EventLogFilter.alerts:
        return event is QueueOverflowed ||
            event is QueuePositionRelocated ||
            event is NotificationChannelRouteUpdated;
    }
  }

  bool _matchesSearch(final _LogEntry entry) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final event = entry.event;
    final meta = _EventMeta.of(event, isDark: true);
    final text = [
      meta.label,
      meta.badge ?? '',
      meta.subtitle ?? '',
      event.runtimeType.toString(),
    ].join(' ').toLowerCase();

    return text.contains(_searchQuery);
  }

  List<_LogEntry> get _filteredEvents => _events
      .where((final e) => _matchesFilter(e.event) && _matchesSearch(e))
      .toList();

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _filteredEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        LayoutBuilder(
          builder: (final context, final constraints) {
            final isCompact = constraints.maxWidth < 260;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Live Pulse Dot
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'EVENTS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: isCompact ? 0.8 : 1.5,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (_activeIds.isNotEmpty) ...[
                        _Badge(
                          label: isCompact
                              ? '${_activeIds.length}'
                              : '${_activeIds.length} active',
                          tooltip: '${_activeIds.length} active',
                          color: const Color(0xFF10B981),
                        ),
                        SizedBox(width: isCompact ? 2 : 4),
                      ],
                      _Badge(
                        label: '${_events.length}',
                        tooltip: '${_events.length} total events',
                        color: colorScheme.primary,
                      ),
                      SizedBox(width: isCompact ? 2 : 4),
                      Tooltip(
                        message: _searchOpen ? 'Close search' : 'Search events',
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _searchOpen = !_searchOpen;
                              if (!_searchOpen) {
                                _searchController.clear();
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 2 : 4),
                            child: Icon(
                              _searchOpen ? Icons.close : Icons.search,
                              size: 16,
                              color: _searchOpen
                                  ? colorScheme.primary
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isCompact ? 2 : 4),
                      Tooltip(
                        message: 'Clear log',
                        child: InkWell(
                          onTap: () {
                            NotificationScope.of(context).clearHistory();
                            setState(() {
                              _events.clear();
                              _activeIds.clear();
                              _selectedEntry = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 2 : 4),
                            child: Icon(
                              Icons.delete_sweep_outlined,
                              size: 16,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isCompact ? 2 : 4),
                      Tooltip(
                        message: 'Collapse Event Stream',
                        child: InkWell(
                          onTap: () => context
                              .read<StudioBloc>()
                              .add(const ToggleEventLog(open: false)),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 2 : 4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_searchOpen) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          hintText: 'Filter by message, id, badge…',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.35),
                          ),
                          prefixIcon: const Icon(Icons.search, size: 14),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Filter pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: EventLogFilter.values.map((final filter) {
                        final isSelected = _currentFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _currentFilter = filter),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                        .withValues(alpha: 0.16)
                                    : colorScheme.onSurface
                                        .withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                          .withValues(alpha: 0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                filter.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── Event list ──
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(
                  colorScheme: colorScheme,
                  hasFilter: _currentFilter != EventLogFilter.all ||
                      _searchQuery.isNotEmpty,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (final context, final i) {
                    final entry = filtered[i];
                    final isSelected = _selectedEntry == entry;
                    return _EventTile(
                      entry: entry,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedEntry = isSelected ? null : entry;
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final _LogEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = _EventMeta.of(entry.event, isDark: isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time
                    SizedBox(
                      width: 50,
                      child: Text(
                        _formatTime(entry.time),
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          height: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Color dot
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: meta.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (final context, final constraints) =>
                                      Row(
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: meta.badge != null
                                              ? (constraints.maxWidth - 36)
                                                  .clamp(0.0, double.infinity)
                                              : constraints.maxWidth,
                                        ),
                                        child: Text(
                                          meta.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                      if (meta.badge != null) ...[
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: _Badge(
                                            label: meta.badge!,
                                            color: meta.color,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isSelected
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 14,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                          if (meta.subtitle != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              meta.subtitle!,
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Inspector Drawer when selected
                if (isSelected) ...[
                  const SizedBox(height: 8),
                  _InspectorDrawer(entry: entry, meta: meta),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(final DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

// ── Inspector Drawer ────────────────────────────────────────────────────────

class _InspectorDrawer extends StatelessWidget {
  const _InspectorDrawer({required this.entry, required this.meta});

  final _LogEntry entry;
  final _EventMeta meta;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = _extractDetails(entry.event);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'DIAGNOSTICS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  final summary = StringBuffer()
                    ..writeln('NFQ Event: ${entry.event.runtimeType}')
                    ..writeln('Timestamp: ${entry.time.toIso8601String()}');
                  for (final row in details.entries) {
                    summary.writeln('${row.key}: ${row.value}');
                  }
                  Clipboard.setData(ClipboardData(text: summary.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Diagnostics copied to clipboard'),
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy,
                        size: 11,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (final context, final constraints) {
              final isWide = constraints.maxWidth >= 480;
              if (isWide) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: details.entries
                      .map(
                        (final e) => SizedBox(
                          width: itemWidth,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: details.entries
                    .map(
                      (final e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, String> _extractDetails(final NotificationEvent event) {
    final map = <String, String>{
      'Event': event.runtimeType.toString(),
    };

    switch (event) {
      case NotificationQueued(:final notification):
        map['ID'] = notification.id;
        map['Channel'] = notification.channelName;
        map['Position'] = notification.queue.position.name;
        map['Priority'] = notification.priority?.name ?? 'default';
        if (notification.title != null) {
          map['Title'] = notification.title!;
        }
        map['Message'] = notification.message;
      case NotificationUpdated(:final notification, :final oldNotification):
        map['ID'] = notification.id;
        map['Channel'] = notification.channelName;
        map['Position'] = notification.queue.position.name;
        map['Message'] = notification.message;
        map['Previous Message'] = oldNotification.message;
        if (notification.title != null) {
          map['Title'] = notification.title!;
        }
      case NotificationDismissed(:final notification, :final reason):
        map['ID'] = notification.id;
        map['Channel'] = notification.channelName;
        map['Reason'] = reason.name;
        if (notification.title != null) {
          map['Title'] = notification.title!;
        }
      case NotificationTapped(:final notification, :final behavior):
        map['ID'] = notification.id;
        map['Channel'] = notification.channelName;
        map['Behavior'] = behavior.runtimeType.toString();
      case NotificationRelocated(:final from, :final to, :final notification):
        map['ID'] = notification.id;
        map['Route'] = '${from.name} → ${to.name}';
      case NotificationReordered(:final notification, :final toIndex):
        map['ID'] = notification.id;
        map['Index'] = '$toIndex';
      case QueueOverflowed(:final queue, :final dropped):
        map['Queue'] = queue.position.name;
        map['Dropped ID'] = dropped.id;
        map['Dropped Msg'] = dropped.title ?? dropped.message;
      case NotificationSnoozed(:final notification, :final duration):
        map['ID'] = notification.id;
        map['Duration'] = '${duration.inSeconds}s';
      case NotificationPinned(:final notification):
        map['ID'] = notification.id;
      case NotificationUnpinned(:final notification):
        map['ID'] = notification.id;
      case NotificationCustomActionTriggered(
          :final notification,
          :final actionName,
        ):
        map['ID'] = notification.id;
        map['Action'] = actionName;
      case NotificationGroupExpanded(:final groupKey, :final count):
        map['GroupKey'] = groupKey;
        map['Cards'] = '$count';
      case NotificationGroupCollapsed(:final groupKey, :final count):
        map['GroupKey'] = groupKey;
        map['Cards'] = '$count';
      case NotificationGroupDismissed(:final groupKey):
        map['GroupKey'] = groupKey;
      case QueuePositionRelocated(:final from, :final to, :final permanent):
        map['From'] = from.name;
        map['To'] = to.name;
        map['Permanent'] = '$permanent';
      case NotificationChannelRouteUpdated(
          :final channelName,
          :final oldPosition,
          :final newPosition,
        ):
        map['Channel'] = channelName;
        map['Change'] = '${oldPosition.name} → ${newPosition.name}';
    }

    return map;
  }
}

// ── Event meta mapping ──────────────────────────────────────────────────────

class _EventMeta {
  const _EventMeta({
    required this.label,
    required this.color,
    this.badge,
    this.subtitle,
  });

  final String label;
  final Color color;
  final String? badge;
  final String? subtitle;

  static _EventMeta of(
    final NotificationEvent event, {
    required final bool isDark,
  }) =>
      switch (event) {
        NotificationQueued(:final notification) => _EventMeta(
            label: 'Queued',
            color: isDark
                ? const Color(0xFF60A5FA)
                : const Color(0xFF1D4ED8), // blue-400 : blue-700
            badge: notification.queue.position.name,
            subtitle: notification.title ?? notification.message,
          ),
        NotificationUpdated(:final notification) => _EventMeta(
            label: 'Updated',
            color: isDark
                ? const Color(0xFF38BDF8) // sky-400
                : const Color(0xFF0284C7), // sky-600
            badge: notification.queue.position.name,
            subtitle: notification.title ?? notification.message,
          ),
        NotificationDismissed(:final notification, :final reason) => _EventMeta(
            label: 'Dismissed',
            color: isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF475569), // slate-400 : slate-600
            badge: reason.name,
            subtitle: notification.title ?? notification.message,
          ),
        NotificationTapped(:final notification, :final behavior) => _EventMeta(
            label: 'Tapped',
            color: isDark
                ? const Color(0xFF34D399)
                : const Color(0xFF047857), // emerald-400 : emerald-700
            badge: switch (behavior) {
              TapToDismiss() => 'TapToDismiss',
              TapToExpand() => 'TapToExpand',
              TapToAct() => 'TapToAct',
              TapDisabled() => 'TapDisabled',
            },
            subtitle: notification.title ?? notification.message,
          ),
        NotificationRelocated(:final from, :final to, :final notification) =>
          _EventMeta(
            label: 'Relocated',
            color: isDark
                ? const Color(0xFFA78BFA)
                : const Color(0xFF6D28D9), // violet-400 : violet-700
            badge: '${from.name} → ${to.name}',
            subtitle: notification.title ?? notification.message,
          ),
        NotificationReordered(:final notification, :final toIndex) =>
          _EventMeta(
            label: 'Reordered',
            color: isDark
                ? const Color(0xFFFBBF24)
                : const Color(0xFFB45309), // amber-400 : amber-700
            badge: 'index $toIndex',
            subtitle: notification.title ?? notification.message,
          ),
        QueueOverflowed(:final queue, :final dropped) => _EventMeta(
            label: 'Overflow',
            color: isDark
                ? const Color(0xFFF87171)
                : const Color(0xFFB91C1C), // red-400 : red-700
            badge: queue.position.name,
            subtitle: dropped.title ?? dropped.message,
          ),
        NotificationSnoozed(:final notification, :final duration) => _EventMeta(
            label: 'Snoozed',
            color: isDark
                ? const Color(0xFFFB7185)
                : const Color(0xFFBE123C), // rose-400 : rose-700
            badge: '${duration.inSeconds}s',
            subtitle: notification.title ?? notification.message,
          ),
        NotificationPinned(:final notification) => _EventMeta(
            label: 'Pinned',
            color: isDark
                ? const Color(0xFFF59E0B)
                : const Color(0xFFB45309), // amber-500 : amber-700
            badge: 'pinned',
            subtitle: notification.title ?? notification.message,
          ),
        NotificationUnpinned(:final notification) => _EventMeta(
            label: 'Unpinned',
            color: isDark
                ? const Color(0xFF6B7280)
                : const Color(0xFF374151), // gray-500 : gray-700
            badge: 'unpinned',
            subtitle: notification.title ?? notification.message,
          ),
        NotificationCustomActionTriggered(
          :final notification,
          :final actionName,
        ) =>
          _EventMeta(
            label: 'Action',
            color: isDark
                ? const Color(0xFF10B981)
                : const Color(0xFF047857), // emerald-500 : emerald-700
            badge: actionName,
            subtitle: notification.title ?? notification.message,
          ),
        NotificationGroupExpanded(:final groupKey, :final count) => _EventMeta(
            label: 'Group Expanded',
            color: isDark
                ? const Color(0xFF22D3EE)
                : const Color(0xFF0E7490), // cyan-400 : cyan-700
            badge: '$count cards',
            subtitle: groupKey,
          ),
        NotificationGroupCollapsed(:final groupKey, :final count) => _EventMeta(
            label: 'Group Collapsed',
            color: isDark
                ? const Color(0xFF67E8F9)
                : const Color(0xFF0E7490), // cyan-300 : cyan-700
            badge: '$count cards',
            subtitle: groupKey,
          ),
        NotificationGroupDismissed(:final groupKey) => _EventMeta(
            label: 'Group Dismissed',
            color: isDark
                ? const Color(0xFF06B6D4)
                : const Color(0xFF0E7490), // cyan-500 : cyan-700
            badge: 'all',
            subtitle: groupKey,
          ),
        QueuePositionRelocated(
          :final from,
          :final to,
          :final permanent,
        ) =>
          _EventMeta(
            label: permanent ? 'Queue Relocated' : 'Queue Moved',
            color: isDark
                ? const Color(0xFFEC4899)
                : const Color(0xFFBE185D), // pink-500 : pink-700
            badge: '${from.name} → ${to.name}',
            subtitle: permanent ? 'Permanent redirect' : 'Ephemeral move',
          ),
        NotificationChannelRouteUpdated(
          :final channelName,
          :final oldPosition,
          :final newPosition,
        ) =>
          _EventMeta(
            label: 'Route Updated',
            color: isDark
                ? const Color(0xFFEC4899)
                : const Color(0xFFBE185D), // pink-500 : pink-700
            badge: channelName,
            subtitle: '${oldPosition.name} → ${newPosition.name}',
          ),
      };
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.tooltip,
  });

  final String label;
  final Color color;
  final String? tooltip;

  @override
  Widget build(final BuildContext context) => Tooltip(
        message: tooltip ?? label,
        waitDuration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colorScheme,
    this.hasFilter = false,
  });

  final ColorScheme colorScheme;
  final bool hasFilter;

  @override
  Widget build(final BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter
                  ? Icons.filter_alt_off_outlined
                  : Icons.sensors_outlined,
              size: 32,
              color: colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 10),
            Text(
              hasFilter ? 'No events match filter' : 'Waiting for events…',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFilter
                  ? 'Try selecting "All" or clearing search'
                  : 'Fire a preset or trigger notifications',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withValues(alpha: 0.22),
              ),
            ),
          ],
        ),
      );
}

// ── Data model ──────────────────────────────────────────────────────────────

class _LogEntry {
  const _LogEntry({required this.event, required this.time});

  final NotificationEvent event;
  final DateTime time;
}
