import 'package:flutter/painting.dart';

import '../../core/design/bv_tokens.dart';

/// How a due time reads (review 50 F34, F57): grey before its day, ink
/// on it, and the action colour once it has passed. A due is a reminder,
/// not a record: never red, which is kept for SENT BACK and real failures.
enum BvDueTone { quiet, today, passed }

/// The colour of a due in [tone].
Color bvDueColor(BvDueTone tone) => switch (tone) {
  BvDueTone.quiet => BvColors.textSecondary,
  BvDueTone.today => BvColors.textPrimary,
  BvDueTone.passed => BvColors.textAction,
};

/// A part of a line in its own style ([bvMarkedSpans]).
typedef BvMark = ({String part, TextStyle style});

/// [text] in [base], with each mark's part in the mark's style, found in
/// order. A part takes the whole run of letters it sits in, so an Arabic
/// word joined to a name or a pronoun ("لك", "وعمر") keeps one shape. A
/// part that isn't in the text is left out.
List<InlineSpan> bvMarkedSpans(
  String text,
  TextStyle base,
  List<BvMark> marks,
) {
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in marks) {
    if (m.part.isEmpty) continue;
    var start = text.indexOf(m.part, at);
    if (start < 0) continue;
    var end = start + m.part.length;
    while (start > at && !_breaks(text[start - 1])) {
      start--;
    }
    while (end < text.length && !_breaks(text[end])) {
      end++;
    }
    if (start > at) {
      spans.add(TextSpan(text: text.substring(at, start), style: base));
    }
    spans.add(TextSpan(text: text.substring(start, end), style: m.style));
    at = end;
  }
  if (at < text.length) {
    spans.add(TextSpan(text: text.substring(at), style: base));
  }
  return spans;
}

/// Where a run of letters ends: a space or a separator dot.
bool _breaks(String c) => c.trim().isEmpty || c == '·' || c == ',';
