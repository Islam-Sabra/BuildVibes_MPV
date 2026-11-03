import 'package:http/http.dart' as http;

/// Review 115 (5): some keyboards' "font" or "style" feature types Unicode
/// mathematical letters (𝑥𝑑𝑓𝑔ℎ, U+1D400–1D7FF) or fullwidth Latin
/// (U+FF21–FF5A) instead of plain letters, and the phone draws them in its
/// own maths font. This turns them, and the letterlike signs that fill that
/// block's gaps (ℎ, ℬ, ℂ…), back into plain letters and digits. Nothing else
/// changes: ², ³, °, ½, µ, ±, ×, Arabic and Arabic-Indic digits stay. No
/// general NFKC: it would turn m² into m2.
String plainLetters(String text) {
  if (!_maybe.hasMatch(text)) return text;
  final out = StringBuffer();
  for (final rune in text.runes) {
    final plain = _plain(rune);
    if (plain == null) {
      out.writeCharCode(rune);
    } else {
      out.write(plain);
    }
  }
  return out.toString();
}

/// Quick look before the work: a surrogate pair (where the maths block
/// lives), a letterlike sign or fullwidth Latin.
final _maybe = RegExp('[\uD835ℂ-ℴＡ-ｚ]');

String? _plain(int c) {
  // Latin letters: 13 styles of A–Z, a–z (U+1D400–1D6A3).
  if (c >= 0x1D400 && c <= 0x1D6A3) {
    final i = (c - 0x1D400) % 52;
    return String.fromCharCode(i < 26 ? 0x41 + i : 0x61 + i - 26);
  }
  if (c == 0x1D6A4) return 'i';
  if (c == 0x1D6A5) return 'j';
  // Greek: 5 styles of 58 (U+1D6A8–1D7C9).
  if (c >= 0x1D6A8 && c <= 0x1D7C9) return _greek[(c - 0x1D6A8) % 58];
  if (c == 0x1D7CA) return 'Ϝ';
  if (c == 0x1D7CB) return 'ϝ';
  // Digits: 5 styles of 0–9 (U+1D7CE–1D7FF).
  if (c >= 0x1D7CE && c <= 0x1D7FF) {
    return String.fromCharCode(0x30 + (c - 0x1D7CE) % 10);
  }
  if (c >= 0xFF21 && c <= 0xFF3A) return String.fromCharCode(0x41 + c - 0xFF21);
  if (c >= 0xFF41 && c <= 0xFF5A) return String.fromCharCode(0x61 + c - 0xFF41);
  return _letterlike[c];
}

/// One Greek style's 58, in the block's order.
final _greek = [
  ...'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡϴΣΤΥΦΧΨΩ'.split(''),
  '∇',
  ...'αβγδεζηθικλμνξοπρςστυφχψω'.split(''),
  ...'∂ϵϑϰϕϱϖ'.split(''),
];

/// The letterlike signs that stand in the maths block's gaps.
const _letterlike = {
  0x210E: 'h', // ℎ
  0x212C: 'B', 0x2130: 'E', 0x2131: 'F', 0x210B: 'H', 0x2110: 'I', //
  0x2112: 'L', 0x2133: 'M', 0x211B: 'R', 0x212F: 'e', 0x210A: 'g', //
  0x2134: 'o', 0x212D: 'C', 0x210C: 'H', 0x2111: 'I', 0x211C: 'R', //
  0x2128: 'Z', 0x2102: 'C', 0x210D: 'H', 0x2115: 'N', 0x2119: 'P', //
  0x211A: 'Q', 0x211D: 'R', 0x2124: 'Z',
};

/// Review 115 (5): every write to the database ([_writes] under
/// `/rest/v1/`) goes in plain letters, so whatever people type and save
/// (notebook, posts, work items, chat, messages, comments, names) is
/// plain. Uploads (multipart) and reads pass through as they are. It sits
/// under the Supabase client, which adds the session as before.
class PlainLettersClient extends http.BaseClient {
  PlainLettersClient(this._inner);

  final http.Client _inner;

  static const _writes = {'POST', 'PATCH', 'PUT'};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request &&
        _writes.contains(request.method) &&
        request.url.path.contains('/rest/v1/')) {
      final body = request.body;
      final plain = plainLetters(body);
      if (plain != body) request.body = plain;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
