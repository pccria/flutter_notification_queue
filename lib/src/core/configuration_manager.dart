part of 'core.dart';

/// The configuration registry for the notification system.
///
/// Stores [NotificationQueue]s and [NotificationChannel]s.
///
/// This class is internal — users configure the system through
/// [NotificationController] and never interact with this class directly.
@internal
class ConfigurationManager {
  ConfigurationManager({
    final Set<NotificationQueue> queues = const {},
    final Set<NotificationChannel> channels = const {},
    final bool strictChannelLookup = false,
    final int maxHistoryEntries = 0,
    final NotificationA11yOptions a11yOptions =
        const NotificationA11yOptions(),
  })  : _queues = _initQueues(queues),
        _channels = Set.unmodifiable(channels),
        _strictChannelLookup = strictChannelLookup,
        _maxHistoryEntries = maxHistoryEntries,
        _a11yOptions = a11yOptions;

  static Set<NotificationQueue> _initQueues(
    final Set<NotificationQueue> inputQueues,
  ) {
    _validateRelocationGroups(inputQueues);
    _validateInputResilience(inputQueues);
    return Set.unmodifiable(_expandRelocationGroups(inputQueues));
  }

  Set<NotificationQueue> _queues;
  Set<NotificationChannel> _channels;
  bool _strictChannelLookup;
  int _maxHistoryEntries;
  NotificationA11yOptions _a11yOptions;

  /// The immutable set of active notification queues.
  Set<NotificationQueue> get queues => _queues;

  /// The immutable set of registered notification channels.
  Set<NotificationChannel> get channels => _channels;

  /// Whether missing channel lookups throw an exception.
  bool get strictChannelLookup => _strictChannelLookup;

  /// The maximum number of entries to retain in event history.
  int get maxHistoryEntries => _maxHistoryEntries;

  /// The accessibility options configured for the notification system.
  NotificationA11yOptions get a11yOptions => _a11yOptions;

  /// Updates the configuration settings in-place.
  void reconfigure({
    final Set<NotificationQueue>? queues,
    final Set<NotificationChannel>? channels,
    final bool? strictChannelLookup,
    final int? maxHistoryEntries,
    final NotificationA11yOptions? a11yOptions,
  }) {
    if (queues != null) {
      _queues = _initQueues(queues);
    }
    if (channels != null) {
      _channels = Set.unmodifiable(channels);
    }
    if (strictChannelLookup != null) {
      _strictChannelLookup = strictChannelLookup;
    }
    if (maxHistoryEntries != null) {
      _maxHistoryEntries = maxHistoryEntries;
    }
    if (a11yOptions != null) {
      _a11yOptions = a11yOptions;
    }
  }

  /// Stores dynamically relocated queue positions mapping source positions
  /// to their new effective positions.
  final Map<QueuePosition, QueuePosition> _relocatedQueuePositions = {};

  /// Updates the relocated queue position route.
  void relocateQueuePosition(
    final QueuePosition sourcePosition,
    final QueuePosition newPosition,
  ) {
    // Update any queue currently pointing to sourcePosition to point to
    // newPosition
    _relocatedQueuePositions.updateAll(
      (final key, final value) => value == sourcePosition ? newPosition : value,
    );
    _relocatedQueuePositions[sourcePosition] = newPosition;
  }

  /// Returns the effective queue position, taking into account any permanent
  /// relocations.
  QueuePosition? getEffectiveQueuePosition(final QueuePosition? position) {
    if (position == null) {
      return null;
    }
    return _relocatedQueuePositions[position] ?? position;
  }

  /// Returns the effective position for a channel.
  @Deprecated('Use getEffectiveQueuePosition instead.')
  QueuePosition? getEffectiveChannelPosition(final String channelName) {
    final channel = getChannel(channelName);
    return getEffectiveQueuePosition(channel.position);
  }

  /// Returns a concise summary of the configuration.
  String get summary => '${queues.length} Queues '
      '(${queues.map((final q) => q.position.name).join(', ')}), '
      '${channels.length} Channels '
      '(${channels.map((final c) => c.name).join(', ')})';

  /// Expands relocation groups: for every [Relocate] and
  /// [ReorderAndRelocate] behavior, ensures sibling queues exist
  /// and the source position is included in the target set
  /// (self-inclusion, so notifications can return home).
  static Set<NotificationQueue> _expandRelocationGroups(
    final Set<NotificationQueue> inputQueues,
  ) {
    if (inputQueues.isEmpty) {
      return inputQueues;
    }

    final expanded = LinkedHashSet<NotificationQueue>(
      equals: (final a, final b) => a.position == b.position,
      hashCode: (final q) => q.position.hashCode,
    )..addAll(inputQueues);

    for (final queue in inputQueues) {
      for (final behavior in [
        queue.longPressDragBehavior,
        queue.dragBehavior,
      ]) {
        final Set<QueuePosition>? positions;
        if (behavior is Relocate) {
          positions = (behavior as Relocate).positions;
        } else if (behavior is ReorderAndRelocate) {
          positions = (behavior as ReorderAndRelocate).positions;
        } else {
          positions = null;
        }

        if (positions != null) {
          // Self-inclusion: add source position to targets
          positions.add(queue.position);
          // Expand: create sibling queues for all target positions
          for (final targetPosition in positions) {
            final alreadyRegistered =
                expanded.any((final q) => q.position == targetPosition);
            if (!alreadyRegistered) {
              _logger.debug(
                'Auto-generating sibling queue at $targetPosition '
                'from relocation group defined on ${queue.position}.',
              );
              expanded.add(targetPosition.generateQueueFrom(queue));
            }
          }
        }
      }
    }
    return expanded;
  }

