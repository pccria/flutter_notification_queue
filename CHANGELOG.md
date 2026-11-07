# Changelog

## [0.6.0-dev]

### Architecture & Sub-Library Decomposition (Track 3 Phase 2)
- **Monolith Decomposition (`A-01`)**:
  - Decomposed the 26-part `notification.dart` monolith into dedicated,
    cohesive sub-libraries:
    - `interaction/zones/`: self-contained spatial drop zones (`DropZone`,
      `EdgeDropZone`, `PositionDropZone`, `SlotDropZone`, and resolvers).
    - `interaction/overlays/`: visual target overlays (`DismissalTargets`,
      `IntentTargets`, `RelocationTargets`, `ReorderTargets`).
    - `interaction/widgets/`: draggable transitions and feedback overlays
      (`DraggableTransitions`, `feedback_overlays.dart`).
    - `interaction/plugins/`: interaction behavior plugins (`plugins.dart`,
      `DismissGesturePlugin`, `RelocateGesturePlugin`, `ReorderGesturePlugin`,
      `ReorderRelocateGesturePlugin`, `SnoozeGesturePlugin`, `PinGesturePlugin`,
      `CustomActionGesturePlugin`, and resolvers).
    - `interaction/gesture_state_machine.dart`: standalone FSM tracking drag
      lifecycles.
    - `interaction/drag_gesture_context.dart` & `drag_start_data.dart`:
      decoupled drag context and metadata interfaces.
  - Exported interaction plugins cleanly through
    `lib/src/notification/plugins.dart`.
- **Theming System Decoupling (`A-02`)**:
  - Extracted `NotificationTheme` from `part of 'notification.dart'` into a
    standalone library under `lib/src/notification/theme/`.
  - Introduced `NotificationThemeTarget` interface to resolve themes without
    tight coupling to concrete widget implementations.
- **Unified Coordinator Resolution (`A-03`)**:
  - Introduced `CoordinatorResolver` mixin in
    `lib/src/core/coordinator_resolver.dart`.
  - Replaced repetitive coordinator lookup logic across
    `NotificationWidgetState`, `DraggableTransitionsState`, `QueueWidgetState`,
    and `_NotificationOverlayState`.
  - Enforced consistent precedence hierarchy: explicit widget override ->
    ambient `NotificationScope` in widget tree -> descriptive `StateError`.
- **Configuration Encapsulation & Immutability (`A-04`)**:
  - Encapsulated internal state of `ConfigurationManager` by converting
    `queues`, `channels`, `strictChannelLookup`, `maxHistoryEntries`, and
    `a11yOptions` to private fields exposed via read-only getters.
  - Wrapped `queues` and `channels` collections in `Set.unmodifiable` on both
    initialization and dynamic `reconfigure` calls, guaranteeing external
    immutability.
- **Polymorphic Event Notification Accessor (`A-05`)**:
  - Added polymorphic `NotificationWidget? get notification => null;` accessor
    on sealed `NotificationEvent` base class.
  - Subclasses carrying a notification target implement `@override
    NotificationWidget get notification;` (`NotificationQueued`,
    `NotificationUpdated`, `NotificationDismissed`, `NotificationTapped`,
    `NotificationRelocated`, `NotificationReordered`, `NotificationSnoozed`,
    `NotificationPinned`, `NotificationUnpinned`, and
    `NotificationCustomActionTriggered`).
  - Simplified `HistoryLogger` event filtering logic by eliminating verbose
    type-checking cascades.
- **Instance-Scoped ID Generator (`A-06`)**:
  - Replaced global static mutable counter `_idCounter` on `NotificationWidget`
    with `NotificationIdGenerator`.
  - Scoped sequence generation to coordinator, configuration, and controller
    instances to eliminate cross-test state leakage and test ordering flakiness.
  - Exported `NotificationIdGenerator` allowing custom seed configuration and
    predictable monotonic sequencing.

