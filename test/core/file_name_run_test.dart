// The lead's check of review 103, D17: a file's name keeps its direction
// in a line, its extension left to right after it.
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:flutter_test/flutter_test.dart';

const _lri = '\u2066';
const _rli = '\u2067';
const _pdi = '\u2069';

void main() {
  test('an Arabic name: the name right to left, ".pdf" left to right', () {
    expect(fileNameRun('إشعار 114.pdf'), '$_rliإشعار 114$_pdi$_lri.pdf$_pdi');
  });

  test('a Latin name: left to right, whole', () {
    expect(fileNameRun('A-501 Rev D.pdf'), '${_lri}A-501 Rev D.pdf$_pdi');
  });

  test('no extension: the name alone', () {
    expect(fileNameRun('Permit'), '${_lri}Permit$_pdi');
  });
}
