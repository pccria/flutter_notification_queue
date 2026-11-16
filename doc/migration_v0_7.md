# Migration Guide: Upgrading to v0.7.0

This guide details the architectural evolution, new features, and deprecation
paths introduced in **v0.7.0**, preparing your codebase for
the upcoming **v0.8.0** release.

---

## 🧭 The Shift to Card-Centric Directional Egress

In versions prior to v0.7.0, swipe-to-dismiss interactions relied on
screen-edge drop zones (`DismissZone.sideEdges`, `naturalDirection`). On
larger displays, tablets, or desktop viewports, dragging a notification card
across wide screen areas to reach an edge bar felt unnatural and visually
intrusive.

Starting in **v0.7.0**, FNQ transitions to a **card-centric directional egress
paradigm**:
- Dismissals operate locally relative to the notification card's resting slot.
- Trajectories are governed by declarative `DismissEgress` policies.
- Dismissals are committed via dual thresholds: displacement distance fraction
  and ballistic flick velocity.
- Sensory feedback includes organic angular tilt, in-slot reveal underlays,
  and inertial momentum exit flight.

---

## 📋 Summary of Changes

| Change | Type | Impact & Action Required |
|---|---|---|
| **`DismissEgress` Hierarchy** | 🟢 New Feature | Sealed class hierarchy (`horizontal`, `natural`, `outward`, `cross`, `any`) defining allowable exit trajectories. |
| **Dual-Threshold Commitment** | 🟢 New Feature | `dismissThreshold` (displacement fraction) and `escapeVelocity` (ballistic flick velocity in dp/s). |
| **Sensory Feedback & Underlay** | 🟢 New Feature | `enableTilt`, `showUnderlay`, `dismissColor`, and `dismissIcon` on `Dismiss`. |
| **Inertial Momentum Flight** | 🟢 New Feature | Committed cards coast off-screen via `EgressFlightOverlay` at finger velocity while stack collapses. |
| **Drag Timer Preservation** | 🟢 Bugfix | Touching/dragging cards pauses auto-dismiss countdown; cancelling drag cleanly resumes countdown without loss. |
| **Queue-Level Stasis Controls** | 🟢 New Feature | Programmatically freeze/resume queue timers via `pauseQueue()`, `resumeQueue()`, `pauseAll()`, and `resumeAll()`. |
| **Atomic Backpressure Purge** | 🟢 New Feature | `controller.dismissAll(clearBacklog: true)` atomically purges pending capacity backlog alongside active cards. |
| **Sub-Viewport Local Scoping** | 🟢 New Feature | `NotificationScope(useRootOverlay: false)` binds portals to nearest ancestor `Overlay` for embedded frames and modals. |
| **`Dismiss(zones: ...)` & `DismissZone`** | 🟡 Deprecated | Deprecated in `v0.7.0`. Fully backward compatible via `effectiveEgress`. Scheduled for removal in `v0.8.0`. |
| **Cross-Queue Relocation Engine** | 🟢 New Feature | `Relocate.to(...)` and `ReorderAndRelocate.to(...)` support live destination insertion previews. |

---

## 1. Migrating from `Dismiss(zones: ...)` to `Dismiss(egress: ...)`

### Deprecation Timeline
- **v0.7.x**: `DismissZone` and `Dismiss.zones` are marked `@Deprecated`. Code
  using `zones` continues to compile and automatically maps to `effectiveEgress`.
- **v0.8.0**: `DismissZone` and `Dismiss.zones` will be completely removed.

### Recipe 1: Side Edges to Horizontal Egress

Before (v0.6.x):
```dart
// ⚠️ DEPRECATED
NotificationQueue(
  position: QueuePosition.topRight,
  dragBehavior: const Dismiss(
    zones: [DismissZone.sideEdges],
  ),
);
```

After (v0.7.x+):
```dart
// ✅ RECOMMENDED (Default egress is horizontal)
NotificationQueue(
  position: QueuePosition.topRight,
  dragBehavior: const Dismiss(
    egress: DismissEgress.horizontal(),
  ),
);
```

### Recipe 2: Natural Direction Egress

Before (v0.6.x):
```dart
// ⚠️ DEPRECATED
NotificationQueue(
  position: QueuePosition.topRight,
  dragBehavior: const Dismiss(
    zones: [DismissZone.naturalDirection],
  ),
);
```

After (v0.7.x+):
```dart
// ✅ RECOMMENDED
NotificationQueue(
  position: QueuePosition.topRight,
  dragBehavior: const Dismiss(
    egress: DismissEgress.natural(),
  ),
);
```

---

## 2. Egress Strategy Reference

The `DismissEgress` sealed hierarchy provides five directional policies:

