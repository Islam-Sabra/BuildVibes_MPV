// Review 113 (18) NN1 and (17): Need you now from the People list and a
// face, the sheet, its refusals, the Space's line, a call arriving with the
// app open; and the check-in nudge opening the composer filled.
import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/data/models/need_you.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/safety_repository.dart';
import 'package:buildvibes/features/spaces/need_you_notice.dart';
import 'package:buildvibes/features/spaces/need_you_sheet.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/check_in_samples.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/need_you_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';
import '../../helpers/safety_fakes.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _space = DaybookSamples.space;
const _omar = DaybookSamples.omar;
const _sara = DaybookSamples.sara;
const _mona = DaybookSamples.mona;

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

NeedYouCall _call({
  String id = 'c1',
  String from = DaybookSamples.islam,
  String to = _omar,
  NeedYouAnswer? answer,
  Duration ago = const Duration(minutes: 5),
}) => NeedYouCall(
  id: id,
  spaceId: _space,
  fromId: from,
  toId: to,
  fromName: 'Islam Ahmed',
  toName: 'Omar Haddad',
  reason: 'Concrete truck waiting',
  place: 'Gate 2',
  createdAt: DaybookSamples.thursday.subtract(ago),
  answer: answer,
);

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  SpacePass pass = SpacePass.lead,
  FakeNeedYouRepository? needYou,
  FakeSafetyRepository? safety,
  FakePushMessaging? push,
  FakeDaybookRepository? daybook,
  String path = '/spaces/$_space',
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository()
      ..details[_space] = s.detail(pass: pass)
      ..spacePeople[_space] = s.people(),
    daybook: daybook ?? (FakeDaybookRepository()..posts[_space] = s.d1()),
    needYou: needYou,
    safety: safety,
    push: push,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

