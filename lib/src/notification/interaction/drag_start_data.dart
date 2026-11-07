import 'dart:ui';

/// Captures initial positional and geometry metadata when a drag gesture
/// starts.
class DragStartData {
  const DragStartData({
    required this.widgetPosition,
    required this.pointerPosition,
    required this.widgetSize,
  });

  final Offset widgetPosition;
  final Offset pointerPosition;
  final Size widgetSize;

  /// Distance from top-left of widget to touch/pointer position.
  Offset get touchOffset => pointerPosition - widgetPosition;
}
