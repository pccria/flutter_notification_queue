part of 'core.dart';

/// Internal interface for the notification scope surface attached to a
/// controller.
@internal
abstract class NotificationScopeState {
  /// Stream of notification events emitted by the attached scope.
  Stream<NotificationEvent> get events;

  /// Enqueues [notification] for display, returning its assigned ID.
  String show(
    final AppNotification notification, {
    final QueuePosition? targetPosition,
  });

  /// Dismisses the notification described by [notification] by matching its id.
  void dismiss(
    final AppNotification notification, {
    final DismissReason reason = DismissReason.programmatic,
  });

  /// Dismisses the notification with [id].
  void dismissById(
    final String id, {
    final DismissReason reason = DismissReason.programmatic,
  });

  /// Dismisses all visible notifications.
  void dismissAll({
    final DismissReason reason = DismissReason.programmatic,
  });

  /// Dismisses the newest currently visible notification.
  void dismissNewest();

  /// Dismisses all notifications that share [groupKey].
  void dismissGroup(
    final String groupKey, {
    final DismissReason reason = DismissReason.programmatic,
  });

  /// Moves [notification] to [newPosition].
  void relocate(
    final AppNotification notification,
    final QueuePosition newPosition,
  );

  /// Moves the notification with [id] to [newPosition].
  void relocateById(final String id, final QueuePosition newPosition);

  /// Changes the display order of [notification] within its queue to
  /// [targetIndex].
  void reorder(final AppNotification notification, final int targetIndex);

  /// Temporarily hides [notification] and re-enqueues it after [duration].
  void snooze(final AppNotification notification, final Duration duration);

  /// Temporarily hides the notification with [id] and re-enqueues it after
  /// [duration].
  void snoozeById(final String id, final Duration duration);

  /// Locks [notification] to the top of its queue and disables swipe-dismiss.
  void pin(final AppNotification notification);

  /// Locks the notification with [id] to the top of its queue.
  void pinById(final String id);

  /// Releases the pin on [notification], restoring normal interactive behavior.
  void unpin(final AppNotification notification);

  /// Releases the pin on the notification with [id].
  void unpinById(final String id);

  /// Updates an active or pending notification by [id] in place.
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
  });

  /// Updates an active or pending notification by applying [transform].
  bool updateWith(
    final String id,
    final AppNotification Function(AppNotification current) transform, {
    final bool resetTimer = false,
  });

  /// Retrieves recorded lifecycle history.
  List<NotificationEvent> getHistory({
    final String? channelName,
    final DismissReason? dismissReason,
    final DateTime? since,
    final int? limit,
  });

  /// Clears recorded history.
  void clearHistory();

  /// Disposes resources held by the scope surface.
  void dispose();
}

/// Configuration owner and contextless dispatch handle for a notification
/// surface.
///
/// Create one instance per independent notification surface (one per app
/// window, one per isolated test, one per embedded FlutterEngine). Attach it to
/// the widget tree via `NotificationScope`.
///
/// ## Lifecycle
///
/// ```dart
/// // 1. Create — before or alongside the widget tree
/// final controller = NotificationController();
///
/// // 2. Inject — attach to the tree via NotificationScope
/// NotificationScope(
///   controller: controller,
///   child: MyApp(),
/// );
///
/// // 3. Dispatch — from any layer, with or without BuildContext
/// final handle = controller.show(const AppNotification(message: 'Hello'));
///
/// // 4. Dispose — when the owning widget/object is disposed
/// controller.dispose();
/// ```
class NotificationController {
  /// Creates a [NotificationController] with optional queue and channel
  /// configuration.
  NotificationController({
    final Set<NotificationQueue>? queues,
    final Set<NotificationChannel>? channels,
    final bool strictChannelLookup = false,
    final int maxHistoryEntries = 0,
    final NotificationA11yOptions a11yOptions =
        const NotificationA11yOptions(),
    final LogLevel? logLevel,
    final List<Handler>? logHandlers,
    final bool captureFlutterErrors = false,
  }) : configuration = ConfigurationManager(
          queues: queues ?? {const NotificationQueue()},
          channels: channels ?? NotificationChannel.standardChannels(),
          strictChannelLookup: strictChannelLookup,
          maxHistoryEntries: maxHistoryEntries,
          a11yOptions: a11yOptions,
        ) {
    _configureLogger(
      customLevel: logLevel,
      customHandlers: logHandlers,
      captureFlutterErrors: captureFlutterErrors,
    );
  }

