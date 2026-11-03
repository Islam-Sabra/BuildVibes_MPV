// Review 110 C (RM1d, 2707:39666): after Pick…, the When row shows only
// the picked time, one selected chip with ×; × brings back the
// suggestions. In the Reminder sheet and in Post later's. In English and
// Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/notebook/notebook_page_screen.dart'
    show reminderWhen;
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/later_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

final _now = DaybookSamples.thursday;
final _picked = DateTime(2026, 10, 20, 9, 30);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard>? cards,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = cards ?? s.d1(),
    now: _now,
    overrides: [
      pickDueProvider.overrideWithValue(
        (context, {required now, day, at}) async =>
            (day: DateTime(2026, 10, 20), at: _picked),
      ),
    ],
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);
    final words = DaybookWords(l10n, lang, use24: false);
    String pickedWords() => reminderWhen(l10n, words, _picked, _now);

    group('RM1d the Reminder sheet [$lang]', () {
      final post = s.item(
        id: 'post-formwork',
        at: _now.subtract(const Duration(hours: 2)),
        title: s.t('Formwork check, level 3', 'فحص القوالب، الطابق 3'),
        authorId: DaybookSamples.islam,
        ownerId: DaybookSamples.omar,
      );

      Future<void> remind(WidgetTester tester) async {
        await scrollToRow(tester, _entry(post.id));
        final slip = find
            .descendant(of: _entry(post.id), matching: find.byType(BvSlip))
            .first;
        await tester.longPress(slip);
        await tester.pumpAndSettle();
        await _tap(tester, _key('select-remind'));
      }

      testWidgets('Pick… leaves only the picked time, selected, with ×; × '
          'brings back the suggestions', (tester) async {
        await _open(tester, lang, cards: [s.card(post)]);
        await remind(tester);
        await _tap(tester, _key('reminder-pick'));
        expect(_key('reminder-picked'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('reminder-picked'),
            matching: find.text(pickedWords()),
          ),
          findsOneWidget,
        );
        expect(_key('reminder-tomorrow'), findsNothing);
        expect(_key('reminder-pick'), findsNothing);
        expect(find.bySemanticsLabel(l10n.rmClearTime), findsOneWidget);

        await _tap(tester, _key('reminder-picked-clear'));
        expect(_key('reminder-picked'), findsNothing);
        expect(_key('reminder-tomorrow'), findsOneWidget);
        expect(_key('reminder-pick'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('reminder-pick'),
            matching: find.text(l10n.rmPick),
          ),
          findsOneWidget,
        );
      });
    });

    group('RM1d Post later [$lang]', () {
      Future<void> later(WidgetTester tester) async {
        if (_key('writing-title').evaluate().isEmpty) {
          await _tap(tester, _key('post-bar-notepad'));
        }
        await tester.enterText(
          _key('writing-title'),
          s.t('Morning brief', 'إحاطة الصباح'),
        );
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-who'));
        await _tap(
          tester,
          find.descendant(
            of: find.byType(BvGiveToPicker),
            matching: find.text(s.omarName),
          ),
        );
        await openPostLater(tester);
      }

      testWidgets('Pick… leaves only the picked time; × brings back the '
          'suggestions', (tester) async {
        await _open(tester, lang);
        await later(tester);
        await _tap(tester, _key('later-pick'));
        expect(_key('later-picked'), findsOneWidget);
        expect(
          find.descendant(
            of: _key('later-picked'),
            matching: find.text(pickedWords()),
          ),
          findsOneWidget,
        );
        expect(_key('later-tomorrow'), findsNothing);
        expect(_key('later-workday'), findsNothing);
        expect(_key('later-pick'), findsNothing);

        await _tap(tester, _key('later-picked-clear'));
        expect(_key('later-picked'), findsNothing);
        expect(_key('later-tomorrow'), findsOneWidget);
        expect(_key('later-workday'), findsOneWidget);
        expect(_key('later-pick'), findsOneWidget);
      });
    });
  }
}
