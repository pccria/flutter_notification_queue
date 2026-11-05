# Architecture Blueprint & System Design Rationale

## 1. Executive Summary

This document serves as the foundational architectural blueprint and design rationale for **Flutter Notification Queue (FNQ)**. It details the paradigm shift from prototype-style static singletons to an idiomatic, multi-tenant design, informed by:

- A structural audit of early singleton architectures and their failure modes
- An analysis of how leading overlay libraries in the Flutter ecosystem
  (`toastification`, `bot_toast`, `overlay_support`) each solved — and where they each
  failed — the same problem space
- Canonical Flutter SDK patterns (`ScaffoldMessenger`, `TextEditingController`,
  `Navigator`) as the authoritative reference implementation

**Target audience:** maintainers, contributors, and architects evaluating FNQ's system design.

---

## 2. What v0.x Got Right and What It Got Wrong

### 2.1 The Original Architecture

v0.x prioritized extreme convenience. The entire system was held together by three things:

- **`FlutterNotificationQueue.configure()`** — a static call that created a global singleton coordinator
- **`NotificationWidget(...).show()`** — a widget that knew how to dispatch itself into the global overlay
- **`FlutterNotificationQueue.builder`** — a static builder method that injected the global `OverlayPortal` into `MaterialApp`

This was intentionally minimal and worked well as a proof of concept.

### 2.2 The Two Structural Flaws

**Flaw 1 — The static singleton locks multi-tenancy.**
Because `FlutterNotificationQueue.coordinator` is a global static, there can be exactly one
active notification surface in the process. This makes it impossible to:

- Run two independent queues in a desktop multi-window app
- Sandbox notification state in widget tests without explicit `reset()` teardown calls
- Use FNQ in an add-to-app embedding (multiple `FlutterEngine` instances)
- Have isolated notification contexts per route or page subtree

The line that enforces this lock is in
`notification_overlay.dart` at the point where `initState()` calls:

```dart
// The coupling that makes multi-tenancy impossible:
_attachedCoordinator = FlutterNotificationQueue.coordinator; // global singleton
```

**Flaw 2 — The Active Widget anti-pattern.**
`NotificationWidget` is named `Widget` but is not a Flutter Widget in any meaningful sense.
It is a data/configuration object. Calling `.show()` on it conflates two distinct roles:
the data payload and the dispatch action. This naming misled users into treating it as a
widget (placing it in build methods, passing it to widget parameters) when it is a command.

### 2.3 The Ecosystem Consensus

Every major overlay library in the Flutter ecosystem has gone through the same evolution —
from a static singleton toward a scoped, instance-based model. The end state that wins for
advanced use cases is always the same shape:

```
[One StatefulWidget] = overlay mount point + InheritedWidget lookup
        └── internal State = the engine
        └── pure-Dart controller = contextless escape hatch
```

`ScaffoldMessenger` is the reference implementation of this pattern in the Flutter SDK itself:
a single `StatefulWidget` that simultaneously mounts the snackbar overlay AND provides
`.of(context)` lookup, backed by a pure-Dart `GlobalKey` for contextless access.

The key lesson from libraries that failed at multi-tenancy (`toastification`, `bot_toast`):
they kept their singletons and added contextless escape hatches on top. The library that got
it right (`overlay_support`, `flash`) achieved isolation by making the scope widget the
authoritative owner of the overlay instance.

---

## 3. The Architectural Thesis

> FNQ v1.0 adopts the **`TextEditingController` ↔ `TextField`** attachment pattern from the
> Flutter SDK: a pure-Dart **`NotificationController`** owns configuration and provides
> contextless dispatch; a **`NotificationScope`** widget is the single widget that both mounts
> the overlay surface AND provides `InheritedWidget` lookup — exactly as `ScaffoldMessenger`
> does for snack bars.

The Flutter SDK translation table:

