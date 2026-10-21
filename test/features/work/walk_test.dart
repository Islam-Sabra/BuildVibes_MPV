// Slice 6 (review 77): walk mode (R1), a walk's card with a row per work
// item (R1b), and a row's own card.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/walk_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _walk = '00000000-0000-4000-8000-000000000601';
const _hanger = '00000000-0000-4000-8000-000000000611';
const _tray = '00000000-0000-4000-8000-000000000612';

DaybookPost _walkPost(DaybookSamples s) => DaybookPost(
  id: _walk,
  kind: DaybookPost.workItemKind,
  createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
  title: s.t('Walk, level 4 corridor', 'جولة، ممر الدور 4'),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.islam,
    ownerName: s.islamName,
    ref: 'KCT-030',
  ),
  children: DaybookChildren(
    total: 2,
    checked: 0,
    target: true,
    rows: [
      DaybookChild(
        id: _hanger,
        title: s.t(
          'Hanger missing above door 4.12',
          'علاقة مفقودة فوق الباب 4.12',
        ),
        ownerId: DaybookSamples.omar,
        ownerName: s.omarName,
        need: DaybookNeed.toSign,
        coverPath: 'kct/posts/$_hanger/1.jpg',
      ),
      DaybookChild(
        id: _tray,
        title: s.t('Tray not earthed at riser', 'الحامل غير مؤرض عند الصاعد'),
        status: WorkStatus.done,
        ownerId: DaybookSamples.sara,
        ownerName: s.saraName,
        coverPath: 'kct/posts/$_tray/1.jpg',
      ),
    ],
  ),
);

DaybookCard _child(DaybookSamples s) => DaybookCard(
  post: DaybookPost(
    id: _hanger,
    kind: DaybookPost.workItemKind,
    createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
    title: s.t('Hanger missing above door 4.12', 'علاقة مفقودة فوق الباب 4.12'),
    authorId: DaybookSamples.islam,
    authorName: s.islamName,
    parentId: _walk,
    item: DaybookItem(
      status: WorkStatus.open,
      ownerId: DaybookSamples.omar,
      ownerName: s.omarName,
      ref: 'KCT-031',
    ),
  ),
  lastActivityAt: DaybookSamples.thursday.subtract(const Duration(hours: 1)),
  need: DaybookNeed.toSign,
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String me = DaybookSamples.islam,
  SpacePass pass = SpacePass.lead,
  bool withWalk = true,
  String path = '/spaces/${DaybookSamples.space}',
  FakeDaybookRepository? daybook,
}) async {
  final s = DaybookSamples(lang);
  final fake = daybook ?? FakeDaybookRepository();
  fake.posts[DaybookSamples.space] = [
    if (withWalk)
      DaybookCard(post: _walkPost(s), lastActivityAt: _walkPost(s).createdAt),
  ];
  fake.cardsById[_hanger] = _child(s);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: me == DaybookSamples.islam,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: fake,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String label) async {
  await _tap(tester, _key('space-more'));
  await _tap(tester, find.text(label));
}

