// The lead's check of review 115, small items done with review 116: the
// first-run tip says what a hold now opens (Pin, Reminder, Archive or
// Delete), and the post-audience sheet says "Whole Space", one word for
// the whole Space in the whole app.
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  // The lead's check of 116, P9: as the lead wrote it.
  test('the hold tip names what the hold bar holds', () {
    expect(en.obTipHold, 'Hold a card to pin it, set a reminder and more');
    expect(ar.obTipHold, 'اضغط مطولًا على البطاقة للتثبيت والتذكير والمزيد');
  });

  // P8: Arabic counts "and N more" as Arabic does.
  test('"and N more" in Arabic takes its plural', () {
    const names = 'لينا، طارق';
    expect(ar.pollNamesMore(names, 1), 'لينا، طارق وآخر');
    expect(ar.pollNamesMore(names, 2), 'لينا، طارق وآخران');
    expect(ar.pollNamesMore(names, 3), 'لينا، طارق و3 آخرين');
    expect(ar.pollNamesMore(names, 10), 'لينا، طارق و10 آخرين');
    expect(ar.pollNamesMore(names, 11), 'لينا، طارق و11 آخر');
    expect(en.pollNamesMore('Lina, Tariq', 2), 'Lina, Tariq and 2 more');
  });

  test('the post-audience sheet says Whole Space, never Everyone', () {
    expect(en.whoSeesEveryone, en.daybookWholeSpace);
    expect(ar.whoSeesEveryone, ar.daybookWholeSpace);
    expect(en.whoSeesFoot, 'Members see Whole Space and their own Teams only.');
    expect(ar.whoSeesFoot, 'الأعضاء يرون «المساحة كلها» وفرقهم فقط.');
    for (final t in [en.whoSeesEveryone, en.whoSeesFoot]) {
      expect(t, isNot(contains('Everyone')));
    }
  });

  // Review 116, Arabic wording (founder, 4 Nov 12:16): «صوّت» reads like
  // «صوت», the voice note. A poll is «استطلاع»; a vote is a choice.
  test('Arabic: a poll is «استطلاع» and a vote a choice', () {
    expect(ar.daybookKindPoll, 'استطلاع');
    expect(ar.cpNewPoll, 'استطلاع جديد');
    expect(ar.pollClose, 'أغلق الاستطلاع');
    // The hold bar's one word, as تثبيت، تعديل، أرشفة، حذف (four fit).
    expect(ar.pollCloseShort, 'إغلاق');
    expect(en.pollCloseShort, 'Close poll');
    expect(ar.pollVote, 'اعتمد اختياري');
    expect(ar.pollChangeVote, 'غيّر اختياري');
    expect(ar.pollTakeBack, 'ألغِ اختياري');
    expect(ar.pollNotYet('لينا'), 'لم يختر بعد: لينا');
    expect(ar.pollDecided, 'تقرّر');
    expect(ar.pollTied, 'تعادل');
    for (final t in [
      ar.cpAddPoll,
      ar.pollCloseTitle,
      ar.pollCloseBody,
      ar.activityPollNew('سارة', 'س'),
      ar.activityPollTied('س'),
      ar.activityPollClosed('س'),
      ar.obTipHold,
    ]) {
      expect(t, isNot(matches(RegExp('صوّت|صوت|تصويت|يصوّت'))), reason: t);
    }
  });
}
