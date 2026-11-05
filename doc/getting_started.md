# Getting Started with Flutter Notification Queue

`flutter_notification_queue` (FNQ) is a production-grade, overlay-based spatial notification engine for Flutter. It cleanly separates notification **data payloads** (`AppNotification`) from **spatial queues** (`NotificationQueue`), **channel themes** (`NotificationChannel`), and **state ownership** (`NotificationController` & `NotificationScope`).

---

## 1. Installation

Add `flutter_notification_queue` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_notification_queue: ^latest
```

Import the package in your Dart file:

```dart
import 'package:flutter_notification_queue/flutter_notification_queue.dart';
```

---

## 2. Core Concepts

FNQ is built around four core components:

1. **`AppNotification`**: Pure data payload describing message content, title, priority, auto-dismiss duration, and interactive actions.
2. **`NotificationChannel`**: Logical message category (`info`, `success`, `warning`, `error`, `chat`, etc.) that governs default icons, themes (`NotificationThemeData`), priorities, and target spatial queue positions.
3. **`NotificationQueue`**: Spatial layout container bound to a `QueuePosition` (e.g. `topRight`, `bottomCenter`). Governs stack limits, physics, overflow strategies, drag gestures, and grouping decks.
4. **`NotificationController` & `NotificationScope`**: State management handle and widget-tree overlay injector. Manages state lifecycle, contextless/context-aware dispatching, event observation, and historical logging.

---

## 3. Initialization & Setup

### Step 1: Create a `NotificationController`

Instantiate a `NotificationController` in your app initialization or state management layer (BLoC, Provider, Riverpod, etc.):

```dart
final notificationController = NotificationController(
  queues: {
    const NotificationQueue(
      position: QueuePosition.topRight,
      maxStackSize: 3,
      style: FilledQueueStyle(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    const NotificationQueue(
      position: QueuePosition.bottomCenter,
      maxStackSize: 2,
    ),
  },
  channels: {
    ...NotificationChannel.standardChannels(),
    const NotificationChannel(
      name: 'orders',
      position: QueuePosition.topRight,
      theme: NotificationThemeData(color: Colors.teal),
      defaultIcon: Icon(Icons.local_shipping),
    ),
  },
);
```

> **Note**: If `queues` or `channels` are omitted, standard default queues (`topRight`) and channels (`info`, `success`, `warning`, `error`) are automatically registered.

### Step 2: Mount `NotificationScope` in your App

Wrap your app's widget tree using `NotificationScope` inside `MaterialApp.builder` (or `CupertinoApp.builder`). This attaches the notification overlay surface to your app window.

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.controller});

  final NotificationController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FNQ App',
      builder: (context, child) => NotificationScope(
        controller: controller,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
```

---

## 4. Dispatching Notifications

### Option A: Contextless Dispatching (from Services, BLoCs, Repositories)

You can trigger notifications directly from non-UI layers using your `NotificationController` instance without needing a `BuildContext`:

```dart
controller.show(
  const AppNotification(
    title: 'Order Shipped',
    message: 'Order #1043 is on its way!',
    channelName: 'orders',
  ),
);
```

### Option B: Context-Aware Dispatching (from UI Widgets)

Inside any Flutter widget subtree under `NotificationScope`, access the controller via `NotificationScope.of(context)`:

```dart
ElevatedButton(
  onPressed: () {
    NotificationScope.of(context).show(
      const AppNotification(
        title: 'Settings Saved',
        message: 'Your profile preferences were updated.',
        channelName: 'success',
      ),
    );
  },
  child: const Text('Save Profile'),
);
```

---

## 5. Adding Interactive Actions

Notifications support primary action buttons:

```dart
controller.show(
  AppNotification(
    title: 'Update Available',
    message: 'Version 2.0 is ready for download.',
    channelName: 'info',
    action: NotificationAction.button(
      label: 'Update Now',
      onPressed: () {
        print('User tapped Update Now');
      },
    ),
  ),
);
```

---

## 6. Listening to Lifecycle Events

Listen to the `controller.events` stream to observe notification lifecycle events (e.g. queued, shown, dismissed, snoozed, relocated):

```dart
final subscription = controller.events.listen((NotificationEvent event) {
  switch (event) {
    case NotificationQueued(:final notification):
      print('Notification queued: ${notification.id}');
    case NotificationDismissed(:final notification, :final reason):
      print('Notification dismissed (${reason.name}): ${notification.id}');
    case NotificationTapped(:final notification, :final behavior):
      print('Notification tapped: ${notification.id} (behavior: ${behavior.runtimeType})');
    case NotificationRelocated(:final notification, :final from, :final to):
      print('Notification relocated: ${notification.id} from ${from.name} to ${to.name}');
    case QueueOverflowed(:final queue, :final dropped):
      print('Queue ${queue.position.name} overflowed, dropped: ${dropped.id}');
    default:
      break;
  }
});
```

---

## 7. Disposing the Controller

When your application or module finishes, call `dispose()` on the controller to cancel active timers, detach overlay controllers, and close event streams:

```dart
controller.dispose();
```