  /// The current version of the flutter_notification_queue package.
  static const String version = '0.6.0-dev';

  /// The configuration manager for this controller instance.
  @internal
  final ConfigurationManager configuration;

  /// The accessibility options configured for this controller.
  NotificationA11yOptions get a11yOptions => configuration.a11yOptions;

  /// Stable broadcast proxy stream for all lifecycle events.
  final _proxyController = StreamController<NotificationEvent>.broadcast();

  StreamSubscription<NotificationEvent>? _stateSub;
  NotificationScopeState? _attachedState;

  /// Internal access to the attached coordinator if a NotificationScope is
  /// active.
  @internal
  QueueCoordinator? get coordinator {
    final state = _attachedState;
    return state is QueueCoordinator ? state : null;
  }

  /// Whether a `NotificationScope` is currently mounted and attached to this
  /// controller.
  bool get isAttached => _attachedState != null;

  /// Stable broadcast stream of all notification lifecycle events.
  ///
  /// This stream **persists across `NotificationScope` mount and unmount
  /// cycles**. Listeners attached before the scope mounts will continue to
  /// receive events from the scope once it does mount, without re-subscribing.
  Stream<NotificationEvent> get events => _proxyController.stream;

  /// Dynamically updates queue and channel configuration for this controller
  /// without re-instantiating the controller or interrupting active UI card
  /// lifecycle.
  void reconfigure({
    final Set<NotificationQueue>? queues,
    final Set<NotificationChannel>? channels,
    final bool? strictChannelLookup,
    final int? maxHistoryEntries,
    final NotificationA11yOptions? a11yOptions,
  }) {
    configuration.reconfigure(
      queues: queues,
      channels: channels,
      strictChannelLookup: strictChannelLookup,
      maxHistoryEntries: maxHistoryEntries,
      a11yOptions: a11yOptions,
    );
    if (_attachedState is QueueCoordinator) {
      (_attachedState! as QueueCoordinator).historyLogger.updateMaxEntries(
            configuration.maxHistoryEntries,
          );
    }
  }

  // ── Attachment Protocol ───────────────────────────────────────────────────

  /// Internal attachment protocol called by
  /// `NotificationScopeState.initState()`.
  @internal
  void attach(final NotificationScopeState state) {
    assert(
      _attachedState == null,
      'NotificationController is already attached to a NotificationScope. '
      'A controller may only be used with one scope at a time. '
      'Create a separate controller for each independent notification surface.',
    );
    _attachedState = state;
    _stateSub = state.events.listen((final event) {
      if (!_proxyController.isClosed) {
        _proxyController.add(event);
      }
    });
  }

  /// Internal detachment protocol called by `NotificationScopeState.dispose()`.
  @internal
  void detach() {
    _stateSub?.cancel();
    _stateSub = null;
    _attachedState = null;
  }

  // ── Dispatch ──────────────────────────────────────────────────────────────

  /// Enqueues [notification] for display, returning a [NotificationHandle] for
  /// programmatic management.
  ///
  /// Optionally supply [targetPosition] to route the notification to a
  /// specific queue position, overriding channel defaults.
  ///
  /// Throws [StateError] if no `NotificationScope` is currently attached.
  /// Use [tryShow] for race conditions where the scope may not yet be mounted.
  NotificationHandle show(
    final AppNotification notification, {
    final QueuePosition? targetPosition,
  }) {
    if (!isAttached) {
      throw StateError(
        'Cannot show notification: No NotificationScope is currently attached '
        'to this NotificationController. Ensure NotificationScope is mounted '
        'in the widget tree with this controller.',
      );
    }
    final id = _attachedState!.show(
      notification,
      targetPosition: targetPosition,
    );
    return NotificationHandle(id: id, controller: this);
  }

  /// Enqueues [notification] if a `NotificationScope` is attached,
  /// returning its handle; silently returns `null` otherwise.
  ///
  /// Optionally supply [targetPosition] to route the notification to a
  /// specific queue position, overriding channel defaults.
  ///
  /// Follows Dart's `tryXxx` convention: the safe, non-throwing alternative.
  /// Use this for app-startup race conditions where a BLoC or service may emit
  /// a notification before the first frame renders the scope.
  NotificationHandle? tryShow(
    final AppNotification notification, {
    final QueuePosition? targetPosition,
  }) {
    if (isAttached) {
      return show(notification, targetPosition: targetPosition);
    }
    return null;
  }