### Desktop & Platform Perfection (Track 4)
- **Desktop Context Menu Support (`F-07`)**:
  - Secondary-tap (right-click on desktop/web) opens a rich native context menu
    on notification cards.
  - Keyboard accessible via `Shift + F10` or dedicated `contextMenu` key when a
    notification card holds focus.
  - Built-in default menu entries: **Pin / Unpin**, **Snooze**, **Copy Message**
    (copies notification message to platform clipboard), **Action** (calls
    `action.onPressed()`), and **Dismiss**.
  - Opening the context menu pauses card auto-dismiss progress timers; closing
    resumes the timer smoothly.
  - Fully customizable via `NotificationContextMenuBuilder` on
    `AppNotification.contextMenuBuilder` and toggleable via
    `NotificationA11yOptions.enableContextMenu`.
  - Added seamless `Overlay` fallback for applications mounting
    `NotificationScope` inside `MaterialApp.builder` where no `Navigator`
    ancestor exists, preventing route crashes on right-click and `Shift + F10`.
  - Disabled default browser context menu on Flutter Web when hovering over
    notification cards or while the context menu is open, ensuring right-click
    delivers directly to the notification context menu.
  - Guaranteed auto-dismiss timer stops completely while context menu is open,
    preventing timer ticks and timeout dismissals when moving mouse pointer
    off card to select menu items.
  - Implemented reference-counted `WebContextMenuController` on
    `QueueCoordinator` to prevent premature re-enabling of the native browser
    context menu on Flutter Web when moving between notification cards, across
    queue gaps, or transitioning between context menus.
  - Eliminated pointer-blocking overlay barrier in `_openContextMenuViaOverlay`,
    allowing right-clicking a second notification card to dismiss the first
    context menu and immediately open the second card's menu in a single click
    without swallowing the gesture or triggering the browser context menu.
  - Deferred browser context menu re-enabling via event-loop microturn on
    dismissal to protect against accidental browser context menu popups from
    in-flight dismissing clicks.
- **L-Shaped Unified Corner Bars (`F-08`)**:
  - Automatically unifies orthogonal drop zones (`Top + Left`, `Top + Right`,
    `Bottom + Left`, `Bottom + Right`) for corner queues
    (`QueuePosition.topLeft`, `topRight`, `bottomLeft`, `bottomRight`).
  - Eliminates overlapping double-backdrop filters, dark artifact seams, and
    duplicate close icons.
  - Renders a seamless continuous L-shaped corner dismissal target with a single
    pulsing idle handle when idle, a unified `ClipPath` with radial gradient
    during drag engagement, and a single apex `Icons.close_rounded` icon at the
    corner junction.


### Architecture & API Surface Hardening (Track 3 Phase 1)
- **Breaking Changes - Deprecated v0.5.0 Fields Removed (`AppNotification`)**:
  - Removed `position` parameter (route queue positions via
    `NotificationChannel.position` or `controller.show(..., targetPosition:)`).
  - Removed `dragBehavior` and `longPressDragBehavior` per-notification gesture
    overrides (configure viewport-wide gesture physics on `NotificationQueue`).
  - Removed scalar color properties `color`, `foregroundColor`, and
    `backgroundColor` (use `accentColor` for content accents or
    `NotificationChannel.theme` / `NotificationThemeData` for tokens).
  - Removed `initialIsPinned` (use `permanent: true` or `controller.pin(id)`).
  - Removed internal runtime state `snoozedAt` from public constructor.
- **Public Export Surface Sealing (`flutter_notification_queue.dart`)**:
  - Internal rendering widgets (`NotificationWidget`, `NotificationWidgetState`,
    `NotificationTimerScope`) are now marked `@internal` and hidden from the
    public export.
  - Internal interaction overlays, gesture state machines, and plugins
    (`DismissGesturePlugin`, `RelocateGesturePlugin`, `ReorderTargets`,
    `GestureStateMachine`, etc.) are hidden to prevent namespace pollution.
  - Public library export is now strictly sealed to core payload contracts
    (`AppNotification`, `NotificationAction`), theming (`NotificationThemeData`,
    `NotificationTheme`), queue configuration (`NotificationQueue`,
    `NotificationChannel`), dispatch controllers (`NotificationController`,
    `NotificationScope`, `NotificationHandle`), and lifecycle events.

### Accessibility (WCAG 2.1 AA) & Keyboard Traversal (Track 2 / F-06)
- **Screen Reader Live Regions**: Real-time vocal announcements via
  `SemanticsService.sendAnnouncement` scoped to the platform view. Polite
  announcements for `normal`/`low`/`high` priorities and assertive alerts for
  `critical` priority notifications, configurable via
  `announcePriorityThreshold` and `enableLiveRegions`.
