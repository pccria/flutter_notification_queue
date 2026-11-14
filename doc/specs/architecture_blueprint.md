# Architecture Blueprint & System Design Rationale

## 1. Executive Summary

This document serves as the foundational architectural blueprint and design
rationale for **Flutter Notification Queue (FNQ)**. It details the architectural
evolution of the framework—from its early prototype era through the multi-tenant
revolution (v0.4.0), platform hardening (v0.5.x–v0.6.x), continuous spatial and
temporal invariance (v0.7.x), and the scheduled trajectory to the final
**v1.0.0 General Availability (GA)** release.

The architectural progression is informed by:
- A structural audit of early singleton architectures and their failure modes
  in versions v0.1.0 through v0.3.x.
- An analysis of how leading overlay libraries in the Flutter ecosystem
  (`toastification`, `bot_toast`, `overlay_support`) each solved—and where they
  failed—the same problem space.
- Canonical Flutter SDK patterns (`ScaffoldMessenger`, `TextEditingController`,
  `Navigator`) as the authoritative reference implementation.

**Target audience:** Maintainers, contributors, and architects evaluating FNQ's
system design and evolutionary roadmap.

---

## 2. What the Prototype Era (v0.1.0 – v0.3.x) Got Right and Where It Failed

### 2.1 The Original Architecture
In versions v0.1.0 through v0.3.x, FNQ prioritized extreme convenience for quick
prototyping. The entire system was held together by three global primitives:

- **`FlutterNotificationQueue.configure()`**: A static call that created a
  global singleton coordinator.
- **`NotificationWidget(...).show()`**: A widget-named configuration object that
  knew how to dispatch itself into the global overlay.
- **`FlutterNotificationQueue.builder`**: A static builder method that injected
  the global `OverlayPortal` into `MaterialApp`.

While minimal and functional as a proof of concept, this architecture hit
critical scaling walls in production.

### 2.2 The Two Structural Flaws

#### Flaw 1 — The static singleton locks multi-tenancy (v0.1.x – v0.3.x)
Because `FlutterNotificationQueue.coordinator` was a global static, there could
be exactly one active notification surface in the process. This made it
impossible to:
- Run two independent queues in a desktop multi-window app.
- Sandbox notification state in tests without explicit `reset()` calls.
- Use FNQ in an add-to-app embedding (multiple `FlutterEngine` instances).
- Have isolated notification contexts per route or page subtree.

The coupling that locked multi-tenancy was in `notification_overlay.dart`:
```dart
// The legacy coupling that made multi-tenancy impossible in v0.1.x–v0.3.x:
_attachedCoordinator = FlutterNotificationQueue.coordinator; // global singleton
```

#### Flaw 2 — The Active Widget anti-pattern (v0.1.x – v0.3.x)
`NotificationWidget` was named `Widget` but was not a Flutter widget in any
meaningful sense. It was a data/configuration object. Calling `.show()` on it
conflated two distinct roles: the data payload and the dispatch command. This
naming misled developers into placing it in build methods or passing it to
widget parameters.

### 2.3 The Ecosystem Consensus
Every major overlay library in the Flutter ecosystem has evolved from a static
singleton toward a scoped, instance-based model:

```
[One StatefulWidget] = overlay mount point + InheritedWidget lookup
        └── internal State = the engine
        └── pure-Dart controller = contextless escape hatch
```

`ScaffoldMessenger` is the reference implementation of this pattern in the
Flutter SDK itself: a single `StatefulWidget` that simultaneously mounts the
overlay AND provides `.of(context)` lookup, backed by a pure-Dart handle for
contextless access.

---

## 3. The Multi-Tenant Architecture (Introduced in v0.4.0)

> In **v0.4.0**, FNQ adopted the **`TextEditingController` ↔ `TextField`**
> attachment pattern from the Flutter SDK: a pure-Dart
> **`NotificationController`** owns configuration and provides contextless
> dispatch; a **`NotificationScope`** widget is the single widget that both
> mounts the overlay surface AND provides `InheritedWidget` lookup—exactly as
> `ScaffoldMessenger` does for snack bars.