  /// Displays a notification that automatically updates based on the lifecycle
  /// of [future].
  ///
  /// Displays [loading] initially with auto-dismiss disabled (sticky).
  /// - When [future] resolves successfully, updates the notification using
  ///   [onSuccess] and starts its auto-dismiss countdown.
  /// - When [future] rejects with an error, updates the notification using
  ///   [onError].
  ///
  /// Returns a [NotificationHandle] allowing cancellation or programmatic
  /// control while [future] is pending.
  NotificationHandle showAsync<T>(
    final Future<T> future, {
    required final AppNotification loading,
    required final AppNotification Function(T data) onSuccess,
    required final AppNotification Function(Object error, StackTrace stackTrace)
        onError,
    final QueuePosition? targetPosition,
  }) {
    final handle = show(
      loading.copyWith(permanent: true),
      targetPosition: targetPosition,
    );

    future.then(
      (final data) {
        handle.updateWith(
          (final _) => onSuccess(data),
          resetTimer: true,
        );
      },
      onError: (final Object error, final StackTrace stackTrace) {
        handle.updateWith(
          (final _) => onError(error, stackTrace),
          resetTimer: true,
        );
      },
    );

    return handle;
  }

  /// Displays an asynchronous notification if attached; returns `null`
  /// otherwise.
  NotificationHandle? tryShowAsync<T>(
    final Future<T> future, {
    required final AppNotification loading,
    required final AppNotification Function(T data) onSuccess,
    required final AppNotification Function(Object error, StackTrace stackTrace)
        onError,
    final QueuePosition? targetPosition,
  }) {
    if (isAttached) {
      return showAsync(
        future,
        loading: loading,
        onSuccess: onSuccess,
        onError: onError,
        targetPosition: targetPosition,
      );
    }
    return null;
  }

  /// Programmatically dismisses the notification with [id].
  ///
  /// No-ops silently if no notification with [id] is active or pending.
  void dismissById(
    final String id, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    _attachedState?.dismissById(id, reason: reason);
  }

  /// Programmatically dismisses [notification] by matching its ID.
  ///
  /// No-ops silently if [notification] is no longer active.
  void dismiss(
    final AppNotification notification, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    _attachedState?.dismiss(notification, reason: reason);
  }

