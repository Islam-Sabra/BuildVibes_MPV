import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../design/bv_specs.dart';
import '../design/bv_tokens.dart';

/// The splash cube (review 91 addendum), drawn where the native splash
/// draws it: the centre of the screen, in the geometry of
/// assets/brand/bv_splash.svg. [progress] runs over [BvSplashSpec.loader]:
/// the outline traces itself, the faces fill and the outline fades into
/// them, then the B and V come in. At 1 it is the native splash's cube.
class SplashCubePainter extends CustomPainter {
  SplashCubePainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static double _part(double t, Duration from, Duration length) {
    final ms = t * BvSplashSpec.loader.inMicroseconds;
    return ((ms - from.inMicroseconds) / length.inMicroseconds).clamp(0, 1);
  }

  /// The outline drawn so far, 0 to 1.
  static double traceAt(double t) => BvSplashSpec.traceCurve.transform(
    _part(t, Duration.zero, BvSplashSpec.trace),
  );

  /// The faces filled, 0 to 1.
  static double fillAt(double t) =>
      _part(t, BvSplashSpec.trace, BvSplashSpec.fill);

  /// The letters in, 0 to 1.
  static double lettersAt(double t) =>
      _part(t, BvSplashSpec.trace + BvSplashSpec.fill, BvSplashSpec.letters);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final trace = traceAt(t);
    final fill = fillAt(t);
    final letters = lettersAt(t);

    canvas.save();
    // SVG units around the cube's centre (54, 56) to dp around the screen's
    // centre.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(BvSplashSpec.cubeUnit);
    canvas.translate(-_SplashCube.cx, -_SplashCube.cy);

    if (fill > 0) {
      // The faces fade in as one layer, over the whole hexagon, so no
      // terracotta hairline shows where two faces meet.
      canvas.saveLayer(
        _SplashCube.hexagon.getBounds(),
        Paint()..color = BvColors.brandCubeRight.withValues(alpha: fill),
      );
      canvas.drawPath(
        _SplashCube.hexagon,
        Paint()..color = BvColors.brandCubeRight,
      );
      for (final (face, colour) in _SplashCube.faces) {
        canvas.drawPath(face, Paint()..color = colour);
      }
      canvas.restore();
    }

