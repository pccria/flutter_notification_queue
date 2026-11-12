# Queue System

The **Queue System** determines *where* notifications appear on the screen, *how* they stack, how overflow/capacity rules behave, and how gesture intents operate.

## `NotificationQueue`

A `NotificationQueue` is an immutable configuration value object that defines:
- **Position**: Spatial anchor on the screen (`QueuePosition`).
- **Drag Behavior**: Interaction intent (`Dismiss`, `Reorder`, `Relocate`, `ReorderAndRelocate`, `Disabled`).
- **Permanent Relocation**: Redirection target (`QueuePosition?`) routing all incoming and pending notifications to another queue.
- **Transition**: Entrance and exit animation strategy (`Slide`, `Scale`, `Fade`, `Custom`).
- **Close Button**: Visibility strategy (`AlwaysVisible`, `VisibleOnHover`, `Hidden`).
- **Style**: Visual layout template (`FilledQueueStyle`, `OutlinedQueueStyle`, `FlatQueueStyle`).
- **Grouping**: Deck aggregation rules (`QueueGroupingBehavior`).
- **Constraints**: Maximum stack size (`maxStackSize`), capacity strategy (`overflowStrategy`), margins, and spacing.

---

### `QueuePosition`

The `QueuePosition` enum defines 8 spatial anchor points on screen:
- **Corners**: `topLeft`, `topRight`, `bottomLeft`, `bottomRight`.
- **Centers**: `topCenter`, `bottomCenter`, `centerLeft`, `centerRight`.

---

## Permanent Queue Relocation

Queues can define a `permanentRelocation` destination. When configured, any notification targeting this queue—or waiting in its pending backlog—is automatically rerouted to the destination queue:

```dart
NotificationQueue(
  position: QueuePosition.topCenter,
  behavior: const QueueBehavior(
    permanentRelocation: QueuePosition.topRight,
  ),
);
```

> [!NOTE]
> Relocation is strictly a **Queue Behavior**. Channels do not configure relocation, ensuring domain logic remains independent of physical screen layout changes.

---

## Gesture & Interaction Behaviors

Queue behavior governs how users interact with notification cards in the stack:

- **`Dismiss()`**: Directional swipe to dismiss with customizable egress trajectories, physical tilt, and reveal underlays.
- **`Reorder()`**: Drag up/down to reorder notifications within the stack featuring gravity-well hysteresis.
- **`Relocate()`**: Drag notification cards across queue positions with live drop previews.
- **`ReorderAndRelocate()`**: Hybrid spatial drag supporting both in-queue reordering and cross-queue relocation past an escape threshold.
- **`Disabled()`**: Non-interactive notification cards.

---

### Dismiss & Directional Egress

The `Dismiss` behavior employs a **card-centric egress paradigm**. Rather than pulling cards toward arbitrary screen edges, swipe gestures operate relative to the card's resting slot and orientation within its queue anchor:

```dart
NotificationQueue(
  position: QueuePosition.topRight,
  dragBehavior: const Dismiss(
    egress: DismissEgress.horizontal(),
    dismissThreshold: 0.35,      // Commit after 35% displacement
    escapeVelocity: 550.0,       // Commit on flick >= 550 dp/s
    enableTilt: true,            // Dynamic angular tilt during drag
    showUnderlay: true,          // In-slot reveal underlay
    dismissColor: Color(0xFFEF4444),
    dismissIcon: Icons.delete_outline,
  ),
);
```

#### Egress Strategies (`DismissEgress`)

The sealed `DismissEgress` hierarchy defines allowable dismissal vector directions:

| Strategy | Description | Anchor-Specific Dynamics |
|---|---|---|
| `DismissEgress.horizontal({allowLeft, allowRight})` | Horizontal swipe off screen. | Can constrain to single side via `allowLeft: false` or `allowRight: false`. Defaults to bilateral swipe. |
| `DismissEgress.natural()` | Screen-outward exit direction based on queue position. | Right queues swipe right; left queues swipe left; horizontally centered queues permit bilateral swipe. |
| `DismissEgress.outward()` | Outward exit toward the closest screen boundary. | Top corners swipe top/lateral; bottom corners swipe bottom/lateral; center queues swipe toward nearest boundary. |
| `DismissEgress.cross()` | Inward exit across the viewport toward the center. | Right queues swipe left; left queues swipe right. |
| `DismissEgress.any()` | Omni-directional 2D swipe dismissal. | Freeform 360° translation vector commits in any direction. |

#### Dual-Threshold Commitment Mechanics
1. **Displacement Fraction (`dismissThreshold`)**: Card commits to dismissal when dragged past a fraction of its width (default `0.40`, or 40%).
2. **Ballistic Escape Velocity (`escapeVelocity`)**: Rapid flick gestures committing $\ge 600.0\text{ dp/s}$ in an allowable egress direction trigger immediate dismissal regardless of distance traveled.

