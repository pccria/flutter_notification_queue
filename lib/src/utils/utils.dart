import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class ColorUtils {
  ColorUtils._();
  static MaterialColor getMaterialColor(final Color color) {
    final int red = color.r.round() & 0xff;
    final int green = color.g.round() & 0xff;
    final int blue = color.b.round() & 0xff;

    final Map<int, Color> shades = {
      50: Color.fromRGBO(red, green, blue, .1),
      100: Color.fromRGBO(red, green, blue, .2),
      200: Color.fromRGBO(red, green, blue, .3),
      300: Color.fromRGBO(red, green, blue, .4),
      400: Color.fromRGBO(red, green, blue, .5),
      500: Color.fromRGBO(red, green, blue, .6),
      600: Color.fromRGBO(red, green, blue, .7),
      700: Color.fromRGBO(red, green, blue, .8),
      800: Color.fromRGBO(red, green, blue, .9),
      900: Color.fromRGBO(red, green, blue, 1),
    };

    return MaterialColor(color.toARGB32(), shades);
  }

  /// The grayscale conversion matrix.
  ///
  /// Extracting this as a constant prevents array allocation and matrix
  /// construction on every frame of the drag interaction.
  static const grayscaleFilter = ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

class Utils {
  Utils._();

  static TextDirection estimateDirectionOfText(final String text) {
    bool startsWithRtl(final String text) {
      const String ltrChars =
          r'A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02B8\u0300-\u0590'
          r'\u0800-\u1FFF\u2C00-\uFB1C\uFDFE-\uFE6F\uFEFD-\uFFFF';
      const String rtlChars = r'\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC';
      return RegExp('^[^$ltrChars]*[$rtlChars]').hasMatch(text);
    }

    final words = text.split(RegExp(r'\s+'));
    if (startsWithRtl(words.first)) {
      return TextDirection.rtl;
    } else {
      return TextDirection.ltr;
    }
  }

  static const String phone = 'phone';
  static const String tablet = 'tablet';
  static const String desktop = 'desktop';

  static const _Breakpoint _phoneBreakPoint = _Breakpoint(
    start: 0,
    end: 600,
    name: phone,
  );
  static const _Breakpoint _tabletBreakPoint = _Breakpoint(
    start: 601,
    end: 900,
    name: tablet,
  );

  /// Returns the current media query size without registering a build
  /// dependency on the [BuildContext]. Useful for preventing rebuilds
  /// during window resizing.
  static Size screenSize(final BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<MediaQuery>();
    final widget = element?.widget as MediaQuery?;
    return widget?.data.size ?? Size.zero;
  }

  static BoxConstraints horizontalConstraints(
    final BuildContext context, [
    final double? customMaxWidth,
  ]) =>
      horizontalConstraintsForWidth(
        screenSize(context).width,
        customMaxWidth,
      );

  static BoxConstraints horizontalConstraintsForWidth(
    final double width, [
    final double? customMaxWidth,
  ]) {
    final maxW = customMaxWidth ?? 360.0;
    return BoxConstraints(
      maxWidth: (width <= _phoneBreakPoint.end)
          ? (customMaxWidth != null
              ? customMaxWidth.clamp(0.0, width / 1.3)
              : width / 1.3)
          : (width <= _tabletBreakPoint.end)
              ? (customMaxWidth != null
                  ? customMaxWidth.clamp(0.0, width / 2)
                  : width / 2)
              : maxW,
    );
  }

  /// Reads OS-level insets (status bar, notch, home indicator) from
  /// [flutterView] without subscribing callers to [MediaQuery].
  static EdgeInsets viewPaddingOf(final FlutterView? flutterView) {
    if (flutterView == null) {
      return EdgeInsets.zero;
    }
    final ratio = flutterView.devicePixelRatio;
    final vp = flutterView.viewPadding;
    return EdgeInsets.fromLTRB(
      vp.left / ratio,
      vp.top / ratio,
      vp.right / ratio,
      vp.bottom / ratio,
    );
  }

  /// Computes the nominal global screen-space [Rect] for a widget of
  /// [childSize] docked at [alignment] inside [screenSize], honoring OS
  /// [viewPadding] and resolved [margin].
  static Rect nominalAlignedRect({
    required final AlignmentGeometry alignment,
    required final Size screenSize,
    required final Size childSize,
    final EdgeInsets viewPadding = EdgeInsets.zero,
    final EdgeInsetsGeometry margin = EdgeInsets.zero,
    final TextDirection textDirection = TextDirection.ltr,
  }) {
    final resolvedAlignment = alignment.resolve(textDirection);
    final resolvedMargin = margin.resolve(textDirection);

    final leftBoundary = viewPadding.left + resolvedMargin.left;
    final rightBoundary =
        screenSize.width - viewPadding.right - resolvedMargin.right;
    final topBoundary = viewPadding.top + resolvedMargin.top;
    final bottomBoundary =
        screenSize.height - viewPadding.bottom - resolvedMargin.bottom;

    final double x;
    if (resolvedAlignment.x < -0.5) {
      x = leftBoundary;
    } else if (resolvedAlignment.x > 0.5) {
      x = rightBoundary - childSize.width;
    } else {
      x = (screenSize.width - childSize.width) / 2;
    }

    final double y;
    if (resolvedAlignment.y < -0.5) {
      y = topBoundary;
    } else if (resolvedAlignment.y > 0.5) {
      y = bottomBoundary - childSize.height;
    } else {
      y = (screenSize.height - childSize.height) / 2;
    }

    return Rect.fromLTWH(x, y, childSize.width, childSize.height);
  }
}

/// Paints either a dashed or solid rounded rectangle stroke inside its canvas.
class DashedRRectBorderPainter extends CustomPainter {
  const DashedRRectBorderPainter({
    required this.borderRadius,
    required this.color,
    required this.strokeWidth,
    required this.dashed,
  });

  final BorderRadius borderRadius;
  final Color color;
  final double strokeWidth;
  final bool dashed;

  @override
  void paint(final Canvas canvas, final Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) {
      return;
    }
    final rrect = borderRadius.toRRect(rect.deflate(strokeWidth / 2));
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    if (!dashed) {
      canvas.drawRRect(rrect, paint);
      return;
    }

    const dashWidth = 7.0;
    const dashSpace = 5.0;
    final path = Path()..addRRect(rrect);
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashWidth, metric.length);
        dashedPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant final DashedRRectBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashed != dashed ||
      old.borderRadius != borderRadius;
}

@immutable
class _Breakpoint {
  const _Breakpoint({
    required this.start,
    required this.end,
    this.name,
    this.data,
  });
  final double start;
  final double end;
  final String? name;
  final dynamic data;

  _Breakpoint copyWith({
    final double? start,
    final double? end,
    final String? name,
    final dynamic data,
  }) =>
      _Breakpoint(
        start: start ?? this.start,
        end: end ?? this.end,
        name: name ?? this.name,
        data: data ?? this.data,
      );

  @override
  String toString() => 'Breakpoint(start: $start, end: $end, name: $name)';

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is _Breakpoint &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          name == other.name;

  @override
  int get hashCode => start.hashCode * end.hashCode * name.hashCode;
}