- **Non-Intrusive Focus Ingestion**: Removed automated focus stealing when new
  notifications enter the stack. Text input cursor and user interaction in the
  host application remain uninterrupted.
- **Reversible Keyboard Focus Handoff (`Alt + N` / `⌥N`)**: Quick shortcut
  handoff transfers focus to the active notification stack without touching
  pointer devices. Upon stack exit or dismissal of the final card, previous host
  app focus is restored automatically.
- **Card Keyboard Navigation & Semantics**: Individual notification cards expose
  container semantics with detailed hints. Added keyboard shortcuts when a card
  has focus:
  - `Enter`: Triggers primary action (`widget.action.onPressed()`) if defined,
    or triggers card tap behavior (`_resolvedTapBehavior`).
  - `Space`: Reserved for focused inner controls (action button, close button,
    expand toggle) reached via `Tab` cycling.
  - `E`: Toggles card body expansion between collapsed and preview lines.
  - `P`: Toggles pin/unpin status, canceling or re-initiating auto-dismiss.
  - `S`: Snoozes notification for its default or configured duration.
  - `Shift + Delete` / `Shift + Backspace`: Dismisses the active bundle group.
  - `Delete` / `Backspace` / `Escape`: Dismisses the single focused card.
  - `ArrowDown` / `ArrowUp`: Navigates between cards in the active queue.
  - Exposes `CustomSemanticsAction` for 'Dismiss', 'Expand', 'Pin', 'Snooze',
    and custom action buttons for assistive technologies.
- **Group Toggle Pill Accessibility**: Toggle pills expose `Semantics` button
  roles, dynamic state labels (`Grouped notifications` /
  `Collapse notification group`), and keyboard toggle activation using `Enter`
  or `Space`.
- **Global Configuration (`NotificationA11yOptions`)**: Fully customizable
  keyboard shortcuts (`focusShortcut`), dismissal keys (`dismissKey`), and
  accessibility behaviors provided on `NotificationController` and
  `NotificationScope`.

### Live Updates, Async Promises & Notification Handles (Track 1)
- **Notification Handles (`NotificationHandle`)**: `NotificationController.show`
  now returns a lightweight `NotificationHandle` representing the lifecycle of
  the dispatched notification. Exposes `.dismiss()`, `.update()`,
  `.updateWith()`, `.pin()`, `.unpin()`, `.snooze()`, and `.relocate()`
  for fluent programmatic control without retaining raw notification IDs.
- **In-Place Updates**: Added `NotificationController.update` and
  `updateWith` (along with coordinator and queue widget internals) enabling
  zero-flicker in-place updates of active and pending notifications. Mutates
  content and styles in place without re-triggering entrance transitions.
- **Async/Promise Toasts (`showAsync`)**: Introduced `showAsync<T>` and
  `tryShowAsync<T>` on `NotificationController` to seamlessly bind notifications
  to the lifecycle of asynchronous operations (e.g. uploads, network calls).
  Displays sticky loading states while pending, smoothly transitioning into
  auto-dismissing success or failure toasts upon resolution/rejection.
- **Event Stream Expansion (`NotificationUpdated`)**: Added sealed event
  `NotificationUpdated` carrying `notification` and `oldNotification` snapshots
  emitted on every in-place update.
- **Zero-Boilerplate Controller**: `NotificationController` constructor now
  defaults `queues` to `{const NotificationQueue()}`, eliminating mandatory
  queue configuration for standard single-queue applications.

### Bundled Notifications & Viewport Engine
- **Slot-Based Viewport Engine**: Collapsed notification bundles occupy exactly
  1 visual slot regardless of internal member count, unblocking concurrent
  queue admission for secondary channels and eliminating the Group Starvation
  Paradox.
- **Group Focus / Stash Mode**: Expanding a notification group activates Focus
  Mode, stashing sibling queue blocks from the render tree to strictly uphold
  the Mobile Viewport Height Contract (`renderedCards <= maxStackSize`). Sibling
  blocks restore seamlessly upon bundle collapse.
- **Timer Decoupling (Breaking Change)**: Removed `pauseTimersWhenExpanded`
  parameter; expanding a bundle no longer artificially freezes individual
  notification auto-dismiss timers. Expired items dismiss naturally, and empty
  groups collapse smoothly.
