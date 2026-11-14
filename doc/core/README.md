# Core Engine Overview

The **Core Engine** is the central nervous system of FNQ. It operates as a
modular, testable, multi-tenant architecture decoupled from static global
singletons.

---

## 1. Core Architecture Documentation

For complete technical specifications, consult the dedicated guides:
- [**Core Philosophy & Axioms**](philosophy.md): The 5 foundational axioms.
- [**System Architecture**](architecture.md): The 6 subsystem planes.
- [**Gestures & Interactions**](gestures_and_interactions.md): FSM and egress.
- [**Temporal Invariance & Stasis**](timer_and_stasis.md): Token pause engine.
- [**API Reference**](api.md): Complete public API contract.
- [**Notification Lifecycle**](lifecycle.md): From dispatch to teardown.

---

## 2. Core Components

### 2.1. NotificationController (State & Lifecycle Owner)
- **Role**: Pure Dart state, lifecycle, and dispatching handle.
- **Responsibility**: Owns configuration (`queues`, `channels`), active
  notification states, history logging, and lifecycle event streams.
- **Key Capabilities**:
  - Contextless dispatching (`controller.show(AppNotification(...))`).
  - Lifecycle event observation (`controller.events`).
  - Queue stasis controls (`pauseQueue`, `resumeQueue`, `pauseAll`,
    `resumeAll`).
  - History log management, snoozing, pinning, and queue triage.

### 2.2. NotificationScope (Widget-Tree Injector)
- **Role**: Overlay binding & dependency injector.
- **Responsibility**: Injects `NotificationController` into the Flutter widget
  tree and manages `OverlayPortal` attachment.
- **Key Capabilities**:
  - Context-aware dispatching (`NotificationScope.of(context).show(...)`).
  - Multi-tenant subtree isolation for desktop windows and tabs.

### 2.3. ConfigurationManager (Configuration Registry)
- **Role**: Configuration registry and validator.
- **Responsibility**: Stores and validates `NotificationQueue` and
  `NotificationChannel` definitions.
- **Behavior**:
  - Validates configuration on startup (uniqueness, boundaries).
  - Provides default fallback channels when requested items are missing.
  - Immutable state once constructed by the controller.

### 2.4. QueueCoordinator (Lifecycle Coordinator)
- **Role**: Dynamic runtime state manager and layout bridge.
- **Responsibility**: Bridges logical queues to the visual rendering overlay.
- **Behavior**:
  - Tracks active notification entries per spatial queue bucket.
  - Manages `OverlayPortalController` attachment and detachment.
  - Routes notifications to their corresponding `QueueWidget`.
  - Coordinates queue stasis and cross-queue relocation.

### 2.5. NotificationOverlay (Rendering Surface)
- **Role**: High-performance overlay rendering surface.
- **Responsibility**: Renders active queues into the Flutter overlay portal.
- **Behavior**:
  - Uses `OverlayPortal` for performant rendering over app UI elements.
  - Mounts spatial queue containers without requiring ancestral context.
