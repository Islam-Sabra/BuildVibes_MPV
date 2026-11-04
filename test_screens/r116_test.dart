// Review 116 (Poll), in English and Arabic at 390 × 844 in the app's fonts:
// PL1 the composer (question, options, One answer · More than one, Closes),
// PL2 an open poll on its card (bars and faces, the reader's choice, Not
// yet, Closes), PL3 closed: DECIDED with Make it a work item, TIED with the
// creator's pick, and Close poll in the hold bar. Run:
//   flutter test test_screens/r116_test.dart --update-goldens
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/poll.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_rows.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

const _space = DaybookSamples.space;
const _poll = 'post-poll';

/// Saves the app as it is now to `docs/reviews/shots-116/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/reviews/shots-116/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key).first);
  await tester.pumpAndSettle();
  await tester.tap(_key(key).first);
  await tester.pumpAndSettle();
}

DaybookCard _card(DaybookSamples s, DaybookPoll poll) => s.card(
  DaybookPost(
    id: _poll,
    kind: DaybookPost.pollKind,
    createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
    title: s.t(
      'Which day for the L3 slab pour?',
      'أي يوم لصبّ بلاطة الطابق 3؟',
    ),
    authorId: DaybookSamples.islam,
    authorName: s.islamName,
    poll: poll,
  ),
);

List<PollOption> _options(DaybookSamples s, {bool mine = false}) => [
  PollOption(
    id: 'opt-thu',
    label: s.t('Thursday', 'الخميس'),
    count: mine ? 3 : 2,
    mine: mine,
    voters: [
      if (mine) DaybookPerson(id: DaybookSamples.islam, name: s.islamName),
      DaybookPerson(id: DaybookSamples.omar, name: s.omarName),
      DaybookPerson(id: DaybookSamples.sara, name: s.saraName),
    ],
  ),
  PollOption(
    id: 'opt-sat',
    label: s.t('Saturday', 'السبت'),
    sort: 1,
    count: 1,
    voters: [DaybookPerson(id: DaybookSamples.rakesh, name: s.rakeshName)],
  ),
  PollOption(id: 'opt-sun', label: s.t('Sunday', 'الأحد'), sort: 2),
];

Future<void> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard> posts = const [],
  String composerKind = 'note',
}) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    composerKind: composerKind,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail()
      ..spacePeople[_space] = s.people(),
    daybook: FakeDaybookRepository()..posts[_space] = posts,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    testWidgets('PL1 composer [$lang]', (tester) async {
      await _open(tester, lang, composerKind: 'poll');
      await _tap(tester, 'post-bar-notepad');
      await tester.enterText(
        _key('writing-title'),
        s.t('Which day for the L3 slab pour?', 'أي يوم لصبّ بلاطة الطابق 3؟'),
      );
      await tester.enterText(
        _key('poll-option-field-0'),
        s.t('Thursday', 'الخميس'),
      );
      await tester.enterText(
        _key('poll-option-field-1'),
        s.t('Saturday', 'السبت'),
      );
      await _tap(tester, 'poll-add-option');
      steadyCursor();
      await tester.pumpAndSettle();
      await _snap(tester, 'PL1-composer', lang);
    });

    testWidgets('PL2 open poll [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          _card(
            s,
            DaybookPoll(
              closesAt: DaybookSamples.thursday.add(const Duration(hours: 6)),
              voted: true,
              options: _options(s, mine: true),
              notYet: [s.t('Lina', 'لينا'), s.t('Tariq', 'طارق')],
              notYetMore: 2,
            ),
          ),
        ],
      );
      await scrollToRow(tester, _key('daybook-card-$_poll'));
      await _snap(tester, 'PL2-open', lang);
    });

    // Review 116b V2: a tap picks (outlined, an empty tick); Change vote
    // sends it.
    testWidgets('PL2 picked, not sent [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          _card(
            s,
            DaybookPoll(
              closesAt: DaybookSamples.thursday.add(const Duration(hours: 6)),
              voted: true,
              options: _options(s, mine: true),
              notYet: [s.t('Lina', 'لينا'), s.t('Tariq', 'طارق')],
              notYetMore: 2,
            ),
          ),
        ],
      );
      await scrollToRow(tester, _key('daybook-card-$_poll'));
      await _tap(tester, 'poll-option-opt-sat');
      await scrollToRow(tester, _key('poll-vote'));
      await _snap(tester, 'PL2-picked', lang);
    });

    testWidgets('PL3 decided [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          _card(
            s,
            DaybookPoll(
              closedAt: DaybookSamples.thursday.subtract(
                const Duration(minutes: 5),
              ),
              closedByName: s.islamName,
              decidedOption: 'opt-thu',
              voted: true,
              options: _options(s),
            ),
          ),
        ],
      );
      await scrollToRow(tester, _key('daybook-card-$_poll'));
      await _snap(tester, 'PL3-decided', lang);
    });

    testWidgets('PL3 tied [$lang]', (tester) async {
      final o = _options(s);
      await _open(
        tester,
        lang,
        posts: [
          _card(
            s,
            DaybookPoll(
              closedAt: DaybookSamples.thursday.subtract(
                const Duration(minutes: 5),
              ),
              closedByName: s.islamName,
              tied: true,
              voted: true,
              options: [
                o[0],
                PollOption(
                  id: o[1].id,
                  label: o[1].label,
                  sort: 1,
                  count: 2,
                  voters: [
                    ...o[1].voters,
                    DaybookPerson(id: DaybookSamples.lina, name: s.linaName),
                  ],
                ),
                o[2],
              ],
            ),
          ),
        ],
      );
      await scrollToRow(tester, _key('daybook-card-$_poll'));
      await _snap(tester, 'PL3-tied', lang);
    });

    // The lead's check, P5: Edit for its creator before the first vote.
    testWidgets('PL1 Edit in the hold bar [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          _card(
            s,
            DaybookPoll(
              closesAt: DaybookSamples.thursday.add(const Duration(hours: 6)),
              options: [
                for (final o in _options(s))
                  PollOption(id: o.id, label: o.label, sort: o.sort),
              ],
            ),
          ),
        ],
      );
      final entry = _key('daybook-card-$_poll');
      await scrollToRow(tester, entry);
      await tester.longPress(
        find.descendant(of: entry, matching: find.byType(BvSlip)).first,
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'PL1-edit-hold', lang);
      await _tap(tester, 'select-edit-poll');
      steadyCursor();
      await tester.pumpAndSettle();
      await _snap(tester, 'PL1-edit', lang);
    });

    testWidgets('PL3 Close poll in the hold bar [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        posts: [
          _card(
            s,
            DaybookPoll(
              closesAt: DaybookSamples.thursday.add(const Duration(hours: 6)),
              voted: true,
              options: _options(s),
            ),
          ),
        ],
      );
      final entry = _key('daybook-card-$_poll');
      await scrollToRow(tester, entry);
      await tester.longPress(
        find.descendant(of: entry, matching: find.byType(BvSlip)).first,
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'PL3-close-hold', lang);
      await _tap(tester, 'select-close-poll');
      await _snap(tester, 'PL3-close-ask', lang);
    });
  }
}
