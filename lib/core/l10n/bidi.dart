import 'package:flutter/widgets.dart' show TextDirection;
import 'package:intl/intl.dart' show Bidi;

// Unicode isolates (review 20). Each wrapped value keeps its own direction
// and stays one piece, and the punctuation around it ("·", ":", "،")
// follows the sentence. The older embedding marks let a neutral between
// two English values join them into one run, so an Arabic line read
// "Omar Haddad: Gate 3 من KCT-005 بند جديد".
const _lri = 0x2066;
const _rli = 0x2067;
const _pdi = 0x2069;

/// Keeps a left-to-right run (a phone number, a dial code, an email, a
/// work item ref) in one piece and in order inside a right-to-left
/// sentence: "+965 5000 0001" instead of "0001 5000 965+".
String ltrRun(String text) =>
    '${String.fromCharCode(_lri)}$text${String.fromCharCode(_pdi)}';

/// Keeps a right-to-left run in one piece inside any line: an Arabic time
/// and its part of the day ("10:58 مساءً", review 50 F53), so the period
/// stays beside the time and never moves next to a Latin name.
String rtlRun(String text) =>
    '${String.fromCharCode(_rli)}$text${String.fromCharCode(_pdi)}';

/// Wraps [text] in its own direction (Arabic right to left, Latin left to
/// right). The shared helper for every value put into a sentence: a name,
/// a title, a Space, so mixed lines such as "أخصائي BIM · Gulf Build Co."
/// or "بند جديد KCT-005 من Omar Haddad: Gate 3" keep each part whole.
String inOwnDirection(String text) {
  final open = Bidi.startsWithRtl(text) ? _rli : _lri;
  return '${String.fromCharCode(open)}$text${String.fromCharCode(_pdi)}';
}

/// The dot between the parts of a meta line.
const metaDot = '·';

/// Joins parts of a meta line with " · ", each part in its own direction.
String joinMeta(Iterable<String> parts) =>
    parts.where((p) => p.isNotEmpty).map(inOwnDirection).join(' · ');

/// The direction of a text people wrote (a message, a note): from its first
/// strong letter, whatever the app language. An English message stays left
/// to right in the Arabic app, and the other way round.
TextDirection directionOf(String text) =>
    Bidi.startsWithRtl(text) ? TextDirection.rtl : TextDirection.ltr;
