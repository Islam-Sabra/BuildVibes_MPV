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

  test('the hold tip names what the hold bar holds', () {
    expect(en.obTipHold, 'Hold a card to pin it, set a reminder, or archive '
        'or delete it.');
    expect(ar.obTipHold, 'اضغط مطوّلًا على البطاقة لتثبيتها أو ضبط تذكير أو '
        'أرشفتها أو حذفها.');
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
}
