# Documentation Index

Welcome to the **Flutter Notification Queue (FNQ)** documentation index. This
directory contains architectural guides, API breakdowns, and technical
specifications.

---

## 🧭 Architecture, Philosophy & Knowledge Base

- [**Core Philosophy & The 5 Axioms**](core/philosophy.md):
  The 5 Foundational Axioms of FNQ (Multi-Tenancy, The 4 Gears, Mathematical
  Invariance, Temporal Stasis, Spatial/Physical Continuity).
- [**System Architecture**](core/architecture.md):
  Comprehensive 6-subsystem guide detailing control, configuration,
  coordination, spatial layout, gesture FSM, and invariant timer planes.
- [**Gestures & Spatial Interactions**](core/gestures_and_interactions.md):
  Technical deep dive into the Gesture FSM, card-centric egress paths, dual
  commitment thresholds, tactile tilt, underlays, and drop target registry.
- [**Temporal Invariance & Queue Stasis**](core/timer_and_stasis.md):
  Technical deep dive into the token-based pause engine (`TimerPauseReason`),
  the `shouldTimerRun` invariant equation, and queue stasis synchronization.
- [**System Architecture Blueprint**](specs/architecture_blueprint.md):
  Foundational design rationale covering multi-tenancy, state ownership, and
  ecosystem comparisons with `ScaffoldMessenger`.

---

## 🚀 Getting Started & Migration Guides

- [**Getting Started**](getting_started.md):
  Quick start guide to integrate FNQ into your app using
  `NotificationController` and `NotificationScope`.
- [**Migration Guide: Upgrading to v0.5.0**](migration_v0_5.md):
  Comprehensive upgrade guide for v0.5.0, covering the four architectural tiers,
  permanent queue relocation, `NotificationThemeData`, and `QueueStyle`.
- [**Migration Guide (v0.3.x → v0.4.0)**](migration_v0_4.md):
  Step-by-step instructions for migrating from legacy static singletons to the
  decoupled v0.4.x architecture.
- [**Development Roadmap & Status Board**](roadmap.md):
  Evolutionary release tracks, infrastructure maturation goals, and milestone
  progress.

---

## 📦 Modules & Core Subsystems

### Core Engine
The central nervous system of FNQ.
- [**Overview**](core/README.md):
  How `NotificationController`, `NotificationScope`, `ConfigurationManager`, and
  `QueueCoordinator` work together.
- [**API Reference**](core/api.md):
  Detailed breakdown of public and internal components.
- [**Architecture**](core/architecture.md):
  High-level system design and data flow.
- [**Lifecycle**](core/lifecycle.md):
  Understanding the notification lifecycle from creation to dismissal.

### Queue System
Manages spatial positioning, physics, geometry, and permanent relocation.
- [**Overview**](queue/README.md):
  Understanding `NotificationQueue`, `QueuePosition`, stasis, and relocation.
- [**Queue Styles**](queue/styles.md):
  Configuring archetypes (`FilledQueueStyle`, `OutlinedQueueStyle`,
  `FlatQueueStyle`), geometry, and glassmorphic opacity.

### Channel System
Categorizes notifications by domain intent and assigns semantic chromatics.
- [**Overview**](channel/README.md):
  Understanding `NotificationChannel` and `NotificationThemeData`.
- [**Standard Channels**](channel/README.md#standard-channels):
  Using built-in channel presets.

### Overlay & Rendering
Handles visual presentation in the Flutter overlay.
- [**Overview**](overlay/README.md):
  How `NotificationOverlay` integrates with the widget tree via
  `NotificationScope`.
- [**Accessibility & Focus Traversal**](specs/accessibility.md):
  Engineering RFC for focus ingestion, screen readers, and keyboard navigation.

---

## 🤝 Contributing

- [**Contributing Guidelines**](../CONTRIBUTING.md):
  How to contribute to the project.
- [**Architecture Principles**](../.agents/rules/architecture_principles.md):
  Mandatory technical rules and invariants for contributors and AI agents.