| Flutter SDK concept | FNQ v1.0 equivalent |
|---|---|
| `ScaffoldMessenger` (StatefulWidget + InheritedWidget) | `NotificationScope` |
| `ScaffoldMessengerState` (the engine) | `NotificationScopeState` |
| `GlobalKey<ScaffoldMessengerState>` (contextless handle) | `NotificationController` |
| `SnackBar` (pure data payload) | `AppNotification` |
| `ScaffoldMessenger.of(context)` | `NotificationScope.of(context)` |
| `showSnackBar()` | `show()` |

The attachment lifecycle mirrors `TextEditingController` ↔ `EditableTextState`:

- `controller._attach(state)` — called in `NotificationScope.initState()`
- `controller._detach()` — called in `NotificationScope.dispose()`
- `controller.show(notification)` — delegates to `state.show(notification)` when attached

---

## 4. Terminology & Naming

Every public-facing name was evaluated against four criteria: semantic accuracy, Flutter
precedent, conflict risk, and readability at the call site.

### 4.1 Name Changes

| v0.x | v1.0 | Rationale |
|---|---|---|
| `NotificationWidget` | `AppNotification` | Removes the `Widget` lie. The `App-` prefix distinguishes in-app notifications from OS push notifications — a distinction users genuinely make. No `dart:core` conflict. Matches Flutter's `AppBar`, `AppLifecycleListener` naming pattern. |
| `FlutterNotificationQueue` | `NotificationController` | Lifecycle owner for notification state. Directly consistent with `AnimationController`, `ScrollController`, `TextEditingController`. |
| *(new widget)* | `NotificationScope` | Role-focused, not mechanism-focused. The word "scope" communicates what this widget does — it defines the widget subtree within which notifications appear. `NotificationScope.of(context)` reads as naturally as `ScaffoldMessenger.of(context)`. |
| `FnqEvent` | `NotificationEvent` | Removes an opaque internal abbreviation from public API. The subtypes are already well-named; only the base type changes. |
| `showIfAttached()` | `tryShow()` | Follows Dart's `int.tryParse` convention — the `try` prefix signals "safe, non-throwing version." Concise and idiomatic. |

### 4.2 Names That Do Not Change

`NotificationChannel`, `NotificationQueue`, `QueuePosition`, `DismissReason`,
`NotificationPriority`, and the entire event subtype hierarchy
(`NotificationQueued`, `NotificationDismissed`, `NotificationTapped`, `QueueOverflowed`, etc.)
are semantically accurate and should not change. Notably, `QueueOverflowed` is intentionally
*not* prefixed with `Notification` — the *queue* overflowed, not a notification.

---

## 5. The Complete Public API Contract

### 5.1 `AppNotification` — Pure Data, No Dispatch

```dart
/// Represents the intent to display an in-app notification.
///
/// This is a pure data object — it has no UI dependency, no [BuildContext]
/// requirement, and no dispatch method. Pass it to [NotificationController.show]
/// or [NotificationScope.of(context).show].
///
/// ```dart
/// final notification = AppNotification(
///   id: 'order-123',
///   message: 'Your order has been confirmed.',
///   title: 'Order Confirmed',
///   channelName: 'orders',
///   priority: NotificationPriority.high,
///   dismissDuration: const Duration(seconds: 5),
/// );
/// controller.show(notification);
/// ```
class AppNotification {
  const AppNotification({
    required this.message,
    this.id,
    this.title,
    this.channelName = 'default',
    this.position,
    this.priority,
    this.tapBehavior,
    this.dragBehavior,
    this.longPressDragBehavior,
    this.groupKey,
    this.icon,
    this.color,
    this.foregroundColor,
    this.backgroundColor,
    this.dismissDuration,
    this.permanent = false,
    this.initialIsPinned = false,
    this.snoozedAt,
    this.builder,
    this.action,
  });