The Flutter SDK translation table:

| Flutter SDK Concept | FNQ Implementation (v0.4.0+) |
|---|---|
| `ScaffoldMessenger` (StatefulWidget + InheritedWidget) | `NotificationScope` |
| `ScaffoldMessengerState` (the engine) | `NotificationScopeState` |
| `GlobalKey<ScaffoldMessengerState>` | `NotificationController` |
| `SnackBar` (pure data payload) | `AppNotification` |
| `ScaffoldMessenger.of(context)` | `NotificationScope.of(context)` |
| `showSnackBar()` | `show()` |

The attachment lifecycle mirrors `TextEditingController` ↔ `EditableTextState`:
- `controller._attach(state)` — called in `NotificationScope.initState()`
- `controller._detach()` — called in `NotificationScope.dispose()`
- `controller.show(notification)` — delegates to `state.show(notification)`

---

## 4. Terminology & Evolutionary Renaming (v0.4.0)

Every public-facing name was evaluated against semantic accuracy, Flutter
precedent, conflict risk, and readability at the call site.

### 4.1 Name Changes Introduced in v0.4.0

- **`NotificationWidget` $\to$ `AppNotification`**:
  Pure data intent; removes misleading `Widget` suffix.
- **`FlutterNotificationQueue` $\to$ `NotificationController`**:
  Instance-bound lifecycle controller.
- **`NotificationScope` (new widget)**:
  Widget subtree injector and `OverlayPortal` host.
- **`FnqEvent` $\to$ `NotificationEvent`**:
  Removes opaque abbreviation from public API.
- **`showIfAttached()` $\to$ `tryShow()`**:
  Idiomatic non-throwing try-pattern.

### 4.2 Names Retained for Continuity
`NotificationChannel`, `NotificationQueue`, `QueuePosition`, `DismissReason`,
`NotificationPriority`, and event subtypes (`NotificationQueued`,
`NotificationDismissed`, `NotificationTapped`, `QueueOverflowed`) were retained
due to their semantic clarity.
*not* prefixed with `Notification` — the *queue* overflowed, not a notification.

---

## 5. The Complete Public API Contract

### 5.1 `AppNotification` — Pure Data, No Dispatch

```dart
/// Represents the intent to display an in-app notification.
///
/// This is a pure data object — it has no UI dependency, no [BuildContext]
/// requirement, and no dispatch method.
/// Pass it to [NotificationController.show] or
/// [NotificationScope.of(context).show].
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
/// Configuration owner and contextless dispatch handle for a notification
/// surface.
///
/// Create one instance per independent notification surface (one per app
/// window, one per isolated test, one per embedded FlutterEngine). Attach it
/// to the widget tree via [NotificationScope].
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

  /// Whether a [NotificationScope] is currently mounted and attached to
  /// this controller.
  bool get isAttached;

  /// Stable broadcast stream of all notification lifecycle events.
  ///
  /// This stream **persists across [NotificationScope] mount and unmount
  /// cycles**. Listeners attached before the scope mounts will continue to
  /// receive events from the scope once it does mount, without re-subscribing.
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
  // The proxy survives attach/detach cycles; listeners keep subscriptions.
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
/// For isolated subtree scopes (e.g., a single desktop window), place it
/// directly:
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
  /// Throws if no [NotificationScope] is found. Use [maybeOf] for optional
  /// lookup.
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
      // Note: configuration hot-swapping is not supported.
      // To change configuration, replace the NotificationScope subtree.
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

  void dismiss(
    String id, {
    DismissReason reason = DismissReason.programmatic,
  }) => _coordinator.dismissById(id, reason: reason);

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

- _attachedCoordinator = FlutterNotificationQueue.coordinator;
+ // Coordinator is injected via widget.coordinator from
+ // NotificationScope.build()
+ widget.coordinator.attach(_overlayPortalController);
```

