part of 'notification_queue.dart';

class _QueueLayoutSnapshot {
  const _QueueLayoutSnapshot({
    required this.visibleItems,
    required this.visibleIndexById,
    required this.itemGlobalKeys,
    required this.blocks,
  });

  final List<_NotificationItemState> visibleItems;
  final Map<String, int> visibleIndexById;
  final List<GlobalKey> itemGlobalKeys;
  final List<_QueueRenderBlock> blocks;
}

class QueueWidget extends StatefulWidget {
  const QueueWidget({
    required this.queue,
    this.coordinator,
    this.isEmbeddedInLayout = false,
    super.key,
  });

  final NotificationQueue queue;
  final QueueCoordinator? coordinator;
  final bool isEmbeddedInLayout;

  @override
  State<QueueWidget> createState() => QueueWidgetState();
}

class QueueWidgetState extends State<QueueWidget>
    with TickerProviderStateMixin, CoordinatorResolver<QueueWidget> {
  QueueCoordinator? _cachedCoordinator;
  bool _hasWebQueueHoverDisable = false;

  QueueCoordinator get _coordinator =>
      _cachedCoordinator ??
      resolveCoordinator(
        explicitCoordinator: widget.coordinator,
        callerName: 'QueueWidget',
      );

  final _pendingNotifications = Queue<NotificationEntry>();
  final Map<String, NotificationEntry> _pendingById = {};
  final List<_NotificationItemState> _items = [];
  final Map<String, _NotificationItemState> _itemById = {};
  final Set<String> _expandedGroups = {};

  _QueueLayoutSnapshot? _cachedSnapshot;
  _QueueLayoutSnapshot get _snapshot => _cachedSnapshot ??= _computeSnapshot();

  void _invalidateSnapshot() {
    _cachedSnapshot = null;
  }

  /// Global visible index of an item by its ID.
  int visibleIndexOf(final String id) => _snapshot.visibleIndexById[id] ?? 0;

  /// Retrieves an active [NotificationWidget] by [id], if present.
  NotificationWidget? getNotificationWidget(final String id) =>
      _itemById[id]?.widget;

  /// Retrieves a pending [NotificationWidget] by [id], if present in the
  /// backlog.
  NotificationWidget? getPendingWidget(final String id) =>
      _pendingById[id]?.blueprint;

  /// The newest active notification in this queue.
  NotificationWidget? get newestActiveNotification {
    NotificationWidget? newest;
    for (final item in _items) {
      if (item.status != _ItemStatus.exiting) {
        if (newest == null || item.widget.createdAt.isAfter(newest.createdAt)) {
          newest = item.widget;
        }
      }
    }
    return newest;
  }

  /// Focuses the first active non-exiting notification card in this queue.
  bool focusFirst() {
    for (final item in _items) {
      if (item.status != _ItemStatus.exiting) {
        final state = item.widget.key.currentState;
        if (state != null && state.mounted) {
          state.requestFocus();
          return true;
        }
      }
    }
    return false;
  }

  /// Whether any active notification card in this queue currently has focus.
  bool get hasFocusedNotification {
    for (final item in _items) {
      if (item.status != _ItemStatus.exiting) {
        final state = item.widget.key.currentState;
        if (state != null && state.isFocused) {
          return true;
        }
      }
    }
    return false;
  }

  /// Shifts focus to the next visible card in this queue.
  void focusNext(final String currentId) {
    final visible =
        _items.where((final i) => i.status != _ItemStatus.exiting).toList();
    if (visible.length <= 1) {
      return;
    }
    final currentIndex =
        visible.indexWhere((final i) => i.widget.id == currentId);
    if (currentIndex != -1) {
      final nextIndex = (currentIndex + 1) % visible.length;
      visible[nextIndex].widget.key.currentState?.requestFocus();
    }
  }

  /// Shifts focus to the previous visible card in this queue.
  void focusPrevious(final String currentId) {
    final visible =
        _items.where((final i) => i.status != _ItemStatus.exiting).toList();
    if (visible.length <= 1) {
      return;
    }
    final currentIndex =
        visible.indexWhere((final i) => i.widget.id == currentId);
    if (currentIndex != -1) {
      final prevIndex =
          (currentIndex - 1 + visible.length) % visible.length;
      visible[prevIndex].widget.key.currentState?.requestFocus();
    }
  }

  /// Returns whether this queue contains any active notifications
  /// for [groupKey].
  bool hasActiveGroup(final String groupKey) {
    for (final item in _items) {
      if (item.status != _ItemStatus.exiting &&
          item.widget.resolvedGroupKey == groupKey) {
        return true;
      }
    }
    return false;
  }

  /// Returns the number of un-rendered notifications currently queued in the
  /// pending backlog that share [groupKey].
  int countPendingForGroup(final String groupKey) {
    int count = 0;
    for (final entry in _pendingNotifications) {
      if (entry.resolvedGroupKey == groupKey) {
        count++;
      }
    }
    return count;
  }

  /// The resolved group key of the group whose representative is currently
  /// being dragged. While non-null, the item immediately behind the
  /// representative ("the peek card") is also rendered as visible so the
  /// user can see the next notification surface from beneath the lifted card.
  String? _activeDragGroupKey;

  /// Called by the gesture plugins at drag-start on a group representative.
  void setActiveDragGroup(final String? key) {
    if (_activeDragGroupKey == key) {
      return;
    }
    final previousKey = _activeDragGroupKey;
    setState(() => _activeDragGroupKey = key);
    _invalidateSnapshot();
    if (previousKey != null && previousKey != key) {
      _syncGroupTimers(previousKey);
    }
    if (key != null) {
      _syncGroupTimers(key);
    }
  }

  List<_NotificationItemState> get _visibleItems => _snapshot.visibleItems;

  /// Key attached to the inner Column to measure the queue's exact visual
  /// bounds.
  final GlobalKey _listKey = GlobalKey();

  final ValueNotifier<({int origin, int target})?> _reorderDragState =
      ValueNotifier(null);

  void startDragReorder(final String itemId, final int originIndex) {
    _reorderDragState.value = (origin: originIndex, target: originIndex);
  }

  void updateDragTarget(final int targetIndex) {
    final current = _reorderDragState.value;
    if (current != null && current.target != targetIndex) {
      _reorderDragState.value = (origin: current.origin, target: targetIndex);
    }
  }

  void clearDragTarget() {
    _reorderDragState.value = null;
  }

  void endDragReorder() {
    _reorderDragState.value = null;
  }

  double _getItemHeight(final int visibleIndex) {
    final visible = _visibleItems;
    if (visibleIndex < 0 || visibleIndex >= visible.length) {
      return 0.0;
    }
    final key = visible[visibleIndex].globalKey;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.size.height;
    }
    return 80.0;
  }

  double getTranslationY(final int i, final int origin, final int target) {
    if (origin == target) {
      return 0.0;
    }

    final spacing = widget.queue.spacing;
    final directionMultiplier =
        widget.queue.verticalDirection == VerticalDirection.down ? 1.0 : -1.0;

    if (target < origin) {
      if (i >= target && i < origin) {
        final draggedHeight = _getItemHeight(origin) + spacing;
        return draggedHeight * directionMultiplier;
      }
      if (i == origin) {
        double totalOffset = 0.0;
        for (int k = target; k < origin; k++) {
          totalOffset += _getItemHeight(k) + spacing;
        }
        return -totalOffset * directionMultiplier;
      }
    } else if (target > origin) {
      if (i > origin && i <= target) {
        final draggedHeight = _getItemHeight(origin) + spacing;
        return -draggedHeight * directionMultiplier;
      }
      if (i == origin) {
        double totalOffset = 0.0;
        for (int k = origin + 1; k <= target; k++) {
          totalOffset += _getItemHeight(k) + spacing;
        }
        return totalOffset * directionMultiplier;
      }
    }
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _cachedCoordinator = resolveCoordinator(
      explicitCoordinator: widget.coordinator,
      callerName: 'QueueWidget',
    );
    final startupItems =
        _coordinator.consumeInitializationQueue(widget.queue.position);
    for (final item in startupItems) {
      _pendingNotifications.add(item);
      _pendingById[item.id] = item;
    }
    _sortPending();
    _processPending();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedCoordinator = resolveCoordinator(
      explicitCoordinator: widget.coordinator,
      callerName: 'QueueWidget',
    );
  }

  /// Stops and cancels all active dismiss timers and tickers in this queue.
  void ditchAllDismissTimers() {
    for (final item in _items) {
      item.widget.key.currentState?.ditchDismissTimer();
      if (item.controller.isAnimating) {
        item.controller.stop(canceled: false);
      }
      try {
        item.controller.dispose();
      } on Object catch (_) {}
    }
    _items.clear();
    _itemById.clear();
    _pendingNotifications.clear();
    _pendingById.clear();
    _invalidateSnapshot();
  }

  @override
  void dispose() {
    if (kIsWeb && _hasWebQueueHoverDisable) {
      _cachedCoordinator?.webContextMenuController.releaseDisable();
      _hasWebQueueHoverDisable = false;
    }
    _reorderDragState.dispose();
    ditchAllDismissTimers();
    super.dispose();
  }

  void enqueue(final NotificationEntry entry) {
    // 1. Update Existing Active
    final existingItem = _itemById[entry.id];
    if (existingItem != null) {
      setState(() {
        existingItem.entry = entry;
        _invalidateSnapshot();
      });
      return;
    }

    // 2. Update Pending (in-place)
    if (_pendingById.containsKey(entry.id)) {
      _pendingById[entry.id] = entry;
      final tempQueue = Queue<NotificationEntry>();
      while (_pendingNotifications.isNotEmpty) {
        final n = _pendingNotifications.removeFirst();
        if (n.id == entry.id) {
          tempQueue.add(entry);
        } else {
          tempQueue.add(n);
        }
      }
      _pendingNotifications.addAll(tempQueue);
      _sortPending();
      return;
    }

    // 3. Enqueue New
    if (widget.queue.maxPendingSize != null &&
        _pendingNotifications.length >= widget.queue.maxPendingSize!) {
      if (widget.queue.overflowStrategy ==
          QueueOverflowStrategy.discardOldest) {
        var lowestPriority = NotificationPriority.critical;
        for (final item in _pendingNotifications) {
          if (item.resolvedPriority.index < lowestPriority.index) {
            lowestPriority = item.resolvedPriority;
          }
        }
        final oldestOfLowest = _pendingNotifications.firstWhere(
          (final item) => item.resolvedPriority == lowestPriority,
        );
        _pendingNotifications.remove(oldestOfLowest);
        _pendingById.remove(oldestOfLowest.id);
        _coordinator
          ..unregisterEntryId(
            oldestOfLowest.id,
            widget.queue.position,
          )
          ..emitOverflowed(
            queue: widget.queue,
            dropped: oldestOfLowest.blueprint,
          );
        _pendingNotifications.add(entry);
        _pendingById[entry.id] = entry;
      } else {
        _coordinator
          ..unregisterEntryId(
            entry.id,
            widget.queue.position,
          )
          ..emitOverflowed(
            queue: widget.queue,
            dropped: entry.blueprint,
          );
        return;
      }
    } else {
      _pendingNotifications.add(entry);
      _pendingById[entry.id] = entry;
    }
    _sortPending();
    _triagePriorityEviction();
    _processPending();
    if (mounted) {
      setState(() {});
    }
  }

  /// Returns true when [item] is the "peek card" — the card rendered
  /// semi-transparently behind the dragged representative.
  bool _isPeekItem(
    final _NotificationItemState item,
    final String groupKey,
    final List<_NotificationItemState> activeGroupItems,
  ) {
    if (_activeDragGroupKey != groupKey) {
      return false;
    }
    final rep = _groupRepresentative(activeGroupItems);
    final repIdx = activeGroupItems.indexOf(rep);
    final peekIdx = widget.queue.verticalDirection == VerticalDirection.up
        ? repIdx + 1
        : repIdx - 1;
    if (peekIdx < 0 || peekIdx >= activeGroupItems.length) {
      return false;
    }
    return item == activeGroupItems[peekIdx];
  }

  /// Returns the notification that acts as the visible representative for
  /// a collapsed group. For top-anchored queues the newest card
  /// (`last`) is shown; for bottom-anchored queues the oldest (`first`)
  /// is shown because it sits closest to the screen edge the user reads.
  _NotificationItemState _groupRepresentative(
    final List<_NotificationItemState> groupItems,
  ) =>
      widget.queue.verticalDirection == VerticalDirection.up
          ? groupItems.first
          : groupItems.last;

  /// Expands or collapses [groupKey] in Group Focus/Stash Mode.
  void toggleGroupExpansion(final String groupKey) {
    setState(() {
      if (_expandedGroups.contains(groupKey)) {
        _expandedGroups.remove(groupKey);
      } else {
        _expandedGroups
          ..clear()
          ..add(groupKey);
      }
      _invalidateSnapshot();
    });
    _syncGroupTimers(groupKey);
    _coordinator.emitGroupToggled(
      groupKey: groupKey,
      position: widget.queue.position,
      expanded: _expandedGroups.contains(groupKey),
      count: _items
          .where(
            (final i) =>
                i.widget.resolvedGroupKey == groupKey &&
                i.status != _ItemStatus.exiting,
          )
          .length,
    );
    if (_expandedGroups.isEmpty) {
      _processPending();
    }
  }

  bool _isItemVisible(final _NotificationItemState item) {
    if (item.status == _ItemStatus.exiting) {
      return true;
    }
    if (!widget.queue.groupingBehavior.enabled) {
      return true;
    }
    final key = item.widget.resolvedGroupKey;
    if (_expandedGroups.isNotEmpty) {
      final focusedKey = _expandedGroups.first;
      if (key != focusedKey) {
        return false;
      }
      return true;
    }
    final activeGroupItems = _items
        .where(
          (final i) =>
              i.widget.resolvedGroupKey == key &&
              i.status != _ItemStatus.exiting,
        )
        .toList();
    if (activeGroupItems.length <
        widget.queue.groupingBehavior.maxBeforeGrouping) {
      return true;
    }
    // Peek card: while the representative is being dragged, also show the
    // card directly behind it so the user sees what's "underneath the pile".
    if (_activeDragGroupKey == key) {
      final rep = _groupRepresentative(activeGroupItems);
      final repIdx = activeGroupItems.indexOf(rep);
      // The item immediately behind the representative in insertion order.
      final peekIdx = widget.queue.verticalDirection == VerticalDirection.up
          ? repIdx + 1
          : repIdx - 1;
      if (peekIdx >= 0 && peekIdx < activeGroupItems.length) {
        if (item == activeGroupItems[peekIdx]) {
          return true;
        }
      }
    }
    return item == _groupRepresentative(activeGroupItems);
  }

  void dismiss(
    final NotificationWidget notification, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    dismissById(notification.id, reason: reason);
  }

  void dismissById(
    final String id, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    final item = _itemById[id];
    if (item != null) {
      _animateExit(item, reason: reason);
    } else {
      final pendingEntry = _pendingById.remove(id);
      if (pendingEntry != null) {
        _pendingNotifications.removeWhere(
          (final n) => n.id == id,
        );
        _coordinator
          ..unregisterEntryId(id, widget.queue.position)
          ..emitDismissed(
            notification: pendingEntry.blueprint,
            reason: reason,
          );
        _invalidateSnapshot();
        _checkEmpty();
      }
    }
  }

  /// Updates an active or pending notification in place.
  ///
  /// Returns a record with the updated and previous [NotificationWidget],
  /// or `null` if [id] was not found in this queue.
  ({NotificationWidget updated, NotificationWidget old})? updateById(
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
    final item = _itemById[id];
    if (item != null) {
      final oldWidget = item.widget;
      final updatedWidget = oldWidget.copyForUpdate(
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
        queue: item.entry.queue,
      )..isPinned = item.entry.isPinned;
      setState(() {
        item.entry = newEntry;
        _invalidateSnapshot();
      });
      if (resetTimer) {
        item.widget.key.currentState?.initDismissTimer();
      }
      return (updated: updatedWidget, old: oldWidget);
    }

    final pendingEntry = _pendingById[id];
    if (pendingEntry != null) {
      final oldWidget = pendingEntry.blueprint;
      final updatedWidget = oldWidget.copyForUpdate(
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
        queue: pendingEntry.queue,
      )..isPinned = pendingEntry.isPinned;
      _pendingById[id] = newEntry;
      final tempQueue = Queue<NotificationEntry>();
      while (_pendingNotifications.isNotEmpty) {
        final n = _pendingNotifications.removeFirst();
        tempQueue.add(n.id == id ? newEntry : n);
      }
      _pendingNotifications.addAll(tempQueue);
      _sortPending();
      setState(_invalidateSnapshot);
      return (updated: updatedWidget, old: oldWidget);
    }

    return null;
  }

  bool remove(final NotificationWidget notification) =>
      removeById(notification.id);

  bool removeById(final String id) {
    bool removed = false;
    final item = _itemById[id];

    if (item != null) {
      final index = _items.indexOf(item);
      if (index != -1) {
        _removeItemImmediate(index);
        removed = true;
      }
    } else {
      final exitingIndex = _items.indexWhere((final i) => i.widget.id == id);
      if (exitingIndex != -1) {
        _removeItemImmediate(exitingIndex, unregister: false);
        removed = true;
      } else {
        final removedPending = _pendingById.remove(id);
        if (removedPending != null) {
          _pendingNotifications.removeWhere(
            (final n) => n.id == id,
          );
          _coordinator.unregisterEntryId(id, widget.queue.position);
          removed = true;
        }
      }
    }

    if (removed) {
      _invalidateSnapshot();
      _processPending();
      _checkEmpty();
    }

    return removed;
  }

  /// Dismisses every notification that shares [groupKey] with an animated
  /// exit, regardless of collapsed/expanded state.
  ///
  /// This is the correct way to bulk-remove a bundle. Both active and
  /// pending backlog members are atomically purged. Individual
  /// [dismiss] calls only ever remove a single card.
  void dismissGroup(
    final String groupKey, {
    final DismissReason reason = DismissReason.programmatic,
    final bool isGroupDismissal = true,
    final String? swipedRepresentativeId,
  }) {
    final isSwipe = reason == DismissReason.userSwipe;
    final isGroup = isGroupDismissal || isSwipe;

    // 1. Atomically purge matching backlog items before any active cards exit
    // so _processPending cannot promote next group members into empty slots.
    final pendingToRemove = <NotificationEntry>[];
    final remainingPending = Queue<NotificationEntry>();
    while (_pendingNotifications.isNotEmpty) {
      final entry = _pendingNotifications.removeFirst();
      if (entry.resolvedGroupKey == groupKey) {
        pendingToRemove.add(entry);
        _pendingById.remove(entry.id);
      } else {
        remainingPending.add(entry);
      }
    }
    _pendingNotifications.addAll(remainingPending);

    for (final pending in pendingToRemove) {
      _coordinator
        ..unregisterEntryId(pending.id, widget.queue.position)
        ..emitDismissed(
          notification: pending.blueprint,
          reason: reason,
        );
    }

    // 2. Identify active group items.
    final groupItems = _items
        .where((final i) => i.widget.resolvedGroupKey == groupKey)
        .toList();

    for (final item in groupItems) {
      if (item.widget.id != swipedRepresentativeId) {
        _coordinator.emitDismissed(
          notification: item.widget,
          reason: reason,
        );
      }
    }

    final isCollapsed = !_expandedGroups.contains(groupKey);

    if (isGroup && isCollapsed) {
      // For collapsed whole-bundle dismissals (e.g. bundle swipe), all cards
      // in the bundle exit atomically in a single frame without intermediate
      // promotion or representative swapping.
      setState(() {
        for (final item in groupItems) {
          item.status = _ItemStatus.exiting;
          _items.remove(item);
          _itemById.remove(item.widget.id);
          _coordinator.unregisterEntryId(
            item.widget.id,
            widget.queue.position,
          );
          item.controller.dispose();
        }
        if (_activeDragGroupKey == groupKey) {
          _activeDragGroupKey = null;
        }
        _invalidateSnapshot();
      });
      _syncGroupTimers(groupKey);
      _pruneExpandedGroup(groupKey);
      _processPending();
      _checkEmpty();
      return;
    }

    // Otherwise (expanded group or individual programmatic collapse),
    // animate exit for each member.
    for (final item in groupItems) {
      _animateExit(
        item,
        reason: reason,
        isGroupDismissal: isGroup,
      );
    }

    if (groupItems.isEmpty && pendingToRemove.isNotEmpty) {
      setState(() => _invalidateSnapshot());
      _processPending();
      _checkEmpty();
    }
  }

  /// Moves [notification] to [targetIndex] within the active items list.
  ///
  /// Has no effect if [notification] is not found in the active list.
  /// Dropping at the current index is allowed and resolves as a no-op.
  void reorder(
    final NotificationWidget notification,
    final int targetIndex,
  ) {
    final key = notification.resolvedGroupKey;
    final isGrouped = widget.queue.groupingBehavior.enabled;
    final isCollapsed = !_expandedGroups.contains(key);

    setState(() {
      if (isGrouped && isCollapsed) {
        final groupItems = _items
            .where((final item) => item.widget.resolvedGroupKey == key)
            .toList();

        for (final item in groupItems) {
          _items.remove(item);
        }

        int absoluteInsertIndex = 0;
        final visibleItemsRemaining = _items.where(_isItemVisible).toList();
        if (targetIndex > 0 && targetIndex - 1 < visibleItemsRemaining.length) {
          final anchorItem = visibleItemsRemaining[targetIndex - 1];
          absoluteInsertIndex = _items.indexOf(anchorItem) + 1;
        } else if (targetIndex >= visibleItemsRemaining.length) {
          absoluteInsertIndex = _items.length;
        }

        _items.insertAll(absoluteInsertIndex, groupItems);
      } else {
        final currentIndex = _indexOf(notification.id);
        if (currentIndex == -1) {
          return;
        }
        final item = _items.removeAt(currentIndex);

        int absoluteInsertIndex = 0;
        final visibleItemsRemaining = _items.where(_isItemVisible).toList();
        if (targetIndex > 0 && targetIndex - 1 < visibleItemsRemaining.length) {
          final anchorItem = visibleItemsRemaining[targetIndex - 1];
          absoluteInsertIndex = _items.indexOf(anchorItem) + 1;
        } else if (targetIndex >= visibleItemsRemaining.length) {
          absoluteInsertIndex = _items.length;
        }

        _items.insert(absoluteInsertIndex, item);
      }
      _invalidateSnapshot();
    });
  }

  /// The number of currently active (non-pending) notifications.
  int get itemCount => _snapshot.visibleItems.length;

  /// The list of currently active notifications in this queue.
  List<NotificationWidget> get activeNotifications =>
      _items.map((final item) => item.widget).toList();

  /// The list of notifications currently waiting/pending in this queue.
  List<NotificationWidget> get pendingNotifications =>
      _pendingNotifications.map((final item) => item.blueprint).toList();

  /// Drains and returns all pending notifications waiting in this queue,
  /// optionally preserving an [excludeId] notification so it can be handled
  /// separately (e.g. by [remove]).
  List<NotificationWidget> drainPendingNotifications({
    final String? excludeId,
  }) {
    final list = <NotificationWidget>[];
    final remaining = Queue<NotificationEntry>();
    while (_pendingNotifications.isNotEmpty) {
      final entry = _pendingNotifications.removeFirst();
      if (excludeId != null && entry.id == excludeId) {
        remaining.add(entry);
      } else {
        _pendingById.remove(entry.id);
        list.add(entry.blueprint);
      }
    }
    _pendingNotifications.addAll(remaining);
    _checkEmpty();
    return list;
  }

  /// The active-list index of [notification], or -1 if not found.
  int indexOf(final NotificationWidget notification) =>
      _snapshot.visibleIndexById[notification.id] ?? -1;

  /// Returns whether this queue currently contains a notification with [id],
  /// either as an active notification or waiting in the pending queue.
  bool containsId(final String id) =>
      _itemById.containsKey(id) || _pendingById.containsKey(id);

  /// The [GlobalKey]s of active notification widgets, in stack order.
  ///
  /// Used by the reorder feedback layer to query each notification's
  /// [RenderBox] position for slot anchor computation.
  List<GlobalKey> get itemGlobalKeys => _snapshot.itemGlobalKeys;

  /// The [RenderBox] of the inner column containing the notifications.
  ///
  /// Used to compute the boundary for [ReorderAndRelocate] escape detection.
  RenderBox? get listRenderBox {
    final ctx = _listKey.currentContext;
    if (ctx == null) {
      return null;
    }
    return ctx.findRenderObject() as RenderBox?;
  }

  /// Determines whether [entry] can be admitted into active memory
  /// based on visual slot budget and group active item limits.
  bool _canAdmitEntry(
    final NotificationEntry entry,
    final List<_NotificationItemState> activeItems,
  ) {
    final maxStack = widget.queue.maxStackSize;
    if (!widget.queue.groupingBehavior.enabled) {
      return activeItems.length < maxStack;
    }

    final entryGroupKey = entry.resolvedGroupKey;

    // In Focus Mode, only items of the focused group may be admitted.
    if (_expandedGroups.isNotEmpty &&
        !_expandedGroups.contains(entryGroupKey)) {
      return false;
    }

    // 1. Group active item limit: a single group cannot exceed maxStackSize
    // active items in memory.
    int currentGroupActiveCount = 0;
    for (final item in activeItems) {
      if (item.status != _ItemStatus.exiting &&
          item.widget.resolvedGroupKey == entryGroupKey) {
        currentGroupActiveCount++;
      }
    }
    if (currentGroupActiveCount >= maxStack) {
      return false;
    }

    // 2. Visual slot budget: simulate total slots if entry is admitted.
    int exitingCount = 0;
    final groupCounts = <String, int>{};
    for (final item in activeItems) {
      if (item.status == _ItemStatus.exiting) {
        exitingCount++;
      } else {
        final key = item.widget.resolvedGroupKey;
        groupCounts[key] = (groupCounts[key] ?? 0) + 1;
      }
    }
    groupCounts[entryGroupKey] = (groupCounts[entryGroupKey] ?? 0) + 1;

    final threshold = widget.queue.groupingBehavior.maxBeforeGrouping;
    int simulatedSlots = exitingCount;
    for (final count in groupCounts.values) {
      if (count >= threshold) {
        simulatedSlots += 1;
      } else {
        simulatedSlots += count;
      }
    }

    return simulatedSlots <= maxStack;
  }

  void _processPending() {
    if (_pendingNotifications.isEmpty) {
      return;
    }

    final toAdd = <_NotificationItemState>[];
    final remaining = Queue<NotificationEntry>();
    final simulatedActive = <_NotificationItemState>[..._items];

    while (_pendingNotifications.isNotEmpty) {
      final entry = _pendingNotifications.removeFirst();
      if (_canAdmitEntry(entry, simulatedActive)) {
        _pendingById.remove(entry.id);
        final controller = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
          reverseDuration: const Duration(milliseconds: 200),
        );
        final itemState = _NotificationItemState(
          entry: entry,
          controller: controller,
        );
        toAdd.add(itemState);
        simulatedActive.add(itemState);
        _itemById[entry.id] = itemState;
      } else {
        remaining.add(entry);
      }
    }

    _pendingNotifications.addAll(remaining);

    if (toAdd.isNotEmpty) {
      setState(() {
        _items.addAll(toAdd);
        _invalidateSnapshot();
      });
      final affectedGroupKeys = <String>{};
      for (final item in toAdd) {
        affectedGroupKeys.add(item.widget.resolvedGroupKey);
        item.controller.forward();
      }
      for (final groupKey in affectedGroupKeys) {
        _syncGroupTimers(groupKey);
      }
    }
  }

  void _sortPending() {
    final list = _pendingNotifications.toList()
      ..sort(
        (final a, final b) =>
            b.resolvedPriority.index.compareTo(a.resolvedPriority.index),
      );
    _pendingNotifications
      ..clear()
      ..addAll(list);
  }

  void _triagePriorityEviction() {
    if (_pendingNotifications.isEmpty) {
      return;
    }
    final highestPending = _pendingNotifications.first;
    if (_canAdmitEntry(highestPending, _items)) {
      return;
    }

    _NotificationItemState? lowestActiveItem;
    for (final item in _items) {
      if (item.status == _ItemStatus.exiting) {
        continue;
      }
      if (lowestActiveItem == null ||
          item.widget.resolvedPriority <
              lowestActiveItem.widget.resolvedPriority) {
        lowestActiveItem = item;
      }
    }

    if (lowestActiveItem != null &&
        highestPending.resolvedPriority >
            lowestActiveItem.widget.resolvedPriority) {
      final evictedWidget = lowestActiveItem.widget;
      lowestActiveItem.status = _ItemStatus.exiting;
      _itemById.remove(evictedWidget.id);
      _invalidateSnapshot();
      lowestActiveItem.controller.reverse().then((final _) {
        if (mounted) {
          // Emit a programmatic dismiss for the evicted card so that the
          // coordinator's event stream carries the correct reason.
          _coordinator.emitDismissed(
            notification: evictedWidget,
            reason: DismissReason.evicted,
          );
          final itemIndex = _items.indexOf(lowestActiveItem!);
          if (itemIndex != -1) {
            _removeItemImmediate(itemIndex, unregister: false);
          }

          _pendingNotifications.add(lowestActiveItem.entry);
          _pendingById[lowestActiveItem.entry.id] = lowestActiveItem.entry;
          _sortPending();

          _processPending();
          _checkEmpty();
        }
      });
    }
  }

  int _indexOf(final String id) =>
      _items.indexWhere((final item) => item.widget.id == id);

  void _animateExit(
    final _NotificationItemState item, {
    final DismissReason reason = DismissReason.timeout,
    final bool isGroupDismissal = false,
  }) {
    if (item.status == _ItemStatus.exiting) {
      return;
    }

    final groupKey = item.widget.resolvedGroupKey;

    final groupingBehavior = widget.queue.groupingBehavior;
    final isCollapsed = !_expandedGroups.contains(groupKey);
    if (!isGroupDismissal &&
        groupingBehavior.enabled &&
        isCollapsed &&
        groupingBehavior.enableGroupSwipeDismiss &&
        reason == DismissReason.userSwipe) {
      _coordinator.emitGroupDismissed(
        groupKey: groupKey,
        position: widget.queue.position,
      );
      dismissGroup(
        groupKey,
        reason: reason,
        isGroupDismissal: true,
        swipedRepresentativeId: item.widget.id,
      );
      return;
    }

    // ── Collapsed-group representative: instant content swap ──────────────
    // When the visible representative of a *collapsed* group is dismissed,
    // the height slot must NOT animate — doing so causes either:
    //   • a disappear-then-reappear flash
    //     (no setState before controller.reverse)
    //   • a double-card artefact
    //     (setState before controller.reverse)
    // Both stem from two independent SizeTransition children sharing one
    // logical slot. The fix: remove the departing card immediately inside the
    // same setState that reveals the new representative, so the column sees
    // one clean swap in a single frame. The swipe gesture already delivered
    // the exit feedback; no height animation is needed here.
    if (_isCollapsedGroupRepresentative(item, groupKey) ||
        (isGroupDismissal && isCollapsed)) {
      setState(() {
        item.status = _ItemStatus.exiting;
        final index = _items.indexOf(item);
        if (index != -1) {
          _items.removeAt(index);
          _itemById.remove(item.widget.id);
          _coordinator.unregisterEntryId(
            item.widget.id,
            widget.queue.position,
          );
          _invalidateSnapshot();
          item.controller.dispose();
        }
        // Clear the drag peek — the representative is gone.
        if (_activeDragGroupKey == groupKey) {
          _activeDragGroupKey = null;
        }
        // Stamp a fresh entrance key on the new representative so its
        // micro-animation re-triggers (UX-02).
        if (!isGroupDismissal) {
          final activeItems = _items.where(
            (final i) =>
                i.widget.resolvedGroupKey == groupKey &&
                i.status != _ItemStatus.exiting,
          );
          if (activeItems.isNotEmpty) {
            _groupRepresentative(activeItems.toList()).entranceKey =
                UniqueKey();
          }
        }
      });
      _syncGroupTimers(groupKey);
      _pruneExpandedGroup(groupKey);
      _processPending();
      _checkEmpty();
      return;
    }

    // ── All other cases: normal size-collapse animation ───────────────────
    item.status = _ItemStatus.exiting;
    _itemById.remove(item.widget.id);
    _coordinator.unregisterEntryId(item.widget.id, widget.queue.position);
    _invalidateSnapshot();
    _syncGroupTimers(groupKey);
    item.controller.reverse().then((final _) {
      if (mounted) {
        final idx = _items.indexOf(item);
        if (idx != -1) {
          _removeItemImmediate(idx, unregister: false);
        }
        _pruneExpandedGroup(groupKey);
        _processPending();
        _checkEmpty();
      }
    });
  }

  /// Returns true when [item] is currently the sole visible card of a
  /// collapsed group that still has enough members to remain a bundle after
  /// this item is removed.
  ///
  /// This is the only situation where the height slot should NOT animate:
  /// the next representative immediately fills the same slot.
  bool _isCollapsedGroupRepresentative(
    final _NotificationItemState item,
    final String groupKey,
  ) {
    if (!widget.queue.groupingBehavior.enabled) {
      return false;
    }
    if (_expandedGroups.contains(groupKey)) {
      return false;
    }
    final activeItems = _items
        .where(
          (final i) =>
              i.widget.resolvedGroupKey == groupKey &&
              i.status != _ItemStatus.exiting,
        )
        .toList();
    // Must have at least one card remaining to immediately fill this slot.
    final remainingCount = activeItems.length - 1;
    if (remainingCount < 1) {
      return false;
    }
    return item == _groupRepresentative(activeItems);
  }

  void _removeItemImmediate(final int index, {final bool unregister = true}) {
    if (index == -1 || index >= _items.length) {
      return;
    }
    setState(() {
      final item = _items.removeAt(index);
      _itemById.remove(item.widget.id);
      if (unregister) {
        _coordinator.unregisterEntryId(item.widget.id, widget.queue.position);
      }
      _invalidateSnapshot();
      item.controller.dispose();
    });
  }

  void _checkEmpty() {
    if (_items.isEmpty && _pendingNotifications.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((final _) {
        if (mounted) {
          _coordinator.unmountQueue(widget.queue.position);
        }
      });
    }
  }

  /// Removes [groupKey] from [_expandedGroups] if the group no longer qualifies
  /// for group rendering (e.g. dropped below grouping threshold or removed).
  /// Must be called *after* the departing item has been removed from [_items].
  void _pruneExpandedGroup(final String groupKey) {
    final activeCount = _items
        .where(
          (final i) =>
              i.widget.resolvedGroupKey == groupKey &&
              i.status != _ItemStatus.exiting,
        )
        .length;

    if (activeCount < widget.queue.groupingBehavior.maxBeforeGrouping) {
      if (_expandedGroups.contains(groupKey)) {
        setState(() {
          _expandedGroups.remove(groupKey);
          _invalidateSnapshot();
        });
      }
    }
  }

  /// Synchronises dismiss timers for every member of [groupKey].
  ///
  /// Called at the two precise moments when group visibility actually changes:
  /// - When the bundle is toggled (expand ↔ collapse).
  /// - When the visible representative exits (the next card surfaces).
  ///
  /// This is O(n) and called at most once per user interaction — never on
  /// every build frame.
  void _syncGroupTimers(final String groupKey) {
    if (!widget.queue.groupingBehavior.enabled) {
      return;
    }
    final activeGroupItems = _items
        .where(
          (final i) =>
              i.widget.resolvedGroupKey == groupKey &&
              i.status != _ItemStatus.exiting,
        )
        .toList();

    final rep = activeGroupItems.isEmpty
        ? null
        : _groupRepresentative(activeGroupItems);
    final belowGroupingThreshold = activeGroupItems.length <
        widget.queue.groupingBehavior.maxBeforeGrouping;
    final isExpanded = _expandedGroups.contains(groupKey);
    final isDragging = _activeDragGroupKey == groupKey;

    for (final item in activeGroupItems) {
      final notifState = item.widget.key.currentState;
      if (notifState == null) {
        continue;
      }
      final bool shouldRun;
      if (belowGroupingThreshold || isExpanded) {
        shouldRun = true;
      } else if (isDragging) {
        shouldRun = false;
      } else {
        shouldRun = item == rep;
      }

      if (shouldRun) {
        if (notifState.dismissTimer == null) {
          notifState.initDismissTimer();
        }
      } else {
        notifState.ditchDismissTimer();
      }
    }
  }

  @override
  Widget build(final BuildContext context) {
    final pendingCount = _pendingNotifications.length;
    final blocks = _snapshot.blocks;

    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: Utils.screenSize(context).height * 0.6,
      ),
      child: MouseRegion(
        onEnter: (final _) {
          if (kIsWeb &&
              _coordinator.configuration.a11yOptions.enableContextMenu) {
            if (!_hasWebQueueHoverDisable) {
              _coordinator.webContextMenuController.requestDisable();
              _hasWebQueueHoverDisable = true;
            }
          }
        },
        onExit: (final _) {
          if (kIsWeb && _hasWebQueueHoverDisable) {
            _coordinator.webContextMenuController.releaseDisable();
            _hasWebQueueHoverDisable = false;
          }
        },
        child: Column(
          key: _listKey,
          spacing: 0, // We handle spacing in the wrapper
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: widget.queue.mainAxisAlignment,
          crossAxisAlignment: widget.queue.crossAxisAlignment,
          verticalDirection: widget.queue.verticalDirection,
          children: [
            widget.queue.queueIndicatorBuilder?.call(pendingCount) ??
                const SizedBox.shrink(),
            for (final block in blocks) _buildBlock(block, blocks),
          ],
        ),
      ),
    );

    if (widget.isEmbeddedInLayout) {
      return content;
    }

    return SafeArea(
      child: Container(
        alignment: widget.queue.position.alignment,
        margin: widget.queue.margin,
        child: content,
      ),
    );
  }

  _QueueLayoutSnapshot _computeSnapshot() {
    final visibleItems = <_NotificationItemState>[];
    final visibleIndexById = <String, int>{};
    final itemGlobalKeys = <GlobalKey>[];
    final blocks = <_QueueRenderBlock>[];
    final processedGroupKeys = <String>{};

    final focusedKey = _expandedGroups.isEmpty ? null : _expandedGroups.first;

    for (final item in _items) {
      if (_isItemVisible(item)) {
        visibleIndexById[item.widget.id] = visibleItems.length;
        visibleItems.add(item);
        itemGlobalKeys.add(item.globalKey);
      }

      if (item.status == _ItemStatus.exiting) {
        blocks.add(_SingleItemBlock(item));
        continue;
      }

      final key = item.widget.resolvedGroupKey;

      // In Focus Mode, sibling blocks are stashed (omitted from the
      // render tree).
      if (focusedKey != null && key != focusedKey) {
        continue;
      }

      if (!widget.queue.groupingBehavior.enabled) {
        blocks.add(_SingleItemBlock(item));
        continue;
      }

      final groupItems = _items
          .where(
            (final i) =>
                i.widget.resolvedGroupKey == key &&
                i.status != _ItemStatus.exiting,
          )
          .toList();

      if (groupItems.length < widget.queue.groupingBehavior.maxBeforeGrouping) {
        blocks.add(_SingleItemBlock(item));
        continue;
      }

      if (processedGroupKeys.contains(key)) {
        continue;
      }

      blocks.add(_GroupBlock(key, groupItems));
      processedGroupKeys.add(key);
    }

    return _QueueLayoutSnapshot(
      visibleItems: visibleItems,
      visibleIndexById: visibleIndexById,
      itemGlobalKeys: itemGlobalKeys,
      blocks: blocks,
    );
  }

  Widget _buildBlock(
    final _QueueRenderBlock block,
    final List<_QueueRenderBlock> blocks,
  ) {
    final isLastBlock = block == blocks.last;

    switch (block) {
      case _SingleItemBlock(:final item):
        final visible = _snapshot.visibleItems;
        final isLastItem = visible.isNotEmpty && item == visible.last;
        final spacing = isLastItem ? 0.0 : widget.queue.spacing;
        final visibleIndex = visibleIndexOf(item.widget.id);

        return _buildSingleNotificationCard(
          item: item,
          spacing: spacing,
          visibleIndex: visibleIndex,
        );

      case _GroupBlock(:final groupKey, :final items):
        return _GroupWidget(
          key: ValueKey(groupKey),
          queueWidgetState: this,
          groupKey: groupKey,
          items: items,
          isExpanded: _expandedGroups.contains(groupKey),
          isLastBlock: isLastBlock,
          onToggle: () => toggleGroupExpansion(groupKey),
        );
    }
  }

  Widget _buildSingleNotificationCard({
    required final _NotificationItemState item,
    required final double spacing,
    required final int visibleIndex,
  }) {
    final alignment =
        widget.queue.verticalDirection == VerticalDirection.down ? -1.0 : 1.0;

    final Widget itemWidget = widget.queue.transition.build(
      context,
      item.controller,
      widget.queue.position,
      KeyedSubtree(
        key: item.globalKey,
        child: DraggableTransitions(
          notification: item.widget,
        ),
      ),
    );

    return ValueListenableBuilder<({int origin, int target})?>(
      valueListenable: _reorderDragState,
      builder: (final context, final dragState, final child) {
        final translationY = dragState == null
            ? 0.0
            : getTranslationY(visibleIndex, dragState.origin, dragState.target);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, translationY, 0),
          child: child,
        );
      },
      child: SizeTransition(
        sizeFactor: item.controller.drive(
          CurveTween(curve: Curves.fastOutSlowIn),
        ),
        alignment: Alignment(-1.0, alignment),
        child: Align(
          alignment: widget.queue.position.alignment,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: widget.queue.verticalDirection == VerticalDirection.down
                  ? spacing
                  : 0,
              top: widget.queue.verticalDirection == VerticalDirection.up
                  ? spacing
                  : 0,
            ),
            // RepaintBoundary isolates each card's rasterisation layer so
            // drag-state setStates (reorder slot shifts, group peek reveals)
            // do not force an expensive repaint of unaffected sibling cards.
            child: RepaintBoundary(child: itemWidget),
          ),
        ),
      ),
    );
  }
}
