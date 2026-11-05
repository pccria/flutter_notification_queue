# Documentation Index

Welcome to the **Flutter Notification Queue (FNQ)** documentation index. This directory contains detailed architectural guides, API breakdowns, and migration documentation.

---

## 🚀 Getting Started & Migration Guides

- [**Getting Started**](getting_started.md): Quick start guide to integrate FNQ into your app using `NotificationController` and `NotificationScope`.
- [**Migration Guide: Upgrading to v0.5.0**](migration_v0_5.md): Comprehensive upgrade guide for v0.5.0, covering the four architectural tiers, permanent queue relocation, `NotificationThemeData`, `QueueStyle` strict ownership, and deprecated APIs.
- [**Migration Guide (v0.3.x → v0.4.0)**](migration_v0_4.md): Step-by-step instructions for migrating from legacy static singletons to the decoupled v0.4.x architecture.
- [**Development Roadmap & Status Board**](roadmap.md): Strategic release tracks, complexity matrix, and milestone progress toward v1.0.

---

## 📐 Architecture & Engineering Specifications

- [**System Architecture Blueprint**](specs/architecture_blueprint.md): Foundational design rationale covering multi-tenancy, state ownership, ecosystem comparisons, and physics models.
- [**Accessibility & Focus Traversal Specification**](specs/accessibility.md): Engineering RFC for non-intrusive focus ingestion, screen reader semantics, and keyboard traversal.

---

## 📦 Modules & Core Subsystems

### Core Engine
The central nervous system of FNQ.
- [**Overview**](core/README.md): How `NotificationController`, `NotificationScope`, `ConfigurationManager`, and `QueueCoordinator` work together.
- [**API Reference**](core/api.md): Detailed breakdown of public and internal components.
- [**Architecture**](core/architecture.md): High-level system design and data flow.
- [**Lifecycle**](core/lifecycle.md): Understanding the notification lifecycle from creation to dismissal.

### Queue System
Manages spatial positioning, physics, geometry, and permanent relocation.
- [**Overview**](queue/README.md): Understanding `NotificationQueue`, `QueuePosition`, and `permanentRelocation`.
- [**Queue Styles**](queue/styles.md): Configuring archetypes (`FilledQueueStyle`, `OutlinedQueueStyle`, `FlatQueueStyle`), geometry, and glassmorphic opacity.

### Channel System
Categorizes notifications by domain intent and assigns semantic chromatics.
- [**Overview**](channel/README.md): Understanding `NotificationChannel` and `NotificationThemeData`.
- [**Standard Channels**](channel/README.md#standard-channels): Using the built-in channel presets.

### Overlay & Rendering
Handles the visual presentation of notifications on the screen.
- [**Overview**](overlay/README.md): How `NotificationOverlay` integrates with the widget tree via `NotificationScope`.

---

## 🤝 Contributing

- [**Contributing Guidelines**](../CONTRIBUTING.md): How to contribute to the project.
