# Changelog

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