| Strategy | Allowable Directions | Ideal Use Case |
|---|---|---|
| `DismissEgress.horizontal({allowLeft, allowRight})` | Horizontal swipe left or right. | Standard toast notifications, alerts, and bottom bars. |
| `DismissEgress.natural()` | Outward away from screen center based on queue anchor. | Corner queues (`topRight`, `topLeft`, `bottomRight`, `bottomLeft`). |
| `DismissEgress.outward()` | Toward the closest screen boundary (horizontal or vertical). | Perimeter and edge-pinned queues. |
| `DismissEgress.cross()` | Inward across the screen toward the viewport center. | Specialized workflows where inward swiping archives or dismisses. |
| `DismissEgress.any()` | Omni-directional 360° swipe in any vector. | Freeform, floating, or non-anchored notification decks. |

---

## 3. Configuring Physics and Sensory Feedback

`Dismiss` introduces several ergonomic parameters to tune interaction feel:

```dart
NotificationQueue(
  position: QueuePosition.topRight,
  dragBehavior: const Dismiss(
    egress: DismissEgress.natural(),
    dismissThreshold: 0.35,      // 35% card displacement commits dismissal
    escapeVelocity: 550.0,       // Rapid flick (>= 550 dp/s) commits dismissal
    enableTilt: true,            // Organic card tilt during drag
    showUnderlay: true,          // In-slot reveal underlay exposed on swipe
    dismissColor: Color(0xFFEF4444),
    dismissIcon: Icons.delete_outline,
  ),
);
```

---

## 4. Timer Lifecycle Preservation

In prior versions, initiating a drag on an auto-dismissing notification could
reset or cancel the underlying timer unexpectedly.

In **v0.7.0+**, the timer lifecycle is strictly preserved:
1. When a user touches or drags a card, the auto-dismiss timer enters **stasis**
   (`pauseDismissTimer()`), freezing countdown progress.
2. If the user cancels the drag (releasing before threshold or snapping back),
   the timer resumes smoothly (`resumeDismissTimer()`) from its exact remaining
   duration.
3. If the card commits to dismissal, the timer is safely ditched and disposed.

---

## 5. Queue-Level Stasis Controls

In addition to individual card interaction stasis (hover, drag, expand),
`v0.7.x` introduces programmatic queue-level stasis through
`NotificationController`:

```dart
// Freeze countdown timers for all cards in a specific queue:
controller.pauseQueue(QueuePosition.topRight);

// Resume countdown timers for that queue:
controller.resumeQueue(QueuePosition.topRight);

// Query whether a queue is currently in stasis:
final isFrozen = controller.isQueuePaused(QueuePosition.topRight);

// Freeze or resume all queues simultaneously (e.g. during full-screen modal):
controller.pauseAll();
controller.resumeAll();
```

Behind the scenes, stasis is propagated via `NotificationTimerScope`, ensuring
zero ticker leaks and immediate frame-level freeze.

---

## 6. Atomic Backlog Purging with `dismissAll(clearBacklog: true)`

When queues enforce capacity limits (`maxStackSize`), high-frequency bursts
accumulate pending notifications in the coordinator's backlog.

By default, `controller.dismissAll()` (or `clearBacklog: false`) dismisses all
*currently active* notifications, allowing pending backlog items to be promoted
in FIFO order into freed slots.

To perform a complete and immediate queue reset—cancelling both active and
pending notifications in a single atomic pass—use `clearBacklog: true`:

```dart
// Atomically dismiss all active cards AND purge all pending backlog items:
controller.dismissAll(clearBacklog: true);
```

When `clearBacklog: true` is passed:
1. Pending backlog items in mounted queues are atomically purged before active
   cards exit, preventing pending promotions.
2. Unmounted items waiting in the initialization queue are removed.
3. `NotificationDismissed` events are emitted for all purged items.
4. Active cards execute their standard exit animations.

---

## 7. Sub-Viewport Scoping with `NotificationScope(useRootOverlay: false)`

Historically, `NotificationScope` attached its `OverlayPortal` to the root
application window (`OverlayChildLocation.rootOverlay`). While ideal for
standard apps, this caused overlay bleeding when embedding `NotificationScope`
into nested desktop panes, virtual split viewports, or modal dialogs.

In `v0.7.x`, `NotificationScope` and `NotificationOverlay` accept
`useRootOverlay`:

```dart
// Default (full-window application layer):
NotificationScope(
  controller: controller,
  useRootOverlay: true, // Default
  child: MyApp(),
);

// Local viewport containment (nested stages, desktop split-panes, modals):
NotificationScope(
  controller: localController,
  useRootOverlay: false, // Binds to nearest ancestor Overlay
  child: LocalViewportContainer(),
);
```

When `useRootOverlay: false` is set, notification stacks and flight portals are
strictly bounded within the nearest ancestor `Overlay`, enabling true 1:1
multi-tenant virtual stages without third-party window managers.
