part of 'core.dart';

/// Internal interface for the notification scope surface attached to a
/// controller.
@internal
abstract class NotificationScopeState {
  /// Stream of notification events emitted by the attached scope.
  Stream<NotificationEvent> get events;

  /// Enqueues [notification] for display.
  void show(
    final AppNotification notification, {
    final QueuePosition? targetPosition,
  });

  /// Dismisses the notification described by [notification] by matching its id.
  void dismiss(
    final AppNotification notification, {
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

  /// Changes the display order of [notification] within its queue to
  /// [targetIndex].
  void reorder(final AppNotification notification, final int targetIndex);

  /// Temporarily hides [notification] and re-enqueues it after [duration].
  void snooze(final AppNotification notification, final Duration duration);

  /// Locks [notification] to the top of its queue and disables swipe-dismiss.
  void pin(final AppNotification notification);

  /// Releases the pin on [notification], restoring normal interactive behavior.
  void unpin(final AppNotification notification);

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
/// final controller = NotificationController(
///   queues: {const NotificationQueue()},
/// );
///
/// // 2. Inject — attach to the tree via NotificationScope
/// NotificationScope(
///   controller: controller,
///   child: MyApp(),
/// );
///
/// // 3. Dispatch — from any layer, with or without BuildContext
/// controller.show(AppNotification(message: 'Hello'));
///
/// // 4. Dispose — when the owning widget/object is disposed
/// controller.dispose();
/// ```
class NotificationController {
  /// Creates a [NotificationController] with the given queue and channel
  /// configuration.
  NotificationController({
    required final Set<NotificationQueue> queues,
    final Set<NotificationChannel>? channels,
    final bool strictChannelLookup = false,
    final int maxHistoryEntries = 0,
    final LogLevel? logLevel,
    final List<Handler>? logHandlers,
    final bool captureFlutterErrors = false,
  }) : configuration = ConfigurationManager(
          queues: queues,
          channels: channels ?? NotificationChannel.standardChannels(),
          strictChannelLookup: strictChannelLookup,
          maxHistoryEntries: maxHistoryEntries,
        ) {
    _configureLogger(
      customLevel: logLevel,
      customHandlers: logHandlers,
      captureFlutterErrors: captureFlutterErrors,
    );
  }

  /// The current version of the flutter_notification_queue package.
  static const String version = '0.5.3-dev';

  /// The configuration manager for this controller instance.
  @internal
  final ConfigurationManager configuration;

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
  }) {
    configuration.reconfigure(
      queues: queues,
      channels: channels,
      strictChannelLookup: strictChannelLookup,
      maxHistoryEntries: maxHistoryEntries,
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

  /// Enqueues [notification] for display.
  ///
  /// Optionally supply [targetPosition] to route the notification to a
  /// specific queue position, overriding channel defaults.
  ///
  /// Throws [StateError] if no `NotificationScope` is currently attached.
  /// Use [tryShow] for race conditions where the scope may not yet be mounted.
  void show(
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
    _attachedState!.show(notification, targetPosition: targetPosition);
  }

  /// Enqueues [notification] if a `NotificationScope` is attached; silently
  /// no-ops otherwise.
  ///
  /// Optionally supply [targetPosition] to route the notification to a
  /// specific queue position, overriding channel defaults.
  ///
  /// Follows Dart's `tryXxx` convention: the safe, non-throwing alternative.
  /// Use this for app-startup race conditions where a BLoC or service may emit
  /// a notification before the first frame renders the scope.
  void tryShow(
    final AppNotification notification, {
    final QueuePosition? targetPosition,
  }) {
    if (isAttached) {
      show(notification, targetPosition: targetPosition);
    }
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
    _attachedState?.relocate(notification, newPosition);
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
    _attachedState?.snooze(notification, duration);
  }

  /// Locks [notification] to the top of its queue and disables swipe-dismiss.
  ///
  /// No-ops silently if [notification] is no longer active.
  void pin(final AppNotification notification) {
    _attachedState?.pin(notification);
  }

  /// Releases the pin on [notification], restoring normal interactive behavior.
  ///
  /// No-ops silently if [notification] is no longer active.
  void unpin(final AppNotification notification) {
    _attachedState?.unpin(notification);
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
