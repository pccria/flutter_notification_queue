# Queue System

The **Queue System** determines *where* notifications appear on the screen,
*how* they stack, how capacity rules behave, and how gestures operate.

---

## 1. `NotificationQueue` Configuration

A `NotificationQueue` is an immutable configuration value object that defines:
- **Position**: Spatial anchor on the screen (`QueuePosition`).
- **Drag Behavior**: Interaction intent (`Dismiss`, `Reorder`, `Relocate`,
  `ReorderAndRelocate`, `Disabled`).
- **Permanent Relocation**: Redirection target (`QueuePosition?`) routing all
  incoming and pending notifications to another queue.
- **Transition**: Entrance and exit animation strategy (`Slide`, `Scale`,
  `Fade`, `Custom`).
- **Close Button**: Visibility strategy (`AlwaysVisible`, `VisibleOnHover`,
  `Hidden`).
- **Style**: Visual layout template (`FilledQueueStyle`, `OutlinedQueueStyle`,
  `FlatQueueStyle`).
- **Grouping**: Deck aggregation rules (`QueueGroupingBehavior`).
- **Constraints**: Maximum stack size (`maxStackSize`), capacity strategy
  (`overflowStrategy`), margins, and spacing.

---

### 1.1. `QueuePosition`

The `QueuePosition` enum defines 8 spatial anchor points on screen:
- **Corners**: `topLeft`, `topRight`, `bottomLeft`, `bottomRight`.
- **Centers**: `topCenter`, `bottomCenter`, `centerLeft`, `centerRight`.

---

## 2. Permanent Queue Relocation

Queues can define a `permanentRelocation` destination. When configured, any
notification targeting this queue—or waiting in its pending backlog—is
automatically rerouted to the destination queue:

```dart
NotificationQueue(
  position: QueuePosition.topCenter,
  permanentRelocation: QueuePosition.topRight,
);
```

> [!NOTE]
> Relocation is strictly a **Queue Behavior**. Channels do not configure
> relocation, ensuring domain logic remains independent of physical screen
> layout changes.

---

## 3. Gesture & Interaction Behaviors

Queue behavior governs how users interact with notification cards in the stack:

- **`Dismiss()`**: Directional swipe to dismiss with customizable egress
  trajectories, physical tilt, and reveal underlays.
- **`Reorder()`**: Drag up/down to reorder notifications within the stack
  featuring gravity-well hysteresis.
- **`Relocate.to()`**: Drag notification cards across queue positions with
  live drop previews.
- **`ReorderAndRelocate.to()`**: Hybrid spatial drag supporting both in-queue
  reordering and cross-queue relocation past an escape threshold.
- **`Disabled()`**: Non-interactive notification cards.

---

### 3.1. Dismiss & Directional Egress

The `Dismiss` behavior employs a **card-centric egress paradigm**. Rather than
pulling cards toward arbitrary screen edges, swipe gestures operate relative to
the card's resting slot and orientation within its queue anchor:

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
- `DismissEgress.horizontal({allowLeft = true, allowRight = true})`:
  Bilateral horizontal exit vector (left or right). Default egress policy.
- `DismissEgress.natural()`:
  Screen-outward exit direction based on queue position. Right queues swipe
  right; left queues swipe left; center queues permit bilateral swipe.
- `DismissEgress.outward()`:
  Outward exit toward the closest screen boundary.
- `DismissEgress.cross()`:
  Inward exit across the viewport toward the center.
- `DismissEgress.any()`:
  Omnidirectional 360-degree translation vector.

#### Dual-Threshold Commitment Mechanics
1. **Displacement Fraction (`dismissThreshold`)**: Card commits to dismissal
   when dragged past a fraction of its width (default `0.40`, or 40%).
2. **Ballistic Escape Velocity (`escapeVelocity`)**: Rapid flick gestures
   committing $\ge 600.0\text{ dp/s}$ in an allowable egress direction trigger
   immediate dismissal regardless of distance traveled.

#### Sensory Feedback & Exit Flight
- **Dynamic Angular Tilt (`enableTilt: true`)**: Applies subtle, organic card
  rotation proportional to horizontal displacement.
- **In-Slot Reveal Underlay (`showUnderlay: true`)**: As the card displaces,
  the underlying slot reveals a tinted backdrop with `dismissIcon`.
- **Inertial Momentum Flight**: Upon release past threshold, the card detaches
  into an overlay flight portal (`EgressFlightOverlay`), coasting off-screen at
  its release velocity while the queue stack collapses immediately beneath it.

---

## 4. Queue Stasis & `NotificationTimerScope`

Interactions suspend time. To prevent notifications from disappearing during
user interactions, FNQ injects `NotificationTimerScope` at the queue boundary:

- **Reorder Stasis**: Dragging a card to reorder freezes timers across
  all cards in that queue.
- **Relocation Stasis**: Dragging a card across queues freezes timers in
  both the home queue and the target queue simultaneously.
- **Programmatic Queue Stasis**: Applications can freeze an entire queue via:
  ```dart
  controller.pauseQueue(QueuePosition.topRight);
  controller.resumeQueue(QueuePosition.topRight);
  ```
- **Snap-Back Duration Preservation**: Releasing an uncommitted card snaps it
  back to its slot and resumes countdowns from the exact remaining millisecond
  duration.

---

## 5. Notification Grouping / Bundling (`QueueGroupingBehavior`)

When multiple notifications target the same channel or group key,
`QueueGroupingBehavior` aggregates them into visual card decks:

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
);
```

### Key Capabilities
- **Representative Card**: Top card surfaces newest message while displaying a
  group count indicator pill.
- **Configurable Count Strategies (`GroupCountBehavior`)**:
  - `HiddenCount`: Shows `+N` indicating hidden notifications stacked behind
    the visible representative (e.g. `+2`).
  - `TotalCount`: Shows `N` representing total items in the group (e.g. `3`).
  - `NoCount`: Renders a minimal indicator dot without numbers.
  - `CustomCount`: Custom label builder `(total, hidden) => String`.
- **Expanded Group Timer Suspension**: When expanded via the toggle pill
  (`pauseTimersWhenExpanded: true`), auto-dismiss timers on all cards in the
  bundle pause indefinitely to allow reading.
- **Atomic Bundle Dismiss**: Swiping away a collapsed bundle or calling
  `controller.dismissGroup(groupKey)` purges all active members and backlog
  entries in a single atomic frame.

---

## 6. Close Button Visibility (`QueueCloseButtonBehavior`)

The `closeButtonBehavior` property accepts a `QueueCloseButtonBehavior`:
- **`AlwaysVisible()`** (Default): Close button is rendered at 1.0 opacity.
- **`VisibleOnHover()`**: Fully visible on hover; semi-transparent (0.3 opacity)
  on touch viewports.
- **`Hidden()`**: Removes the visual close button.

> [!WARNING]
> If `Hidden()` close button is selected, the queue must have an interactive
> drag behavior (e.g. `Dismiss()`) or auto-dismiss duration configured.
