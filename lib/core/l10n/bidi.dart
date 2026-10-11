import 'package:intl/intl.dart' show Bidi;

/// Keeps a left-to-right run (a phone number, a dial code, an email) in one
/// piece and in order inside a right-to-left sentence: "+965 5000 0001"
/// instead of "0001 5000 965+". Uses the Unicode left-to-right embedding
/// marks (built from their code points); Flutter's text engine did not
/// honour the newer isolate marks on Android.
String ltrRun(String text) =>
    '${String.fromCharCode(_lre)}$text${String.fromCharCode(_pdf)}';

const _lre = 0x202A;
const _pdf = 0x202C;

/// Wraps [text] in its own direction (Arabic right to left, Latin left to
/// right), so mixed lines such as "أخصائي BIM · Gulf Build Co." keep each
/// part whole.
String inOwnDirection(String text) {
  final rtl = Bidi.startsWithRtl(text);
  final open = String.fromCharCode(rtl ? _rle : _lre);
  return '$open$text${String.fromCharCode(_pdf)}';
}

/// Joins parts of a meta line with " · ", each part in its own direction.
String joinMeta(Iterable<String> parts) =>
    parts.where((p) => p.isNotEmpty).map(inOwnDirection).join(' · ');

const _rle = 0x202B;
