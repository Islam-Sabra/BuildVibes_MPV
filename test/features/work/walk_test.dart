// Slice 6 (review 77): walk mode (R1), a walk's card with a row per work
// item (R1b), and a row's own card.
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/work/walk_saved.dart';
import 'package:buildvibes/features/work/walk_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_undo_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/hold.dart';
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
  Map<String, Object> stored = const {},
  String? lostPhoto,
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
    stored: stored,
    lostPhoto: lostPhoto,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

Finder _key(String k) => find.byKey(Key(k));

/// Where the phone keeps Islam's walk in progress in the sample Space.
const _savedKey =
    'walk_in_progress:${DaybookSamples.islam}:${DaybookSamples.space}';

SavedWalk? _saved(TestApp app) {
  final raw = app.prefs.getString(_savedKey);
  return raw == null
      ? null
      : SavedWalk.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// A copy of the sample photo, as the app's folder keeps one.
String _keptCopy() => File(
  testPhotoPath,
).copySync('${Directory.systemTemp.createTempSync('bv_walk').path}/1.png').path;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The lead's rulings on 105A: Walk mode is in the camera, one tap from
/// Work: the post bar's camera opens Photo · Walk.
Future<void> _openWalk(WidgetTester tester) async {
  await _tap(tester, _key('post-bar-camera'));
  await _tap(tester, _key('camera-walk'));
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
      await _openWalk(tester);
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
      // Review 80: the picker has no "now" under the one chosen.
      await _tap(tester, _key('walk-owner'));
      expect(find.text(l10n.daybookOwnerNow), findsNothing);
      await _tap(
        tester,
        find.descendant(
          of: _key('walk-owner-picker'),
          matching: find.text(s.saraName),
        ),
      );
      await _tap(tester, _key('walk-finish'));
      await tester.pumpAndSettle();
      expect(find.byType(WalkScreen), findsNothing);

      // F95: the next walk in this Space starts where this one was.
      await _openWalk(tester);
      expect(
        tester.widget<TextField>(_key('walk-place')).controller?.text,
        'Level 4 corridor',
      );
      expect(
        tester.widget<TextField>(_key('walk-name')).controller?.text,
        isEmpty,
      );

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
      await _openWalk(tester);
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

    testWidgets('a Viewer has no Walk the site: no camera [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        me: DaybookSamples.mona,
        pass: SpacePass.viewer,
      );
      expect(_key('post-bar-camera'), findsNothing);
      await _tap(tester, _key('space-header'));
      expect(find.text(l10n.walkMenu), findsNothing);
    });

    testWidgets('the camera opens one choice at the bottom, Photo · Walk; '
        'Walk is not in Space info [$lang]', (tester) async {
      await _open(tester, lang, withWalk: false);
      await _tap(tester, _key('space-header'));
      expect(_key('info-walk'), findsNothing);
      expect(find.text(l10n.walkMenu), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tap(tester, _key('post-bar-camera'));
      expect(_key('camera-modes'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('camera-photo'),
          matching: find.text(l10n.cameraPhoto),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('camera-walk'),
          matching: find.text(l10n.cameraWalk),
        ),
        findsOneWidget,
      );
      // At the bottom, Photo first in the reading direction.
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getRect(_key('camera-modes')).bottom,
        greaterThan(size.height * 0.75),
      );
      final photo = tester.getCenter(_key('camera-photo')).dx;
      final walk = tester.getCenter(_key('camera-walk')).dx;
      expect(lang == 'ar' ? photo > walk : photo < walk, isTrue);
      await _tap(tester, _key('camera-walk'));
      expect(find.byType(WalkScreen), findsOneWidget);
    });

    testWidgets('Photo writes a work item with the photo, as the camera '
        'did [$lang]', (tester) async {
      await _open(tester, lang, withWalk: false);
      await _tap(tester, _key('post-bar-camera'));
      await _tap(tester, _key('camera-photo'));
      expect(_key('daybook-writing-card'), findsOneWidget);
      expect(_key('camera-modes'), findsNothing);
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

    testWidgets("review 94: a row's own card holds to check; CHECKED lands "
        'there at once, Undo on its sheet takes it back, and a hold let go '
        'through is sent [$lang]', (tester) async {
      final app = await _open(tester, lang);
      final done = _child(s);
      app.daybook.cardsById[_hanger] = DaybookCard(
        post: DaybookPost(
          id: _hanger,
          kind: DaybookPost.workItemKind,
          createdAt: done.post.createdAt,
          title: done.post.title,
          authorId: DaybookSamples.islam,
          authorName: s.islamName,
          parentId: _walk,
          item: DaybookItem(
            status: WorkStatus.done,
            ownerId: DaybookSamples.omar,
            ownerName: s.omarName,
            ref: 'KCT-031',
          ),
        ),
        proof: DaybookProof(
          at: DaybookSamples.thursday,
          byId: DaybookSamples.omar,
          byName: s.omarName,
          note: 'Fixed',
          outcome: DaybookOutcome(
            kind: DaybookOutcomeKind.done,
            at: DaybookSamples.thursday,
            byId: DaybookSamples.omar,
            byName: s.omarName,
          ),
        ),
        lastActivityAt: DaybookSamples.thursday,
        need: DaybookNeed.toCheck,
      );
      await _tap(tester, _key('target-row-$_hanger'));
      final sheet = _key('daybook-child-$_hanger');
      Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
      await hold(tester, inSheet(find.byKey(const Key('hold-check'))));
      expect(inSheet(find.text(l10n.daybookStampChecked)), findsOneWidget);
      expect(inSheet(find.text(l10n.daybookLineYouChecked)), findsOneWidget);
      expect(find.byType(BvUndoBar), findsOneWidget);
      // On the sheet, where it can be tapped.
      await tester.tap(find.byKey(const Key('undo-bar-action')));
      await tester.pumpAndSettle();
      expect(inSheet(find.text(l10n.daybookStampDone)), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(app.work.calls, isEmpty);
      await hold(tester, inSheet(find.byKey(const Key('hold-check'))));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(app.work.calls.single, 'check $_hanger');
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
      await _openWalk(tester);
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
    testWidgets('a refused walk: Try again sends it as it was, and Throw '
        'away asks first [$lang]', (tester) async {
      final daybook = FakeDaybookRepository()..refuseWalk = true;
      await _open(tester, lang, withWalk: false, daybook: daybook);
      await _openWalk(tester);
      await tester.enterText(_key('walk-name'), 'Walk, stairs');
      await tester.pumpAndSettle();
      await _tap(tester, _key('walk-start'));
      await tester.enterText(_key('walk-line-0'), 'Handrail loose');
      await tester.pumpAndSettle();
      await _owner(tester, s.omarName);
      await _tap(tester, _key('walk-finish'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.daybookCouldNotSend), findsOneWidget);
      expect(daybook.createdWalks, isEmpty);

      // Never a one-item Draft: its own choice.
      await _tap(tester, find.text('Walk, stairs'));
      expect(_key('walk-refused-menu'), findsOneWidget);
      daybook.refuseWalk = false;
      await _tap(tester, find.text(l10n.commonRetry));
      final walk = daybook.createdWalks.single;
      expect(walk.title, 'Walk, stairs');
      expect(walk.items.single.line, 'Handrail loose');
      expect(walk.items.single.ownerId, DaybookSamples.omar);
    });

    testWidgets('a refused walk thrown away leaves the daybook [$lang]', (
      tester,
    ) async {
      final daybook = FakeDaybookRepository()..refuseWalk = true;
      await _open(tester, lang, withWalk: false, daybook: daybook);
      await _openWalk(tester);
      await tester.enterText(_key('walk-name'), 'Walk, stairs');
      await tester.pumpAndSettle();
      await _tap(tester, _key('walk-start'));
      await tester.enterText(_key('walk-line-0'), 'Handrail loose');
      await tester.pumpAndSettle();
      await _owner(tester, s.omarName);
      await _tap(tester, _key('walk-finish'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Walk, stairs'));
      await _tap(tester, find.text(l10n.walkDiscard));
      expect(find.text(l10n.walkDiscardTitle), findsOneWidget);
      await _tap(tester, _key('bv-dialog-confirm'));
      expect(find.text('Walk, stairs'), findsNothing);
      expect(daybook.createdWalks, isEmpty);
    });

    testWidgets('P1: the walk is kept on the phone from the first photo: '
        'name, place, each photo, line and owner; Finish clears it '
        '[$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      final app = await _open(tester, lang, withWalk: false, daybook: daybook);
      await _openWalk(tester);
      await tester.enterText(_key('walk-name'), 'Walk, level 4');
      await tester.enterText(_key('walk-place'), 'Level 4 corridor');
      await tester.pumpAndSettle();
      expect(_saved(app), isNull);
      await _tap(tester, _key('walk-start'));
      await tester.enterText(_key('walk-line-0'), 'Hanger missing');
      await tester.pumpAndSettle();
      await _owner(tester, s.omarName);
      final saved = _saved(app)!;
      expect(saved.name, 'Walk, level 4');
      expect(saved.place, 'Level 4 corridor');
      expect(saved.camera, isFalse);
      final shot = saved.shots.single;
      expect(File(shot.local).existsSync(), isTrue);
      expect(shot.line, 'Hanger missing');
      expect(shot.ownerId, DaybookSamples.omar);
      expect(shot.ownerName, s.omarName);

      await _tap(tester, _key('walk-finish'));
      await tester.pumpAndSettle();
      expect(daybook.createdWalks.single.items.single.line, 'Hanger missing');
      expect(_saved(app), isNull);
    });

    testWidgets('P1: after Android closed the app with the camera open, the '
        'Space offers the walk; Continue brings it back with the photo the '
        'camera took [$lang]', (tester) async {
      final daybook = FakeDaybookRepository();
      final walk = SavedWalk(
        name: 'Walk, level 4',
        place: 'Level 4 corridor',
        shots: [
          SavedShot(
            local: _keptCopy(),
            at: DaybookSamples.thursday,
            line: 'Hanger missing',
            ownerId: DaybookSamples.omar,
            ownerName: s.omarName,
          ),
        ],
        camera: true,
      );
      final app = await _open(
        tester,
        lang,
        withWalk: false,
        daybook: daybook,
        stored: {_savedKey: jsonEncode(walk.toJson())},
        lostPhoto: testPhotoPath,
      );
      expect(find.text(l10n.walkInProgress), findsOneWidget);
      expect(
        find.descendant(
          of: _key('bv-dialog'),
          matching: find.textContaining('Walk, level 4'),
        ),
        findsOneWidget,
      );
      await _tap(tester, find.text(l10n.walkContinue));
      expect(find.byType(WalkScreen), findsOneWidget);
      // The lost photo is the second one, the owner staying for it.
      expect(_key('walk-thumb-1'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('walk-owner'),
          matching: find.text(s.omarName),
        ),
        findsOneWidget,
      );
      final saved = _saved(app)!;
      expect(saved.camera, isFalse);
      expect(saved.shots, hasLength(2));
      expect(saved.shots.first.line, 'Hanger missing');

      await tester.enterText(_key('walk-line-1'), 'Tray not earthed');
      await tester.pumpAndSettle();
      await _tap(tester, _key('walk-finish'));
      await tester.pumpAndSettle();
      final sent = daybook.createdWalks.single;
      expect(sent.title, 'Walk, level 4');
      expect(sent.place, 'Level 4 corridor');
      expect(
        [for (final i in sent.items) i.line],
        ['Hanger missing', 'Tray not earthed'],
      );
      expect(_saved(app), isNull);
    });

    testWidgets("P1: a lost photo is only a walk's when the walk was "
        'waiting for it [$lang]', (tester) async {
      final walk = SavedWalk(
        name: 'Walk, roof',
        shots: [
          SavedShot(
            local: _keptCopy(),
            at: DaybookSamples.thursday,
            line: 'Drain blocked',
          ),
        ],
      );
      final app = await _open(
        tester,
        lang,
        withWalk: false,
        stored: {_savedKey: jsonEncode(walk.toJson())},
        lostPhoto: testPhotoPath,
      );
      await _tap(tester, find.text(l10n.walkContinue));
      expect(_key('walk-thumb-0'), findsOneWidget);
      expect(_key('walk-thumb-1'), findsNothing);
      expect(_saved(app)!.shots, hasLength(1));
    });

    testWidgets('P1: Throw away asks first, then the walk and its photos are '
        'gone [$lang]', (tester) async {
      final photo = _keptCopy();
      final walk = SavedWalk(
        name: 'Walk, roof',
        shots: [
          SavedShot(local: photo, at: DaybookSamples.thursday, line: 'Drain'),
        ],
      );
      final app = await _open(
        tester,
        lang,
        withWalk: false,
        stored: {_savedKey: jsonEncode(walk.toJson())},
      );
      await _tap(tester, find.text(l10n.walkThrowAway));
      expect(find.text(l10n.walkDiscardTitle), findsOneWidget);
      expect(_saved(app), isNotNull);
      await _tap(tester, _key('bv-dialog-confirm'));
      // The phone's own file goes too (real file work, outside the test's
      // clock).
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && File(photo).existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      expect(_saved(app), isNull);
      expect(File(photo).existsSync(), isFalse);
      expect(find.byType(WalkScreen), findsNothing);
      expect(find.text(l10n.walkInProgress), findsNothing);
    });
  }
}
