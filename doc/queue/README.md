# Queue System (v0.5.0)

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

- **`Dismiss()`**: Standard directional swipe to dismiss.
- **`Reorder()`**: Drag up/down to reorder notifications within the stack.
- **`Relocate()`**: Drag notification cards across queue positions.
- **`ReorderAndRelocate()`**: Hybrid spatial drag supporting both in-queue reordering and cross-queue relocation.
- **`Disabled()`**: Non-interactive notification cards.

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
