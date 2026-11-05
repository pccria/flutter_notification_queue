# Core Engine Overview (v0.5.x)

The **Core Engine** is the central nervous system of FNQ. In **v0.5.x**, it operates as a modular, testable, multi-tenant architecture decoupled from static global singletons.

## Components

### 1. NotificationController (State & Lifecycle Owner)
- **Role**: State, lifecycle, and dispatching handle.
- **Responsibility**: Owns configuration (`queues`, `channels`), active notification states, history logging, and life-cycle event streams.
- **Key Capabilities**:
  - Contextless dispatching (`controller.show(AppNotification(...))`).
  - Lifecycle event observation (`controller.events`).
  - Management of history entries, snoozing, pinning, relocation, and queue triage.

### 2. NotificationScope (Widget-Tree Injector)
- **Role**: Overlay binding & dependency injector.
- **Responsibility**: Injects `NotificationController` into the Flutter widget tree and manages overlay portal attachment.
- **Key Capabilities**:
  - Context-aware dispatching (`NotificationScope.of(context).show(...)`).
  - Multi-tenant subtree isolation.

### 3. ConfigurationManager (Configuration Registry)
- **Role**: Configuration Registry.
- **Responsibility**: Stores and resolves `NotificationQueue` and `NotificationChannel` definitions.
- **Behavior**:
  - Validates configuration on startup.
  - Provides fallback logic (Standard Defaults) when requested items are missing.
  - Immutable state once constructed by the controller.

### 4. QueueCoordinator (Lifecycle Coordinator)
- **Role**: Queue & Overlay Coordinator.
- **Responsibility**: Bridges logical queues to the visual rendering overlay.
- **Behavior**:
  - Tracks active notification entries per spatial queue.
  - Manages `OverlayPortalController` attachment and detachment.
  - Routes notifications to their corresponding `QueueWidget`.

### 5. NotificationOverlay (Rendering Surface)
- **Role**: Rendering Surface.
- **Responsibility**: Inserts the notification queue stack into the Flutter overlay widget tree.
- **Behavior**:
  - Uses `OverlayPortal` for performant rendering over app UI elements.
  - Mounts spatial queue containers without context requirement.
