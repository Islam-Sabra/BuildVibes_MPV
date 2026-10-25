// The kind word after a post's number in its card header is the frozen
// prototype's (K1, K2 v13, K5, F74, R2; review 96, addendum): an
// announcement's word is its audience, a scheduled activity is
// "scheduled". Not the kind chip's words.
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final en = lang == 'en';

    test('the header words, as the prototype has them [$lang]', () {
      expect(l10n.daybookKindNoteWord, en ? '· note' : '· ملاحظة');
      expect(
        l10n.daybookKindChecklistWord,
        en ? '· checklist' : '· قائمة تحقق',
      );
      expect(l10n.daybookToEveryone, en ? '· to everyone' : '· للجميع');
      expect(l10n.daybookKindActivityWord, en ? '· scheduled' : '· مُجدول');
      expect(l10n.daybookKindFileWord, en ? '· file' : '· ملف');
      expect(
        l10n.daybookKindReportWord,
        en ? '· daily report' : '· تقرير يومي',
      );
    });
  }
}
