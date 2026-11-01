// Review 109 CI2 (2706:39456 EN, 2706:39785 AR): a check_in_open push is
// drawn from the server's words exactly (plain ones when lock-screen text
// is off), with Check in (or Check out) · Open; Check in marks without
// opening the app once the warning was accepted, else it opens the app;
// the result comes back as a notification that names the post only when
// lock-screen text is on; a summary opens the creator's list. In English
// and Arabic.
import 'package:buildvibes/core/l10n/bv_time.dart';
import 'package:buildvibes/core/location/location_reader.dart';
import 'package:buildvibes/core/push/push_state.dart';
import 'package:buildvibes/data/models/check_in.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/work/check_in_marking.dart';
import 'package:buildvibes/features/work/check_in_notice.dart';
import 'package:buildvibes/features/work/check_in_phone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/check_in_fakes.dart';
import '../../helpers/check_in_samples.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/location_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Map<String, String> _open({
  String mark = 'in',
  String? pushTitle,
  String? pushBody,
}) => {
  'kind': checkInOpenKind,
  'post_id': CheckInSamples.id,
  'space_id': DaybookSamples.space,
  'mark': mark,
  'title': 'Morning, Block B',
  'space_name': 'Kuwait City Tower',
  'until': '2026-10-15T04:15:00Z',
  'tz': CheckInSamples.zone,
  'push_title': ?pushTitle,
  'push_body': ?pushBody,
  'channel_id': 'check_in',
  'tag': 'checkin:${CheckInSamples.id}:$mark',
};

