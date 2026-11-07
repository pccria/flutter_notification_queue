part of 'core.dart';

/// Manages the browser context menu state on web platforms.
///
/// Uses reference counting to prevent premature re-enabling of the browser
/// context menu during transitions between notification cards, across
/// notification queues, or while context menus are open.
class WebContextMenuController {
  int _disableRequests = 0;

  /// Whether browser context menu disabling is currently active.
  bool get isContextMenuDisabled => _disableRequests > 0;

  /// The current number of active disable requests.
  int get disableRequests => _disableRequests;

  /// Requests the browser's context menu to be disabled.
  ///
  /// Increments the reference count and disables the native browser context
  /// menu on web platforms when transitioning from 0 to 1 request.
  void requestDisable() {
    if (!kIsWeb) {
      return;
    }
    _disableRequests++;
    if (_disableRequests == 1) {
      unawaited(BrowserContextMenu.disableContextMenu());
    }
  }

  /// Releases a previously requested disable state.
  ///
  /// Decrements the reference count and re-enables the browser context menu
  /// once all active requests have been released.
  void releaseDisable() {
    if (!kIsWeb) {
      return;
    }
    if (_disableRequests > 0) {
      _disableRequests--;
      if (_disableRequests == 0) {
        Timer.run(() {
          if (_disableRequests == 0) {
            unawaited(BrowserContextMenu.enableContextMenu());
          }
        });
      }
    }
  }

  /// Forces the browser context menu to be re-enabled and resets the request
  /// counter to zero.
  void reset() {
    if (!kIsWeb) {
      return;
    }
    if (_disableRequests > 0) {
      _disableRequests = 0;
      unawaited(BrowserContextMenu.enableContextMenu());
    }
  }
}
