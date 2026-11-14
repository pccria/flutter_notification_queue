# Rule: Core Architecture Principles & Technical Invariants

When modifying, extending, or maintaining the `flutter_notification_queue`
package (FNQ) or its example app, strictly adhere to the following technical
principles and invariants:

---

## 1. Mathematical Invariance & Token Accounting
- **No Loose Boolean Flags**: Never introduce independent boolean flags (such as
  `_isHovered`, `_isDragging`, `_isPaused`) to control timer playback.
- **Token Set Accounting**: All pause triggers must be registered as discrete
  tokens in `final Set<TimerPauseReason> _pauseReasons`.
- **Derived Invariant**: Timer playback must strictly depend on the invariant:
  `shouldTimerRun = isTimerEnabled && _pauseReasons.isEmpty && !_isDismissing`
- **Idempotent Dismissal**: Guard all dismissal triggers with `_isDismissing` to
  prevent duplicate controller dismiss calls or post-dispose animations.
- **Safe Token Release**: Always release registered tokens in `dispose()` or
  gesture completion callbacks to prevent leaked freeze states.

---

## 2. Temporal Stasis & Remaining Duration Preservation
- **Interaction Freezes Time**: Any user interaction (card hover, touch hold,
  drag gesture, context menu open, queue reordering, cross-queue relocation)
  MUST immediately freeze notification countdown timers.
- **Queue-Level Stasis**: Queues must propagate freeze states to their rendered
  cards via `NotificationTimerScope(enabled: !isQueuePaused)`.
- **Exact Duration Conservation**: Pausing a timer must never reset elapsed or
  remaining duration. When resumed, countdowns continue from the exact
  remaining milliseconds.

---

## 3. Multi-Tenant Purity & Zero Static Singletons
- **No Global Singletons**: Never introduce top-level static state or singletons
  for controllers, queue registries, or event buses.
- **Subtree Scoping**: All state belongs to explicit `NotificationController`
  instances injected into the widget tree via `NotificationScope`.
- **Desktop & Test Isolation**: Every controller instance must operate
  independently to support multi-window desktop environments and concurrent
  unit/widget test suites.

---

## 4. Strict Separation of the Four Gears
- **Gear 1: Intent (`AppNotification`)**: Pure data payloads. Never attach UI
  widgets, layout constraints, or styling to notification payloads.
- **Gear 2: Domain (`NotificationChannel`)**: Routing rules, priority limits,
  and sound/vibration semantics.
- **Gear 3: Space (`NotificationQueue` & `QueueStyle`)**: Geometric layout,
  stack offsets, scale curves, opacity gradients, and screen positions.
- **Gear 4: Time & Chromatics (`NotificationTimerScope` &
  `NotificationThemeData`)**: Countdown duration, pause tokens, and color
  tokens.
- Never let changes in one gear silently mutate or override another gear.

---

## 5. Strict 80-Character Line Limit
- Every line of code, comment, and documentation across all Dart files (`lib/`,
  `test/`, `example/`) and Markdown files (`doc/`, `.agents/`, `README.md`)
  MUST be strictly $\le 80$ characters in length.

---

## 6. Zero Analyzer Warning Tolerance
- The workspace must maintain zero warnings and zero lints under:
  `flutter analyze lib test example --fatal-warnings`
- Any new code must comply with the pedantic analysis options configured in
  `analysis_options.yaml`.

---

## 7. Test Isolation & Regression Invariance
- Every new feature, gesture, or bug fix must include dedicated unit and widget
  tests in `test/`.
- Tests must construct independent `NotificationController` instances and
  dispose of all open stream subscriptions before test completion.
- Running `flutter test` and `(cd example && flutter test)` must pass with 100%
  success rate before committing.