  /// Validates relocation groups:
  /// 1. Ensures no [QueuePosition] is targeted by multiple relocation groups.
  /// 2. Enforces Cluster Invariance: ensures no target landing pad is
  ///    independently configured in [queues].
  static void _validateRelocationGroups(
    final Set<NotificationQueue> queues,
  ) {
    final targetToSourceMap = <QueuePosition, NotificationQueue>{};

    for (final queue in queues) {
      final targets = <QueuePosition>{};
      for (final behavior in [
        queue.longPressDragBehavior,
        queue.dragBehavior,
      ]) {
        if (behavior is Relocate) {
          targets.addAll((behavior as Relocate).positions);
        } else if (behavior is ReorderAndRelocate) {
          targets.addAll((behavior as ReorderAndRelocate).positions);
        }
      }

      for (final target in targets) {
        if (target == queue.position) {
          continue;
        }
        if (targetToSourceMap.containsKey(target) &&
            targetToSourceMap[target] != queue) {
          throw ArgumentError(
            '$target appears in multiple relocation groups '
            '(${queue.position.name} and '
            '${targetToSourceMap[target]!.position.name}). '
            'Relocation groups must be disjoint.',
          );
        }
        targetToSourceMap[target] = queue;
      }
    }

    // Enforce Cluster Invariance:
    // None of the explicitly provided queues can be a target of another queue.
    for (final queue in queues) {
      if (targetToSourceMap.containsKey(queue.position)) {
        final sourceQueue = targetToSourceMap[queue.position]!;
        final sourceName = sourceQueue.position.name;
        throw ArgumentError(
          'QueuePosition.${queue.position.name} cannot be configured as an '
          'independent queue because it is already a target landing pad in '
          'the relocation cluster defined on QueuePosition.$sourceName. '
          'Target positions inherit their cluster styles automatically.',
        );
      }
    }
  }

  /// Validates that queues have at least one interactive way to be dismissed.
  ///
  /// Prevents "Zombie" notifications that cannot be closed by the user.
  static void _validateInputResilience(
    final Set<NotificationQueue> queues,
  ) {
    for (final queue in queues) {
      final isDismissible = queue.dragBehavior is Dismiss ||
          queue.longPressDragBehavior is Dismiss;
      final hasCloseButton = queue.closeButtonBehavior is! Hidden;

      if (!isDismissible && !hasCloseButton) {
        throw ArgumentError(
          'Queue ${queue.position} configuration creates "Zombie"'
          ' notifications. Notifications in this queue cannot be dismissed '
          'by the user because gestures are disabled AND the close button '
          'is hidden.  Please enable at least one interaction method or '
          'show the close button.',
        );
      }
    }
  }

  static final _logger = Logger.get('fnq.Core.Manager');

  /// Resolves a [NotificationChannel] by [channelName].
  ///
  /// Returns the first registered channel if [channelName] is not found,
  /// or a default channel if no channels are registered.
  NotificationChannel getChannel(final String channelName) {
    if (channels.isEmpty) {
      return NotificationChannel.defaultChannel();
    }

    bool registeredChannel = false;
    final notificationChannel = channels.firstWhere(
      (final channel) {
        registeredChannel = channel.name == channelName;
        return registeredChannel;
      },
      orElse: () => NotificationChannel.defaultChannel(),
    );

    if (!registeredChannel) {
      if (strictChannelLookup) {
        throw ArgumentError(
          'Channel "$channelName" is not registered. '
          'To disable this check and fallback to defaults, '
          'set strictChannelLookup to false.',
        );
      }
      _logger.warning(
        'Channel "$channelName" is not registered. '
        'Falling back to the default channel. '
        'Register it via NotificationController(channels: {...}).',
      );
    }

    return notificationChannel;
  }

  /// Resolves a [NotificationQueue] by [position].
  ///
  /// If [position] is `null`, returns the first registered queue.
  /// If no queue is configured for the given position, generates a new
  /// queue from the default queue's style at the requested position.
  NotificationQueue getQueue(final QueuePosition? position) {
    // 1. Handle Null Position
    if (position == null) {
      if (queues.isNotEmpty) {
        return queues.first;
      }
      return const NotificationQueue(
        position: QueuePosition.topCenter,
        style: FilledQueueStyle(),
      );
    }

    // 2. Find Configured Queue
    final queue = queues.firstWhere(
      (final q) => q.position == position,
      orElse: () => NotificationQueue(position: position),
    );

    final isGenerated = !queues.contains(queue);

    if (!isGenerated) {
      return queue;
    } else {
      _logger.debug(
        'Position $position not configured. '
        'Generated default queue from style.',
      );
      return position.generateQueueFrom(queue);
    }
  }
}