  final String message;
  final String? id;
  final String? title;
  final String channelName;
  final QueuePosition? position;
  final NotificationPriority? priority;
  final TapBehavior? tapBehavior;
  final DragBehavior? dragBehavior;
  final LongPressDragBehavior? longPressDragBehavior;
  final String? groupKey;
  final Widget? icon;
  final Color? color;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Duration? dismissDuration;
  final bool permanent;
  final bool initialIsPinned;
  final DateTime? snoozedAt;
  final NotificationBuilder? builder;
  final NotificationAction? action;
}
```

### 5.2 `NotificationController` — Lifecycle Owner & Dispatch Handle

```dart
/// Configuration owner and contextless dispatch handle for a notification surface.
///
/// Create one instance per independent notification surface (one per app window,
/// one per isolated test, one per embedded FlutterEngine). Attach it to the
/// widget tree via [NotificationScope].
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
/// MaterialApp(
///   builder: (context, child) => NotificationScope(
///     controller: controller,
///     child: child!,
///   ),
/// );
///
/// // 3. Dispatch — from any layer, with or without BuildContext
/// controller.show(AppNotification(message: 'Hello'));
///
/// // 4. Dispose — when the owning widget/object is disposed
/// controller.dispose();
/// ```
class NotificationController {
  NotificationController({
    required Set<NotificationQueue> queues,
    Set<NotificationChannel>? channels,
    bool strictChannelLookup = false,
    bool enableDynamicChannelParking = false,
    int maxHistoryEntries = 0,
    LogLevel? logLevel,
    List<Handler>? logHandlers,
    bool captureFlutterErrors = false,
  });

  /// Whether a [NotificationScope] is currently mounted and attached to this controller.
  bool get isAttached;

  /// Stable broadcast stream of all notification lifecycle events.
  ///
  /// This stream **persists across [NotificationScope] mount and unmount cycles**.
  /// Listeners attached before the scope mounts will continue to receive events
  /// from the scope once it does mount, without re-subscribing.
  ///
  /// ```dart
  /// controller.events.listen((event) {
  ///   switch (event) {
  ///     case NotificationQueued(:final notification):
  ///       analytics.track('shown', id: notification.id);
  ///     case NotificationDismissed(:final reason):
  ///       if (reason == DismissReason.timeout) log('auto-dismissed');
  ///     case NotificationTapped():
  ///     case QueueOverflowed():
  ///   }
  /// });
  /// ```
  Stream<NotificationEvent> get events;

  // ── Dispatch ──────────────────────────────────────────────────────────────

  /// Enqueues [notification] for display.
  ///
  /// Throws [StateError] if no [NotificationScope] is currently attached.
  /// Use [tryShow] for race conditions where the scope may not yet be mounted.
  void show(AppNotification notification);

  /// Enqueues [notification] if a [NotificationScope] is attached; silently
  /// no-ops otherwise.
  ///
  /// Follows Dart's `tryXxx` convention: the safe, non-throwing alternative.
  /// Use this for app-startup race conditions where a BLoC or service may emit
  /// a notification before the first frame renders the scope.
  void tryShow(AppNotification notification);

  /// Programmatically dismisses the notification with the given [id].
  void dismiss(String id, {DismissReason reason = DismissReason.programmatic});

  /// Programmatically dismisses all currently visible notifications.
  void dismissAll({DismissReason reason = DismissReason.programmatic});

  // ── History ───────────────────────────────────────────────────────────────

  /// Returns recorded notification lifecycle events, filtered by the given
  /// criteria. History recording is opt-in via [maxHistoryEntries].
  List<NotificationEvent> getHistory({
    String? channelName,
    DismissReason? dismissReason,
    DateTime? since,
    int? limit,
  });

  /// Clears all recorded history.
  void clearHistory();

  // ── Testing ───────────────────────────────────────────────────────────────

  /// Returns a [Future] that completes with the next event of type [T].
  /// Only for use in tests.
  @visibleForTesting
  Future<T> nextEvent<T extends NotificationEvent>();

