// Review 105C part A, before / after (Part 7, SP7 2670:38703, AR
// 2670:38980): Before is the photo posted with the work item, After its
// Sign as done photo. When both exist they sit side by side with their
// times, and the stamp (CHECKED) is on After. In Arabic After is at the
// left. With only one, the card shows it as before. In English and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

final _posted = DateTime(2026, 10, 15, 8, 10);
final _signed = DateTime(2026, 10, 15, 10, 56);
final _checked = DateTime(2026, 10, 15, 11, 20);

/// The sleeves: posted with a photo at 8:10, signed with one at 10:56,
/// checked at 11:20 ([checked]); [cover] and [proof] say which photos.
DaybookCard _sleeves(
  DaybookSamples s, {
  bool cover = true,
  bool proof = true,
  bool checked = true,
}) => s.card(
  s.item(
    id: 'post-ba',
    at: _posted,
    title: s.sleeves,
    authorId: DaybookSamples.islam,
    ownerId: DaybookSamples.omar,
    status: checked ? WorkStatus.checked : WorkStatus.done,
    cover: cover ? '${DaybookSamples.space}/post-ba/before.jpg' : null,
  ),
  events: [
    s.event(
      'ev-ba-done',
      DaybookEventKind.done,
      _signed,
      DaybookSamples.omar,
      photos: [
        if (proof)
          const WorkPhoto(path: '${DaybookSamples.space}/ba/after.jpg'),
      ],
      note: proof ? null : 'Done',
    ),
    if (checked)
      s.event(
        'ev-ba-checked',
        DaybookEventKind.checked,
        _checked,
        DaybookSamples.islam,
      ),
  ],
);

Future<void> _open(
  WidgetTester tester,
  String lang,
  List<DaybookCard> posts,
) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.omar,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.crew)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  await scrollToRow(tester, _entry('post-ba'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);
    final clock = DaybookWords(l10n, lang, use24: false).time.clock;

    group('105C before / after [$lang]', () {
      testWidgets('both photos: side by side with their times', (tester) async {
        await _open(tester, lang, [_sleeves(s)]);
        final pair = find.descendant(
          of: _entry('post-ba'),
          matching: _key('before-after'),
        );
        expect(pair, findsOneWidget);
        expect(
          find.descendant(
            of: _key('photo-before'),
            matching: find.text(l10n.daybookBefore(clock(_posted))),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('photo-after'),
            matching: find.text(l10n.daybookAfter(clock(_signed))),
          ),
          findsOneWidget,
        );
        final before = tester.getRect(_key('photo-before'));
        final after = tester.getRect(_key('photo-after'));
        expect(before.top, after.top);
        expect(before.width, closeTo(after.width, 0.5));
        // In Arabic After is at the left.
        if (lang == 'ar') {
          expect(after.left, lessThan(before.left));
        } else {
          expect(before.left, lessThan(after.left));
        }
      });

      testWidgets('the CHECKED stamp is on After', (tester) async {
        await _open(tester, lang, [_sleeves(s)]);
        final stamp = find.descendant(
          of: _key('photo-after'),
          matching: find.byType(BvInkStamp),
        );
        expect(stamp, findsOneWidget);
        expect(
          find.descendant(
            of: _key('photo-before'),
            matching: find.byType(BvInkStamp),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: stamp,
            matching: find.text(l10n.daybookStampChecked),
          ),
          findsOneWidget,
        );
      });

      testWidgets('only the Sign as done photo: one photo, as before', (
        tester,
      ) async {
        await _open(tester, lang, [_sleeves(s, cover: false)]);
        expect(_key('before-after'), findsNothing);
        expect(
          find.descendant(of: _entry('post-ba'), matching: _key('slip-photo')),
          findsOneWidget,
        );
      });

      testWidgets('a proof with no photo: no pair', (tester) async {
        await _open(tester, lang, [_sleeves(s, proof: false)]);
        expect(_key('before-after'), findsNothing);
      });
    });
  }
}