The `_NotificationOverlay` widget gains a `coordinator` parameter supplied by
`NotificationScopeState.build()`. All existing overlay rendering logic
(`OverlayPortal`, `Stack` fallback, queue widgets) remains unchanged.

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
// Note: QueueOverflowed intentionally omits the "Notification" prefix:
final class QueueOverflowed extends NotificationEvent { ... }
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

One controller, one scope, app-wide coverage. The simplest and most common
usage:

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

The controller lives as long as the app. No `dispose()` needed (process ends
when app ends). For apps using Riverpod, the controller is a natural
`Provider` value.

---

### Scenario B — Flutter Desktop Multi-Window

Each window gets its own controller and scope. Notifications are completely
isolated.

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

When the user closes Window A, `_EditorWindowState.dispose()` runs, calling
`_notifications.dispose()`. The `NotificationScope.dispose()` that runs first
(as part of widget tree teardown) calls `controller._detach()`. The coordinator
is cleaned up via standard Flutter lifecycle.

Notifications dispatched to `_notifications` appear **only** in Window A's
overlay. Window B's `_notifications` instance is completely independent.

If the app needs a global merged event stream for analytics:

```dart
// app_analytics.dart
final _allWindowEvents = StreamGroup.merge([
  windowAController.events,
  windowBController.events,
]);
_allWindowEvents.listen(analyticsService.track);
```

The library does not impose a global merge — merging is the app's concern.

---

### Scenario C — Flutter Add-to-App (Embedded in Native)

When Flutter is embedded in a native iOS or Android app, multiple
`FlutterEngine` instances may run concurrently. In the v0.1.x–v0.3.x prototype
era with a global singleton, only the first engine's notifications would work;
the second would fight over the same coordinator state.

Since v0.4.0, each engine gets its own controller, created when the Flutter
module initializes:

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

No state is shared between engine instances. Each embedded Flutter surface
operates with full isolation.

---

### Scenario D — Per-Route / Per-Page Isolated Scope

Some apps need notifications scoped to a specific page — for example, a
dashboard where "data sync" notifications should only appear while the
dashboard is visible and auto-dismiss when the user navigates away.

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
    // all notifications auto-dismiss on page exit
    _localNotifications.dispose();
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

In the v0.1.x–v0.3.x prototype era, every widget test that used FNQ required a
`tearDown` call to `FlutterNotificationQueue.reset()`, because the global
singleton leaked between tests.

Since v0.4.0, each test tree creates its own isolated controller:

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

## 8. Historical Milestone: The v0.3.0 → v0.4.0 Architectural Transition

In August 2026, FNQ executed a two-phase architectural transition to eliminate
the legacy prototype singletons and establish the multi-tenant baseline:

### Phase A — v0.3.0: Additive Deprecations (Zero Breaking Changes)
Shipped the modern `NotificationController` and `NotificationScope` API
alongside legacy singletons. The old API continued functioning while emitting
actionable deprecation warnings:

```dart
@Deprecated(
  'FlutterNotificationQueue is replaced by NotificationController + '
  'NotificationScope. See doc/migration_v0_4.md for a step-by-step guide.',
)
final class FlutterNotificationQueue { ... }

@Deprecated(
  'NotificationWidget is replaced by AppNotification. '
  'NotificationWidget(...).show() becomes '
  'controller.show(AppNotification(...)).',
)
final class NotificationWidget { ... }

@Deprecated('FnqEvent is renamed to NotificationEvent.')
typedef FnqEvent = NotificationEvent;
```

### Phase B — v0.4.0: Breaking Removal
Removed all deprecated static symbols in `v0.4.0` under pre-1.0 SemVer rules
(where `0.y.0` indicates breaking structural changes). The codebase was
standardized 100% around `NotificationController`, `NotificationScope`, and
`AppNotification`.

**One-to-one migration replacement:**

