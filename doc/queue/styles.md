# Queue Styles

A `QueueStyle` defines the **physical industrial chassis** and layout archetype for notifications within a `NotificationQueue`.

In FNQ's architectural model, `QueueStyle` lives **strictly on `NotificationQueue`**. It answers *how the card is built physically* (`borderRadius`, `padding`, `elevation`, `opacity`), while semantic coloring and typography are driven by `NotificationThemeData` on `NotificationChannel`.

---

## Built-in Archetypes

`QueueStyle` is a sealed class with three built-in archetypes:

### 1. `FilledQueueStyle`
- **Anatomy**: The entire card background is filled with the resolved `NotificationThemeData.color`.
- **WCAG Contrast**: Foreground text and icons automatically calculate contrast against the fill color (`luminance > 0.5 ? Colors.black : Colors.white`).
- **Best For**: High-impact alerts, error banners, system critical notifications, and vibrant toasts.

```dart
const FilledQueueStyle(
  borderRadius: BorderRadius.all(Radius.circular(14)),
  elevation: 4.0,
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
)
```

### 2. `OutlinedQueueStyle`
- **Anatomy**: The card background remains the ambient `colorScheme.surface` (or translucent if `opacity < 1.0`). The card's perimeter stroke is drawn using `borderWidth` and tinted by `NotificationThemeData.color`.
- **Best For**: Clean, minimal designs, dark mode interfaces, and subtle non-disruptive feedback.

```dart
const OutlinedQueueStyle(
  borderWidth: 1.5,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
)
```

### 3. `FlatQueueStyle`
- **Anatomy**: The card background remains ambient `colorScheme.surface` while the leading edge features a vertical accent color strip matching `NotificationThemeData.color`.
- **Best For**: Informational messages, standard toasts, task confirmations, and audit logs.

```dart
const FlatQueueStyle(
  borderRadius: BorderRadius.all(Radius.circular(10)),
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
)
```

---

## Glassmorphic Opacity

Every `QueueStyle` accepts an `opacity` double (`0.0` to `1.0`, defaulting to `1.0`). When configured with `opacity < 1.0`, the card renders with translucent background alpha:

```dart
NotificationQueue(
  position: QueuePosition.topRight,
  style: const FilledQueueStyle(
    opacity: 0.85, // Glassmorphic translucent surface
    borderRadius: BorderRadius.all(Radius.circular(16)),
    elevation: 8.0,
  ),
);
```

---

## Anatomy Properties

All `QueueStyle` subclasses share the following geometric properties:

| Property | Type | Description |
|---|---|---|
| **`borderRadius`** | `BorderRadius` | Corner curvature of the notification container. |
| **`borderWidth`** | `double` | Stroke thickness (primarily used in `OutlinedQueueStyle`). |
| **`elevation`** | `double` | Z-axis elevation casting ambient drop shadows. |
| **`opacity`** | `double` | Surface transparency (`0.0`–`1.0`) for glassmorphism. |
| **`padding`** | `EdgeInsetsGeometry?` | Internal content insets around the title and message. |

> [!NOTE]
> Drop shadow color is governed optically by the ambient environment via `Theme.of(context).shadowColor`, scaled by `elevation`. It is intentionally independent of domain channel styling.
