// Review 96 F2: the kind word after a post's number ("· KCT-017 · note")
// is the kind chip's own word, in English and Arabic; a work item has
// none.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/work/daybook_draft.dart' show DaybookKind;
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    test('each kind\'s word is its chip\'s word [$lang]', () {
      for (final kind in DaybookKind.values) {
        final word = kindWord(l10n, kind.json);
        if (kind == DaybookKind.workItem) {
          expect(word, isNull, reason: 'a work item shows its number only');
          continue;
        }
        expect(
          word,
          l10n.daybookCardKindWord(kindName(l10n, kind).toLowerCase()),
          reason: kind.name,
        );
      }
    });

    test('the words, as read [$lang]', () {
      final en = lang == 'en';
      expect(kindWord(l10n, DaybookPost.noteKind), en ? '· note' : '· ملاحظة');
      expect(
        kindWord(l10n, DaybookPost.checklistKind),
        en ? '· checklist' : '· قائمة تحقق',
      );
      expect(
        kindWord(l10n, DaybookPost.announcementKind),
        en ? '· announcement' : '· إعلان',
      );
      expect(
        kindWord(l10n, DaybookPost.activityKind),
        en ? '· scheduled activity' : '· نشاط مجدول',
      );
      expect(kindWord(l10n, DaybookPost.fileKind), en ? '· file' : '· ملف');
      expect(
        kindWord(l10n, DaybookPost.reportKind),
        en ? '· daily report' : '· تقرير يومي',
      );
      expect(kindWord(l10n, DaybookPost.workItemKind), isNull);
    });
  }
}
