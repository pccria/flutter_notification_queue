# Notification Overlay

The **Notification Overlay** is the visual rendering surface that sits above application content to host spatial notification queues.

## Rendering Mechanism

FNQ uses Flutter's modern `OverlayPortal` primitive for overlay rendering:
- **Zero Tree Rebuild Overhead**: Avoids rebuilding the main app widget tree when notifications are shown, animated, or dismissed.
- **Lazy Portal Lifecycle**: The `QueueCoordinator` automatically attaches the portal (`OverlayPortalController.show()`) when active notifications exist, and detaches it (`hide()`) when all queues are empty to eliminate unused layout passes.
- **Top-Level Z-Ordering**: Renders cleanly above `Navigator` routes, modals, popups, and dialogs.

## Integration & Scope Binding

### Recommended Setup (`NotificationScope` in `MaterialApp.builder`)

The notification overlay is attached using `NotificationScope` inside `MaterialApp.builder` (or `CupertinoApp.builder`):

```dart
MaterialApp(
  title: 'My App',
  builder: (context, child) => NotificationScope(
    controller: notificationController,
    child: child!,
  ),
  home: const HomeScreen(),
)
```

This pattern automatically:
1. Mounts `NotificationOverlay` above your app's `Navigator`.
2. Connects the `NotificationController` instance to the underlying overlay portal.
3. Exposes the controller to all descendant widgets via `NotificationScope.of(context)`.

### Subtree & Multi-Tenant Scope Binding

For embedded Flutter modules, desktop split views, or multi-window screens, `NotificationScope` can be placed over any independent widget subtree:

```dart
NotificationScope(
  controller: dashboardNotificationController,
  child: DashboardWidget(),
)
```

Notifications dispatched via `dashboardNotificationController` or `NotificationScope.of(context)` within this subtree will render inside that specific scope's overlay bounds.
