# FlutterNotificationQueue

[![CI](https://github.com/pccria/flutter_notification_queue/actions/workflows/ci.yml/badge.svg)](https://github.com/pccria/flutter_notification_queue/actions/workflows/ci.yml)
[![Pub Version](https://img.shields.io/pub/v/flutter_notification_queue)](https://pub.dev/packages/flutter_notification_queue)
[![Pub Likes](https://img.shields.io/pub/likes/flutter_notification_queue)](https://pub.dev/packages/flutter_notification_queue)
[![Pub Points](https://img.shields.io/pub/points/flutter_notification_queue)](https://pub.dev/packages/flutter_notification_queue)
[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Platform: Flutter](https://img.shields.io/badge/Platform-Flutter-blue?logo=flutter)](https://flutter.dev)

A production-grade, overlay-based spatial notification engine for Flutter applications.

[![Try NFQ Studio Web Demo](https://img.shields.io/badge/Try_Live_Demo-NFQ_Studio-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://pccria.github.io/flutter_notification_queue/)

`FlutterNotificationQueue` (FNQ) provides a comprehensive solution for displaying in-app notifications with spatial queue placement, Intent-First interactive drag/reorder/relocate gestures, notification bundling, priority triage preemption, permanent queue relocation, real-time observability, and deep theming.

---

## 💡 Core Architecture & Mental Model

FNQ cleanly decouples **what** a message represents from **where** and **how** it is rendered on screen:

```
┌────────────────────────┐      ┌─────────────────────────┐
│    AppNotification     │      │   NotificationChannel   │
│  (Data Payload Intent) │────► │  (Visual Category/Theme)│
└────────────────────────┘      └────────────┬────────────┘
                                             │ Maps route position
                                             ▼
┌────────────────────────┐      ┌─────────────────────────┐
│ NotificationController │      │    NotificationQueue    │
│  & NotificationScope   │ ◄──► │ (Spatial Position/Rules)│
│  (Lifecycle & State)   │      │ (Gestures & Grouping)   │
└────────────────────────┘      └─────────────────────────┘
```

1. **`AppNotification`**: Pure data payload describing notification content, title, message, priority, dismiss duration, actions, and tap behaviors.
2. **`NotificationChannel`**: Logical grouping for messages (e.g., `success`, `error`, `chat`). Governs default colors, icons, priorities, auto-dismiss durations, and target queue positions.
3. **`NotificationQueue`**: Spatial layout container fixed to a `QueuePosition` (e.g., `topRight`, `bottomCenter`). Controls physics, max stack limits, overflow strategies, drag behaviors (`Dismiss`, `Reorder`, `Relocate`, `ReorderAndRelocate`), and grouping decks.
4. **`NotificationController` & `NotificationScope`**: State management handle and widget-tree dependency injector. Manages lifecycle, contextless or context-aware dispatching, event streams, history logging, and live runtime reconfiguration.

---

## ⚡ Quick Start

### 1. Add Dependency

Add `flutter_notification_queue` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_notification_queue: ^0.5.0
```

### 2. Initialize and Mount Scope

Initialize a `NotificationController` and wrap your `MaterialApp` with `NotificationScope`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_notification_queue/flutter_notification_queue.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Instantiate the controller with queues and channels
    final controller = NotificationController(
      channels: {
        const NotificationChannel(
          name: 'info',
          position: QueuePosition.topRight,
          theme: NotificationThemeData(color: Color(0xFF0EA5E9)),
        ),
        const NotificationChannel(
          name: 'error',
          position: QueuePosition.topRight,
          theme: NotificationThemeData(color: Color(0xFFEF4444)),
        ),
      },
      queues: {
        const NotificationQueue(
          position: QueuePosition.topRight,
          maxStackSize: 3,
          style: FilledQueueStyle(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            elevation: 6,
          ),
        ),
      },
    );

    return MaterialApp(
      // 2. Attach NotificationScope at the root builder
      builder: (context, child) => NotificationScope(
        controller: controller,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
```

### 3. Dispatch Notifications

Show notifications from UI widgets using `NotificationScope.of(context)` or contextlessly from BLoCs, Cubits, Repositories, or Services using `controller.show()`:

```dart
// Context-aware dispatch from UI
NotificationScope.of(context).show(
  const AppNotification(
    title: 'Update Complete',
    message: 'System package updated successfully.',
    channelName: 'info',
  ),
);

// Error notification with button action
NotificationScope.of(context).show(
  AppNotification(
    title: 'Connection Failure',
    message: 'Unable to reach backend service. Retrying...',
    channelName: 'error',
    dismissDuration: null, // Stay until dismissed
    action: NotificationAction.button(
      label: 'RETRY',
      onPressed: () => print('Retry clicked'),
    ),
  ),
);

// Contextless dispatch (from BLoCs, Cubits, Repositories, or background services)
controller.show(
  const AppNotification(
    title: 'Background Sync',
    message: 'Data synchronization completed in background.',
    channelName: 'info',
  ),
);

// Safe contextless dispatch before first frame renders
controller.tryShow(
  const AppNotification(
    title: 'App Startup',
    message: 'Loaded user session.',
    channelName: 'info',
  ),
);
```

---

## 🎨 Common Recipes & Use Cases

### Custom Actions & Tap Behaviors

Configure how users interact with the card surface or action buttons:

```dart
// Button Action
AppNotification(
  title: 'New Message',
  message: 'Sarah sent you a message.',
  channelName: 'info',
  action: NotificationAction.button(
    label: 'REPLY',
    onPressed: () => openChat(),
  ),
);

// Tap-To-Act (Entire card surface is tapable)
AppNotification(
  title: 'Security Alert',
  message: 'Unrecognized login attempt. Tap to review.',
  channelName: 'warning',
  tapBehavior: TapToAct(
    onTap: () => openSecuritySettings(),
    dismissOnAct: true,
  ),
);

// Tap-To-Expand (Expand long text on tap)
const AppNotification(
  title: 'Build Output',
  message: 'Detailed build log output spanning multiple lines...',
  channelName: 'info',
  tapBehavior: TapToExpand(),
);
```

### Permanent & Sticky Notifications

```dart
// Permanent card (no auto-dismiss countdown, stays until user action)
const AppNotification(
  title: 'Ongoing Download',
  message: 'Downloading asset pack (45%)...',
  channelName: 'info',
  permanent: true,
);

// Sticky Alert with button action
AppNotification(
  title: 'Critical Alert',
  message: 'System requires immediate attention.',
  channelName: 'error',
  permanent: true,
  action: NotificationAction.button(
    label: 'ACKNOWLEDGE',
    onPressed: () => handleAlert(),
  ),
);
```

---

## 🚀 Advanced Capabilities

### 1. Intent-First Interactive Gestures

FNQ provides sophisticated pointer and touch gesture handling configured at the queue level via `dragBehavior` and `longPressDragBehavior`:

* **`Dismiss`**: Swipe to dismiss. Supports `DismissZone.sideEdges` or `DismissZone.naturalDirection`.
* **`Reorder`**: Live-shifting drag reordering within the stack featuring **Gravity-Well Hysteresis** to eliminate pointer wobble and **Selection Reticles** for drop slot feedback.
* **`Relocate`**: Drag a notification card to move it into another queue position.
* **`ReorderAndRelocate`**: Reorder within the current stack, or drag past an escape threshold to relocate to a destination queue.
* **`Disabled`**: Disables drag gestures.

```dart
NotificationQueue(
  position: QueuePosition.topRight,
  dragBehavior: const Dismiss(),
  longPressDragBehavior: ReorderAndRelocate.to(
    positions: {QueuePosition.bottomRight},
  ),
)
```

> [!TIP]
> **Relocation Auto-Registration**: When target positions are defined in `Relocate.to({...})` or `ReorderAndRelocate.to(positions: {...})`, FNQ automatically registers sibling target queues, clones source queue styling, and configures self-inclusion so cards can return home.

---

### 2. Notification Grouping (Bundling)

Prevent screen flooding by collapsing multiple notifications from the same channel/group into an interactive stacked deck:

```dart
NotificationQueue(
  position: QueuePosition.topRight,
  groupingBehavior: QueueGroupingBehavior(
    enabled: true,
    maxBeforeGrouping: 2,         // Bundle after 2 notifications arrive
    maxStackedLayers: 3,          // Background card layers in bundle deck
    stackStepOffset: 6.0,         // Pixels offset per background card
    stackScaleMultiplier: 0.04,   // Scale reduction per background card
    enableGroupSwipeDismiss: true,// Swipe top card or whole bundle
  ),
)
```

* **Single-Card Swipe**: Swiping the top card in a bundle dismisses only that notification and automatically surfaces the next hidden member.
* **Group Indicator Bar**: Displays non-overlapping bundle indicators with dynamic padding and theme adaptation.

---

### 3. Priority Triage & Backpressure Eviction

FNQ includes a semantic priority triage engine (`NotificationPriority.low`, `normal`, `high`, `critical`):

```dart
const AppNotification(
  title: 'Database Outage',
  message: 'Primary DB node unresponsive!',
  channelName: 'error',
  priority: NotificationPriority.critical,
);
```

* **Priority Auto-Sorting**: Pending notifications auto-sort by priority so critical items display first.
* **Preemption Eviction**: If a queue is full (`maxStackSize`) and a higher-priority notification arrives, FNQ automatically evicts the lowest-priority active card (emitting `DismissReason.evicted`), returns it to the pending queue, and displays the critical notification immediately.
* **Overflow Strategy**: Configure `QueueOverflowStrategy.discardOldest` or `discardNewest` when pending queue capacity (`maxPendingSize`) is reached.

---

### 4. Permanent Queue Relocation

Configure a queue to dynamically relocate to other screen positions upon drag, migrating active notifications and redirecting future queue traffic:

```dart
NotificationQueue(
  position: QueuePosition.topRight,
  longPressDragBehavior: Relocate.to(
    {QueuePosition.topLeft, QueuePosition.bottomRight},
    permanent: true, // Queue redirects future notifications here & migrates active cards
  ),
)
```

When `permanent: true` is set, relocating any card moves the entire queue: active sibling cards smoothly migrate to join it, and future incoming notifications targeting that queue are automatically delivered to the new position.

---

### 5. Observability & Event History Log

Observe lifecycle events in real-time or query an in-memory LIFO history ring buffer:

```dart
// 1. Subscribe to live stream
controller.events.listen((event) {
  switch (event) {
    case NotificationQueued(:final notification):
      print('Displayed: ${notification.id}');
    case NotificationDismissed(:final notification, :final reason):
      print('Dismissed: ${notification.id} ($reason)');
    case NotificationRelocated(:final notification, :final from, :final to):
      print('Relocated from ${from.name} to ${to.name}');
    case QueuePositionRelocated(:final from, :final to, :final permanent):
      print('Queue moved from ${from.name} to ${to.name} (permanent: $permanent)');
    default:
      break;
  }
});

// 2. Query bounded history log (Opt-in via maxHistoryEntries)
final history = controller.getHistory(
  channelName: 'error',
  limit: 10,
);
```

> [!NOTE]
> Set `maxHistoryEntries: 0` (the default) for zero runtime memory or CPU overhead when history logging is not needed.

---

### 6. In-Place Runtime Reconfiguration

Update queues, channels, and history settings live **without re-instantiating the controller** or clearing active visible cards:

```dart
controller.reconfigure(
  queues: {
    const NotificationQueue(
      position: QueuePosition.topRight,
      maxStackSize: 5,
    ),
  },
  maxHistoryEntries: 50,
);
```

---

### 7. Custom Transitions & Styling

Choose from standard queue styles or provide custom transition animations and widget builders:

```dart
// Outlined Queue Style
const OutlinedQueueStyle(
  borderRadius: BorderRadius.all(Radius.circular(10)),
  borderWidth: 1.5,
  elevation: 4,
);

// Scale Transition
const ScaleTransitionStrategy(
  initialScale: 0.7,
  curve: Curves.backOut,
);

// Custom Animation Builder
NotificationQueue(
  position: QueuePosition.topCenter,
  transition: BuilderTransitionStrategy(
    (context, animation, position, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
  ),
);
```

---

## 🌐 Platform & Accessibility Support

* **RTL Detection**: Automatic text direction detection for Arabic, Persian, Hebrew, and Urdu.
* **Safe Area Integration**: Automatic handling of notches, status bars, and navigation bars.
* **Desktop & Web**: Mouse hover detection, desktop scroll wheel support, and progressive close button visibility (`VisibleOnHover`, `AlwaysVisible`, `Hidden`).
* **Haptics & Touch**: Native touch gesture feedback and spring snapback physics.

---

## 📈 Migration Guide (v0.x to v1.0)

| Legacy v0.x API | Modern v1.0 Architecture | Description |
|---|---|---|
| `FlutterNotificationQueue.configure(...)` | `final controller = NotificationController(...)` | Pure Dart configuration owner |
| `MaterialApp(builder: FlutterNotificationQueue.builder)` | `NotificationScope(controller: controller, child: child!)` | Scoped widget tree overlay binding |
| `NotificationWidget(message: '...').show()` | `controller.show(AppNotification(message: '...'))` | Pure data payload intent |
| `NotificationScope.of(context).show(...)` | `NotificationScope.of(context).show(AppNotification(...))` | Context-aware dispatching |
| `FlutterNotificationQueue.events` | `controller.events` | Stable broadcast stream |

For full step-by-step details, see the migration guides:
* [**Upgrading to v0.5.0**](doc/migration_v0_5.md) (Four architectural tiers, permanent queue relocation, `NotificationThemeData`)
* [**Upgrading to v0.4.0**](doc/migration_v0_4.md) (Migration to `NotificationController` and `NotificationScope`)

---

## 📄 License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.