Future<void> _person(WidgetTester tester, String id) async {
  await _tap(tester, _key('member-$id'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('NN1 from the People list: the person, a reason, a place, '
        'Need you now [$lang]', (tester) async {
      final needYou = FakeNeedYouRepository();
      await _open(
        tester,
        lang,
        needYou: needYou,
        path: '/spaces/$_space/people',
      );
      await _person(tester, _omar);
      await _tap(tester, _key('person-need-you'));
      expect(_key('need-you-sheet'), findsOneWidget);
      expect(find.textContaining(s.omarName), findsWidgets);
      expect(
        find.textContaining(l10n.needYouStrongNote('X').split('X').last.trim()),
        findsOneWidget,
      );
      Finder field(String k) =>
          find.descendant(of: _key(k), matching: find.byType(TextField));
      await tester.enterText(field('need-you-reason'), 'Truck waiting');
      await _tap(tester, _key('need-you-add-place'));
      await tester.enterText(field('need-you-place'), 'Gate 2');
      await tester.pumpAndSettle();
      await _tap(tester, _key('need-you-send'));
      final sent = needYou.sent.single;
      expect(sent.to, _omar);
      expect(sent.reason, 'Truck waiting');
      expect(sent.place, 'Gate 2');
      expect(_key('need-you-sheet'), findsNothing);
    });

    testWidgets('the reason and the place may stay empty [$lang]', (
      tester,
    ) async {
      final needYou = FakeNeedYouRepository();
      await _open(
        tester,
        lang,
        needYou: needYou,
        path: '/spaces/$_space/people',
      );
      await _person(tester, _omar);
      await _tap(tester, _key('person-need-you'));
      await _tap(tester, _key('need-you-send'));
      expect(needYou.sent.single.place, isNull);
    });

    testWidgets('hidden for myself, a Viewer, from a Viewer, across a block '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        safety: FakeSafetyRepository(
          blocked: const [
            BlockedPerson(id: _sara, firstName: 'Sara', lastName: 'M'),
          ],
        ),
        path: '/spaces/$_space/people',
      );
      Future<void> none(String id) async {
        await _person(tester, id);
        expect(_key('person-need-you'), findsNothing, reason: id);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      await none(DaybookSamples.islam);
      await none(_mona);
      await none(_sara);
    });

    testWidgets('I, a Viewer, can call nobody [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        pass: SpacePass.viewer,
        path: '/spaces/$_space/people',
      );
      await _person(tester, _omar);
      expect(_key('person-need-you'), findsNothing);
    });

    testWidgets('the 3-an-hour refusal in plain words; the sheet stays '
        '[$lang]', (tester) async {
      final needYou = FakeNeedYouRepository()
        ..refuseSend = const SpaceException(
          SpaceFailure.badInput,
          'at most 3 an hour',
        );
      await _open(
        tester,
        lang,
        needYou: needYou,
        path: '/spaces/$_space/people',
      );
      await _person(tester, _omar);
      await _tap(tester, _key('person-need-you'));
      await _tap(tester, _key('need-you-send'));
      expect(_key('need-you-sheet'), findsOneWidget);
      expect(_key('need-you-refused'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('need-you-refused')).data,
        contains(l10n.needYouTooMany('X').split('X').last.trim()),
      );
    });

    testWidgets('a block the other way: the server refuses, plainly [$lang]', (
      tester,
    ) async {
      final needYou = FakeNeedYouRepository()
        ..refuseSend = const SpaceException(SpaceFailure.notAllowed);
      await _open(
        tester,
        lang,
        needYou: needYou,
        path: '/spaces/$_space/people',
      );
      await _person(tester, _omar);
      await _tap(tester, _key('person-need-you'));
      await _tap(tester, _key('need-you-send'));
      expect(
        tester.widget<Text>(_key('need-you-refused')).data,
        contains(l10n.needYouRefused('X').split('X').last.trim()),
      );
    });

    testWidgets('from a face on a card: someone else\'s opens the sheet '
        '[$lang]', (tester) async {
      await _open(
        tester,
        lang,
        daybook: FakeDaybookRepository()..posts[_space] = [s.rebar()],
      );
      final faces = _key('slip-face');
      expect(faces, findsWidgets);
      await _tap(tester, faces);
      expect(_key('need-you-sheet'), findsOneWidget);
    });

    testWidgets('a Viewer\'s cards have no face to tap [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        pass: SpacePass.viewer,
        daybook: FakeDaybookRepository()..posts[_space] = [s.rebar()],
      );
      expect(_key('slip-face'), findsNothing);
    });

    testWidgets('the sender sees the answer in the Space; waiting first '
        '[$lang]', (tester) async {
      final needYou = FakeNeedYouRepository()..callsList.add(_call());
      await _open(tester, lang, needYou: needYou);
      expect(_key('need-you-call-c1'), findsOneWidget);
      expect(find.textContaining(l10n.needYouWaiting('')), findsOneWidget);
      expect(
        find.descendant(
          of: _key('need-you-call-c1'),
          matching: find.textContaining('Omar'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an answer arriving with the app open: the line changes and '
        'the sender is told [$lang]', (tester) async {
      final needYou = FakeNeedYouRepository()..callsList.add(_call());
      final push = FakePushMessaging();
      await _open(tester, lang, needYou: needYou, push: push);
      needYou.callsList
        ..clear()
        ..add(_call(answer: NeedYouAnswer.coming));
      push.arrive({
        'kind': needYouAnswerKind,
        'call_id': 'c1',
        'space_id': _space,
        'answer': 'coming',
        'name': 'Omar Haddad',
      });
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('need-you-call-c1'),
          matching: find.textContaining(l10n.needYouOnMyWay),
        ),
        findsOneWidget,
      );
      expect(_key('need-you-answered'), findsOneWidget);
    });

    testWidgets('a call I got, its notification gone: On my way in the Space '
        '[$lang]', (tester) async {
      final needYou = FakeNeedYouRepository()
        ..callsList.add(_call(from: _omar, to: DaybookSamples.islam));
      await _open(tester, lang, needYou: needYou);
      await _tap(tester, _key('need-you-coming-c1'));
      expect(needYou.answers, ['c1 coming']);
    });

    testWidgets('a need_you push with the app open is drawn in the server\'s '
        'words [$lang]', (tester) async {
      final push = FakePushMessaging();
      final app = await _open(tester, lang, push: push);
      expect(app.needYouNotices.channels, 1, reason: 'made at start');
      push.arrive({
        'kind': needYouKind,
        'call_id': 'c9',
        'space_id': _space,
        'tag': 'needyou:c9',
        'push_title': 'Omar Haddad needs you now',
        'push_body': 'Gate 2',
      });
      await tester.pumpAndSettle();
      final n = app.needYouNotices.shown.single;
      expect(n.title, 'Omar Haddad needs you now');
      expect(n.body, 'Gate 2');
      expect(n.id, 0);
      expect(n.tag, 'needyou:c9');
    });

    testWidgets('a tapped need_you push opens the Space (open=need_you) '
        '[$lang]', (tester) async {
      final push = FakePushMessaging();
      await _open(tester, lang, push: push, path: '/explore');
      push.tap({
        'kind': needYouKind,
        'route': '/spaces/$_space',
        'open': 'need_you',
        'space_id': _space,
        'call_id': 'c9',
      });
      await tester.pumpAndSettle();
      expect(_key('space-switch'), findsOneWidget);
    });

    testWidgets('(17) the nudge opens the composer filled from the last '
        'check-in [$lang]', (tester) async {
      final push = FakePushMessaging();
      final daybook = FakeDaybookRepository()
        ..posts[_space] = [CheckInSamples.card(lang)];
      final app = await _open(
        tester,
        lang,
        push: push,
        daybook: daybook,
        path: '/explore',
      );
      push.tap({
        'kind': 'check_in_nudge',
        'route': '/spaces/$_space',
        'open': 'check_in_nudge',
        'space_id': _space,
        'from_post_id': CheckInSamples.id,
      });
      await tester.pumpAndSettle();
      expect(_key('composer'), findsOneWidget);
      final d = ProviderScope.containerOf(
        tester.element(_key('composer')),
      ).read(daybookDraftProvider(_space))!;
      expect(d.kind, DaybookKind.checkIn);
      expect(d.title, s.t('Morning, Block B', 'صباح المبنى B'));
      expect(d.inTime, const DayTime(7, 0));
      expect(d.inAllow, 15);
      expect(d.outTime, const DayTime(14, 0));
      expect(d.daily, isTrue);
      expect(d.id, isNot(CheckInSamples.id), reason: 'a new post');
      expect(app.daybook.createdPosts, isEmpty, reason: 'nothing posted');
      // Lead's ruling: Same as last check-in; Send is on.
      expect(d.samePlaceAs, CheckInSamples.id);
      expect(d.siteLat, isNull);
      expect(d.readyToTry, isTrue);
      expect(find.text(l10n.checkInSamePlace), findsOneWidget);
      await tester.tap(_key('writing-post'));
      await tester.pumpAndSettle();
      final sent = app.checkIns.posted.single.toParams();
      expect(sent['p_same_place_as'], CheckInSamples.id);
      expect(sent['p_site_lat'], isNull);
      expect(sent['p_site_lng'], isNull);
      expect(sent.keys.last, 'p_same_place_as');
    });

    Future<void> nudged(WidgetTester tester, FakePushMessaging push) async {
      push.tap({
        'open': 'check_in_nudge',
        'space_id': _space,
        'from_post_id': CheckInSamples.id,
      });
      await tester.pumpAndSettle();
    }

    DaybookPostDraft draftOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ).read(daybookDraftProvider(_space))!;

    testWidgets('(17) the place line sets a new place instead, clearing '
        'Same as last check-in [$lang]', (tester) async {
      final push = FakePushMessaging();
      await _open(
        tester,
        lang,
        push: push,
        daybook: FakeDaybookRepository()
          ..posts[_space] = [CheckInSamples.card(lang)],
        path: '/explore',
      );
      await nudged(tester, push);
      await _tap(tester, _key('writing-check-in-place'));
      final d = draftOf(tester);
      expect(d.samePlaceAs, isNull);
      expect(d.siteSet, isTrue);
      expect(find.text(l10n.checkInSamePlace), findsNothing);
    });

    for (final failure in [SpaceFailure.notAllowed, SpaceFailure.badInput]) {
      testWidgets('(17) the server refuses the same place ($failure): a '
          'plain line, back to Set place here [$lang]', (tester) async {
        final push = FakePushMessaging();
        final app = await _open(
          tester,
          lang,
          push: push,
          daybook: FakeDaybookRepository()
            ..posts[_space] = [CheckInSamples.card(lang)],
          path: '/explore',
        );
        app.checkIns.refusePost = SpaceException(failure, 'refused');
        await nudged(tester, push);
        await _tap(tester, _key('writing-post'));
        final d = draftOf(tester);
        expect(d.samePlaceAs, isNull);
        expect(d.readyToTry, isFalse, reason: 'Send off until a place');
        // The refused Draft on Work opens with its line.
        await tester.tap(_key('writing-card-error'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text(l10n.checkInSetPlace), findsOneWidget);
        expect(find.text(l10n.checkInSamePlaceRefused), findsOneWidget);
        // A tap on the line sets the place.
        app.checkIns.refusePost = null;
        await _tap(tester, _key('writing-could-not-send'));
        expect(draftOf(tester).siteSet, isTrue);
        await _tap(tester, _key('writing-post'));
        expect(app.checkIns.posted.single.toParams()['p_site_lat'], isNotNull);
      });
    }

    testWidgets('(17) a half-written card stays [$lang]', (tester) async {
      final push = FakePushMessaging();
      final daybook = FakeDaybookRepository()
        ..posts[_space] = [CheckInSamples.card(lang)];
      await _open(tester, lang, push: push, daybook: daybook);
      await _tap(tester, _key('post-bar-notepad'));
      await tester.enterText(_key('writing-title'), 'My own words');
      await tester.pumpAndSettle();
      push.tap({
        'open': 'check_in_nudge',
        'space_id': _space,
        'from_post_id': CheckInSamples.id,
      });
      await tester.pumpAndSettle();
      final d = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      ).read(daybookDraftProvider(_space))!;
      expect(d.title, 'My own words');
    });
  }

  test('the Space line: what I got first, my own only for 2 hours', () {
    final now = DaybookSamples.thursday;
    final shown = needYouShown(
      [
        _call(id: 'old', ago: const Duration(hours: 3)),
        _call(id: 'mine'),
        _call(id: 'got', from: _omar, to: DaybookSamples.islam),
        _call(
          id: 'done',
          from: _omar,
          to: DaybookSamples.islam,
          answer: NeedYouAnswer.cant,
        ),
      ],
      DaybookSamples.islam,
      now,
    );
    expect([for (final c in shown) c.id], ['got', 'mine']);
  });

  test('a call as my_need_you_calls gives it', () {
    final c = NeedYouCall.fromJson({
      'id': 'c',
      'space_id': 's',
      'from_id': 'a',
      'from_name': 'Omar',
      'to_id': 'b',
      'to_name': null,
      'reason': null,
      'place': 'Gate 2',
      'created_at': '2026-11-01T10:00:00Z',
      'answer': 'cant',
      'answered_at': '2026-11-01T10:01:00Z',
    });
    expect(c.answer, NeedYouAnswer.cant);
    expect(c.toName, isNull);
    expect(c.answeredAt, isNotNull);
  });
}