  void dispose();
}
```

**Internal attachment protocol** (private, not part of the public API):

```dart
// Called by NotificationScope.initState()
void _attach(NotificationScopeState state) {
  assert(
    _attachedState == null,
    'NotificationController is already attached to a NotificationScope. '
    'A controller may only be used with one scope at a time. '
    'Create a separate controller for each independent notification surface.',
  );
  _attachedState = state;
  // Wire the scope's raw event stream into the stable proxy stream.
  // The proxy survives attach/detach cycles; listeners do not need to re-subscribe.
  _stateSub = state._coordinator.events.listen(_proxyController.add);
}

// Called by NotificationScope.dispose()
void _detach() {
  _stateSub?.cancel();
  _stateSub = null;
  _attachedState = null;
}
```

### 5.3 `NotificationScope` — One Widget, Two Roles

```dart
/// The single integration point for FNQ in the widget tree.
///
/// `NotificationScope` simultaneously serves two roles:
///
/// **Role 1 — Overlay mount point.** Renders in-app notifications via
/// [OverlayPortal] (or a [Stack]/[Overlay] fallback when used in
/// [MaterialApp.builder] where no [Overlay] ancestor exists).
///
/// **Role 2 — InheritedWidget scope.** Provides [NotificationScope.of(context)]
/// for context-based dispatch from any widget in the subtree.
///
/// ## Placement
///
/// The recommended placement is in [MaterialApp.builder] for app-wide coverage:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => NotificationScope(
///     controller: controller,
///     child: child!,
///   ),
/// );
/// ```
///
/// For isolated subtree scopes (e.g., a single desktop window), place it directly:
///
/// ```dart
/// NotificationScope(
///   controller: windowController,
///   child: WindowContent(),
/// )
/// ```
class NotificationScope extends StatefulWidget {
  const NotificationScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final NotificationController controller;
  final Widget child;

  /// Returns the [NotificationScopeState] for the nearest [NotificationScope]
  /// ancestor in the widget tree.
  ///
  /// Throws if no [NotificationScope] is found. Use [maybeOf] for optional lookup.
  ///
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () => NotificationScope.of(context).show(
  ///     AppNotification(message: 'Saved'),
  ///   ),
  ///   child: const Text('Save'),
  /// )
  /// ```
  static NotificationScopeState of(BuildContext context) { ... }

  /// Returns [null] instead of throwing if no [NotificationScope] is found.
  static NotificationScopeState? maybeOf(BuildContext context) { ... }

  @override
  State<NotificationScope> createState() => NotificationScopeState();
}

class NotificationScopeState extends State<NotificationScope> {
  late final QueueCoordinator _coordinator; // internal — not exposed publicly

  @override
  void initState() {
    super.initState();
    _coordinator = QueueCoordinator.fromController(widget.controller);
    widget.controller._attach(this);
  }

  @override
  void didUpdateWidget(NotificationScope old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._detach();
      widget.controller._attach(this);
      // Note: configuration hot-swapping is not supported in v1.0.
      // To change queue/channel configuration, replace the NotificationScope subtree.
    }
  }

  @override
  void dispose() {
    widget.controller._detach();
    _coordinator.dispose();
    super.dispose();
  }

  void show(AppNotification notification) =>
      _coordinator.queue(notification._toEntry());

  void dismiss(String id, {DismissReason reason = DismissReason.programmatic}) =>
      _coordinator.dismissById(id, reason: reason);

  void dismissAll({DismissReason reason = DismissReason.programmatic}) =>
      _coordinator.dismissAll(reason: reason);

  @override
  Widget build(BuildContext context) {
    return _NotificationScopeData(   // private InheritedWidget
      state: this,
      child: _NotificationOverlay(   // internal render widget
        coordinator: _coordinator,   // injected — not pulled from global state
        child: widget.child,
      ),
    );
  }
}
```

### 5.4 The Critical Internal Fix

This single change is the mechanical unlock for all multi-tenancy scenarios:

```diff
// lib/src/core/notification_overlay.dart — initState()

