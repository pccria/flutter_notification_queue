part of 'core.dart';

/// The lifecycle bridge between [NotificationQueue]s and the rendering surface.
///
/// Owns the [OverlayPortalController] and manages the lifecycle of queue
/// widgets. Implements [NotificationScopeState] so that [NotificationScope]
/// can attach it to a [NotificationController].
class QueueCoordinator implements NotificationScopeState {
  QueueCoordinator({
    final ConfigurationManager? configuration,
  }) : configuration = configuration ??
            ConfigurationManager(
              queues: {const NotificationQueue()},
              channels: NotificationChannel.standardChannels(),
            ) {
    _historyLogger = HistoryLogger(
      maxEntries: this.configuration.maxHistoryEntries,
    )..startListening(events);
  }

  /// Creates a [QueueCoordinator] pre-configured from a
  /// [NotificationController].
  factory QueueCoordinator.fromController(
    final NotificationController controller,
  ) =>
      QueueCoordinator(configuration: controller.configuration);

  /// The configuration this coordinator was initialised with.
  final ConfigurationManager configuration;

  late final HistoryLogger _historyLogger;
  HistoryLogger get historyLogger => _historyLogger;

  static final _logger = Logger.get('fnq.Core.Coordinator');

  OverlayPortalController? _controller;

  /// Broadcast stream of all notification lifecycle events.
  final _eventController =
      StreamController<NotificationEvent>.broadcast(sync: true);

  /// A broadcast stream of all notification lifecycle events for this
  /// coordinator instance.
  @override
  Stream<NotificationEvent> get events => _eventController.stream;

