# Channel System

The **Channel System** categorizes notifications by domain intent. It allows you to define global semantic themes and default queue targets for different categories of messages.

## `NotificationChannel`

A `NotificationChannel` is a named configuration profile that defines:
- **Name**: Unique string identifier (e.g., `'success'`, `'orders'`, `'chat'`).
- **Theme**: Semantic styling via `NotificationThemeData` (`color`, typography, icon themes).
- **Icon**: Default icon widget.
- **Target Queue**: Optional `QueuePosition` override routing all channel notifications to a specific queue.
- **Priority**: Default priority tier (`low`, `normal`, `high`, `critical`).
- **Auto-Dismiss Duration**: Default display duration before auto-dismissal.

> [!IMPORTANT]
> **Styling vs. Theming Separation**:
> - **`NotificationChannel.theme`** (`NotificationThemeData`) controls the semantic domain voice (accent color, text style, icon styling).
> - **`NotificationQueue.style`** (`QueueStyle`) controls physical industrial geometry (`borderRadius`, `padding`, `elevation`, `opacity`).
> - Channels do not define `QueueStyle` or relocation rules.

---

### Why Use Channels?

1. **Visual Consistency**: Ensures all "Error" or "Success" notifications maintain uniform styling across your app.
2. **Centralized Theming**: Modify the theme or target position of a channel in one place without touching UI dispatch calls.
3. **Intent-First Dispatching**: Call `controller.show(AppNotification(message: '...', channelName: 'orders'))` without manually specifying colors, icons, or positions at every callsite.

---

## Standard Channels

FNQ provides built-in standard channels out of the box:

- **`success`**: Green accent, Checkmark icon.
- **`error`**: Red accent, Error icon.
- **`warning`**: Orange accent, Warning icon.
- **`info`**: Blue accent, Info icon.

Standard channels are accessible via `NotificationChannel.standardChannels()`.

---

## Custom Channels & Controller Setup

Define your own channels using `NotificationThemeData` and pass them to your `NotificationController`:

```dart
final chatChannel = NotificationChannel(
  name: 'chat',
  defaultIcon: const Icon(Icons.chat_bubble),
  theme: const NotificationThemeData(
    color: Color(0xFF8B5CF6),
  ),
  position: QueuePosition.topRight,
);

final billingChannel = NotificationChannel(
  name: 'billing',
  theme: NotificationThemeData.fromSeed(
    seedColor: const Color(0xFF6366F1),
  ),
  position: QueuePosition.bottomRight,
);

final controller = NotificationController(
  channels: {
    ...NotificationChannel.standardChannels(),
    chatChannel,
    billingChannel,
  },
);
```