    if (trace > 0 && fill < 1) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = BvSplashSpec.stroke / BvSplashSpec.cubeUnit
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = BvColors.brandCubeOutline.withValues(alpha: 1 - fill);
      canvas.drawPath(_SplashCube.outlineUpTo(trace), pen);
    }

    if (letters > 0) {
      final ink = Paint()
        ..color = BvColors.brandCubeLetters.withValues(alpha: letters);
      canvas.drawPath(_SplashCube.b, ink);
      canvas.drawPath(_SplashCube.v, ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashCubePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// The cube of bv_splash.svg in its own units (before the 0.72 group
/// scale, which [BvSplashSpec.cubeUnit] holds), ported by hand.
abstract final class _SplashCube {
  static const cx = 54.0;
  static const cy = 56.0;

  static const _top = Offset(54, 20);
  static const _topRight = Offset(86, 38);
  static const _bottomRight = Offset(86, 74);
  static const _bottom = Offset(54, 92);
  static const _bottomLeft = Offset(22, 74);
  static const _topLeft = Offset(22, 38);
  static const _centre = Offset(cx, cy);

  static Path _poly(List<Offset> points) => Path()..addPolygon(points, true);

  static final hexagon = _poly([
    _top,
    _topRight,
    _bottomRight,
    _bottom,
    _bottomLeft,
    _topLeft,
  ]);

  static final faces = [
    (_poly([_top, _topRight, _centre, _topLeft]), BvColors.brandCubeTop),
    (_poly([_topLeft, _centre, _bottom, _bottomLeft]), BvColors.brandCubeLeft),
    (
      _poly([_centre, _topRight, _bottomRight, _bottom]),
      BvColors.brandCubeRight,
    ),
  ];

  /// One pen line: the hexagon from the top, then the inner Y where the
  /// three faces meet.
  static final _outline = Path()
    ..moveTo(_top.dx, _top.dy)
    ..lineTo(_topRight.dx, _topRight.dy)
    ..lineTo(_bottomRight.dx, _bottomRight.dy)
    ..lineTo(_bottom.dx, _bottom.dy)
    ..lineTo(_bottomLeft.dx, _bottomLeft.dy)
    ..lineTo(_topLeft.dx, _topLeft.dy)
    ..close()
    ..moveTo(_topLeft.dx, _topLeft.dy)
    ..lineTo(_centre.dx, _centre.dy)
    ..lineTo(_topRight.dx, _topRight.dy)
    ..moveTo(_centre.dx, _centre.dy)
    ..lineTo(_bottom.dx, _bottom.dy);

  static final _metrics = _outline.computeMetrics().toList();
  static final _length = _metrics.fold<double>(0, (sum, m) => sum + m.length);

  /// The first [part] (0 to 1) of the pen line.
  static Path outlineUpTo(double part) {
    final drawn = Path();
    var left = _length * part;
    for (final m in _metrics) {
      if (left <= 0) break;
      drawn.addPath(m.extractPath(0, left.clamp(0, m.length)), Offset.zero);
      left -= m.length;
    }
    return drawn;
  }

  /// A letter's font outline (Plus Jakarta Sans ExtraBold, font units, y
  /// up) on its face: the SVG's matrix(1 [skewY] 0 1 [e] [f]), then
  /// translate([dx] 27) scale(0.023 -0.023).
  static Path _onFace(
    Path glyph, {
    required double skewY,
    required double e,
    required double f,
    required double dx,
  }) {
    const s = 0.023;
    // Column-major 4 × 4: x' = s·x + e + dx, y' = skewY·(s·x + dx) − s·y +
    // f + 27.
    final m = Float64List.fromList([
      s, skewY * s, 0, 0, //
      0, -s, 0, 0, //
      0, 0, 1, 0, //
      e + dx, f + skewY * dx + 27, 0, 1,
    ]);
    return glyph.transform(m);
  }

  static final b = _onFace(
    Path()
      ..moveTo(66, 0)
      ..lineTo(66, 745)
      ..lineTo(381, 745)
      ..quadraticBezierTo(497, 745, 561.5, 687.5)
      ..quadraticBezierTo(626, 630, 626, 527)
      ..quadraticBezierTo(626, 493, 613.5, 461)
      ..quadraticBezierTo(601, 429, 573, 402)
      ..quadraticBezierTo(622, 368, 639.5, 324.5)
      ..quadraticBezierTo(657, 281, 657, 232)
      ..quadraticBezierTo(657, 122, 584, 61)
      ..quadraticBezierTo(511, 0, 381, 0)
      ..close()
      ..moveTo(221, 465)
      ..lineTo(392, 465)
      ..quadraticBezierTo(428, 465, 449.5, 485.5)
      ..quadraticBezierTo(471, 506, 471, 540)
      ..quadraticBezierTo(471, 574, 449.5, 594.5)
      ..quadraticBezierTo(428, 615, 392, 615)
      ..lineTo(221, 615)
      ..close()
      ..moveTo(221, 135)
      ..lineTo(399, 135)
      ..quadraticBezierTo(446, 135, 474, 162)
      ..quadraticBezierTo(502, 189, 502, 232)
      ..quadraticBezierTo(502, 276, 474, 303)
      ..quadraticBezierTo(446, 330, 399, 330)
      ..lineTo(221, 330)
      ..close(),
    skewY: 0.5625,
    e: 22,
    f: 38,
    dx: 8.065,
  );

  static final v = _onFace(
    Path()
      ..moveTo(266, 0)
      ..lineTo(11, 745)
      ..lineTo(181, 745)
      ..lineTo(356, 200)
      ..lineTo(531, 745)
      ..lineTo(701, 745)
      ..lineTo(446, 0)
      ..close(),
    skewY: -0.5625,
    e: 54,
    f: 56,
    dx: 7.812,
  );
}