- **Group Count Defaults & Formatting**: Configured `maxCount` to default to 9
  (previously 99) in `HiddenCount` and format overflow values as `9+` (e.g.,
  `+9+`), keeping bundle pills compact on constrained mobile viewports.

### Performance & Memory Hygiene
- **O(1) Backlog Registry**: Added `_pendingById` registry in `QueueWidgetState`
  for instant $O(1)$ pending notification lookups and deduplication, eliminating
  redundant double-sorting and temporary queue drains on enqueue.
- **O(1) Coordinator Resolution**: Optimized `QueueCoordinator` lookups via
  direct positional targeting, eliminating linear queue traversals.
- **Eviction Integrity**: Fixed priority eviction unregistration to preserve
  position tracking when cards are re-queued into pending backlogs.
- **Timer Allocation Reduction**: Pre-computed group item filters in
  `_syncGroupTimers` to prevent repeated allocations in tight loops.

### Studio (Example App)
- **Shortcut Deduplication**: Eliminated duplicate firing on `Ctrl+Enter` /
  `⌘Enter` in Studio when text fields are actively focused.
- **Live Update Event Support**: Added `NotificationUpdated` pattern handling
  to Studio Event Log panels.

### Test Suite
- **Track 1 Test Coverage**: Added comprehensive test suites in
  `test/interaction/live_updates_test.dart` and
  `test/src/core/notification_controller_test.dart` validating handle methods,
  in-place active/pending updates, `showAsync` future lifecycles, and
  `NotificationUpdated` events.
- **Slot & Focus Mode Test Matrix**: Added automated test coverage in
  `test/interaction/grouping_test.dart` validating multi-channel concurrent
  slot admission, sibling block stashing in Focus Mode, and natural timer
  expiry within expanded bundles.

## [0.5.2] - 2026-11-05

### Bundled Notifications & Grouping UX
- **Configurable Group Count API (`GroupCountBehavior`)**: Introduced a sealed class hierarchy to customize bundle size counting and formatting:
  - `TotalCount`: Displays the total number of notifications in the bundle (e.g. `3`).
  - `HiddenCount`: Displays the count of hidden notifications behind the visible representative card in `+N` format (e.g. `+2`), with an optional `showPlusSign: false` toggle. Default strategy across all queues.
  - `NoCount`: Renders a clean indicator dot without numerical counts.
  - `CustomCount`: Provides complete control via custom label builder `(totalCount, hiddenCount) => String`.
  - Configurable via `QueueGroupingBehavior(countBehavior: ...)`.
- **Peek Card Timer Stasis & Drag Auto-Dismiss Pause**: When the representative notification card of a collapsed bundle is lifted or dragged to expose the peek card beneath, the peek card enters visual stasis (`opacity = 0.55`) and its auto-dismiss timer is explicitly paused. The dragged representative card's timer is also paused to prevent cards vanishing during active touch interaction. Timers resume smoothly upon release/snap-back.
- **Expanded Group Timer Suspension**: Pauses auto-dismiss timers on all cards within a group while expanded in multi-card view (`pauseTimersWhenExpanded: true`), preventing cards from disappearing while reading.
- **Atomic Bundle Dismiss & Backlog Purging**: Swiping away a collapsed bundle (or invoking `controller.dismissGroup(groupKey)`) atomically dismisses all active members and purges all pending backlog notifications sharing that `groupKey` in a single frame. Dispatches individual `NotificationDismissed` events with appropriate dismissal reasons, prevents ghost promotions of dismissed items, and immediately promotes waiting notifications from other channels.

### Performance & Memory Hygiene
- **CurvedAnimation Ticker Leak Prevention**: Disposed intermediate `CurvedAnimation` ticker listeners cleanly in `DraggableTransitionsState` and `QueueGroupWidget` across drag snap-back and bundle collapse lifecycles.
- **Same-ID Cross-Queue Relocation Safety**: Hardened `QueueCoordinator` against `Duplicate GlobalKey` collisions when re-dispatching active or pending notification IDs across different queues, automatically purging previous queue entries before re-insertion.
- **Coordinator Mapping Integrity**: Guaranteed cleanup of `_positionById` tracking entries upon discard, overflow eviction, and dismissal, preventing unbounded memory growth under heavy notification load.
- **Reorder 120Hz Smoothness**: Optimized drag-reorder slot calculations with memoized layout snapshots, avoiding unneeded `setState` cascades and sibling card repaints during reordering gestures.

