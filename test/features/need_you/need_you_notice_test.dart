// Review 113 NN2: a need_you push is drawn from the server's words exactly,
// under its tag with id 0, on its own channel, with On my way · Can't now;
// an action answers and the result takes its place, in English and Arabic.
import 'package:buildvibes/data/models/need_you.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/spaces/need_you_notice.dart';
import 'package:buildvibes/features/spaces/need_you_phone.dart';
import 'package:buildvibes/features/work/check_in_notice.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/check_in_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/need_you_fakes.dart';

Map<String, String> _data({bool words = true}) => {
  'kind': needYouKind,
  'call_id': 'c1',
  'space_id': 's1',
  'tag': 'needyou:c1',
  'push_title': words ? 'Omar Haddad needs you now' : 'Someone needs you now',
  'push_body': words ? 'NBKCH Site · Gate 2, concrete truck waiting' : '',
};

void main() {
  test('only a need_you push with its ids is one to draw', () {
    expect(NeedYouPush.fromData(_data()), isNotNull);
    expect(NeedYouPush.fromData({..._data(), 'kind': 'work_item'}), isNull);
    expect(NeedYouPush.fromData({'kind': needYouKind}), isNull);
  });

  test('the payload carries ids and the tag, never the words', () {
    final push = NeedYouPush.fromData(_data())!;
    expect(push.payload, isNot(contains('Omar')));
    expect(push.payload, isNot(contains('Gate')));
    final back = NeedYouPush.fromPayload(push.payload)!;
    expect(back.callId, 'c1');
    expect(back.spaceId, 's1');
    expect(back.tag, 'needyou:c1');
    expect(NeedYouPush.fromPayload('check_in:{}'), isNull);
    expect(NeedYouPush.fromPayload('need_you:nonsense'), isNull);
  });

  test('without a tag in the data, the call\'s own', () {
    final data = _data()..remove('tag');
    expect(NeedYouPush.fromData(data)!.tag, 'needyou:c1');
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    test('NN2: exactly the server\'s words, id 0, its tag, both answers, '
        'none opening the app on Android [$lang]', () {
      final n = needYouNotice(l10n, NeedYouPush.fromData(_data())!);
      expect(n.title, 'Omar Haddad needs you now');
      expect(n.body, 'NBKCH Site · Gate 2, concrete truck waiting');
      expect(n.id, 0);
      expect(n.tag, 'needyou:c1');
      expect(n.category, needYouCategory);
      expect(
        [for (final a in n.actions) a.label],
        [l10n.needYouOnMyWay, l10n.needYouCantNow],
      );
      expect(n.actions.any((a) => a.opensApp), isFalse);
    });

    test('the lock-screen rule: plain words stay plain [$lang]', () {
      final n = needYouNotice(l10n, NeedYouPush.fromData(_data(words: false))!);
      expect(n.title, 'Someone needs you now');
      expect(n.body, '');
    });

    test('its own strong channel, under the tag [$lang]', () {
      final n = needYouNotice(l10n, NeedYouPush.fromData(_data())!);
      final android = needYouNotificationDetails(l10n, n).android!;
      expect(android.channelId, 'need_you');
      expect(android.importance, Importance.max);
      expect(android.playSound, isTrue);
      expect(android.tag, 'needyou:c1');
      expect(android.actions, hasLength(2));
      expect(android.actions!.first.showsUserInterface, isFalse);
      expect(
        needYouNotificationDetails(l10n, n).iOS!.interruptionLevel,
        InterruptionLevel.timeSensitive,
      );
    });

    test('iPhone: On my way · Can\'t now on NEED_YOU, opening the app '
        '[$lang]', () {
      final c = needYouDarwinCategories(l10n).single;
      expect(c.identifier, 'NEED_YOU');
      expect(
        [for (final a in c.actions) a.title],
        [l10n.needYouOnMyWay, l10n.needYouCantNow],
      );
      for (final a in c.actions) {
        expect(a.options, contains(DarwinNotificationActionOption.foreground));
      }
    });

    test('an action answers; the result replaces the notification, with no '
        'name [$lang]', () async {
      final repo = FakeNeedYouRepository();
      final notes = FakeCheckInNotifier();
      final push = NeedYouPush.fromData(_data())!;
      final ok = await answerFromNotice(
        push: push,
        answer: needYouAnswerOfAction(needYouActionComing)!,
        repository: repo,
        notifier: notes,
        l10n: l10n,
      );
      expect(ok, isTrue);
      expect(repo.answers, ['c1 coming']);
      final r = notes.shown.single;
      expect(r.tag, 'needyou:c1');
      expect(r.id, fcmNotificationId);
      expect(r.body, l10n.needYouYouAnswered(l10n.needYouOnMyWay));
      expect(r.title, isNot(contains('Omar')));
      expect(r.actions, isEmpty);
    });

    test('already answered, or no signal: said in place, never thrown '
        '[$lang]', () async {
      final repo = FakeNeedYouRepository()
        ..refuseAnswer = const SpaceException(
          SpaceFailure.badInput,
          'already answered',
        );
      final notes = FakeCheckInNotifier();
      final push = NeedYouPush.fromData(_data())!;
      await answerFromNotice(
        push: push,
        answer: NeedYouAnswer.cant,
        repository: repo,
        notifier: notes,
        l10n: l10n,
      );
      expect(notes.shown.last.body, l10n.needYouAlreadyAnswered);
      repo.refuseAnswer = const SpaceException(SpaceFailure.network);
      await answerFromNotice(
        push: push,
        answer: NeedYouAnswer.cant,
        repository: repo,
        notifier: notes,
        l10n: l10n,
      );
      expect(notes.shown.last.body, l10n.needYouAnswerFailed);
    });
  }

  group('who Need you now shows for', () {
    final s = DaybookSamples('en');
    SpaceDetail space(SpacePass pass) => s.detail(pass: pass);
    final people = s.people();

    test('another Lead or Crew in the Space', () {
      expect(
        mayCallNeedYou(
          space: space(SpacePass.crew),
          people: people,
          me: DaybookSamples.islam,
          target: DaybookSamples.omar,
        ),
        isTrue,
      );
    });

    test('never myself, a Viewer, from a Viewer, a former member, a block', () {
      bool may(
        SpacePass mine,
        String target, {
        Set<String> blocked = const {},
      }) => mayCallNeedYou(
        space: space(mine),
        people: people,
        me: DaybookSamples.islam,
        target: target,
        blocked: blocked,
      );
      expect(may(SpacePass.lead, DaybookSamples.islam), isFalse);
      expect(may(SpacePass.lead, DaybookSamples.mona), isFalse);
      expect(may(SpacePass.viewer, DaybookSamples.omar), isFalse);
      expect(may(SpacePass.lead, 'gone'), isFalse);
      expect(
        may(
          SpacePass.lead,
          DaybookSamples.omar,
          blocked: {DaybookSamples.omar},
        ),
        isFalse,
      );
    });
  });
}
