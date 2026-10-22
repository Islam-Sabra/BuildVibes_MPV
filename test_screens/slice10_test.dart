// Slice 10, no signal and notifications (review 87), against OF
// (2544:35135), the note's menu (2557:35481) and A1 v3. The Remind me
// picker, the phone's reminder, F96's Settings line, F98's person card and
// the page editor's note have no frames (review 87, question 6): built
// from existing parts. English and Arabic, at 390 × 844 on a 12-hour
// phone, in the app's fonts.
// Run:
//   flutter test test_screens/slice10_test.dart --update-goldens
import 'dart:async';

import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/models/activity.dart';
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/settings/push_host.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/features/work/daybook_writing.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/activity_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/dm_fakes.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/notebook_fakes.dart';
import '../test/helpers/notebook_samples.dart';
import '../test/helpers/page_fakes.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/push_fakes.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/work_fakes.dart';
import 'shot.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Saves the app as it is now, at 390 × 844 and twice the pixels, to
/// `docs/screens/slice10/<name>_<lang>.png`.
Future<void> _snap(WidgetTester tester, String name, String lang) async {
  tester.view.physicalSize = shotSize * shotPixelRatio;
  tester.view.devicePixelRatio = shotPixelRatio;
  debugDisableShadows = false;
  ContextMenuController.removeAny();
  try {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('../docs/screens/slice10/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _go(WidgetTester tester, String path) async {
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
}

FakeSpaceRepository _spaces(DaybookSamples s) => FakeSpaceRepository()
  ..spaces.add(
    SpaceSummary(
      id: DaybookSamples.space,
      name: s.spaceName,
      pass: SpacePass.lead,
      isAdmin: true,
    ),
  )
  ..details[DaybookSamples.space] = s.detail()
  ..spacePeople[DaybookSamples.space] = s.people();

const _pagePost = '00000000-0000-4000-8000-000000000a01';
const _pageText = '00000000-0000-4000-8000-000000000a02';

DaybookPost _openItem(DaybookSamples s) => DaybookPost(
  id: _pagePost,
  kind: DaybookPost.workItemKind,
  createdAt: DaybookSamples.thursday.subtract(const Duration(hours: 2)),
  title: s.t(
    'Sleeves at grid C7 before the pour',
    'الجلب عند المحور C7 قبل الصب',
  ),
  body: s.t('Fix them before the pour.', 'ثبّتها قبل الصب.'),
  authorId: DaybookSamples.islam,
  authorName: s.islamName,
  item: DaybookItem(
    status: WorkStatus.open,
    ownerId: DaybookSamples.omar,
    ownerName: s.omarName,
    ref: 'KCT-021',
  ),
  hasPage: true,
);

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('OF: no signal: the strip, a send-back and a tick waiting '
        '[$lang]', (tester) async {
      await warmSamplePhoto(tester);
      final daybook = FakeDaybookRepository()
        ..posts[DaybookSamples.space] = s.d1()
        ..failMarks = 99;
      await pumpApp(
        tester,
        language: lang,
        now: DaybookSamples.thursday,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        spaces: _spaces(s),
        daybook: daybook,
        work: FakeWorkRepository()..failNext = 999,
        overrides: [
          daybookPhotoProvider.overrideWith((ref, path) => samplePhoto),
        ],
      );
      await _go(tester, '/spaces/${DaybookSamples.space}');
      final card = find.descendant(
        of: _key('daybook-card-post-sleeves'),
        matching: find.byType(BvSlip),
      );
      await tester.ensureVisible(card.first);
      await tester.pumpAndSettle();
      await tester.longPress(card.first);
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.descendant(
          of: _key('slip-menu'),
          matching: find.text(l10n.daybookSendBack),
        ),
      );
      await tester.tap(find.text(l10n.daybookReasonNotFinished));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _key('send-back-card'),
          matching: find.text(l10n.daybookSendBack),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('daybook-card-post-sleeves'));
      await tester.pumpAndSettle();
      await _snap(tester, 'OF-no-signal', lang);
    });

    testWidgets('page editor: no signal, and leaving asks first [$lang]', (
      tester,
    ) async {
      final pages = FakePageRepository()
        ..pages[_pagePost] = PostPage(
          post: _openItem(s),
          version: 1,
          blocks: [
            PageText(
              _pageText,
              s.t(
                'Check the sizes against the drawing.',
                'طابق المقاسات مع المخطط.',
              ),
            ),
          ],
        );
      await pumpApp(
        tester,
        language: lang,
        now: DaybookSamples.thursday,
        auth: FakeAuthRepository(
          userId: DaybookSamples.islam,
          phone: '+96550000001',
        ),
        spaces: _spaces(s),
        daybook: FakeDaybookRepository()
          ..posts[DaybookSamples.space] = [
            DaybookCard(
              post: _openItem(s),
              lastActivityAt: _openItem(s).createdAt,
            ),
          ],
        postPages: pages,
      );
      await _go(tester, '/spaces/${DaybookSamples.space}');
      await tester.longPress(
        find
            .descendant(
              of: _key('daybook-card-$_pagePost'),
              matching: find.byType(BvSlip),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.descendant(
          of: _key('slip-menu'),
          matching: find.text(l10n.pageEdit),
        ),
      );
      final field = find.descendant(
        of: _key('page-field-t:$_pageText'),
        matching: find.byType(EditableText),
      );
      await tester.enterText(
        field.first,
        s.t(
          'Check every sleeve against the drawing.',
          'طابق كل جلبة مع المخطط.',
        ),
      );
      await tester.pumpAndSettle();
      pages.offline = true;
      await _tap(tester, _key('page-done'));
      await _snap(tester, 'page-no-signal', lang);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      // Back: the sheet asks first.
      unawaited(Navigator.of(tester.element(_key('page-editor'))).maybePop());
      await tester.pumpAndSettle();
      await _snap(tester, 'page-leave', lang);
    });

    testWidgets('A1: the six daybook-post kinds in Activity [$lang]', (
      tester,
    ) async {
      ActivityRow row(
        String id,
        ActivityKind kind,
        String actor,
        String title,
        int minutesAgo,
      ) => ActivityRow(
        id: id,
        kind: kind,
        createdAt: testNow.subtract(Duration(minutes: minutesAgo)),
        spaceId: DaybookSamples.space,
        spaceName: s.spaceName,
        workItemTitle: title,
        spacePostId: 'post-$id',
        actorId: 'p-$id',
        actorName: actor,
        read: minutesAgo > 60,
      );
      await pumpApp(
        tester,
        language: lang,
        spaces: _spaces(s),
        activity: FakeActivityRepository(
          rows: [
            row(
              'a',
              ActivityKind.announcementNew,
              s.saraName,
              s.t('Concrete pour tomorrow', 'صب الخرسانة غدًا'),
              8,
            ),
            row(
              'b',
              ActivityKind.checklistForYou,
              s.islamName,
              s.t('Before the site walk', 'قبل جولة الموقع'),
              25,
            ),
            row(
              'c',
              ActivityKind.activityInvited,
              s.omarName,
              s.t('Site walk with the consultant', 'جولة موقع مع الاستشاري'),
              50,
            ),
            row(
              'd',
              ActivityKind.fileNewVersion,
              s.linaName,
              'A-501 Rev D',
              90,
            ),
            row(
              'e',
              ActivityKind.itemEdited,
              s.islamName,
              s.t('Sleeves at grid C7', 'الجلب عند المحور C7'),
              150,
            ),
            row(
              'f',
              ActivityKind.itemCancelled,
              s.saraName,
              s.t('Pump booking, Sunday', 'حجز المضخة، الأحد'),
              200,
            ),
          ],
        ),
      );
      await _tap(tester, _key('nav-activity'));
      await _snap(tester, 'A1-post-kinds', lang);
    });

    testWidgets('Remind me: the menu and the slip [$lang]', (tester) async {
      final n = NotebookSamples(lang);
      await pumpApp(
        tester,
        language: lang,
        now: NotebookSamples.now,
        notebook: FakeNotebookRepository(
          notes: [
            n.pinned(),
            n.todo().copyWith(remindAt: () => DateTime(2026, 10, 15, 16)),
            n.checklist(),
            n.voice(),
            n.yesterday(),
          ],
        ),
        overrides: [
          pickDueProvider.overrideWithValue(
            (context, {required now, day, at}) async =>
                (day: DateTime(2026, 10, 15), at: DateTime(2026, 10, 15, 16)),
          ),
        ],
      );
      await _go(tester, '/notebook');
      await tester.ensureVisible(_key('note-note-sleeves'));
      await tester.pumpAndSettle();
      await _snap(tester, 'NB-reminder-slip', lang);
      await tester.longPress(_key('note-note-walk'));
      await tester.pumpAndSettle();
      await _snap(tester, 'NB-remind-menu', lang);
    });

    testWidgets('F96: a day without a token, in Settings [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        push: FakePushMessaging(
          current: PushPermission.granted,
          tokenFailures: 99,
        ),
        stored: {
          pushNoTokenSinceKey: testNow
              .subtract(const Duration(hours: 25))
              .toUtc()
              .toIso8601String(),
        },
      );
      await _tap(tester, _key('nav-profile'));
      await _tap(tester, _key('profile-settings'));
      await _tap(tester, _key('row-notifications'));
      await _snap(tester, 'S3-not-yet', lang);
    });

    testWidgets('F98: the person card at the start of a conversation '
        '[$lang]', (tester) async {
      final now = DateTime(2026, 10, 15, 11);
      DmThreadPage page(DmState state) => DmThreadPage(
        threadId: 't-omar',
        person: DmPerson(
          id: 'p-omar',
          name: s.omarName,
          headline: s.t('Site Engineer', 'مهندس موقع'),
          company: s.t('Al Hamra Contracting', 'الحمراء للمقاولات'),
        ),
        state: state,
        sharedSpaceId: state == DmState.open ? DaybookSamples.space : null,
        sharedSpaceName: state == DmState.open ? s.spaceName : null,
        messages: [
          DmMessage(
            id: 'm1',
            fromMe: false,
            kind: ChatKind.text,
            createdAt: DateTime(2026, 10, 15, 10, 40),
            body: s.t('At the gate at 7?', 'عند البوابة الساعة 7؟'),
          ),
        ],
      );
      final dm = FakeDmRepository()..pages['t-omar'] = page(DmState.open);
      await pumpApp(tester, language: lang, dm: dm, now: now);
      await _go(tester, '/messages/t-omar');
      await _snap(tester, 'DM2-person-card', lang);
      dm.pages['t-omar'] = page(DmState.request);
      GoRouter.of(tester.element(_key('dm-messages'))).pop();
      await tester.pumpAndSettle();
      await _go(tester, '/messages/t-omar');
      await _snap(tester, 'DM6-request-card', lang);
    });
  }
}