- _attachedCoordinator = FlutterNotificationQueue.coordinator; // ← global singleton
+ // coordinator is now injected via widget.coordinator from NotificationScope.build()
+ widget.coordinator.attach(_overlayPortalController);
```

The `_NotificationOverlay` widget gains a `coordinator` constructor parameter, which
`NotificationScopeState.build()` supplies. All existing overlay rendering logic —
`OverlayPortal`, the `Stack` fallback, `_NotificationQueueStack`, `QueueWidget` — remains
completely unchanged.

### 5.5 `NotificationEvent` — Renamed Event Base Type

```dart
// Before:
sealed class FnqEvent { const FnqEvent(); }

// After:
sealed class NotificationEvent { const NotificationEvent(); }

// All subtypes are unchanged:
final class NotificationQueued extends NotificationEvent { ... }
final class NotificationDismissed extends NotificationEvent { ... }
final class NotificationTapped extends NotificationEvent { ... }
final class NotificationRelocated extends NotificationEvent { ... }
final class NotificationReordered extends NotificationEvent { ... }
final class NotificationSnoozed extends NotificationEvent { ... }
final class NotificationPinned extends NotificationEvent { ... }
final class NotificationUnpinned extends NotificationEvent { ... }
final class NotificationCustomActionTriggered extends NotificationEvent { ... }
final class NotificationGroupExpanded extends NotificationEvent { ... }
final class NotificationGroupCollapsed extends NotificationEvent { ... }
final class NotificationGroupDismissed extends NotificationEvent { ... }
final class NotificationChannelRouteUpdated extends NotificationEvent { ... }
final class QueueOverflowed extends NotificationEvent { ... } // note: not "Notification" prefix
```

---

## 6. The Dispatch Ergonomics — Full Picture

```dart
// ════════════════════════════════════════
// 1. Setup (once per app or window)
// ════════════════════════════════════════

final controller = NotificationController(
  queues: {
    const NotificationQueue(position: QueuePosition.topCenter),
    const NotificationQueue(position: QueuePosition.bottomRight),
  },
  channels: {
    ...NotificationChannel.standardChannels(),
    NotificationChannel('orders', displayName: 'Order Updates'),
  },
  maxHistoryEntries: 100,
);

// ════════════════════════════════════════
// 2. Tree injection (in MaterialApp)
// ════════════════════════════════════════

MaterialApp(
  builder: (context, child) => NotificationScope(
    controller: controller,
    child: child!,
  ),
);

// ════════════════════════════════════════
// 3a. Contextless dispatch (service/BLoC)
// ════════════════════════════════════════

class OrderBloc {
  OrderBloc({required this.notifications});
  final NotificationController notifications;

  Future<void> onOrderPlaced(Order order) async {
    final result = await _api.placeOrder(order);
    notifications.show(AppNotification(
      id: 'order-${order.id}',
      message: 'Order #${order.number} confirmed!',
      channelName: 'orders',
      priority: NotificationPriority.high,
      dismissDuration: const Duration(seconds: 6),
      tapBehavior: TapToAct(onTap: () => router.go('/orders/${order.id}')),
    ));
  }
}

// ════════════════════════════════════════
// 3b. Context-based dispatch (widget layer)
// ════════════════════════════════════════

ElevatedButton(
  onPressed: () => NotificationScope.of(context).show(
    AppNotification(message: 'Settings saved', channelName: 'success'),
  ),
  child: const Text('Save'),
)

// ════════════════════════════════════════
// 4. Event stream (analytics / reactions)
// ════════════════════════════════════════