### Studio (Example App)
- **Interactive Group Count Selector**: Added real-time count strategy selector (`HiddenCount`, `TotalCount`, `NoCount`) to the Studio Configurator with live Dart code generation.
- **Interactive Scenarios**: Added dedicated grouping demo scenarios showcasing peek stasis, count strategies, and atomic whole-bundle swipe dismissals.
- **Header & Version Dialog Modernization**: Updated the top navigation version badge and Project Info modal to dynamically bind to `NotificationController.version`.

### Test Suite & CI
- **Expanded Interaction Test Coverage**: Added comprehensive interaction tests covering peek timer stasis, drag release snap-back, count formatting, atomic backlog purging, and multi-channel promotion on group dismissal.
- **Version Synchronization Test**: Added automated test ensuring `NotificationController.version` strictly matches `pubspec.yaml`.

## [0.5.1] - 2026-10-27

### Maintenance
- **Account Migration**: Updated repository, homepage, issue tracker, documentation, demo URL, and sponsorship links to reflect account migration to `pccria`.

## [0.5.0] - 2026-10-14

### Architectural Governance & Design System
- **Permanent Queue Relocation**: Added `permanentRelocation: QueuePosition?` to `QueueBehavior` and `NotificationQueue`. All incoming notifications and pending backlog items are automatically routed to the destination queue. Decoupled relocation strictly to the queue layer (channels have zero relocation logic).
- **The Four Architectural Tiers**: Formalized the separation between Surface Owner (`NotificationScope`), Spatial Anchor (`NotificationQueue`), Domain Routing (`NotificationChannel`), and Event Payload (`AppNotification`).
- **`QueueStyle` Strict Single Ownership**: `QueueStyle` (`FilledQueueStyle`, `OutlinedQueueStyle`, `FlatQueueStyle`) lives strictly on `NotificationQueue` to govern physical card geometry (`borderRadius`, `padding`, `elevation`, `opacity` for glassmorphism). Neither channels nor payloads take styling archetypes.
- **Parametric Theme Token System (`NotificationThemeData`)**: Introduced unified, dark-mode reactive `NotificationThemeData` driven parametrically by `color` and Material 3 design tokens, deterministically controlling archetype role distribution with automatic WCAG contrast.
- **Standardized Box Model Spacing**: Standardized `margin` (safe-area boundary spacing), `spacing` (inter-card gap in stacks), and `padding` (intra-card content insets).
- **Contextual Dispatch-Time Routing (`targetPosition`)**: Added `targetPosition` parameter to `NotificationController.show()`, `controller.tryShow()`, and `QueueCoordinator.show()`, enabling callers to specify placement contextually without hardcoding coordinates on data payloads.
- **Removal of Archiving**: Removed phantom `Archive<T>` drag intent and plugin. Use `Dismiss` or listen to `NotificationDismissed` / `HistoryLogger`.
- **Payload Deprecation Window (v0.5.x → v0.6.0)**: Marked `AppNotification.position`, `dragBehavior`, `longPressDragBehavior`, `initialIsPinned`, `snoozedAt`, and loose scalar colors as `@Deprecated` with non-breaking fallbacks.
- **Multi-Window Layout Modernization**: Migrated `_QueueOverlayLayoutDelegate` from `PlatformDispatcher.instance.implicitView` to context-aware `View.maybeOf(context)`, future-proofing for multi-window Flutter.
- **Experimental Drag Intents**: Annotated `Pin<T>`, `Snooze<T>`, and `CustomAction<T>` with `@experimental`.