Future<void> _owner(WidgetTester tester, String name) async {
  await _tap(tester, _key('walk-owner'));
  await _tap(
    tester,
    find.descendant(of: _key('walk-owner-picker'), matching: find.text(name)),
  );
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('R1: a walk of two photos goes as one walk, a work item per '
        'photo, each photo in its own work item [$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      await _open(tester, lang, withWalk: false, daybook: daybook);
      await _menu(tester, l10n.walkMenu);
      expect(find.byType(WalkScreen), findsOneWidget);
      // A name first.
      expect(
        tester
            .widget<TextButton>(
              find.descendant(
                of: _key('walk-start'),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(_key('walk-name'), 'Walk, level 4');
      await tester.enterText(_key('walk-place'), 'Level 4 corridor');
      await tester.pumpAndSettle();
      await _tap(tester, _key('walk-start'));
      // The first photo: its line and owner before the next.
      await tester.enterText(
        _key('walk-line-0'),
        'Hanger missing above door 4.12',
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('walk-shutter'));
      expect(find.text(l10n.walkNeedsOwner), findsOneWidget);
      await _owner(tester, s.omarName);
      await _tap(tester, _key('walk-shutter'));
      expect(_key('walk-thumb-1'), findsOneWidget);
      // The owner stays for the next photo.
      expect(
        find.descendant(
          of: _key('walk-owner'),
          matching: find.text(s.omarName),
        ),
        findsOneWidget,
      );
      await tester.enterText(_key('walk-line-1'), 'Tray not earthed');
      await tester.pumpAndSettle();
      await _owner(tester, s.saraName);
      await _tap(tester, _key('walk-finish'));
      await tester.pumpAndSettle();
      expect(find.byType(WalkScreen), findsNothing);

      final walk = daybook.createdWalks.single;
      expect(walk.title, 'Walk, level 4');
      expect(walk.place, 'Level 4 corridor');
      expect(
        [for (final i in walk.items) i.line],
        ['Hanger missing above door 4.12', 'Tray not earthed'],
      );
      expect(
        [for (final i in walk.items) i.ownerId],
        [DaybookSamples.omar, DaybookSamples.sara],
      );
      for (final i in walk.items) {
        expect(i.photo, contains('/posts/${i.id}/'));
      }
    });

    testWidgets('R1: Finish asks for a missing line; ✕ asks before throwing '
        'the photos away [$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      await _open(tester, lang, withWalk: false, daybook: daybook);
      await _menu(tester, l10n.walkMenu);
      await tester.enterText(_key('walk-name'), 'Walk, roof');
      await tester.pumpAndSettle();
      await _tap(tester, _key('walk-start'));
      await _tap(tester, _key('walk-finish'));
      expect(find.text(l10n.walkNeedsLine), findsOneWidget);
      expect(daybook.createdWalks, isEmpty);
      await _tap(tester, _key('walk-close'));
      expect(find.text(l10n.walkDiscardTitle), findsOneWidget);
      await _tap(tester, _key('bv-dialog-confirm'));
      expect(find.byType(WalkScreen), findsNothing);
      expect(daybook.createdWalks, isEmpty);
    });

    testWidgets('a Viewer has no Walk the site [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.mona,
        pass: SpacePass.viewer,
      );
      await _tap(tester, _key('space-more'));
      expect(find.text(l10n.walkMenu), findsNothing);
    });

    testWidgets('R1b: one card for the walk, a row per work item, N of M '
        'checked; Omar is asked to sign his row [$lang]', (tester) async {
      await _open(tester, lang, me: DaybookSamples.omar, pass: SpacePass.crew);
      expect(_key('target-rows-$_walk'), findsOneWidget);
      expect(_key('target-row-$_hanger'), findsOneWidget);
      expect(_key('target-row-$_tray'), findsOneWidget);
      expect(find.text(l10n.walkEachItem(2)), findsOneWidget);
      expect(find.text(l10n.pageUnderChecked(0, 2)), findsOneWidget);
      expect(
        find.descendant(
          of: _key('target-row-$_hanger'),
          matching: find.text(l10n.daybookSignAsDone),
        ),
        findsOneWidget,
      );
      // The walk itself asks nobody to sign it.
      expect(
        find.descendant(
          of: _key('daybook-card-$_walk'),
          matching: find.text(l10n.daybookSignAsDone),
        ),
        findsOneWidget,
      );
    });

    testWidgets('R1b: a row opens its own card, with its actions [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, me: DaybookSamples.omar, pass: SpacePass.crew);
      await _tap(tester, _key('target-row-$_hanger'));
      expect(_key('daybook-child-$_hanger'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('daybook-child-$_hanger'),
          matching: find.textContaining('KCT-031', findRichText: true),
        ),
        findsWidgets,
      );
    });

    testWidgets('a link to a walk\'s work item opens the walk and its card '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.omar,
        pass: SpacePass.crew,
        path: '/spaces/${DaybookSamples.space}?card=$_hanger',
      );
      expect(_key('daybook-child-$_hanger'), findsOneWidget);
      expect(find.text(l10n.daybookRemoved), findsNothing);
    });

    testWidgets('a walk waiting to send shows its rows from the phone '
        '[$lang]', (tester) async {
      final daybook = FakeDaybookRepository()..offline = true;
      await _open(tester, lang, withWalk: false, daybook: daybook);
      await _menu(tester, l10n.walkMenu);
      await tester.enterText(_key('walk-name'), 'Walk, stairs');
      await tester.pumpAndSettle();
      await _tap(tester, _key('walk-start'));
      await tester.enterText(_key('walk-line-0'), 'Handrail loose');
      await tester.pumpAndSettle();
      await _owner(tester, s.omarName);
      await _tap(tester, _key('walk-finish'));
      await tester.pumpAndSettle();
      expect(find.text('Walk, stairs'), findsOneWidget);
      expect(find.text('Handrail loose'), findsOneWidget);
      expect(find.text(l10n.daybookWaitingToSend), findsOneWidget);
    });
  }
}
