import 'dart:ui';

/// Layout mode used by the HUD overlay.
enum OverlayLayoutMode {
  /// A single full-screen zone for the active workspace.
  single,

  /// Side-by-side horizontal division (used on landscape/desktop).
  splitHorizontal,

  /// Top-and-bottom vertical division (used on portrait/mobile).
  splitVertical,
}

/// Calculated screen rectangles for the workspace overlay zones.
class ZoneRects {
  const ZoneRects({
    required this.mode,
    required this.zoneA,
    this.zoneB,
  });

  final OverlayLayoutMode mode;
  final Rect zoneA;
  final Rect? zoneB;
}

/// Computes the exact screen geometry for overlay zones.
///
/// This pure function determines whether zones split horizontally or vertically
/// based on screen aspect ratio, or whether the inactive zone is held offscreen
/// in single mode to preserve timer and state lifecycles.
ZoneRects computeZoneRects({
  required final Size totalSize,
  required final bool isSplit,
  required final int windowCount,
  required final String activeWindowId,
}) {
  const offscreenOffset = -99999.0;
  final offscreenRect = Rect.fromLTWH(
    offscreenOffset,
    offscreenOffset,
    totalSize.width > 0 ? totalSize.width : 100,
    totalSize.height > 0 ? totalSize.height : 100,
  );

  final fullRect = Rect.fromLTWH(0, 0, totalSize.width, totalSize.height);

  if (windowCount <= 1) {
    return ZoneRects(
      mode: OverlayLayoutMode.single,
      zoneA: fullRect,
      zoneB: null,
    );
  }

  if (!isSplit) {
    final isWin1Active = activeWindowId == 'win_1';
    return ZoneRects(
      mode: OverlayLayoutMode.single,
      zoneA: isWin1Active ? fullRect : offscreenRect,
      zoneB: isWin1Active ? offscreenRect : fullRect,
    );
  }

  // Dual mode: divide screen based on aspect ratio
  final isLandscape = totalSize.width >= totalSize.height;

  if (isLandscape) {
    final halfWidth = totalSize.width / 2;
    return ZoneRects(
      mode: OverlayLayoutMode.splitHorizontal,
      zoneA: Rect.fromLTWH(0, 0, halfWidth, totalSize.height),
      zoneB: Rect.fromLTWH(halfWidth, 0, halfWidth, totalSize.height),
    );
  } else {
    final halfHeight = totalSize.height / 2;
    return ZoneRects(
      mode: OverlayLayoutMode.splitVertical,
      zoneA: Rect.fromLTWH(0, 0, totalSize.width, halfHeight),
      zoneB: Rect.fromLTWH(0, halfHeight, totalSize.width, halfHeight),
    );
  }
}