### Studio & Observability (Example App)
- **Live In-Place Draft Card Preview (`LiveCardPreview`)**: Real-time presentational sandbox resolving the 3-gear theme cascade with zero dismiss timers or queue side-effects, featuring an optical checkerboard canvas to highlight glassmorphic transparency.
- **Live Spatial Stage Radar (`LiveStageRadar`)**: 3×3 spatial radar monitoring active counts, pending counts, and permanent relocations across all 8 queue positions with instant stage controls (`Dismiss Newest`, `Dismiss All`).
- **Global Hardware Keyboard Shortcuts**: Bound `Ctrl+Enter` (`⌘Enter`) to fire preview drafts, `Ctrl+E` to reset drafts, and `Ctrl+L` to load random drafts, operating cleanly even when input fields are focused.
- **Top Cockpit & Single Source of Truth**: Consolidated notification firing into the Top Cockpit, eliminating duplicate fire buttons from inner sub-tabs.
- **Adaptive Multi-Column Dashboard & Resizable Panes**: Added 3-column resizable layout with drag dividers, collapsible sidebars, bounded aesthetic proportions, and an adaptive 660px 2-pane threshold for narrow screens.
- **Queue & Channel Geometry Editors**: Integrated live radius, elevation, padding, opacity, and margin controls directly into the configurator with real-time code generation.
- **Snooze & Pin Studio Integration**: Added interactive configurator controls, live preview actions, and dedicated demo scenarios for Snooze duration and Pin toggling.
- **Multi-Platform Toolchain**: Modernized Gradle build configuration and added unified multi-platform launcher script (`example/scripts/run.sh`).

### Stability & Resource Hardening
- **Snooze Timer Lifecycle & Leak Protection**: Added active timer registry (`_snoozeTimers`) to `QueueCoordinator`. All pending snooze timers are automatically cancelled upon coordinator detach or disposal, and callbacks guard against invoking actions on disposed instances.
- **Idempotent Lifecycle Disposal**: Added `_isDisposed` guards and public `isDisposed` getters to both `NotificationController` and `QueueCoordinator`, eliminating double-dispose exceptions when controllers and widget scopes unmount in varying orders.
- **Chained `FlutterError.onError` Handler**: Replaced destructive `FlutterError.onError` reassignment in `NotificationController` with non-destructive handler chaining, preserving integration with crash reporters (Sentry, Firebase Crashlytics) and Flutter defaults.
- **Single Source of Truth for `isPinned`**: Linked `NotificationEntry` directly to the blueprint's `isPinnedNotifier`, and refactored `pinWidget` and `unpinWidget` in `QueueCoordinator` to mutate pinned state directly through the notifier.
- **Robust Detach & Disposal Logging**: Replaced empty `on Object catch (_) {}` exception swallowing in `QueueCoordinator` with contextual debug logging.

### Test Suite & Visual Regression Hardening
- **Tolerant Golden File Comparator**: Added `_TolerantGoldenComparator` with a 0.5% diff tolerance threshold to `visual_regression_test.dart` to prevent platform-specific sub-pixel anti-aliasing false positives in CI environments.
- **Queue Relocation & Backlog Migration Tests**: Added test coverage validating queue-level permanent relocation, cluster invariance, and automatic migration of pending/waiting notifications.
- **Studio Widget & Adaptability Tests**: Added 22 widget tests covering multi-column adaptability, resizable panes, and hardware keyboard shortcuts.
- **Lifecycle & Chaining Unit Tests**: Added unit tests covering `NotificationController` and `QueueCoordinator` disposal idempotency, snooze timer cancellation on detach/dispose, and `FlutterError.onError` preservation.

### Documentation & Guides
- **v0.5.0 Migration Guide**: Published [`doc/migration_v0_5.md`](doc/migration_v0_5.md) detailing the four architectural tiers, breaking changes, permanent queue relocation, and deprecation roadmap.
- **Module Documentation Updates**: Completely modernized [`doc/queue/styles.md`](doc/queue/styles.md), [`doc/queue/README.md`](doc/queue/README.md), and [`doc/channel/README.md`](doc/channel/README.md) for v0.5.0 conventions.
- **NFQ Studio Guide**: Overhauled [`example/README.md`](example/README.md) with comprehensive feature guides, keyboard shortcuts, and local platform run instructions.

## [0.4.1] - 2026-09-12

### Studio & Web Deployment
- **Web Release Display Fix**: Fixed an issue in the Studio web app where configurator options and generated code snippets displayed minified type names in web release builds.

## [0.4.0] - 2026-08-30

### Breaking API Changes (Deprecated Surface Removal)
- **Removed Legacy Static Singleton Facade**: Removed `FlutterNotificationQueue` static facade. `NotificationController` and `NotificationScope` are now the canonical API for all notification queue management.
- **Removed `FnqEvent` Typedef**: Standardized on `sealed class NotificationEvent` for all lifecycle event subscriptions.
- **Removed Legacy Action Factory**: Removed `@Deprecated factory NotificationAction.onTap`. Use `NotificationAction.button` or gesture intents (`TapBehavior`, `DragBehavior`) instead.
- **Removed `NotificationWidget.show()`**: Notifications are dispatched as `AppNotification` payloads via `controller.show(...)` or `NotificationScope.of(context).show(...)`.

