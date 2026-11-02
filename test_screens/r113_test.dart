// Review 113 Part A, in English and Arabic at 390 × 844 in the app's fonts:
// ST1 the Spaces tab; a Space on Work; RX1 reactions, the picker, the names,
// the Share sheet; the hold bar; CV3 the composer, Discard, Type's grid, the
// long-press menu, recording, a card with a voice note. Run:
//   flutter test test_screens/r113_test.dart --update-goldens
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

/// Saves the app as it is now to `docs/screens/r113/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  debugDisableShadows = false;
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/r113/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _everyone = 'thread-all';
const _mep = 'thread-mep';

DaybookCard _with(
  DaybookCard c, {
  List<DaybookReactionGroup>? reactions,
  PostHold? hold,
  DaybookVoice? voice,
}) => c.copyWith(
  post: c.post.shownAs(reactions: reactions, hold: hold, voice: voice),
);

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = DaybookSamples(lang);

    List<DaybookReactionGroup> reacted() => [
      DaybookReactionGroup(
        kind: PostReaction.like,
        people: [
          DaybookPerson(id: DaybookSamples.sara, name: s.saraName),
          DaybookPerson(
            id: DaybookSamples.omar,
            name: s.nameOf(DaybookSamples.omar),
          ),
        ],
      ),
      DaybookReactionGroup(
        kind: PostReaction.bravo,
        people: [
          DaybookPerson(
            id: DaybookSamples.islam,
            name: s.nameOf(DaybookSamples.islam),
          ),
        ],
      ),
    ];

    Future<void> space(
      WidgetTester tester,
      List<DaybookCard> posts, {
      String composerKind = 'work_item',
    }) async {
      await pumpApp(
        tester,
        language: lang,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        composerKind: composerKind,
        spaces: FakeSpaceRepository()
          ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
          ..spacePeople[DaybookSamples.space] = s.people(),
        daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = posts,
        chat: FakeChatRepository(now: DaybookSamples.thursday)
          ..threadsBySpace[DaybookSamples.space] = [
            const ChatThread(id: _everyone),
            ChatThread(id: _mep, teamId: 'team-mep', teamName: 'MEP'),
          ],
        now: DaybookSamples.thursday,
      );
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).push('/spaces/${DaybookSamples.space}');
      await tester.pumpAndSettle();
    }

    Future<void> compose(WidgetTester tester) async {
      await space(tester, s.d1());
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(
        _key('writing-title'),
        s.t(
          'Fix the cracked tile at the stair',
          'إصلاح البلاطة المكسورة عند الدرج',
        ),
      );
      await tester.enterText(
        _key('writing-body'),
        s.t(
          'Two tiles near the landing, level 2. Same colour as the corridor.',
          'بلاطتان قرب بسطة الدرج، الدور 2. بنفس لون الممر.',
        ),
      );
      await tester.pumpAndSettle();
    }

    FakeSpaceRepository spaces() =>
        FakeSpaceRepository(now: testNow)
          ..spaces.addAll([
            SpaceSummary(
              id: 'space-1',
              name: s.t('NBKCH Site team', 'فريق موقع NBKCH'),
              pass: SpacePass.lead,
              isAdmin: true,
              needsYou: 2,
            ),
            SpaceSummary(
              id: 'space-2',
              name: s.t('Test site', 'موقع تجريبي'),
              pass: SpacePass.lead,
              isAdmin: true,
              needsYou: 1,
            ),
            SpaceSummary(
              id: 'space-3',
              name: s.t('Test site 2', 'موقع تجريبي 2'),
              pass: SpacePass.viewer,
              isAdmin: false,
            ),
          ]);

    NeedsCard need(String id, String space) => NeedsCard(
      kind: NeedsKind.forYou,
      spaceId: space,
      spaceName: space,
      at: testNow,
      workItemId: id,
      workItemTitle: 'Rebar',
    );

    testWidgets('ST1 the Spaces tab [$lang]', (tester) async {
      await pumpApp(
        tester,
        language: lang,
        spaces: spaces(),
        activity: FakeActivityRepository(
          cards: [
            need('i1', 'space-1'),
            need('i2', 'space-1'),
            need('i3', 'space-2'),
          ],
          today: [
            SpaceToday(
              spaceId: 'space-1',
              spaceName: 'x',
              change: SpaceChange.chat,
              at: testNow,
            ),
          ],
        ),
      );
      await _snap(tester, 'ST1_spaces_tab', lang);
    });

    testWidgets('ST1 with no Space [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await _snap(tester, 'ST1_empty', lang);
    });

    testWidgets('a Space opens on Work; cards with React · Share [$lang]', (
      tester,
    ) async {
      await space(tester, [_with(s.rebar(), reactions: reacted())]);
      await _snap(tester, 'RX1_cards', lang);
      await _tap(tester, _key('card-react-post-rebar'));
      await _snap(tester, 'RX1_picker', lang);
      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();
      await _tap(tester, _key('card-reactions-post-rebar'));
      await _snap(tester, 'RX1_names', lang);
    });

    testWidgets('the Share sheet [$lang]', (tester) async {
      await space(tester, [s.rebar()]);
      await _tap(tester, _key('card-share-post-rebar'));
      await _snap(tester, 'RX1_share', lang);
    });

    testWidgets('the hold bar: Delete [$lang]', (tester) async {
      await space(tester, [_with(s.rebar(), hold: PostHold.delete)]);
      await tester.longPress(_key('daybook-card-post-rebar'));
      await tester.pumpAndSettle();
      await _snap(tester, 'HOLD_delete', lang);
    });

    testWidgets('the hold bar: Archive, and its question [$lang]', (
      tester,
    ) async {
      await space(tester, [_with(s.rebar(), hold: PostHold.archive)]);
      await tester.longPress(_key('daybook-card-post-rebar'));
      await tester.pumpAndSettle();
      await _snap(tester, 'HOLD_archive', lang);
      await _tap(tester, _key('select-archive'));
      await _snap(tester, 'HOLD_archive_open', lang);
    });

    testWidgets('CV3 the composer, Discard, Type [$lang]', (tester) async {
      await compose(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _snap(tester, 'CV3_composer', lang);
      await _tap(tester, _key('writing-kind'));
      await _snap(tester, 'CV3_type', lang);
      await _tap(tester, _key('writing-kind'));
      await _tap(tester, _key('composer-discard'));
      await _snap(tester, 'CV3_discard', lang);
    });

    testWidgets('CV3 the long-press menu [$lang]', (tester) async {
      await compose(tester);
      await tester.longPress(_key('writing-body'));
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byTooltip(
          MaterialLocalizations.of(
            tester.element(_key('writing-body')),
          ).moreButtonTooltip,
        ),
      );
      await _snap(tester, 'CV3_long_press', lang);
    });

    testWidgets('CV3 the "/" menu [$lang]', (tester) async {
      await compose(tester);
      await tester.enterText(_key('writing-body'), '');
      await tester.pumpAndSettle();
      await tester.enterText(_key('writing-body'), '/');
      await tester.pumpAndSettle();
      await _snap(tester, 'CV3_slash', lang);
    });

    testWidgets('CV3 recording a voice note, and its chip [$lang]', (
      tester,
    ) async {
      await compose(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final hold = await tester.startGesture(
        tester.getCenter(_key('writing-mic')),
      );
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await _snap(tester, 'CV3_recording', lang);
      await hold.up();
      await tester.pumpAndSettle();
      await _snap(tester, 'CV3_voice_chip', lang);
    });

    testWidgets('a card with a voice note [$lang]', (tester) async {
      await space(tester, [
        _with(
          s.rebar(),
          voice: const DaybookVoice(
            path: 'space/posts/p/v.m4a',
            durationMs: 12000,
          ),
        ),
      ]);
      await _snap(tester, 'CV3_voice_card', lang);
    });
  }
}