controller.events.listen((event) {
  switch (event) {
    case NotificationQueued(:final notification):
      analytics.track('notification_shown', id: notification.id);
    case NotificationDismissed(:final notification, :final reason):
      analytics.track('notification_dismissed', properties: {
        'id': notification.id,
        'reason': reason.name,
      });
    case NotificationTapped(:final notification):
      analytics.track('notification_tapped', id: notification.id);
    case QueueOverflowed():
      metrics.increment('queue_overflow');
    default:
      break;
  }
});
```

---

## 7. Real-World Multi-Tenancy Scenarios

### Scenario A — Standard Mobile/Web App (Most Common)

One controller, one scope, app-wide coverage. The simplest and most common usage.

```dart
// main.dart
void main() {
  final notifications = NotificationController(
    queues: {const NotificationQueue(position: QueuePosition.topCenter)},
  );

  runApp(MyApp(notifications: notifications));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.notifications});
  final NotificationController notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => NotificationScope(
        controller: notifications,
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}
```

The controller lives as long as the app. No `dispose()` needed (process ends when app ends).
For apps using Riverpod, the controller is a natural `Provider` or `StateProvider` value.

---

### Scenario B — Flutter Desktop Multi-Window

Each window gets its own controller and scope. Notifications are completely isolated.

```dart
// Window A — spawned when the user opens a new editor window
class EditorWindow extends StatefulWidget { ... }

class _EditorWindowState extends State<EditorWindow> {
  // Controller is owned by the window's state — disposed when the window closes
  late final NotificationController _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = NotificationController(
      queues: {
        const NotificationQueue(position: QueuePosition.topRight),
        const NotificationQueue(position: QueuePosition.bottomCenter),
      },
      channels: {
        NotificationChannel('editor', displayName: 'Editor Notifications'),
        NotificationChannel('collaboration', displayName: 'Collaboration'),
      },
    );
  }

  @override
  void dispose() {
    _notifications.dispose(); // ← cleans up the coordinator and event stream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationScope(
      controller: _notifications,
      child: EditorContent(notifications: _notifications),
    );
  }
}
```

When the user closes Window A, `_EditorWindowState.dispose()` runs, which calls
`_notifications.dispose()`. The `NotificationScope.dispose()` that runs first (as part of
widget tree teardown) calls `controller._detach()`. The coordinator is cleaned up via
standard Flutter lifecycle — no manual intervention required.

Notifications dispatched to `_notifications` appear **only** in Window A's overlay.
Window B's `_notifications` instance is completely independent.

If the app needs a global merged event stream for analytics:

```dart
// app_analytics.dart
final _allWindowEvents = StreamGroup.merge([
  windowAController.events,
  windowBController.events,
]);
_allWindowEvents.listen(analyticsService.track);
```

The library does not impose a global merge — merging is the app's concern and the app's choice.

---

### Scenario C — Flutter Add-to-App (Embedded in Native)

When Flutter is embedded in a native iOS or Android app, multiple `FlutterEngine` instances
may run concurrently. With v0.x's global singleton, only the first engine's notifications
would work; the second would fight over the same coordinator state.

With v1.0, each engine gets its own controller, created when the Flutter module initializes:

```dart
// flutter_module/lib/main.dart — entry point for the embedded engine
@pragma('vm:entry-point')
void embeddedMain() {
  // Each engine invocation creates a fresh controller
  final notifications = NotificationController(
    queues: {const NotificationQueue(position: QueuePosition.topCenter)},
  );

  runApp(EmbeddedApp(notifications: notifications));
}

class EmbeddedApp extends StatelessWidget {
  const EmbeddedApp({super.key, required this.notifications});
  final NotificationController notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => NotificationScope(
        controller: notifications,
        child: child!,
      ),
      home: const EmbeddedHomePage(),
    );
  }
}
```

No state is shared between engine instances. Each embedded Flutter surface operates with
full isolation.

---

### Scenario D — Per-Route / Per-Page Isolated Scope

Some apps need notifications scoped to a specific page — for example, a dashboard where
"data sync" notifications should only appear while the dashboard is visible and auto-dismiss
when the user navigates away.

```dart
class DashboardPage extends StatefulWidget { ... }

