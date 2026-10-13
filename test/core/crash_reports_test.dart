import 'package:buildvibes/core/crash/crash_reports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a crash report names the error type, never its message', () {
    final error = FormatException('Slab poured on level 3 by Omar Haddad');
    expect(crashSummary(error), 'FormatException');
    final scrubbed = ScrubbedError(crashSummary(error));
    expect(scrubbed.toString(), 'FormatException');
    expect(scrubbed.toString(), isNot(contains('Omar')));
  });

  test('works for any thrown value', () {
    expect(crashSummary(StateError('chat text')), 'StateError');
    expect(crashSummary('a plain string thrown'), 'String');
  });
}
