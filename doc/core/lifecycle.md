# Notification Lifecycle

Understanding the lifecycle of a notification from payload intent to teardown is essential for debugging, customization, and event stream observation.

## The 5 Stages

### 1. Intent Dispatch (`controller.show(AppNotification(...))`)
- Application code or service dispatches an `AppNotification` payload.
- `NotificationController` validates channel and queue configurations via `ConfigurationManager`.
- Resolves target queue (via `targetPosition`, `channel.position`, or default).
- Emits `NotificationQueued` event on `controller.events`.

### 2. Queue Triage & Capacity Evaluation
- The notification is passed to the `QueueCoordinator`.
- Coordinator evaluates priority triage, preemption rules, and capacity limits (`maxStackSize`).
- If capacity is exceeded, lower-priority notifications are dropped, evicted, or parked according to queue policies (`QueueOverflowed` event emitted).

### 3. Mounting & Display
- `QueueCoordinator` ensures `OverlayPortalController` is attached via `NotificationScope`.
- Active `QueueWidget` mounts and renders the card into the spatial stack.
- The notification animates onto the screen using its configured entrance animation (`Slide`, `Scale`, `Fade`).

### 4. Active Interaction & Timer Countdown
- The card sits in the spatial stack.
- Users can interact with the notification (swipe dismiss, drag to reorder/relocate, expand deck, tap actions).
- **Auto-Dismiss Timer**: If `defaultDismissDuration` or notification-specific duration is specified, an internal countdown timer runs.
- **Timer Stasis & Drag Resilience**:
  - **Touch & Drag Stasis**: Initiating a swipe or drag interaction immediately suspends the auto-dismiss timer countdown (`pauseDismissTimer()`), freezing remaining duration.
  - **Cancel & Snap-Back Recovery**: If the drag is released before threshold without committing, the card snaps back to its slot and the timer cleanly resumes (`resumeDismissTimer()`) from its exact remaining duration.
  - **Bundled Deck Stasis**: Lifting the representative card reveals the peek card beneath in visual stasis (`opacity = 0.55`) with its timer frozen. Expanding a bundle (`pauseTimersWhenExpanded: true`) halts timers across all bundled cards.

### 5. Dismissal & Teardown (`NotificationDismissed`)
- **Trigger**: Timer completion, manual swipe, card tap, group purge, or programmatic `controller.dismiss(...)`.
- **Exit Modes**:
  - **In-Place Reverse Animation**: For programmatic dismissals, timeout completions, and tap-to-dismiss actions, the card executes its configured reverse transition (`Slide`, `Scale`, `Fade`).
  - **Ballistic Inertial Exit Flight (`EgressFlightOverlay`)**: For committed user swipe dismissals, the card smoothly detaches into an overlay flight portal, continuing its coasting trajectory off-screen at its exact finger release velocity. The source slot in the queue stack collapses immediately beneath it.
- **Teardown**: Notification state is removed from the active queue list and disposed.
- Emits `NotificationDismissed` event containing the exact `DismissReason` (`timeout`, `userSwipe`, `userTap`, `programmatic`, `evicted`).
- **Portal Cleanup**: When all queues become empty, `QueueCoordinator` detaches the `OverlayPortalController` to release system resources.
