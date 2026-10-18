import 'package:flutter/widgets.dart';

import '../../core/design/bv_tokens.dart';

/// The Daybook's paper slip: a torn top edge and rounded bottom corners
/// ("Daybook / Torn edge", 310 × 6). One shape, so a shadow follows the
/// tears, as Figma's drop shadow does.
///
/// The tear sits inside the top [edgeHeight] of the rect; content starts
/// below it. Three tear patterns (Figma draws three so neighbouring slips
/// don't look cut by one die); [BvSlipBorder.forId] picks one for a post,
/// the same in both languages.
class BvSlipBorder extends OutlinedBorder {
  const BvSlipBorder({
    this.variant = 0,
    this.edgeHeight = edgeHeightDefault,
    this.bottomRadius = BvRadius.slip,
    super.side,
  });

  factory BvSlipBorder.forId(
    String id, {
    double edgeHeight = edgeHeightDefault,
  }) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return BvSlipBorder(variant: h % _tears.length, edgeHeight: edgeHeight);
  }

  /// Figma: 6 on a slip, 7 on the Profile proof card.
  static const edgeHeightDefault = 6.0;
  static const edgeHeightProof = 7.0;

  final int variant;
  final double edgeHeight;
  final double bottomRadius;

  // The three tears from Figma, as (x of 310, y of 6) points; the first is
  // the published component.
  static const _width = 310.0;
  static const _height = 6.0;
  static const _tears = [
    [
      0,
      6,
      7,
      2,
      14,
      5,
      23,
      1,
      31,
      6,
      37,
      1,
      45,
      4,
      53,
      1,
      60,
      5,
      65,
      1,
      74,
      5,
      80,
      2,
      89,
      5,
      94,
      1,
      100,
      5,
      107,
      2,
      113,
      4,
      119,
      2,
      128,
      5,
      134,
      1,
      141,
      5,
      150,
      1,
      157,
      6,
      164,
      0,
      170,
      4,
      175,
      2,
      180,
      5,
      186,
      0,
      194,
      5,
      201,
      2,
      207,
      5,
      212,
      1,
      218,
      5,
      226,
      1,
      232,
      6,
      237,
      2,
      244,
      5,
      252,
      1,
      259,
      4,
      265,
      1,
      272,
      4,
      281,
      2,
      289,
      5,
      296,
      1,
      304,
      5,
      309,
      0,
      310,
      4,
    ],
    [
      0,
      6,
      9,
      1,
      15,
      6,
      23,
      0,
      29,
      6,
      37,
      0,
      44,
      6,
      52,
      1,
      58,
      5,
      66,
      1,
      73,
      6,
      81,
      1,
      87,
      4,
      95,
      0,
      100,
      5,
      107,
      1,
      116,
      5,
      124,
      1,
      131,
      4,
      137,
      0,
      146,
      6,
      153,
      1,
      158,
      5,
      166,
      2,
      174,
      5,
      179,
      0,
      186,
      5,
      194,
      0,
      201,
      5,
      207,
      2,
      216,
      5,
      222,
      1,
      229,
      4,
      238,
      1,
      246,
      5,
      254,
      1,
      262,
      5,
      268,
      1,
      274,
      6,
      282,
      2,
      288,
      4,
      297,
      2,
      303,
      4,
      310,
      1,
    ],
    [
      0,
      6,
      6,
      2,
      13,
      5,
      19,
      0,
      25,
      5,
      31,
      0,
      38,
      4,
      45,
      1,
      54,
      6,
      60,
      2,
      65,
      4,
      71,
      1,
      78,
      5,
      84,
      2,
      93,
      5,
      102,
      0,
      108,
      4,
      114,
      0,
      122,
      5,
      130,
      0,
      139,
      6,
      144,
      2,
      151,
      6,
      157,
      0,
      166,
      5,
      171,
      1,
      177,
      4,
      183,
      2,
      189,
      5,
      197,
      2,
      203,
      5,
      210,
      2,
      216,
      4,
      225,
      0,
      234,
      5,
      240,
      1,
      246,
      5,
      253,
      1,
      261,
      4,
      270,
      0,
      278,
      6,
      287,
      0,
      293,
      5,
      298,
      1,
      305,
      5,
      310,
      2,
    ],
  ];

  Path _path(Rect rect) {
    final tear = _tears[variant % _tears.length];
    final sx = rect.width / _width;
    final sy = edgeHeight / _height;
    final r = bottomRadius;
    final path = Path()..moveTo(rect.left, rect.top + tear[1] * sy);
    for (var i = 2; i < tear.length; i += 2) {
      path.lineTo(rect.left + tear[i] * sx, rect.top + tear[i + 1] * sy);
    }
    path
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(
        Offset(rect.right - r, rect.bottom),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - r),
        radius: Radius.circular(r),
      )
      ..close();
    return path;
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(top: edgeHeight);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect), side.toPaint());
  }

  @override
  BvSlipBorder copyWith({BorderSide? side}) => BvSlipBorder(
    variant: variant,
    edgeHeight: edgeHeight,
    bottomRadius: bottomRadius,
    side: side ?? this.side,
  );

  @override
  ShapeBorder scale(double t) => BvSlipBorder(
    variant: variant,
    edgeHeight: edgeHeight * t,
    bottomRadius: bottomRadius * t,
    side: side.scale(t),
  );

  @override
  bool operator ==(Object other) =>
      other is BvSlipBorder &&
      other.variant == variant &&
      other.edgeHeight == edgeHeight &&
      other.bottomRadius == bottomRadius &&
      other.side == side;

  @override
  int get hashCode => Object.hash(variant, edgeHeight, bottomRadius, side);
}