| v0.1.x–v0.3.x Legacy Symbol | v0.4.0+ Modern Architecture |
|---|---|
| `FlutterNotificationQueue.configure(...)` | `NotificationController(...)` |
| `FlutterNotificationQueue.builder` | `NotificationScope(controller: c, ...)` |
| `NotificationWidget.show()` | `controller.show(AppNotification(...))` |
| `FlutterNotificationQueue.events` | `controller.events` |
| `FlutterNotificationQueue.getHistory(...)` | `controller.getHistory(...)` |
| `FlutterNotificationQueue.reset()` | Not needed — controller scoped to tree |
| `FnqEvent` | `NotificationEvent` |

---

## 9. Historical Implementation Stages of v0.4.0

The structural migration to `v0.4.0` was executed across 10 progressive steps:

```
Step 1  AppNotification (pure data payload class)
Step 2  NotificationController (pure Dart lifecycle owner)
Step 3  _NotificationOverlay refactor (accepts coordinator instance)
Step 4  QueueCoordinator.fromController() constructor
Step 5  NotificationScope (StatefulWidget + InheritedWidget)
Step 6  NotificationEvent sealed class rename
Step 7  Deprecation warnings on FlutterNotificationQueue
Step 8  Update test suite to remove reset() tearDown calls
Step 9  Update example app to multi-tenant controllers
Step 10 Publish doc/migration_v0_4.md guide
```

---

## 10. Ecosystem Comparison & Current Standing

The table below reflects FNQ's capabilities as of **v0.7.x**:

| Capability | FNQ | toastification | bot_toast | overlay_supp. | flash |
|---|:---:|:---:|:---:|:---:|:---:|
| True multi-tenancy (isolated controller) | ✅ | ❌ | ❌ | ⚠️ limited | ✅ native |
| Spatial multi-queue (simultaneous) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Priority triage & overflow backpressure | ✅ | ❌ | ❌ | ❌ | ❌ |
| Notification grouping with card unravel | ✅ | ❌ | ❌ | ❌ | ❌ |
| Typed event stream | ✅ | Partial | Partial | ❌ | Partial |
| Channel-based routing & dynamic parking | ✅ | ❌ | ❌ | ❌ | ❌ |
| Zero-reset test isolation | ✅ | ❌ | ❌ | ✅ | ✅ |
| Continuous egress & momentum flight | ✅ | ❌ | ❌ | ❌ | ❌ |
| Token invariant & queue stasis engine | ✅ | ❌ | ❌ | ❌ | ❌ |

All of the advanced architectural capabilities listed above are active and
verified in the codebase today (`v0.7.x`).

---

## 11. Evolutionary Lineage & The Infrastructure Maturation Path

The roadmap toward eventual production readiness is an evolving exploration
rather than a rigid countdown.

> [!NOTE]
> **Working Hypotheses & Exploratory Pre-1.0 SemVer**: All future milestone
> projections (`v0.8.x`, `v0.9.x`, etc.) are **surface anticipations and
> working hypotheses**, not immutable commitments. FNQ will iterate through as
> many minor releases as required to thoroughly stress-test infrastructure,
> discover edge cases, and harden fundamentals before declaring any API freeze.

The major evolutionary phases across FNQ's history and active exploration:

### Prototype Era: v0.1.0 – v0.3.x
- **Focus**: Proof-of-concept and rapid setup via
  `FlutterNotificationQueue.configure()`.
- **Architectural Flaws**: Global static singleton blocked desktop multi-window
  apps and test isolation (required `reset()` in tests); Active Widget
  anti-pattern conflated data payload with dispatch command.

### Multi-Tenant Revolution: v0.4.0
- **Architectural Shift**: Eliminated all static singletons.
- **Key Deliverables**: Introduced pure-Dart `NotificationController`,
  widget-tree `NotificationScope`, pure data `AppNotification`, and sealed
  `NotificationEvent` hierarchy.

### Stability, Leaks & Grouping: v0.5.0 – v0.5.2
- **Architectural Shift**: Memory hardening and visual card bundling.
- **Key Deliverables**: Resolved snooze timer leaks, non-destructive error
  chaining, `GroupCountBehavior` deck bundling, peek card timer stasis, and
  duplicate GlobalKey collisions.

