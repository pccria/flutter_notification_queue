import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

import '../bloc/notification_bloc.dart';
import '../models/channel_setup.dart';
import '../models/queue_setup.dart';
import '../models/studio_setup.dart';

/// What scope of Dart code to generate.
enum CodeSnippetScope {
  /// Complete controller, scope, channels, and dispatch setup.
  fullSetup('Full Setup', Icons.settings_suggest_outlined),

  /// Just the `controller.show(AppNotification(...))` dispatch statement.
  dispatchOnly('Dispatch Only', Icons.bolt_rounded),

  /// Just the `NotificationChannel` map configuration.
  channelsOnly('Channels', Icons.tune_rounded),

  /// Just the `NotificationQueue` baseline definitions.
  queuesOnly('Queues', Icons.view_quilt_outlined);

  const CodeSnippetScope(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Generates a copy-pasteable Dart code snippet from the current
/// [StudioSetup] and [NotificationDraft].
String generateCode({
  required final StudioSetup setup,
  required final NotificationDraft draft,
  final CodeSnippetScope scope = CodeSnippetScope.fullSetup,
}) {
  final buf = StringBuffer();

  switch (scope) {
    case CodeSnippetScope.dispatchOnly:
      _writeDispatch(buf, draft);
      break;

    case CodeSnippetScope.channelsOnly:
      buf
        ..writeln('// Channel Configurations')
        ..writeln('final channels = <String, NotificationChannel>{');
      for (final channel in setup.channels.values) {
        _writeChannel(buf, channel);
      }
      buf.writeln('};');
      break;

    case CodeSnippetScope.queuesOnly:
      buf
        ..writeln('// Queue Baseline Configurations')
        ..writeln('final queues = <QueuePosition, NotificationQueue>{');
      for (final entry in setup.queues.entries) {
        _writeQueue(buf, entry.key, entry.value);
      }
      buf.writeln('};');
      break;

    case CodeSnippetScope.fullSetup:
      buf
        ..writeln('// NFQ Studio — Generated Code (v0.5.0)\n')
        ..writeln('final controller = NotificationController(')
        ..writeln('  queues: {');

      for (final entry in setup.queues.entries) {
        _writeQueue(buf, entry.key, entry.value);
      }

      buf
        ..writeln('  },')
        ..writeln('  channels: {');

      for (final channel in setup.channels.values) {
        _writeChannel(buf, channel);
      }

      buf.writeln('  },');

      if (setup.maxHistoryEntries != 0) {
        buf.writeln('  maxHistoryEntries: ${setup.maxHistoryEntries},');
      }

      buf
        ..writeln(');')
        ..writeln()
        ..writeln('// 1. Attach NotificationScope to your widget tree:')
        ..writeln('// MaterialApp(')
        ..writeln('//   builder: (context, child) => NotificationScope(')
        ..writeln('//     controller: controller,')
        ..writeln('//     child: child!,')
        ..writeln('//   ),')
        ..writeln('// );')
        ..writeln()
        ..writeln('// 2. Dispatch a notification:');

      _writeDispatch(buf, draft);
      break;
  }

  return buf.toString();
}

void _writeDispatch(final StringBuffer buf, final NotificationDraft draft) {
  buf
    ..writeln('controller.show(')
    ..writeln('  AppNotification(')
    ..writeln("    title: '${draft.title}',")
    ..writeln("    message: '${draft.message}',")
    ..writeln("    channelName: '${draft.channelName}',");

  if (draft.priority != null) {
    buf.writeln(
      '    priority: NotificationPriority.${draft.priority!.name},',
    );
  }

  if (draft.permanent) {
    buf.writeln('    permanent: true,');
  }

  if (draft.accentColorOverride != null) {
    final hex = draft.accentColorOverride!
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    buf.writeln('    accentColor: const Color(0x$hex),');
  }

  if (draft.actionStyle == NotificationActionStyle.button) {
    buf
      ..writeln('    action: NotificationAction.button(')
      ..writeln("      label: '${draft.actionLabel}',")
      ..writeln('      onPressed: () {},')
      ..writeln('    ),');
  } else if (draft.actionStyle == NotificationActionStyle.onTap) {
    buf
      ..writeln('    action: NotificationAction.onTap(')
      ..writeln('      onPressed: () {},')
      ..writeln('    ),');
  }

  if (draft.dismissSeconds != null) {
    buf.writeln(
      '    dismissDuration: '
      'const Duration(seconds: ${draft.dismissSeconds}),',
    );
  }

  buf.writeln('  ),');

  if (draft.positionOverride != null) {
    buf.writeln(
      '  targetPosition: QueuePosition.${draft.positionOverride!.name},',
    );
  }

  buf
    ..writeln(');')
    ..writeln();
}

void _writeQueue(
  final StringBuffer buf,
  final QueuePosition position,
  final QueueSetup q,
) {
  buf
    ..writeln('    NotificationQueue(')
    ..writeln('      position: QueuePosition.${position.name},')
    ..writeln(
      '      style: ${_styleSnippet(q)},',
    )
    ..writeln(
      '      transition: ${_transitionSnippet(q.transitionType)},',
    )
    ..writeln('      maxStackSize: ${q.maxStackSize},')
    ..writeln('      spacing: ${q.spacing},');

  if (q.maxWidth != null) {
    buf.writeln('      maxWidth: ${q.maxWidth},');
  }

  buf
    ..writeln(
      '      dragBehavior: ${_behaviorSnippet(q.dragBehaviorType, q, true)},',
    )
    ..writeln(
      '      longPressDragBehavior: '
      '${_behaviorSnippet(q.longPressBehaviorType, q, false)},',
    )
    ..writeln(
      '      closeButtonBehavior: '
      '${_closeButtonSnippet(q.closeButtonBehaviorType)},',
    )
    ..writeln(
      '      margin: const EdgeInsets.symmetric(\n'
      '        vertical: ${q.verticalMargin},\n'
      '        horizontal: ${q.horizontalMargin},\n'
      '      ),',
    );

  if (q.groupingEnabled) {
    final countSnippet = switch (q.groupingCountType) {
      GroupCountType.hiddenCount => (q.groupingCountMaxCount == 99 &&
              q.groupingCountIncludePending)
          ? 'const HiddenCount()'
          : 'const HiddenCount(\n'
              '          maxCount: ${q.groupingCountMaxCount},\n'
              '          includePending: ${q.groupingCountIncludePending},\n'
              '        )',
      GroupCountType.totalCount => (q.groupingCountMaxCount == 99 &&
              q.groupingCountIncludePending)
          ? 'const TotalCount()'
          : 'const TotalCount(\n'
              '          maxCount: ${q.groupingCountMaxCount},\n'
              '          includePending: ${q.groupingCountIncludePending},\n'
              '        )',
      GroupCountType.noCount => 'const NoCount()',
    };

    buf
      ..writeln('      groupingBehavior: QueueGroupingBehavior(')
      ..writeln('        enabled: true,');
    if (q.groupingThreshold != 2) {
      buf.writeln('        maxBeforeGrouping: ${q.groupingThreshold},');
    }
    if (q.groupingMaxLayers != 2) {
      buf.writeln('        maxStackedLayers: ${q.groupingMaxLayers},');
    }
    if (q.groupingSwipeDismiss) {
      buf.writeln('        enableGroupSwipeDismiss: true,');
    }
    if (!q.groupingPauseTimers) {
      buf.writeln('        pauseTimersWhenExpanded: false,');
    }
    buf
      ..writeln('        countBehavior: $countSnippet,')
      ..writeln('      ),');
  }

  buf.writeln('    ),');
}

void _writeChannel(final StringBuffer buf, final ChannelSetup c) {
  buf
    ..writeln('    NotificationChannel(')
    ..writeln("      name: '${c.name}',");
  if (c.description != null) {
    buf.writeln("      description: '${c.description}',");
  }

  final theme = c.theme ??
      (c.color != null
          ? NotificationThemeData(
              color: c.color,
            )
          : null);
  if (theme != null) {
    _writeThemeSnippet(buf, theme, indent: '    ');
  }

  if (c.position != null) {
    buf.writeln(
      '      position: QueuePosition.${c.position!.name},',
    );
  }
  if (c.dismissSeconds != null) {
    buf.writeln(
      '      defaultDismissDuration: '
      'const Duration(seconds: ${c.dismissSeconds}),',
    );
  }
  if (c.iconPreset != ChannelIconPreset.none) {
    final iconName = switch (c.iconPreset) {
      ChannelIconPreset.info => 'info',
      ChannelIconPreset.success => 'check_circle',
      ChannelIconPreset.warning => 'warning',
      ChannelIconPreset.error => 'error',
      ChannelIconPreset.notification => 'notifications',
      ChannelIconPreset.none => '',
    };
    buf.writeln('      defaultIcon: Icon(Icons.$iconName),');
  }
  // Only emit `enabled: false` — omitting it implies true (the default).
  if (!c.enabled) {
    buf.writeln('      enabled: false,');
  }
  buf.writeln('    ),');
}

String _styleClassName(final Type t) => switch (t) {
      == FilledQueueStyle => 'FilledQueueStyle',
      == FlatQueueStyle => 'FlatQueueStyle',
      == OutlinedQueueStyle => 'OutlinedQueueStyle',
      _ => t.toString(),
    };

String _styleSnippet(final QueueSetup q) {
  final buf = StringBuffer('${_styleClassName(q.styleType)}(\n')
    ..writeln('        opacity: ${q.opacity},')
    ..writeln('        elevation: ${q.elevation},')
    ..writeln(
      '        borderRadius: BorderRadius.circular(${q.borderRadius}),',
    );
  if (q.padding != null) {
    buf.writeln('        padding: const EdgeInsets.all(${q.padding}),');
  }
  if (q.borderWidth != null) {
    buf.writeln('        borderWidth: ${q.borderWidth},');
  }
  buf.write('      )');
  return buf.toString();
}

String _transitionSnippet(final Type t) => switch (t) {
      == SlideTransitionStrategy => 'const SlideTransitionStrategy()',
      == FadeTransitionStrategy => 'const FadeTransitionStrategy()',
      == ScaleTransitionStrategy => 'const ScaleTransitionStrategy()',
      _ => 'const $t()',
    };

String _behaviorSnippet(final Type t, final QueueSetup q, final bool isDrag) {
  final zone = isDrag ? q.dragDismissZone : q.longPressDismissZone;

  if (t == Dismiss) {
    return 'const Dismiss(zones: DismissZone.${zone.name})';
  }
  if (t == Snooze) {
    final secs = isDrag ? q.dragSnoozeSeconds : q.longPressSnoozeSeconds;
    return 'const Snooze(duration: Duration(seconds: $secs))';
  }
  if (t == Pin) {
    return 'const Pin()';
  }
  if (t == Relocate) {
    if (q.relocateTargets.isEmpty) {
      return 'Relocate.to({}) // ERROR: Relocation targets must not be empty!';
    }
    final targets = q.relocateTargets
        .map((final p) => 'QueuePosition.${p.name}')
        .join(', ');
    return q.relocatePermanent
        ? 'Relocate.to({$targets}, permanent: true)'
        : 'Relocate.to({$targets})';
  }
  if (t == ReorderAndRelocate) {
    if (q.relocateTargets.isEmpty) {
      return 'ReorderAndRelocate.to(positions: {}) '
          '// ERROR: Relocation targets must not be empty!';
    }
    final targets = q.relocateTargets
        .map((final p) => 'QueuePosition.${p.name}')
        .join(', ');
    final permanentParam =
        q.relocatePermanent ? '        permanent: true,\n' : '';
    return 'ReorderAndRelocate.to(\n'
        '        positions: {$targets},\n'
        '$permanentParam'
        '      )';
  }
  if (t == Reorder) {
    return 'const Reorder()';
  }
  return 'const Disabled()';
}

String _closeButtonSnippet(final Type t) => switch (t) {
      == AlwaysVisible => 'const AlwaysVisible()',
      == VisibleOnHover => 'const VisibleOnHover()',
      == Hidden => 'const Hidden()',
      _ => 'const $t()',
    };

String _colorHex(final Color color) =>
    '0x${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

void _writeThemeSnippet(
  final StringBuffer buf,
  final NotificationThemeData theme, {
  required final String indent,
}) {
  buf.writeln('$indent  theme: const NotificationThemeData(');
  final color = theme.color;
  if (color != null) {
    buf.writeln('$indent    color: Color(${_colorHex(color)}),');
  }
  buf.writeln('$indent  ),');
}