## [0.3.2] - 2026-08-26

### Studio Application & Web Deployment
- **GitHub Pages CI/CD Workflow**: Added automated GitHub Actions workflow (`deploy_pages.yml`) to compile and deploy the NFQ Studio web app (`example/`) to GitHub Pages on version tag pushes (`v*`).
- **Interactive Web Demo Link**: Integrated a prominent `img.shields.io` for-the-badge demo button in `README.md` directing users to the hosted NFQ Studio live web app.
- **Mobile Floating Action Button (FAB)**: Added a scroll-responsive floating action button in NFQ Studio for narrow screen viewports, enabling instant notification preview triggers on mobile devices.

## [0.3.1] - 2026-08-14

### Memory Teardown & Resource Hardening
- **Automated Timer Teardown**: Added `ditchAllDismissTimers()` to `QueueWidgetState` and integrated it into `QueueCoordinator.dispose()` to ensure active tickers and auto-dismiss timers across all registered queues stop immediately on coordinator/controller disposal.
- **Animation Ticker Teardown**: Prevented active `_snapBackController` animation leaks in `DraggableTransitionsState` and invoked `ditchDismissTimer()` prior to disposing `NotificationWidgetState`.
- **OverlayPortal Controller Teardown**: Ensured `OverlayPortalController` and scope bindings detach cleanly on widget unmounting.

### Test Suite Hardening
- **Multi-Tenant Scope Verification**: Added unit and widget test suite in `notification_scope_test.dart` covering multi-tenant subtree isolation, scope nesting overrides, unmount detachment, and graceful timer teardown.

## [0.3.0] - 2026-08-14

### Architectural Evolution (v1.0 Preparation)
- **`NotificationController` Facade**: Introduced an explicit `NotificationController` to own configuration (`queues`, `channels`), active state, event streams, and history logging. Replaces global static state with clean dependency injection.
- **`NotificationScope` Integration**: Introduced `NotificationScope` (`StatefulWidget` & `InheritedWidget`) to provide scoped access to `NotificationController` via `NotificationScope.of(context)`.
- **`AppNotification` Intent Payload**: Separated data payload from widget rendering state. Applications dispatch immutable `AppNotification` payloads via `controller.show(AppNotification(...))`.
- **Expanded Controller Surface**: Added `show`, `tryShow`, `dismiss`, `dismissAll`, `dismissNewest`, `dismissGroup`, `relocate`, `reorder`, `snooze`, `pin`, `unpin`, `getHistory`, `clearHistory`, and `events` directly to `NotificationController`.
- **Sealed Event Hierarchy**: Renamed `FnqEvent` base class to `NotificationEvent` (`typedef FnqEvent = NotificationEvent` provided for backward compatibility).
- **Deprecation Path**: Marked `FlutterNotificationQueue`, `NotificationWidget.show()`, and direct `NotificationWidget` instantiation as `@Deprecated`. See `doc/migration_v0_4.md` for complete migration guidance.

### Bug Fixes & Stability
- **Reorder & Relocate Null Safety**: Resolved unexpected `null` value errors and unmounted state crashes during card reordering and relocation interactions.
- **Context-Aware Scope Resolution**: Implemented a 3-tier coordinator lookup hierarchy (`explicit -> NotificationScope.maybeCoordinatorOf(context) -> FlutterNotificationQueue.coordinator`) across UI overlay, queue widgets, and draggable transitions, preventing scoped `NotificationController` instances from defaulting to global static singletons.
- **Blueprint Coordinator Preservation**: Preserved `coordinator` references across `copyToQueue` (relocation) and `copyForRequeue` (snooze) blueprint copies.
- **Unmounted Timer Prevention**: Prevented calling `initDismissTimer()` on unmounting notification states after successful relocation.

### Documentation & Tooling
- **Migration Guide**: Added comprehensive migration documentation in `doc/migration_v0_4.md`.
- **Studio Application**: Refactored `example/` Studio app to showcase `NotificationController` and `NotificationScope` patterns.