void main() {
  test('only a check_in_open push is a check-in to draw', () {
    expect(CheckInPush.fromData(_open()), isNotNull);
    expect(CheckInPush.fromData({..._open(), 'kind': 'work_item'}), isNull);
    expect(CheckInPush.fromData({'kind': checkInOpenKind}), isNull);
  });

  test('a payload carries the ids, the post title and the zone back, and '
      'nothing about the person', () {
    final push = CheckInPush.fromData(_open(mark: 'out'))!;
    final back = CheckInPush.fromPayload(push.payload)!;
    expect(back.postId, CheckInSamples.id);
    expect(back.spaceId, DaybookSamples.space);
    expect(back.kind, CheckInMarkKind.checkOut);
    expect(back.postTitle, 'Morning, Block B');
    expect(back.zone, CheckInSamples.zone);
    expect(CheckInPush.fromPayload('note-1'), isNull);
    expect(push.notificationId, back.notificationId);
    expect(
      checkInNotificationId('p', CheckInMarkKind.checkIn),
      isNot(checkInNotificationId('p', CheckInMarkKind.checkOut)),
    );
  });

  test('option C: the app’s notification takes the server’s tag and id 0, '
      'so it replaces FCM’s own; on the check_in channel', () {
    final push = CheckInPush.fromData(_open())!;
    expect(push.tag, 'checkin:${CheckInSamples.id}:in');
    expect(push.notificationId, 0);
    expect(CheckInPush.fromPayload(push.payload)!.tag, push.tag);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final n = checkInOpenNotice(l10n, push, accepted: true);
    expect(n.id, 0);
    expect(n.tag, push.tag);
    final d = checkInNotificationDetails(l10n, n);
    expect(d.android!.channelId, 'check_in');
    expect(checkInChannelId, 'check_in');
    expect(d.android!.tag, 'checkin:${CheckInSamples.id}:in');
    expect(d.android!.importance, Importance.max);
    expect(d.android!.playSound, isTrue);
    expect(d.android!.actions!.map((a) => a.title), [
      l10n.checkInButton,
      l10n.checkInActionOpen,
    ]);
    expect(d.android!.actions!.first.showsUserInterface, isFalse);
    expect(d.android!.actions!.last.showsUserInterface, isTrue);
    expect(d.iOS!.interruptionLevel, InterruptionLevel.timeSensitive);
    expect(d.iOS!.categoryIdentifier, checkInCategoryIn);
    // The result replaces the same one.
    final r = checkInResultNotice(
      l10n,
      BvTime(l10n, 'en', use24: false),
      push,
      CheckInResult(
        day: DateTime(2026, 10, 15),
        kind: CheckInMarkKind.checkIn,
        mark: CheckInMark(
          at: CheckInSamples.at(6, 58),
          onTime: true,
          place: CheckInPlace.onSite,
        ),
      ),
      showText: false,
    );
    expect((r.id, r.tag), (0, push.tag));
    // Without a tag (an older server): its own id.
    final old = CheckInPush.fromData({..._open()}..remove('tag'))!;
    expect(old.notificationId, isNot(0));
  });

  test('iOS categories CHECK_IN_IN and CHECK_IN_OUT: both actions open the '
      'app', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final c = checkInDarwinCategories(l10n);
    expect(c.map((x) => x.identifier), ['CHECK_IN_IN', 'CHECK_IN_OUT']);
    expect(c.first.actions.map((a) => a.title), [
      l10n.checkInButton,
      l10n.checkInActionOpen,
    ]);
    for (final a in c.expand((x) => x.actions)) {
      expect(a.options, contains(DarwinNotificationActionOption.foreground));
    }
  });

  test('a summary opens the creator’s list; an open push the card', () {
    expect(
      checkInPushRoute({
        'kind': checkInSummaryKind,
        'post_id': 'p1',
        'space_id': 's1',
      }),
      '/spaces/s1/check-ins/p1',
    );
    expect(checkInPushRoute(_open()), contains(CheckInSamples.id));
    expect(checkInPushRoute({'kind': 'work_item'}), isNull);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final time = BvTime(l10n, lang, use24: false);

    group('CI2 [$lang]', () {
      test('drawn from push_title and push_body exactly, with Check in · '
          'Open; Check in runs without the app once accepted', () {
        final push = CheckInPush.fromData(
          _open(pushTitle: 'Check in: Morning', pushBody: 'Tower · by 7:15'),
        )!;
        final n = checkInOpenNotice(l10n, push, accepted: true);
        expect(n.title, 'Check in: Morning');
        expect(n.body, 'Tower · by 7:15');
        expect(n.category, checkInCategoryIn);
        expect(n.actions.map((a) => a.label), [
          l10n.checkInButton,
          l10n.checkInActionOpen,
        ]);
        expect(n.actions.first.opensApp, isFalse);
        expect(n.actions.last.opensApp, isTrue);
        expect(
          checkInOpenNotice(l10n, push, accepted: false).actions.first.opensApp,
          isTrue,
        );
      });

      test('lock-screen text off: the server’s plain words, never rebuilt '
          'from the title or the Space', () {
        final plain = CheckInPush.fromData(
          _open(pushTitle: l10n.checkInTimeIn, pushBody: ''),
        )!;
        final n = checkInOpenNotice(l10n, plain, accepted: true);
        expect(n.title, l10n.checkInTimeIn);
        expect(n.body, isNot(contains('Morning')));
        expect(n.body, isNot(contains('Kuwait')));
        // No words sent at all: the plain title, never the post's.
        final none = checkInOpenNotice(
          l10n,
          CheckInPush.fromData(_open(mark: 'out'))!,
          accepted: true,
        );
        expect(none.title, l10n.checkInTimeOut);
        expect(none.body, isEmpty);
        expect(none.category, checkInCategoryOut);
        expect(none.actions.first.label, l10n.checkOutButton);
      });

      group('the Check in action', () {
        late SharedPreferences prefs;
        late FakeCheckInRepository repo;
        late FakeLocationReader reader;
        late FakeCheckInNotifier notifier;
        final push = CheckInPush.fromData(_open())!;

        Future<CheckInResult?> act({
          bool accepted = true,
          bool showText = false,
        }) async {
          SharedPreferences.setMockInitialValues({
            if (accepted) checkInConsentKey('user-1'): true,
          });
          prefs = await SharedPreferences.getInstance();
          return markFromNotice(
            push: push,
            marker: CheckInMarker(
              repository: repo,
              reader: reader,
              prefs: prefs,
              userId: 'user-1',
            ),
            notifier: notifier,
            l10n: l10n,
            time: time,
            showText: () async => showText,
          );
        }

        setUp(() {
          repo = FakeCheckInRepository(now: () => CheckInSamples.at(6, 58));
          reader = FakeLocationReader();
          notifier = FakeCheckInNotifier();
        });

        test('accepted: the location read once and passed to the mark; the '
            'result in place of the notification, in plain words', () async {
          final r = await act();
          expect(r, isNotNull);
          expect(reader.reads, 1);
          expect(repo.marks.single.lat, isNotNull);
          final n = notifier.shown.single;
          expect(n.id, push.notificationId);
          expect(n.title, l10n.checkInChannel);
          expect(n.title, isNot(contains('Morning')));
          final clock = time.clock(
            DateTime.utc(
              2026,
              10,
              15,
              6,
              58,
            ).toLocal().copyWith(hour: 6, minute: 58),
          );
          expect(
            n.body,
            l10n.checkInResultIn(
              clock,
              '${l10n.checkInOnTime} · ${l10n.checkInOnSite}',
            ),
          );
        });

        test('lock-screen text on: the result names the post', () async {
          await act(showText: true);
          expect(notifier.shown.single.title, 'Morning, Block B');
        });

        test('the setting unknown: plain words', () async {
          SharedPreferences.setMockInitialValues({
            checkInConsentKey('user-1'): true,
          });
          prefs = await SharedPreferences.getInstance();
          await markFromNotice(
            push: push,
            marker: CheckInMarker(
              repository: repo,
              reader: reader,
              prefs: prefs,
              userId: 'user-1',
            ),
            notifier: notifier,
            l10n: l10n,
            time: time,
            showText: () async => throw Exception('offline'),
          );
          expect(notifier.shown.single.title, l10n.checkInChannel);
        });

        test('not accepted on this phone: nothing is read', () async {
          await act(accepted: false);
          expect(reader.reads, 0);
          expect(repo.marks.single.lat, isNull);
        });

        test('weak twice: location not shared, no error', () async {
          reader = FakeLocationReader([
            const LocationRead.miss(LocationMiss.weak),
          ]);
          await act();
          expect(reader.reads, 2);
          expect(repo.marks.single.lat, isNull);
          expect(notifier.shown.single.body, contains(l10n.checkInNotShared));
        });

        test('refused: why, in plain words', () async {
          repo.refuseMark = const SpaceException(
            SpaceFailure.badInput,
            'closed',
          );
          final r = await act();
          expect(r, isNull);
          expect(notifier.shown.single.body, l10n.checkInRefusedClosed);
        });
      });

      testWidgets('with the app open, the push is drawn as its notification', (
        tester,
      ) async {
        final s = DaybookSamples(lang);
        final app = await pumpApp(
          tester,
          language: lang,
          spaces: FakeSpaceRepository()
            ..details[DaybookSamples.space] = s.detail()
            ..spacePeople[DaybookSamples.space] = s.people(),
          daybook: FakeDaybookRepository(),
        );
        ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
            .read(pushArrivalProvider.notifier)
            .add(_open(pushTitle: 'T', pushBody: 'B'));
        await tester.pumpAndSettle();
        expect(app.notices.channels, greaterThan(0));
        final n = app.notices.shown.single;
        expect(n.title, 'T');
        expect(n.id, 0);
        expect(n.tag, 'checkin:${CheckInSamples.id}:in');
        expect(n.actions.first.label, l10n.checkInButton);
        // Not accepted yet on this phone: Check in opens the app.
        expect(n.actions.first.opensApp, isTrue);
      });

      testWidgets('a tap on the plain (system) notification opens the '
          'check-in, with Check in on it', (tester) async {
        final s = DaybookSamples(lang);
        final app = await pumpApp(
          tester,
          language: lang,
          spaces: FakeSpaceRepository()
            ..details[DaybookSamples.space] = s.detail(
              pass: SpacePass.crew,
              admin: false,
              timeZone: CheckInSamples.zone,
            )
            ..spacePeople[DaybookSamples.space] = s.people(),
          daybook: FakeDaybookRepository()
            ..posts[DaybookSamples.space] = [CheckInSamples.card(lang)],
          now: CheckInSamples.at(7, 0),
        );
        app.push.tap(_open(pushTitle: 'T', pushBody: 'B'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('check-in-card-${CheckInSamples.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('check-in-${CheckInSamples.id}')),
          findsOneWidget,
        );
      });
    });
  }
}