### Encapsulation & Platform Hardening: v0.6.0 – v0.6.1
- **Architectural Shift**: Monolith decomposition and accessibility.
- **Key Deliverables**: Decomposed 26-part monolith into clean sub-libraries,
  added WCAG 2.1 AA accessibility options (`NotificationA11yOptions`), desktop
  right-click context menu engine, and `NotificationThemeData`.

### Continuous Egress & Temporal Invariance: v0.7.0 – v0.7.1
- **Architectural Shift**: Physical continuous egress and invariant timekeeping.
- **Key Deliverables**: Replaced artificial screen-edge drop zones with
  card-centric `DismissEgress` and `EgressFlightOverlay`; cross-queue slot
  relocation; replaced loose boolean flags with token-based invariant engine
  (`TimerPauseReason`); introduced queue-level stasis
  (`NotificationTimerScope`).

### Infrastructure Maturation & Gesture Rationalization: v0.8.x (Planned)
- **Architectural Shift**: Conceptual gesture unification & reality testing.
- **Key Deliverables**:
  1. Consolidate fragmented spatial movement (`Reorder`, `Relocate`,
     `ReorderAndRelocate`) into a single, cohesive spatial movement engine.
  2. Rationalize card retention actions (`Pin`, `Snooze`) out of standalone
     drag behaviors into a dedicated card action/retention model.
  3. Purge legacy `DismissZone` and screen-edge target machinery (~1,200 LOC).
  4. Implement real multi-window desktop support in the Studio example to
     battle-test `NotificationController` and `NotificationScope` under real
     OS multi-window conditions.

### Deep Hardening & Edge-Case Stress Testing: v0.9.x+ (Exploratory)
- **Architectural Shift**: High-throughput profiling and multi-engine teardowns.
- **Key Deliverables**: Stress benchmarks under 120Hz frame budgets, screen
  reader WCAG 2.1 AA audit, and memory leak analysis across rapid lifecycle
  events.

### Eventual Production Stability: v1.0.0 (Target Horizon)
- **Architectural Shift**: Production General Availability.
- **Milestone Definition**: Long-term API freeze and stability guarantee,
  declared only when the underlying infrastructure has proven rock-solid
  across real desktop, web, and mobile production workloads.

### 11.1 Token-Based Invariant Engine (Shipped in v0.7.1)
The legacy approach of managing countdowns through ad-hoc boolean flags
(`_isMouseHovering`, `_isDragPaused`) was replaced with an immutable token set:

```dart
final Set<TimerPauseReason> _pauseReasons = <TimerPauseReason>{};

bool get shouldTimerRun =>
    NotificationTimerScope.isEnabledNonSubscribing(context) &&
    _pauseReasons.isEmpty &&
    !_isDismissing;
```

Any interaction (`drag`, `hover`, `touchHold`, `expanded`, `contextMenu`,
`pinned`) acquires a discrete token. Releasing the interaction revokes the
token. The timer runs if and only if zero pause tokens exist.

### 11.2 Queue Stasis (`NotificationTimerScope`, Shipped in v0.7.1)
Queues synchronize stasis across all rendered cards via
`NotificationTimerScope`. During in-queue reordering, cross-queue relocation, or
programmatic pause (`controller.pauseQueue`, `controller.pauseAll`), the entire
queue halts countdowns without mutating individual card state tokens.

### 11.3 Card-Centric Egress & Inertial Flight (Shipped in v0.7.0/v0.7.1)
Swipe dismissals follow card-centric egress trajectories (`DismissEgress`)
rather than hardcoded screen borders. Committing past dual thresholds
(fractional displacement or ballistic `escapeVelocity`) detaches the card
into an `EgressFlightOverlay` that coasts off-screen while the queue stack
immediately collapses the vacated slot beneath it.

---

*Last updated: 2026-11-14 — Incorporates: architectural axioms, token-based
timer invariant engine, queue stasis subsystem, card-centric egress physics,
cross-queue slot relocation, and complete version lineage tracking.*
