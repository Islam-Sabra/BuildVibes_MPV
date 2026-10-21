import 'dart:convert';

import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_due_today_strip.dart';
import 'package:buildvibes/shared/widgets/bv_marked_text.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/work_fakes.dart';

/// Omar's Friday: the cable trays are his to sign, due today (L1).
Future<void> _open(
  WidgetTester tester,
  String lang, {
  required List<DaybookCard> posts,
  Map<String, Object> stored = const {},
  bool noSignal = false,
}) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    stored: stored,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.crew)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = posts
      ..calendar.add(s.cableTraysDue()),
    now: DateTime(2026, 10, 16, 9),
    // No signal: a sign-off made here waits on the phone.
    work: FakeWorkRepository()
      ..refuse = noSignal ? const SpaceException(SpaceFailure.network) : null,
    auth: FakeAuthRepository(userId: DaybookSamples.omar, phone: '+9655'),
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting());

  group('review 50 F34: who it is for stands out', () {
    test('the parts: the name or "you", and the due\'s tone', () {
      for (final lang in ['en', 'ar']) {
        final s = DaybookSamples(lang);
        final w = DaybookWords(
          lookupAppLocalizations(Locale(lang)),
          lang,
          use24: true,
        );
        final now = DateTime(2026, 10, 16, 9);
        final trays = s.cableTrays().post;
        final forOmar = w.metaMarks(trays, me: DaybookSamples.islam, now: now);
        expect(forOmar.who, s.omarName);
        expect(forOmar.tone, BvDueTone.today);
        final forMe = w.metaMarks(trays, me: DaybookSamples.omar, now: now);
        // "you" in "For you"; Arabic's "لك" is one word.
        expect(
          w.meta(trays, me: DaybookSamples.omar, now: now),
          contains(forMe.who),
        );
        final late = w.metaMarks(
          trays,
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 17, 9),
        );
        // F57: the action colour, never red, for its owner.
        expect(late.tone, BvDueTone.passed);
        expect(bvDueColor(late.tone), BvColors.textAction);
        // Someone else sees a passed due grey.
        expect(
          w
              .metaMarks(
                trays,
                me: DaybookSamples.rakesh,
                now: DateTime(2026, 10, 17, 9),
              )
              .tone,
          BvDueTone.quiet,
        );
        // F57: signed as done, the due leaves the card.
        final signed = trays.shownAs(status: WorkStatus.done);
        expect(
          w
              .metaMarks(
                signed,
                me: DaybookSamples.omar,
                now: DateTime(2026, 10, 17, 9),
              )
              .due,
          isNull,
        );
        expect(
          w.meta(signed, me: DaybookSamples.omar, now: now),
          isNot(
            contains(w.metaMarks(trays, me: DaybookSamples.omar, now: now).due),
          ),
        );
        final later = w.metaMarks(
          trays,
          me: DaybookSamples.omar,
          now: DateTime(2026, 10, 14, 9),
        );
        expect(later.tone, BvDueTone.quiet);
      }
    });

    test('a marked part takes its whole word, so Arabic stays joined', () {
      const base = TextStyle();
      const strong = TextStyle(fontWeight: FontWeight.w700);
      final spans = bvMarkedSpans('لعمر حداد · قبل الساعة 14:00', base, [
        (part: 'عمر حداد', style: strong),
      ]);
      expect((spans.first as TextSpan).text, 'لعمر حداد');
      expect((spans.first as TextSpan).style, strong);
      final en = bvMarkedSpans('For Omar Haddad · by today 14:00', base, [
        (part: 'Omar Haddad', style: strong),
        (part: 'by today 14:00', style: base),
      ]);
      expect(
        [for (final s in en) (s as TextSpan).text],
        ['For ', 'Omar Haddad', ' · ', 'by today 14:00'],
      );
    });

    for (final lang in ['en', 'ar']) {
      testWidgets('on the card: the name in the emphasis weight and the '
          'primary colour; today\'s due in the primary colour [$lang]', (
        tester,
      ) async {
        final s = DaybookSamples(lang);
        await _open(tester, lang, posts: [s.cableTrays()]);
        final fact = find.descendant(
          of: find.byKey(const Key('daybook-card-post-trays')),
          matching: find.byType(BvSlipFact),
        );
        final rich = tester
            .widgetList<RichText>(
              find.descendant(of: fact.first, matching: find.byType(RichText)),
            )
            .last;
        final spans = <TextSpan>[];
        rich.text.visitChildren((s) {
          if (s is TextSpan && s.text != null) spans.add(s);
          return true;
        });
        final type = lang == 'ar' ? BvType.arabic : BvType.latin;
        final who = spans.firstWhere(
          (s) =>
              s.style?.fontWeight == type.emphasis.fontWeight &&
              s.style?.color == BvColors.textPrimary,
        );
        expect(who.text, isNotEmpty);
        // The due is today: the primary colour, not grey.
        expect(
          spans.where(
            (s) =>
                s.style?.color == BvColors.textPrimary &&
                s.style?.fontWeight == type.bodyMd.fontWeight,
          ),
          isNotEmpty,
        );
      });
    }
  });

  group('review 50 F38: Due today is what is left to do', () {
    for (final lang in ['en', 'ar']) {
      final l10n = lookupAppLocalizations(Locale(lang));
      final s = DaybookSamples(lang);
      final strip = find.byType(BvDueTodayStrip);

      testWidgets('open: on the strip [$lang]', (tester) async {
        await _open(tester, lang, posts: [s.cableTrays()]);
        expect(find.text('${l10n.daybookToDo} · 1'), findsOneWidget);
      });

      testWidgets(
        'signed as done on the phone: off the strip at once [$lang]',
        (tester) async {
          final signOff = PendingItem(
            id: 'post-trays',
            spaceId: DaybookSamples.space,
            title: s.cableTraysTitle,
            ownerId: DaybookSamples.omar,
            ownerName: s.omarName,
            note: 'Done',
            madeAt: DateTime(2026, 10, 16, 8, 59),
          );
          await _open(
            tester,
            lang,
            posts: [s.cableTrays()],
            noSignal: true,
            stored: {
              'work_outbox:${DaybookSamples.omar}': jsonEncode([
                signOff.toJson(),
              ]),
            },
          );
          expect(strip, findsNothing);
        },
      );

      testWidgets('Done on the page: off the strip [$lang]', (tester) async {
        final trays = s.cableTrays();
        await _open(
          tester,
          lang,
          posts: [
            trays.copyWith(post: trays.post.shownAs(status: WorkStatus.done)),
          ],
        );
        expect(strip, findsNothing);
      });

      testWidgets('sent back: Open again, back on the strip [$lang]', (
        tester,
      ) async {
        final trays = s.cableTrays();
        await _open(
          tester,
          lang,
          posts: [
            trays.copyWith(
              history: [
                DaybookEvent(
                  id: 'sb',
                  kind: DaybookEventKind.sentBack,
                  at: DateTime(2026, 10, 16, 8),
                  byId: DaybookSamples.islam,
                  byName: s.islamName,
                ),
                ...trays.history,
              ],
            ),
          ],
        );
        expect(strip, findsOneWidget);
      });
    }
  });
}