#### Sensory Feedback & Exit Flight
- **Dynamic Angular Tilt (`enableTilt: true`)**: Applies subtle, organic card rotation proportional to horizontal displacement, producing a tactile physical feel.
- **In-Slot Reveal Underlay (`showUnderlay: true`)**: As the card displaces, the underlying slot reveals a tinted backdrop with `dismissIcon` and progress scaling.
- **Inertial Momentum Flight**: Upon release past threshold, the card detaches into an overlay flight portal (`EgressFlightOverlay`), coasting off-screen at its release velocity while the queue stack immediately collapses behind it.
- **Auto-Dismiss Timer Resilience**: Holding or dragging a notification card safely pauses its countdown timer. If the drag is cancelled (snapped back), the timer smoothly resumes from its exact remaining duration without dropping or resetting.

> [!NOTE]
> **Deprecation Notice**: The legacy screen-edge target parameter `Dismiss(zones: ...)` and `DismissZone` enum are deprecated in `v0.7.x` and will be removed in `v0.8.0`. Use `Dismiss(egress: ...)` instead.

---

## Notification Grouping / Bundling (`QueueGroupingBehavior`)

When multiple notifications target the same channel or group key, `QueueGroupingBehavior` aggregates them into visual card decks:

```dart
const NotificationQueue(
  position: QueuePosition.topRight,
  groupingBehavior: QueueGroupingBehavior(
    enabled: true,
    maxBeforeGrouping: 2,
    maxStackedLayers: 3,
    enableGroupSwipeDismiss: true,
    pauseTimersWhenExpanded: true,
    countBehavior: HiddenCount(
      maxCount: 99,
      prefix: '+',
    ),
  ),
)
```

### Key Capabilities
- **Representative Card**: Top card surfaces the newest message while displaying a group count indicator pill.
- **Configurable Count Strategies (`GroupCountBehavior`)**:
  - `HiddenCount` (Default): Shows `+N` indicating hidden notifications stacked behind the visible representative (e.g. `+2`).
  - `TotalCount`: Shows `N` representing the total items in the group (e.g. `3`).
  - `NoCount`: Renders a minimal indicator dot without numbers.
  - `CustomCount`: Custom label builder `(totalCount, hiddenCount) => String` for bespoke formats.
  - All strategies support `maxCount` overflow capping (e.g. `+99+`) and `includePending` to determine whether unrendered queue backlog items are counted.
- **Peek Card Timer Stasis & Drag Auto-Dismiss Pause**: Lifting or dragging the representative card reveals the peek card beneath in visual stasis (`opacity = 0.55`) and pauses its auto-dismiss timer. The dragged card's timer is also suspended, resuming cleanly on release or snap-back.
- **Expanded Group Timer Suspension**: When expanded via the toggle pill (`pauseTimersWhenExpanded: true`), auto-dismiss timers on all cards in the bundle pause indefinitely to allow reading.
- **Atomic Bundle Dismiss & Backlog Purging**: When swiping away a collapsed bundle or calling `controller.dismissGroup(groupKey)`, all active members and all pending backlog queue entries sharing the key are purged in a single atomic frame, preventing ghost promotions and allowing waiting notifications from other channels to surface immediately.

---

## Close Button Visibility (`QueueCloseButtonBehavior`)

The `closeButtonBehavior` property accepts a `QueueCloseButtonBehavior` strategy:

- **`AlwaysVisible()`** (Default): Close button is always rendered at 1.0 opacity.
- **`VisibleOnHover()`**: Adaptive behavior. Fully visible on hover; semi-transparent (0.3 opacity) on touch viewports for discoverability.
- **`Hidden()`**: Removes the visual close button.

> [!WARNING]
> **Safety Assertion**: If `Hidden()` close button is selected, the queue must have an interactive drag behavior enabled (e.g. `Dismiss()`) or auto-dismiss duration configured to prevent undismissable cards.

---

## Configuring Queues in `NotificationController`

Configure queues by passing a `Set<NotificationQueue>` to your `NotificationController`:

```dart
final controller = NotificationController(
  queues: {
    // 1. Filled Deck in Top Right
    const NotificationQueue(
      position: QueuePosition.topRight,
      maxStackSize: 5,
      spacing: 8.0,
      margin: EdgeInsets.all(16),
      style: FilledQueueStyle(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        elevation: 4.0,
      ),
      dragBehavior: ReorderAndRelocate(),
    ),
    
    // 2. Outlined Toast in Bottom Center
    const NotificationQueue(
      position: QueuePosition.bottomCenter,
      maxStackSize: 1,
      margin: EdgeInsets.all(24),
      style: OutlinedQueueStyle(),
      dragBehavior: Dismiss(),
    ),

    // 3. Relocated Top-Center (redirects to Top-Right)
    const NotificationQueue(
      position: QueuePosition.topCenter,
      permanentRelocation: QueuePosition.topRight,
    ),
  },
);
```