class _DashboardPageState extends State<DashboardPage> {
  late final NotificationController _localNotifications;

  @override
  void initState() {
    super.initState();
    _localNotifications = NotificationController(
      queues: {const NotificationQueue(position: QueuePosition.bottomCenter)},
      channels: {NotificationChannel('sync', displayName: 'Data Sync')},
    );
  }

  @override
  void dispose() {
    _localNotifications.dispose(); // all notifications auto-dismiss on page exit
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This NotificationScope is NESTED inside the app-level scope.
    // NotificationScope.of(context) within DashboardContent will resolve
    // to this local scope, not the app-level one.
    return NotificationScope(
      controller: _localNotifications,
      child: DashboardContent(notifications: _localNotifications),
    );
  }
}
```

When the user navigates away from the dashboard, the route is popped, the
`_DashboardPageState` is disposed, the controller is disposed, and all dashboard
notifications vanish — with zero explicit cleanup code required.

---

### Scenario E — Widget Test Isolation (Zero Shared State)

In v0.x, every widget test that used FNQ required a `tearDown` call to `FlutterNotificationQueue.reset()`, because the global singleton leaked between tests.

In v1.0, each test tree has its own controller:

```dart
testWidgets('shows error notification when API fails', (tester) async {
  final controller = NotificationController(
    queues: {const NotificationQueue()},
  );

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => NotificationScope(
        controller: controller,
        child: child!,
      ),
      home: const ApiDemoPage(),
    ),
  );

  // Trigger the failing API call
  await tester.tap(find.byKey(const Key('fetch-button')));
  await tester.pump();

  // Verify via the controller event stream
  await expectLater(
    controller.events,
    emits(isA<NotificationQueued>()),
  );

  // Or verify by widget inspection
  expect(find.text('Failed to load data'), findsOneWidget);

  // No tearDown needed — pumpWidget disposal handles all cleanup
});

testWidgets('does not show notification when API succeeds', (tester) async {
  // Completely fresh state — no reset() call needed
  final controller = NotificationController(
    queues: {const NotificationQueue()},
  );
  // ...
});
```

---

## 8. Migration Plan: v0.3.0 → v0.4.0

### Phase A — v0.3.0: Additive Deprecations (Zero Breaking Changes)

Ship the entire new API alongside the existing API. Users can adopt at their own pace.
The old API continues to work but emits deprecation warnings.

```dart
@Deprecated(
  'FlutterNotificationQueue is replaced by NotificationController + NotificationScope. '
  'See doc/migration_v0_4.md for a step-by-step guide.',
)
final class FlutterNotificationQueue { ... }

@Deprecated(
  'NotificationWidget is replaced by AppNotification. '
  'NotificationWidget(...).show() becomes controller.show(AppNotification(...)). '
  'See doc/migration_v0_4.md.',
)
final class NotificationWidget { ... }