## [0.2.0] - 2026-07-19

### Consolidated API & Subclass Removal
- **Simplified NotificationQueue:** Removed all 8 specialized subclasses (`TopLeftQueue`, etc.) in favor of a single, highly configurable concrete `NotificationQueue` class with a `const` constructor.
- **QueuePosition Helpers:** Simplified `generateQueue()` on `QueuePosition` to directly build `NotificationQueue` instances, removing duplicate subclass-generation switch blocks.

### Internal State Decoupling
- **Introduced NotificationEntry:** Decoupled `NotificationWidget` configuration blueprint from active runtime state (dismiss timers, pinned lifecycle, resolved priority) by introducing the internal `NotificationEntry` wrapper class.
- **QueueCoordinator & Layout State:** Refactored state-storage maps and animation list managers to use `NotificationEntry`, preventing potential `GlobalKey` conflicts.

## [0.1.0] - 2026-07-10

### Initial Public Preview Baseline

All features from early pre-releases (`0.4.0` - `0.7.0`) consolidated into a single unified public baseline.

#### Interaction Engine (Physics & Reordering)
- **Reorder Behavior:** Users can pick up notifications and seamlessly rearrange them within their queue, empowering sophisticated inbox management.
- **Overlap Mechanics:** Replaced legacy gap-based targeting with a deeply physical "Overlap Target" model. The engine dynamically calculates the 2D bounding `Rect` of every active notification on the fly to yield precise target indices.
- **Perfect Deadband Hysteresis:** Implemented a "Gravity Well" (Target-Centric State) algorithm. The active drop zone applies a persistent 40-pixel magnetic lock to its own hit-test calculations, generating a flawless 80-pixel optical deadband that is 100% immune to pointer jitter, velocity spikes, and physical hand vibrations.
- **Premium Bounding Reticles:** Replaced the destructive horizontal center-line drop indicator with a Selection Reticle. Hovering over a card instantly frames its exterior in a glowing border while subtly darkening the interior (Recess Effect).
- **Self-Target Suppression:** The physics engine natively understands "cancel" drags. Hovering a payload over its own original starting slot visually suppresses all target feedback, rendering an empty placeholder hole so the user can comfortably drop the card back to safely abort.
- **Smooth Height & Spring Snapbacks:** Added dynamic height transitions when notifications expand or collapse, and physical spring snapback physics for aborted cancel drags.
- **Visual Grab Cursors:** Added grab and grabbing cursor states on draggable cards to improve desktop UX.

#### Layout, Grouping & Customization
- **Notification Grouping & Bundling:** Introduced dynamic stack configuration parameters (custom layer count, offsets, scales), recursive-safe swipe dismissals with reason propagation, and non-overlapping indicators with direction-aware tap-to-expand.
- **Visual Boundaries:** Added per-queue `maxWidth` constraints and layout collision delegate resolution.
- **Adaptive Close Button:** Opacity-based model (`0.0`–`1.0`) with subtle presence for touch devices (starts at `0.3` opacity for discoverability) and progressive enhancement (hidden until hover on desktop).
- **Hover-to-Pause Dismissal:** Hovering over a notification card pauses its auto-dismiss timer, which resumes smoothly when the pointer leaves.

#### Core API & Observability
- **Permanent Queue Relocation:** Introduced runtime queue relocation via `Relocate.to(..., permanent: true)` where dragging a card permanently redirects future queue traffic and migrates active cards together.
- **Event History Log:** Added an in-memory, LIFO bounded ring buffer (`maxHistoryEntries`) to capture notification events. Added `getHistory()` for querying with filters (channelName, dismissReason, since, limit) and `clearHistory()` for cache management.
- **Zero-overhead Disabling:** When disabled (`maxHistoryEntries` is set to `0` or less), the history subscription is completely cancelled and detached, guaranteeing zero runtime performance or memory overhead.
- **Logd Core Integration:** Upgraded logging package to `logd` version `^0.8.6` and integrated package-wide structured log handlers.
- **Stable Event Proxy:** Replaced transient event streams with a persistent broadcast proxy stream to prevent zombie listeners across configure/reset cycles.
- **Per-Notification Permanence:** Added `permanent: true` flag to individual `NotificationWidget`s to bypass channel-level default dismiss durations.
