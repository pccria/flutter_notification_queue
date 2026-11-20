import 'package:flutter/material.dart';

import '../../models/virtual_window_data.dart';

/// A transparent, pass-through visual boundary indicating an active
/// notification overlay canvas perimeter.
///
/// Wraps all contents in [IgnorePointer] to ensure 100% of pointer interactions
/// fall through to the underlying application UI.
///
/// Uses [BlurStyle.outer] to guarantee ZERO color or shadow paint inside the
/// canvas interior, keeping the underlying workbench UI at 100% natural
/// brightness and sharpness with no floating labels or obstructions.
class ZoneFrame extends StatelessWidget {
  const ZoneFrame({
    required this.window,
    required this.isActive,
    required this.isSplit,
    super.key,
  });

  final VirtualWindowData window;
  final bool isActive;
  final bool isSplit;

  @override
  Widget build(final BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _GlowBorderPainter(
            accentColor: window.accentColor,
            isActive: isActive,
            isSplit: isSplit,
          ),
          child: const SizedBox.expand(),
        ),
      );
}

/// Paints a subtle, semi-transparent perimeter border and soft ambient bloom.
///
/// Crucially, [BlurStyle.outer] draws only OUTSIDE the bounding [RRect],
/// completely eliminating any color wash or tint from the interior canvas.
class _GlowBorderPainter extends CustomPainter {
  const _GlowBorderPainter({
    required this.accentColor,
    required this.isActive,
    required this.isSplit,
  });

  final Color accentColor;
  final bool isActive;
  final bool isSplit;

  @override
  void paint(final Canvas canvas, final Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final insets = isSplit ? 4.0 : 6.0;
    final rect = Rect.fromLTWH(
      insets,
      insets,
      (size.width - (insets * 2)).clamp(0.0, double.infinity),
      (size.height - (insets * 2)).clamp(0.0, double.infinity),
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12.0));

    if (isActive) {
      // Gentle, subtle ambient bloom outside the border
      final bloomPaint = Paint()
        ..color = accentColor.withValues(alpha: isSplit ? 0.20 : 0.15)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8.0);
      canvas.drawRRect(rrect, bloomPaint);
    }

    // Crisp, subtle perimeter hairline with refined opacity
    final strokePaint = Paint()
      ..color = isActive
          ? accentColor.withValues(alpha: isSplit ? 0.60 : 0.45)
          : accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive ? 1.2 : 1.0;
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant final _GlowBorderPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isActive != isActive ||
      oldDelegate.isSplit != isSplit;
}