  /// Updates an active or pending notification by [id] in place.
  ///
  /// Set [resetTimer] to `true` to restart the auto-dismiss timer.
  /// Returns `true` if the notification was found and updated.
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
  }) =>
      _attachedState?.update(
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
      ) ??
      false;

  /// Updates an active or pending notification by applying [transform]
  /// to its current configuration.
  ///
  /// Set [resetTimer] to `true` to restart the auto-dismiss timer.
  /// Returns `true` if the notification was found and updated.
  bool updateWith(
    final String id,
    final AppNotification Function(AppNotification current) transform, {
    final bool resetTimer = false,
  }) =>
      _attachedState?.updateWith(id, transform, resetTimer: resetTimer) ??
      false;

  /// Programmatically dismisses all currently visible notifications.
  void dismissAll({
    final DismissReason reason = DismissReason.programmatic,
  }) {
    _attachedState?.dismissAll(reason: reason);
  }

  /// Dismisses the newest currently visible notification.
  ///
  /// No-ops silently if no notifications are currently active.
  void dismissNewest() {
    _attachedState?.dismissNewest();
  }

  /// Dismisses all visible notifications that share [groupKey].
  ///
  /// Prefer this over calling [dismiss] in a loop — it guarantees atomic
  /// group semantics and emits a single [NotificationGroupDismissed] event
  /// per affected queue position.
  void dismissGroup(
    final String groupKey, {
    final DismissReason reason = DismissReason.programmatic,
  }) {
    _attachedState?.dismissGroup(groupKey, reason: reason);
  }

  /// Moves [notification] to [newPosition].
  ///
  /// No-ops silently if [notification] is no longer active.
  void relocate(
    final AppNotification notification,
    final QueuePosition newPosition,
  ) {
    if (notification.id != null) {
      relocateById(notification.id!, newPosition);
    } else {
      _attachedState?.relocate(notification, newPosition);
    }
  }

  /// Moves the notification with [id] to [newPosition].
  void relocateById(final String id, final QueuePosition newPosition) {
    _attachedState?.relocateById(id, newPosition);
  }

  /// Changes the display order of [notification] within its queue to
  /// [targetIndex].
  ///
  /// No-ops silently if [notification] is no longer active.
  void reorder(final AppNotification notification, final int targetIndex) {
    _attachedState?.reorder(notification, targetIndex);
  }

  /// Temporarily hides [notification] and re-enqueues it after [duration].
  ///
  /// No-ops silently if [notification] is no longer active.
  void snooze(final AppNotification notification, final Duration duration) {
    if (notification.id != null) {
      snoozeById(notification.id!, duration);
    } else {
      _attachedState?.snooze(notification, duration);
    }
  }

  /// Temporarily hides the notification with [id] and re-enqueues it after
  /// [duration].
  void snoozeById(final String id, final Duration duration) {
    _attachedState?.snoozeById(id, duration);
  }

  /// Locks [notification] to the top of its queue and disables swipe-dismiss.
  ///
  /// No-ops silently if [notification] is no longer active.
  void pin(final AppNotification notification) {
    if (notification.id != null) {
      pinById(notification.id!);
    } else {
      _attachedState?.pin(notification);
    }
  }

  /// Locks the notification with [id] to the top of its queue.
  void pinById(final String id) {
    _attachedState?.pinById(id);
  }

  /// Releases the pin on [notification], restoring normal interactive behavior.
  ///
  /// No-ops silently if [notification] is no longer active.
  void unpin(final AppNotification notification) {
    if (notification.id != null) {
      unpinById(notification.id!);
    } else {
      _attachedState?.unpin(notification);
    }
  }

  /// Releases the pin on the notification with [id].
  void unpinById(final String id) {
    _attachedState?.unpinById(id);
  }

  // ── History ───────────────────────────────────────────────────────────────

  /// Returns recorded notification lifecycle events, filtered by the given
  /// criteria. History recording is opt-in via
  /// [ConfigurationManager.maxHistoryEntries].
  List<NotificationEvent> getHistory({
    final String? channelName,
    final DismissReason? dismissReason,
    final DateTime? since,
    final int? limit,
  }) {
    final state = _attachedState;
    if (state == null) {
      return const [];
    }
    return state.getHistory(
      channelName: channelName,
      dismissReason: dismissReason,
      since: since,
      limit: limit,
    );
  }

  /// Clears all recorded history.
  void clearHistory() {
    _attachedState?.clearHistory();
  }

  // ── Testing ───────────────────────────────────────────────────────────────

  /// Returns a [Future] that completes with the next event of type [T].
  /// Only for use in tests.
  @visibleForTesting
  Future<T> nextEvent<T extends NotificationEvent>() =>
      events.where((final e) => e is T).cast<T>().first;

  bool _isDisposed = false;

  /// Whether this controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Disposes this controller and releases resources.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _attachedState?.dispose();
    detach();
    if (!_proxyController.isClosed) {
      _proxyController.close();
    }
  }

  static void _configureLogger({
    final LogLevel? customLevel,
    final List<Handler>? customHandlers,
    final bool captureFlutterErrors = false,
  }) {
    const bool isDebug = kDebugMode;
    final LogLevel resolvedLevel =
        customLevel ?? (isDebug ? LogLevel.debug : LogLevel.warning);

    final List<Handler>? resolvedHandlers = customHandlers ??
        (isDebug
            ? [
                const Handler(
                  formatter: StructuredFormatter(),
                  decorators: [
                    BoxDecorator(),
                    HierarchyDepthPrefixDecorator(),
                  ],
                  sink: ConsoleSink(),
                ),
              ]
            : null);

    if (resolvedHandlers != null && resolvedHandlers.isNotEmpty) {
      Logger.configure(
        'fnq',
        logLevel: resolvedLevel,
        handlers: resolvedHandlers,
      );
    }

    if (captureFlutterErrors) {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (final details) {
        Logger.get('fnq').error(
          details.exceptionAsString(),
          stackTrace: details.stack,
        );
        originalOnError?.call(details);
      };
    }
  }
}