  /// Emits [event] on [events] and records it in history if enabled.
  @internal
  void emitEvent(final NotificationEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Registry of keys to communicate with active queue widgets.
  final _widgetStateKeys = <QueuePosition, GlobalKey<QueueWidgetState>>{};

  /// Registry of notification IDs to their current queue position.
  final _positionById = <String, QueuePosition>{};

  /// Unregisters an ID if it is currently registered to [position].
  @internal
  void unregisterEntryId(final String id, final QueuePosition position) {
    if (_positionById[id] == position) {
      _positionById.remove(id);
    }
  }

  void _removeEntryFromPosition(final String id, final QueuePosition position) {
    final key = _widgetStateKeys[position];
    if (key?.currentState != null) {
      key!.currentState!.removeById(id);
    } else {
      _initializationQueue[position]?.removeWhere((final n) => n.id == id);
      unregisterEntryId(id, position);
      if (_initializationQueue[position]?.isEmpty ?? false) {
        _unmountQueue(position);
      }
    }
  }

  /// Holds notifications for queues that are initializing (mounting).
  ///
  /// This bridges the gap between a logical enqueue request and the visual
  /// mount of the [QueueWidget]. When a queue is requested but not yet mounted,
  /// items are stored here.
  final _initializationQueue = <QueuePosition, List<NotificationEntry>>{};

  /// The set of currently active queues (those with visible notifications).
  final _activeQueuesNotifier =
      ValueNotifier<Map<QueuePosition, NotificationQueue>>({});

  /// Active snooze timers that need to be cancelled if the coordinator
  /// detaches or disposes.
  final _snoozeTimers = <Timer>{};

  bool _isDisposed = false;

  /// Whether this coordinator has been disposed.
  bool get isDisposed => _isDisposed;

  void attach(final OverlayPortalController controller) {
    _logger.debug('Attaching OverlayPortalController...');
    _controller = controller;
  }

  void detach() {
    _logger.debug('Detaching OverlayPortalController...');
    for (final timer in _snoozeTimers) {
      timer.cancel();
    }
    _snoozeTimers.clear();
    for (final key in _widgetStateKeys.values) {
      key.currentState?.ditchAllDismissTimers();
    }
    _controller = null;
    _widgetStateKeys.clear();
    _initializationQueue.clear();
    _positionById.clear();
    if (!_isDisposed) {
      try {
        _activeQueuesNotifier.value = {};
      } on Object catch (e) {
        _logger.debug('Error resetting active queues notifier on detach: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    for (final key in _widgetStateKeys.values) {
      key.currentState?.ditchAllDismissTimers();
    }
    detach();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    _historyLogger.dispose();
    try {
      _activeQueuesNotifier.dispose();
    } on Object catch (e) {
      _logger.debug('Error disposing active queues notifier: $e');
    }
  }

  /// Retrieves and clears pending initialization items for a queue.
  /// Called by [QueueWidgetState.initState].
  List<NotificationEntry> consumeInitializationQueue(
    final QueuePosition position,
  ) =>
      _initializationQueue.remove(position) ?? [];

  /// Registers a queue's key.
  GlobalKey<QueueWidgetState> _getKey(final QueuePosition position) =>
      _widgetStateKeys.putIfAbsent(
        position,
        () => GlobalKey<QueueWidgetState>(),
      );

  // ── History ──────────────────────────────────────────────────────────────

  @override
  List<NotificationEvent> getHistory({
    final String? channelName,
    final DismissReason? dismissReason,
    final DateTime? since,
    final int? limit,
  }) =>
      _historyLogger.getHistory(
        channelName: channelName,
        dismissReason: dismissReason,
        since: since,
        limit: limit,
      );

  @override
  void clearHistory() => _historyLogger.clear();

  // --- Actions ---

  void queue(
    final NotificationWidget notification,
  ) {
    if (!notification.channel.enabled) {
      return;
    }

    final id = notification.id;
    final notificationQueue = notification.queue;
    final targetPosition = notificationQueue.position;

    // Cross-queue same-ID dispatch: if already at a different position,
    // remove first.
    final existingPosition = _positionById[id];
    if (existingPosition != null && existingPosition != targetPosition) {
      _removeEntryFromPosition(id, existingPosition);
    }
    _positionById[id] = targetPosition;

    _eventController.add(NotificationQueued(notification: notification));
    _announceNotification(notification);

    final key = _widgetStateKeys[targetPosition];
    final isMounted = key?.currentState != null;

    final entry = NotificationEntry(
      blueprint: notification,
      queue: notificationQueue,
    );

    if (isMounted) {
      // Widget is alive, delegate directly.
      key!.currentState!.enqueue(entry);
    } else {
      // Widget is not alive. Schedule startup.
      _initializationQueue
          .putIfAbsent(notificationQueue.position, () => [])
          .add(entry);
      _mountQueue(notificationQueue);
    }
  }

  @override
  String show(
    final AppNotification notification, {
    final QueuePosition? targetPosition,
  }) {
    final widget = notification.toWidget(
      configuration,
      this,
      targetPosition,
    );
    queue(widget);
    return widget.id;
  }

  // ── Dismiss ──────────────────────────────────────────────────────────────

  /// Resolves an active [NotificationWidget] by [id] in O(1) time.
  NotificationWidget? _resolveActiveWidget(final String? id) {
    if (id == null) {
      return null;
    }
    final pos = _positionById[id];
    if (pos == null) {
      return null;
    }
    return _widgetStateKeys[pos]?.currentState?.getNotificationWidget(id);
  }

  /// Dismisses the notification with [id].
  @override
  void dismissById(
    final String id, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    final activeWidget = _resolveActiveWidget(id);
    if (activeWidget != null) {
      dismissWidget(activeWidget, reason: reason);
      return;
    }

    final pos = _positionById[id];
    if (pos != null) {
      final key = _widgetStateKeys[pos];
      if (key?.currentState != null && key!.currentState!.containsId(id)) {
        key.currentState!.dismissById(id, reason: reason);
        return;
      }
      final initQueue = _initializationQueue[pos];
      if (initQueue != null) {
        final index = initQueue.indexWhere((final n) => n.id == id);
        if (index != -1) {
          final entry = initQueue.removeAt(index);
          unregisterEntryId(id, pos);
          _eventController.add(
            NotificationDismissed(
              notification: entry.blueprint,
              reason: reason,
            ),
          );
          if (initQueue.isEmpty) {
            _unmountQueue(pos);
          }
          return;
        }
      }
    }
  }

  /// Dismisses the notification described by [notification] by matching its id.
  @override
  void dismiss(
    final AppNotification notification, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    final id = notification.id;
    if (id != null) {
      dismissById(id, reason: reason);
    }
  }

  /// Dismisses [notification] directly by widget reference.
  ///
  /// Used internally by gesture plugins and lifecycle handlers that operate on
  /// a [NotificationWidget] instance rather than an [AppNotification] record.
  void dismissWidget(
    final NotificationWidget notification, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    _eventController.add(
      NotificationDismissed(notification: notification, reason: reason),
    );

    final pos = _positionById[notification.id] ?? notification.queue.position;
    var key = _widgetStateKeys[pos];
    if (key?.currentState == null ||
        !key!.currentState!.containsId(notification.id)) {
      for (final candidate in _widgetStateKeys.values) {
        if (candidate.currentState != null &&
            candidate.currentState!.containsId(notification.id)) {
          key = candidate;
          break;
        }
      }
    }
    if (key?.currentState != null) {
      key!.currentState!.dismissById(notification.id, reason: reason);
    } else {
      final notificationQueue = notification.queue;
      _initializationQueue[notificationQueue.position]
          ?.removeWhere((final n) => n.id == notification.id);
      unregisterEntryId(notification.id, notificationQueue.position);

      if (_initializationQueue[notificationQueue.position]?.isEmpty ?? false) {
        _unmountQueue(notificationQueue.position);
      }
    }
  }

  /// Dismisses the newest active notification across all active queues.
  @override
  void dismissNewest() {
    NotificationWidget? newest;
    for (final key in _widgetStateKeys.values) {
      final candidate = key.currentState?.newestActiveNotification;
      if (candidate != null) {
        if (newest == null || candidate.createdAt.isAfter(newest.createdAt)) {
          newest = candidate;
        }
      }
    }
    if (newest != null) {
      dismissWidget(newest, reason: DismissReason.programmatic);
    }
  }

  /// Dismisses all active notifications across all active queues.
  @override
  void dismissAll({
    final DismissReason reason = DismissReason.programmatic,
  }) {
    final active = activeNotifications;
    for (final notification in active) {
      dismissWidget(notification, reason: reason);
    }
  }

  /// Dismisses all active and pending notifications that share [groupKey].
  @override
  void dismissGroup(
    final String groupKey, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    for (final entry in _widgetStateKeys.entries) {
      final position = entry.key;
      final state = entry.value.currentState;
      final hasActive = state != null && state.hasActiveGroup(groupKey);
      final hasPending =
          state != null && state.countPendingForGroup(groupKey) > 0;
      final initQueue = _initializationQueue[position];
      final hasInit = initQueue != null &&
          initQueue.any((final e) => e.resolvedGroupKey == groupKey);

      if (hasActive || hasPending) {
        emitGroupDismissed(groupKey: groupKey, position: position);
        state.dismissGroup(groupKey, reason: reason);
      }

      if (hasInit) {
        if (!hasActive && !hasPending) {
          emitGroupDismissed(groupKey: groupKey, position: position);
        }
        initQueue.removeWhere((final entry) {
          if (entry.resolvedGroupKey == groupKey) {
            unregisterEntryId(entry.id, position);
            emitDismissed(
              notification: entry.blueprint,
              reason: reason,
            );
            return true;
          }
          return false;
        });
        if (initQueue.isEmpty) {
          _unmountQueue(position);
        }
      }
    }
  }

  /// Legacy widget-level helper for group dismissal at a specific [position].
  void dismissGroupAt(
    final QueuePosition position,
    final String groupKey, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    final state = _widgetStateKeys[position]?.currentState;
    final hasActive = state != null && state.hasActiveGroup(groupKey);
    final hasPending =
        state != null && state.countPendingForGroup(groupKey) > 0;
    final initQueue = _initializationQueue[position];
    final hasInit = initQueue != null &&
        initQueue.any((final e) => e.resolvedGroupKey == groupKey);

    if (hasActive || hasPending || hasInit) {
      emitGroupDismissed(groupKey: groupKey, position: position);
    }

    state?.dismissGroup(groupKey, reason: reason);

    if (hasInit) {
      initQueue.removeWhere((final entry) {
        if (entry.resolvedGroupKey == groupKey) {
          unregisterEntryId(entry.id, position);
          emitDismissed(
            notification: entry.blueprint,
            reason: reason,
          );
          return true;
        }
        return false;
      });
      if (initQueue.isEmpty) {
        _unmountQueue(position);
      }
    }
  }

  // ── Relocate ─────────────────────────────────────────────────────────────

  /// Moves the notification with [id] to [newPosition].
  @override
  void relocateById(final String id, final QueuePosition newPosition) {
    final activeWidget = _resolveActiveWidget(id);
    if (activeWidget != null) {
      relocateWidget(activeWidget, newPosition);
    }
  }

  /// Moves the notification described by [notification] to [newPosition].
  @override
  void relocate(
    final AppNotification notification,
    final QueuePosition newPosition,
  ) {
    final id = notification.id;
    if (id != null) {
      relocateById(id, newPosition);
    }
  }

  /// Moves [notification] (by widget reference) to [newPosition].
  ///
  /// Used internally by gesture plugins.
  NotificationWidget? relocateWidget(
    final NotificationWidget notification,
    final QueuePosition newPosition, {
    final bool migrateSiblings = true,
  }) {
    final notificationQueue = notification.queue;
    NotificationWidget? newNotification;
    QueuePosition fromPosition = notificationQueue.position;
    var sourceKey = _widgetStateKeys[fromPosition];
    if (sourceKey?.currentState == null ||
        !sourceKey!.currentState!.containsId(notification.id)) {
      for (final entry in _widgetStateKeys.entries) {
        if (entry.value.currentState != null &&
            entry.value.currentState!.containsId(notification.id)) {
          fromPosition = entry.key;
          sourceKey = entry.value;
          break;
        }
      }
    }

    // Determine if relocation is permanent for this queue
    bool isPermanent = false;
    for (final behavior in [
      notificationQueue.longPressDragBehavior,
      notificationQueue.dragBehavior,
    ]) {
      if (behavior is Relocate && (behavior as Relocate).permanent) {
        isPermanent = true;
        break;
      }
      if (behavior is ReorderAndRelocate &&
          (behavior as ReorderAndRelocate).permanent) {
        isPermanent = true;
        break;
      }
    }

    // Capture sibling notifications before removing the dragged card.
    // In permanent relocation, ALL notifications (active and pending) migrate.
    final pendingToMigrate = <NotificationWidget>[];
    final activeToMigrate = <NotificationWidget>[];

    if (isPermanent && migrateSiblings) {
      final state = sourceKey?.currentState;
      if (state != null) {
        // Drain pending notifications first so remove() does NOT promote them
        // into the old queue!
        pendingToMigrate.addAll(
          state.drainPendingNotifications(
            excludeId: notification.id,
          ),
        );
        activeToMigrate.addAll(
          state.activeNotifications.where(
            (final n) => n.id != notification.id,
          ),
        );
      }
      // Capture any unmounted notifications in _initializationQueue
      final initQueue = _initializationQueue[fromPosition];
      if (initQueue != null) {
        pendingToMigrate.addAll(
          initQueue
              .where((final e) => e.id != notification.id)
              .map((final e) => e.blueprint),
        );
        initQueue.clear();
      }
    }

    // 1. Remove from source
    bool removed = false;
    final sourceState = sourceKey?.currentState;
    if (sourceState != null) {
      removed = sourceState.remove(notification);
    } else {
      // Check initialization queue
      final initQueue = _initializationQueue[fromPosition];
      if (initQueue != null) {
        final initialLen = initQueue.length;
        initQueue.removeWhere((final n) => n.id == notification.id);
        removed = initQueue.length < initialLen;
      }
    }

    // 2. Add to target if removed
    if (removed) {
      final targetQueue = newPosition.generateQueueFrom(notification.queue);
      final migrated = notification.copyToQueue(targetQueue);
      newNotification = migrated;
      _positionById[notification.id] = newPosition;

      // Register dragged notification callback first
      WidgetsBinding.instance.addPostFrameCallback((final _) {
        queue(migrated);
      });

      final config = configuration;
      if (isPermanent && migrateSiblings) {
        config.relocateQueuePosition(fromPosition, newPosition);
        _eventController.add(
          QueuePositionRelocated(
            from: fromPosition,
            to: newPosition,
            permanent: true,
          ),
        );

        // Migrate all remaining active notifications in this queue
        for (final sibling in activeToMigrate) {
          relocateWidget(sibling, newPosition, migrateSiblings: false);
        }

        // Migrate all pending notifications to the new queue
        WidgetsBinding.instance.addPostFrameCallback((final _) {
          for (final pending in pendingToMigrate) {
            final targetPending = pending.copyToQueue(targetQueue);
            _eventController.add(
              NotificationRelocated(
                notification: targetPending,
                from: fromPosition,
                to: newPosition,
              ),
            );
            queue(targetPending);
          }
        });
      }

      _eventController.add(
        NotificationRelocated(
          notification: newNotification,
          from: fromPosition,
          to: newPosition,
        ),
      );
    }

    return newNotification;
  }

  // ── Reorder ──────────────────────────────────────────────────────────────

  /// Reorders [notification] to [targetIndex] within its queue.
  @override
  void reorder(final AppNotification notification, final int targetIndex) {
    final activeWidget = _resolveActiveWidget(notification.id);
    if (activeWidget != null) {
      reorderWidget(activeWidget, targetIndex);
    }
  }

  /// Reorders [notification] (by widget reference) to [targetIndex].
  ///
  /// Used internally by gesture plugins.
  void reorderWidget(
    final NotificationWidget notification,
    final int targetIndex,
  ) {
    _eventController.add(
      NotificationReordered(notification: notification, toIndex: targetIndex),
    );
    final key = _widgetStateKeys[notification.queue.position];
    key?.currentState?.reorder(notification, targetIndex);
  }

  /// Temporarily hides the notification with [id] and re-enqueues it after
  /// [duration].
  @override
  void snoozeById(final String id, final Duration duration) {
    final activeWidget = _resolveActiveWidget(id);
    if (activeWidget != null) {
      snoozeWidget(activeWidget, duration);
    }
  }

  /// Temporarily hides [notification] and re-enqueues it after [duration].
  @override
  void snooze(final AppNotification notification, final Duration duration) {
    final id = notification.id;
    if (id != null) {
      snoozeById(id, duration);
    }
  }

  /// Snoozes [notification] (by widget reference) for [duration].
  ///
  /// Used internally by gesture plugins.
  void snoozeWidget(
    final NotificationWidget notification,
    final Duration duration,
  ) {
    // 1. Remove from active queue
    final notificationQueue = notification.queue;
    final key = _widgetStateKeys[notificationQueue.position];
    if (key?.currentState != null) {
      key!.currentState!.remove(notification);
    } else {
      _initializationQueue[notificationQueue.position]
          ?.removeWhere((final n) => n.id == notification.id);
      unregisterEntryId(notification.id, notificationQueue.position);
    }

    // 2. Emit NotificationSnoozed event
    _eventController.add(
      NotificationSnoozed(notification: notification, duration: duration),
    );

    // 3. Schedule auto-re-queue
    late final Timer timer;
    timer = Timer(duration, () {
      _snoozeTimers.remove(timer);
      if (_isDisposed) {
        return;
      }
      final freshCopy = notification.copyForRequeue(snoozedAt: null);
      queue(freshCopy);
    });
    _snoozeTimers.add(timer);
  }

  // ── Pin / Unpin ──────────────────────────────────────────────────────────

  /// Locks the notification with [id] to the top of its queue.
  @override
  void pinById(final String id) {
    final activeWidget = _resolveActiveWidget(id);
    if (activeWidget != null) {
      pinWidget(activeWidget);
    }
  }

  /// Pins [notification], making it persistent and immune to swipe gestures.
  @override
  void pin(final AppNotification notification) {
    final id = notification.id;
    if (id != null) {
      pinById(id);
    }
  }

  /// Pins [notification] (by widget reference).
  ///
  /// Used internally by gesture plugins.
  void pinWidget(final NotificationWidget notification) {
    notification.isPinnedNotifier.value = true;
    _eventController.add(
      NotificationPinned(
        notification: notification.key.currentState?.widget ?? notification,
      ),
    );
  }

  /// Releases the pin on the notification with [id].
  @override
  void unpinById(final String id) {
    final activeWidget = _resolveActiveWidget(id);
    if (activeWidget != null) {
      unpinWidget(activeWidget);
    }
  }

  /// Releases the pin on [notification].
  @override
  void unpin(final AppNotification notification) {
    final id = notification.id;
    if (id != null) {
      unpinById(id);
    }
  }

  /// Releases the pin on [notification] (by widget reference).
  ///
  /// Used internally by gesture plugins.
  void unpinWidget(final NotificationWidget notification) {
    notification.isPinnedNotifier.value = false;
    _eventController.add(
      NotificationUnpinned(
        notification: notification.key.currentState?.widget ?? notification,
      ),
    );
  }

  // ── Update ───────────────────────────────────────────────────────────────

  /// Updates an active or pending notification by [id] in place.
  @override
  bool update(
    final String id, {
    final String? message,
    final String? title,
    final Widget? icon,
    final NotificationAction? action,
    final NotificationPriority? priority,
    final Color? color,
    final Color? backgroundColor,
    final Color? foregroundColor,
    final Color? accentColor,
    final Duration? dismissDuration,
    final bool? permanent,
    final bool resetTimer = false,
  }) {
    final pos = _positionById[id];
    if (pos == null) {
      return false;
    }
    final key = _widgetStateKeys[pos];
    if (key?.currentState != null) {
      final result = key!.currentState!.updateById(
        id,
        message: message,
        title: title,
        icon: icon,
        action: action,
        priority: priority,
        color: color,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        accentColor: accentColor,
        dismissDuration: dismissDuration,
        permanent: permanent,
        resetTimer: resetTimer,
      );
      if (result != null) {
        _eventController.add(
          NotificationUpdated(
            notification: result.updated,
            oldNotification: result.old,
          ),
        );
        return true;
      }
    }
    final initQueue = _initializationQueue[pos];
    if (initQueue != null) {
      final index = initQueue.indexWhere((final e) => e.id == id);
      if (index != -1) {
        final oldEntry = initQueue[index];
        final updatedWidget = oldEntry.blueprint.copyForUpdate(
          message: message,
          title: title,
          icon: icon,
          action: action,
          priority: priority,
          color: color,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          accentColor: accentColor,
          dismissDuration: dismissDuration,
          permanent: permanent,
        );
        final newEntry = NotificationEntry(
          blueprint: updatedWidget,
          queue: oldEntry.queue,
        )..isPinned = oldEntry.isPinned;
        initQueue[index] = newEntry;
        _eventController.add(
          NotificationUpdated(
            notification: updatedWidget,
            oldNotification: oldEntry.blueprint,
          ),
        );
        return true;
      }
    }
    return false;
  }

  /// Updates an active or pending notification by applying [transform].
  @override
  bool updateWith(
    final String id,
    final AppNotification Function(AppNotification current) transform, {
    final bool resetTimer = false,
  }) {
    final pos = _positionById[id];
    if (pos == null) {
      return false;
    }
    final key = _widgetStateKeys[pos];
    if (key?.currentState != null) {
      final currentWidget = key!.currentState!.getNotificationWidget(id) ??
          key.currentState!.getPendingWidget(id);
      if (currentWidget != null) {
        final currentApp = currentWidget.toAppNotification();
        final transformed = transform(currentApp);
        return update(
          id,
          message: transformed.message,
          title: transformed.title,
          icon: transformed.icon,
          action: transformed.action,
          priority: transformed.priority,
          accentColor: transformed.accentColor,
          dismissDuration: transformed.dismissDuration,
          permanent: transformed.permanent,
          resetTimer: resetTimer,
        );
      }
    }
    final initQueue = _initializationQueue[pos];
    if (initQueue != null) {
      final index = initQueue.indexWhere((final e) => e.id == id);
      if (index != -1) {
        final currentWidget = initQueue[index].blueprint;
        final currentApp = currentWidget.toAppNotification();
        final transformed = transform(currentApp);
        return update(
          id,
          message: transformed.message,
          title: transformed.title,
          icon: transformed.icon,
          action: transformed.action,
          priority: transformed.priority,
          accentColor: transformed.accentColor,
          dismissDuration: transformed.dismissDuration,
          permanent: transformed.permanent,
          resetTimer: resetTimer,
        );
      }
    }
    return false;
  }

  // ── Misc Actions ─────────────────────────────────────────────────────────

  /// Triggers a developer-defined custom action on [notification].
  void triggerCustomAction(
    final NotificationWidget notification,
    final String actionName,
  ) {
    _eventController.add(
      NotificationCustomActionTriggered(
        notification: notification,
        actionName: actionName,
      ),
    );
  }

  void bringToFront(final QueuePosition position) {
    if (!_activeQueuesNotifier.value.containsKey(position)) {
      return;
    }
    final currentMap = Map.of(_activeQueuesNotifier.value);
    final queue = currentMap.remove(position)!;
    currentMap[position] = queue;
    _activeQueuesNotifier.value = currentMap;
  }

  /// Called by QueueWidgetState when it's empty to self-destruct.
  void unmountQueue(final QueuePosition position) {
    _unmountQueue(position);
  }

  // ── Accessibility & Focus Traversal ──────────────────────────────────────

  void _announceNotification(final NotificationWidget notification) {
    final a11y = configuration.a11yOptions;
    if (!a11y.enableLiveRegions) {
      return;
    }
    final priority = notification.resolvedPriority;
    if (priority < a11y.announcePriorityThreshold) {
      return;
    }
    final title = notification.title;
    final message = notification.message;
    final announcement = title != null && title.isNotEmpty
        ? '$title: $message'
        : message;
    final assertiveness = priority == NotificationPriority.critical
        ? Assertiveness.assertive
        : Assertiveness.polite;

    final view = PlatformDispatcher.instance.implicitView ??
        PlatformDispatcher.instance.views.firstOrNull;
    if (view != null) {
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          announcement,
          TextDirection.ltr,
          assertiveness: assertiveness,
        ),
      );
    }
  }

  /// Attempts to transfer keyboard focus to the first active notification card.
  ///
  /// Returns `true` if a notification card received focus; `false` otherwise.
  bool focusFirstNotification() {
    for (final key in _widgetStateKeys.values) {
      final state = key.currentState;
      if (state != null && state.focusFirst()) {
        return true;
      }
    }
    return false;
  }

  /// Whether any active notification card currently holds keyboard focus.
  bool get isNotificationFocused {
    for (final key in _widgetStateKeys.values) {
      final state = key.currentState;
      if (state != null && state.hasFocusedNotification) {
        return true;
      }
    }
    return false;
  }

  // --- Helpers ---

  void _mountQueue(final NotificationQueue queue) {
    if (_activeQueuesNotifier.value.containsKey(queue.position)) {
      return;
    }

    _getKey(queue.position); // Ensure key exists
    final newMap = Map.of(_activeQueuesNotifier.value);
    newMap[queue.position] = queue;
    _activeQueuesNotifier.value = newMap;
    _controller?.show();
  }

  void _unmountQueue(final QueuePosition position) {
    if (!_activeQueuesNotifier.value.containsKey(position)) {
      return;
    }

    final newMap = Map.of(_activeQueuesNotifier.value)..remove(position);
    _activeQueuesNotifier.value = newMap;

    // We can clean up the key too if we want fresh state next time
    // (which we do, since the widget is disposing)
    _widgetStateKeys.remove(position);
    _initializationQueue.remove(position);

    if (newMap.isEmpty) {
      _controller?.hide();
    }
  }

  /// Emits a [NotificationTapped] event.
  ///
  /// Called by [NotificationWidgetState] which lives in a separate library
  /// and cannot access the private [_eventController] directly.
  void emitTapped({
    required final NotificationWidget notification,
    required final TapBehavior behavior,
  }) =>
      _eventController.add(
        NotificationTapped(notification: notification, behavior: behavior),
      );

  /// Emits a [QueueOverflowed] event.
  ///
  /// Called by [QueueWidgetState] when a notification is dropped.
  void emitOverflowed({
    required final NotificationQueue queue,
    required final NotificationWidget dropped,
  }) =>
      _eventController.add(QueueOverflowed(queue: queue, dropped: dropped));

  /// Emits a [NotificationGroupExpanded] or [NotificationGroupCollapsed]
  /// event depending on [expanded].
  ///
  /// Called by [QueueWidgetState] when the bundle pill is toggled.
  void emitGroupToggled({
    required final String groupKey,
    required final QueuePosition position,
    required final bool expanded,
    required final int count,
  }) =>
      _eventController.add(
        expanded
            ? NotificationGroupExpanded(
                groupKey: groupKey,
                position: position,
                count: count,
              )
            : NotificationGroupCollapsed(
                groupKey: groupKey,
                position: position,
                count: count,
              ),
      );

  /// Emits a [NotificationGroupDismissed] event.
  ///
  /// Called by [QueueWidgetState] when a group is swiped or dismissed.
  void emitGroupDismissed({
    required final String groupKey,
    required final QueuePosition position,
  }) =>
      emitEvent(
        NotificationGroupDismissed(groupKey: groupKey, position: position),
      );

  /// Emits a [NotificationDismissed] event.
  ///
  /// Called by [QueueWidgetState] when a notification is dismissed.
  void emitDismissed({
    required final NotificationWidget notification,
    required final DismissReason reason,
  }) =>
      emitEvent(
        NotificationDismissed(notification: notification, reason: reason),
      );

  /// Exposed for overlay.
  GlobalKey<QueueWidgetState> getWidgetKey(final QueuePosition position) =>
      _widgetStateKeys.putIfAbsent(
        position,
        () => GlobalKey<QueueWidgetState>(),
      );

  ValueListenable<Map<QueuePosition, NotificationQueue>> get activeQueues =>
      _activeQueuesNotifier;

  /// Returns a list of all currently active notifications across all active
  /// queues.
  List<NotificationWidget> get activeNotifications {
    final list = <NotificationWidget>[];
    for (final key in _widgetStateKeys.values) {
      final state = key.currentState;
      if (state != null) {
        list.addAll(state.activeNotifications);
      }
    }
    return list;
  }

  /// Returns a list of all currently pending notifications waiting across all
  /// queues and initializing queues.
  List<NotificationWidget> get pendingNotifications {
    final list = <NotificationWidget>[];
    for (final key in _widgetStateKeys.values) {
      final state = key.currentState;
      if (state != null) {
        list.addAll(state.pendingNotifications);
      }
    }
    for (final entries in _initializationQueue.values) {
      list.addAll(entries.map((final e) => e.blueprint));
    }
    return list;
  }
}
