import 'package:flutter/widgets.dart';

import '../../core/l10n/bidi.dart';

/// A name people gave, on its own (a file in a list, a file page's
/// title), in its own direction (review 79 A4): a Latin name in an Arabic
/// list is cut at its own end, "Method statement, sl…", never
/// "…Method statement, sleeves". It still sits on the line's start side:
/// when its direction differs from the screen's, it aligns to its own end.
class BvNameText extends StatelessWidget {
  const BvNameText(this.text, {super.key, this.style, this.maxLines = 1});

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final own = directionOf(text);
    return Text(
      text,
      textDirection: own,
      textAlign: own == Directionality.of(context)
          ? TextAlign.start
          : TextAlign.end,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
