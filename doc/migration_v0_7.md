# Migration Guide: Upgrading to v0.7.0

This guide details the architectural evolution, new features, and deprecation
paths introduced in **v0.7.0** and **v0.7.1**, preparing your codebase for
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

In **v0.7.1+**, the timer lifecycle is strictly preserved:
1. When a user touches or drags a card, the auto-dismiss timer enters **stasis**
   (`pauseDismissTimer()`), freezing countdown progress.
2. If the user cancels the drag (releasing before threshold or snapping back),
   the timer resumes smoothly (`resumeDismissTimer()`) from its exact remaining
   duration.
3. If the card commits to dismissal, the timer is safely ditched and disposed.