@Deprecated('FnqEvent is renamed to NotificationEvent.')
typedef FnqEvent = NotificationEvent;
```

No user code breaks in v0.3.0. The deprecation warnings are the migration signal.

### Phase B — v0.4.0: Breaking Removal

Remove all deprecated static symbols in v0.4.0 under pre-1.0 SemVer rules (where `0.y.0` indicates breaking API changes). The codebase is completely standardized around `NotificationController`, `NotificationScope`, and `AppNotification`. A `doc/migration_v0_4.md` guide accompanies the release.

**One-to-one replacement table:**

| v0.3.x Legacy API | v0.4.0 Modern Architecture |
|---|---|
| `FlutterNotificationQueue.configure(queues: q, channels: c)` | `NotificationController(queues: q, channels: c)` |
| `FlutterNotificationQueue.builder` | `(ctx, child) => NotificationScope(controller: c, child: child!)` |
| `NotificationWidget(message: m).show()` | `controller.show(AppNotification(message: m))` |
| `FlutterNotificationQueue.show(message: m)` | `controller.show(AppNotification(message: m))` |
| `FlutterNotificationQueue.events` | `controller.events` |
| `FlutterNotificationQueue.getHistory(...)` | `controller.getHistory(...)` |
| `FlutterNotificationQueue.reset()` | Not needed — dispose controller or let tree dispose it |
| `FnqEvent` | `NotificationEvent` |

---

## 9. Implementation Order for v0.3.0

Steps 1 and 2 are purely additive and carry zero risk.
Step 3 is the highest-risk change — the render engine touches — but is also the smallest
in terms of diff size: one line in `notification_overlay.dart`.
Steps 4–5 can proceed in parallel with step 3 once the coordinator interface is stable.

```
Step 1  AppNotification
        ├── Create class with same parameters as NotificationWidget
        ├── Add internal _toEntry() adapter method
        └── Mark NotificationWidget @Deprecated

Step 2  NotificationController
        ├── Pure Dart, zero Flutter SDK imports
        ├── _attach() / _detach() internal protocol
        ├── Stable _proxyController event stream
        └── show(), tryShow(), dismiss(), dismissAll(), getHistory(), events, dispose()

Step 3  _NotificationOverlay refactor
        ├── Add coordinator constructor parameter
        ├── Remove FlutterNotificationQueue.coordinator static access
        └── All rendering logic (OverlayPortal, Stack fallback) is unchanged

Step 4  QueueCoordinator.fromController() factory
        └── Accept configuration from NotificationController rather than ConfigurationManager

Step 5  NotificationScope
        ├── StatefulWidget + private _NotificationScopeData InheritedWidget
        ├── initState() → controller._attach(this)
        ├── dispose() → controller._detach()
        ├── build() → _NotificationScopeData + _NotificationOverlay(coordinator: _coordinator)
        ├── NotificationScope.of(context)
        └── NotificationScope.maybeOf(context)

Step 6  NotificationEvent rename
        ├── sealed class NotificationEvent (rename FnqEvent)
        └── typedef FnqEvent = NotificationEvent (deprecation bridge)

Step 7  Mark FlutterNotificationQueue @Deprecated

Step 8  Update all tests
        └── Remove FlutterNotificationQueue.reset() tearDown calls

Step 9  Update example app

Step 10 Write doc/migration_v0_4.md
```

---

## 10. Where FNQ Stands in the Ecosystem After v1.0

| Capability | FNQ v1.0 | toastification | bot_toast | overlay_support | flash |
|---|:---:|:---:|:---:|:---:|:---:|
| True multi-tenancy (isolated controller per surface) | ✅ | ❌ | ❌ | ⚠️ limited | ✅ native |
| Spatial multi-queue (multiple positions simultaneously) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Priority triage & overflow backpressure | ✅ | ❌ | ❌ | ❌ | ❌ |
| Notification grouping with gesture-driven unravel | ✅ | ❌ | ❌ | ❌ | ❌ |
| Rich typed event stream (`NotificationEvent` sealed class) | ✅ | Partial | Partial | ❌ | Partial |
| Channel-based routing & dynamic parking | ✅ | ❌ | ❌ | ❌ | ❌ |
| Zero-reset test isolation | ✅ | ❌ | ❌ | ✅ | ✅ |

v1.0 does not add new features. It makes FNQ's existing, unique capabilities available to
every production Flutter application — the ones that cannot tolerate a global static
singleton because they run multiple windows, embed multiple engines, or demand rigorous
test isolation.

---

*Last updated: 2026-08-13 — Incorporates: maturity audit, ecosystem analysis,
TextEditingController attachment pattern, NotificationScope decision, AppNotification
naming, NotificationEvent rename, tryShow() convention, and multi-tenancy scenario review.*
