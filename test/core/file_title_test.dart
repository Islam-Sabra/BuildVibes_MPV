// The lead's check of review 103, D17 and D23: a file's name on rows,
// chips, titles and bubbles has no extension (the icon and "PDF" say the
// type), and keeps its own direction in a line.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:flutter_test/flutter_test.dart';

const _lri = '\u2066';
const _rli = '\u2067';
const _pdi = '\u2069';

void main() {
  test('an Arabic name: right to left, no ".pdf"', () {
    expect(
      fileTitle('مسح · الأربعاء 4 نوفمبر.pdf'),
      '$_rliمسح · الأربعاء 4 نوفمبر$_pdi',
    );
  });

  test('a Latin name: left to right, no ".pdf"', () {
    expect(fileTitle('A-501 Rev D.pdf'), '${_lri}A-501 Rev D$_pdi');
  });

  test('no extension, or a dot that is not one: the name as it is', () {
    expect(fileTitle('Permit'), '${_lri}Permit$_pdi');
    expect(fileTitle('Level 3.revised'), '${_lri}Level 3.revised$_pdi');
  });
}
