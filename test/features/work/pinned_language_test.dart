// The lead's check of 105A, H2: a pinned announcement follows Work's one
// language. A tap opens it, a hold selects it (the bar at the bottom, as
// for a card); folding is on its own chevron at the start of its head, as
// in review 106 T2: ⌄ when open, › when folded (‹ in Arabic), a 44 tap
// area. In English and Arabic.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_pinned_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang, {
  required String me,
}) async {
  final s = DaybookSamples(lang);
  final post = s.halfDayPost();
  final daybook = FakeDaybookRepository()
    ..posts[DaybookSamples.space] = [
      DaybookCard(post: post, lastActivityAt: post.createdAt),
      s.rebar(),
    ]
    ..extrasBySpace[DaybookSamples.space] = DaybookExtras(pinned: [post]);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: daybook,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return daybook;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('H2 a pinned announcement [$lang]', () {
      testWidgets('in full: a tap opens it', (tester) async {
        await _open(tester, lang, me: DaybookSamples.omar);
        expect(find.byType(BvPinnedNote), findsOneWidget);
        await _tap(tester, find.text(s.halfDay));
        expect(_key('daybook-page'), findsOneWidget);
      });

      testWidgets('a hold selects it; a tap then lets it go', (tester) async {
        await _open(tester, lang, me: DaybookSamples.omar);
        await tester.longPress(find.byType(BvPinnedNote));
        await tester.pumpAndSettle();
        expect(_key('daybook-page'), findsNothing);
        expect(find.text(l10n.workSelected(1)), findsOneWidget);
        expect(_key('selection-bar'), findsOneWidget);
        expect(
          tester.widget<BvPinnedNote>(find.byType(BvPinnedNote)).selected,
          isTrue,
        );
        // Not mine: no Delete.
        expect(_key('select-delete'), findsNothing);
        await _tap(tester, find.text(s.halfDay));
        expect(_key('selection-bar'), findsNothing);
        expect(_key('daybook-page'), findsNothing);
      });

      testWidgets('its author\'s, folded: a tap on the line opens it; the '
          'chevron unfolds and folds it', (tester) async {
        final daybook = await _open(tester, lang, me: DaybookSamples.sara);
        expect(find.byType(BvPinnedLine), findsOneWidget);
        final fold = _key('pinned-fold');
        expect(
          find.descendant(
            of: fold,
            matching: find.byIcon(BvIcons.caretForward),
          ),
          findsOneWidget,
        );
        // A 24 chevron (its touch area reaches past it, rule 2).
        expect(tester.getSize(fold), const Size.square(BvSize.iconLg));
        // The chevron is at the start of the line.
        final line = tester.getRect(find.byType(BvPinnedLine));
        final chevron = tester.getRect(fold);
        expect(
          lang == 'ar' ? line.right - chevron.right : chevron.left - line.left,
          lessThan(line.width / 4),
        );
        await _tap(tester, fold);
        expect(find.byType(BvPinnedNote), findsOneWidget);
        expect(
          find.descendant(of: fold, matching: find.byIcon(BvIcons.caretDown)),
          findsOneWidget,
        );
        await _tap(tester, fold);
        expect(find.byType(BvPinnedLine), findsOneWidget);
        await _tap(tester, find.byType(BvPinnedLine));
        expect(_key('daybook-page'), findsOneWidget);
        expect(daybook.calls, isEmpty);
      });

      testWidgets('its author\'s, held: Delete is in the bar', (tester) async {
        final daybook = await _open(tester, lang, me: DaybookSamples.sara);
        await tester.longPress(find.byType(BvPinnedLine));
        await tester.pumpAndSettle();
        expect(
          tester.widget<BvPinnedLine>(find.byType(BvPinnedLine)).selected,
          isTrue,
        );
        await _tap(tester, _key('select-delete'));
        await _tap(tester, find.text(l10n.delete).last);
        expect(daybook.calls, contains('delete ${DaybookSamples.halfDayId}'));
      });
    });
  }
}
