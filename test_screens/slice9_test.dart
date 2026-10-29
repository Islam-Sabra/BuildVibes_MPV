// Slice 9, meeting notes into work items and the week report (review 85),
// against R3 (2540:34503), the Space menu (MN1 2566:35619) and MR1
// (2566:35515). No Arabic frames: the Arabic is built mirrored. The owner
// picker, Share in chat's thread list, the report's card in the chat and
// the empty week have no frames (review 85, question 3). English and
// Arabic, at 390 × 844 on a 12-hour phone, in the app's fonts.
// Run:
//   flutter test test_screens/slice9_test.dart --update-goldens
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/week_report.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/helpers/chat_fakes.dart';
import '../test/helpers/daybook_fakes.dart';
import '../test/helpers/daybook_samples.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/meeting_report_samples.dart';
import '../test/helpers/pump_app.dart';
import '../test/helpers/space_fakes.dart';
import '../test/helpers/week_report_fakes.dart';
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
/// `docs/screens/slice9/<name>_<lang>.png`.
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
      matchesGoldenFile('../docs/screens/slice9/${name}_$lang.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required String path,
  FakeChatRepository? chat,
  WeekReport? report,
}) async {
  final s = DaybookSamples(lang);
  final m = MeetingReportSamples(lang);
  await warmSamplePhoto(tester);
  final app = await pumpApp(
    tester,
    language: lang,
    now: MeetingReportSamples.now,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = [s.gate(), s.rebar()],
    chat: chat ?? m.chat(),
    weekReports: FakeWeekReportRepository(
      reports: {MeetingReportSamples.week: report ?? m.report()},
    ),
    overrides: [daybookPhotoProvider.overrideWith((ref, path) => samplePhoto)],
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(path);
  await tester.pumpAndSettle();
  return app;
}

Future<void> _pickOwner(WidgetTester tester, String name) async {
  await tester.tap(
    find
        .descendant(of: _key('meeting-owner-picker'), matching: find.text(name))
        .first,
  );
  await tester.pumpAndSettle();
}

const _space = '/spaces/${DaybookSamples.space}';
const _everyone = '$_space/chat/${MeetingReportSamples.everyone}';

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);

    testWidgets('R3: the hold menu, ticks and owners, the picker, posted '
        '[$lang]', (tester) async {
      await _open(tester, lang, path: _everyone);
      await tester.longPress(
        _key('chat-message-${MeetingReportSamples.meeting}'),
      );
      await tester.pumpAndSettle();
      await _snap(tester, 'R3-hold-menu', lang);
      await _tap(tester, _key('chat-action-meeting'));
      await _snap(tester, 'R3-meeting-notes', lang);
      await _tap(tester, _key('meeting-line-0'));
      await _snap(tester, 'R3-owner-picker', lang);
      await _pickOwner(tester, s.rakeshName);
      await _tap(tester, _key('meeting-line-1'));
      await _pickOwner(tester, s.linaName);
      await _tap(tester, _key('meeting-line-2'));
      await _pickOwner(tester, s.omarName);
      await _snap(tester, 'R3-ticked', lang);
      await _tap(tester, _key('meeting-post'));
      await _snap(tester, 'R3-posted', lang);
    });

    testWidgets('MR1 the week report [$lang]', (tester) async {
      await _open(tester, lang, path: _space);
      // Review 105 Part 1: the week report is in Space info; MN1 is gone.
      await _tap(tester, _key('space-header'));
      await _tap(tester, find.text(l10n.weekReportTitle));
      await _snap(tester, 'MR1-week-report', lang);
      await tester.drag(_key('week-list'), const Offset(0, -500));
      await tester.pumpAndSettle();
      await _snap(tester, 'MR1-week-report-end', lang);
    });

    testWidgets('MR1: an empty week, Share in chat, and its card in the chat '
        '[$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        path: '$_space/week',
        report: const WeekReport(),
      );
      await _snap(tester, 'MR1-empty', lang);
      await _tap(tester, _key('week-share'));
      await _snap(tester, 'MR1-share-in-chat', lang);
      await _tap(tester, _key('week-share-${MeetingReportSamples.everyone}'));
      final shared = app.weekReports.shared.single;
      app.chat.messagesByThread[MeetingReportSamples.everyone] = [
        ChatMessage(
          id: shared.id,
          threadId: MeetingReportSamples.everyone,
          kind: ChatKind.report,
          createdAt: DateTime(2026, 10, 15, 10, 50),
          authorId: DaybookSamples.islam,
          authorName: s.islamName,
          reportWeek: MeetingReportSamples.week,
        ),
        ...app.chat.messagesByThread[MeetingReportSamples.everyone]!,
      ];
      // The "Shared in Everyone" line goes first.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(Navigator).first)).push(_everyone);
      await tester.pumpAndSettle();
      await _snap(tester, 'MR1-card-in-chat', lang);
    });
  }
}
