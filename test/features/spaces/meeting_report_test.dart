// Slice 9 (review 85): meeting notes into work items (R3) and the week
// report (MR1), with Share in chat, in English and Arabic.
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/week_report.dart';
import 'package:buildvibes/features/chat/meeting_notes_screen.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/daybook_target.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/meeting_report_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/week_report_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  SpacePass pass = SpacePass.lead,
  FakeChatRepository? chat,
  FakeWeekReportRepository? reports,
  String? path,
}) async {
  final s = DaybookSamples(lang);
  final m = MeetingReportSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    now: MeetingReportSamples.now,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(
        pass: pass,
        admin: pass == SpacePass.lead,
      )
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()..posts[DaybookSamples.space] = const [],
    chat: chat ?? m.chat(),
    weekReports: reports,
  );
  _router(tester).push(
    path ??
        '/spaces/${DaybookSamples.space}/chat/${MeetingReportSamples.everyone}',
  );
  await tester.pumpAndSettle();
  return app;
}

/// Scrolls the week report until [key] shows.
Future<void> _seen(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    _key(key),
    200,
    scrollable: find
        .descendant(of: _key('week-list'), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pickOwner(WidgetTester tester, String name) async {
  await tester.tap(
    find
        .descendant(of: _key('meeting-owner-picker'), matching: find.text(name))
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('meeting notes: the first line is the title, list marks go, blank '
      'lines are skipped, a long line is cut at a word', () {
    final notes = meetingNotes(
      'Coordination meeting\n\n- Raise the duct\n• Send the schedule\n'
      '2) Order sleeves\n${List.filled(40, 'concrete').join(' ')}',
    );
    expect(notes.title, 'Coordination meeting');
    expect(notes.lines.take(3), [
      'Raise the duct',
      'Send the schedule',
      'Order sleeves',
    ]);
    expect(notes.lines.last.length, lessThanOrEqualTo(140));
    expect(notes.lines.last.endsWith('concrete'), isTrue);
    expect(hasMeetingLines('One line only'), isFalse);
    expect(hasMeetingLines('Title\nA line'), isTrue);
  });

  test('a week report from the server', () {
    final r = WeekReport.fromJson({
      'needs_decision': [
        {
          'post_id': 'p1',
          'title': 'Rebar',
          'state': 'sent_back',
          'reason': 'photo_missing',
          'owner_name': 'Rakesh Nair',
          'needs_me': true,
        },
      ],
      'checked': [
        {
          'post_id': 'p2',
          'title': 'Sleeves',
          'checked_at': '2026-10-15T07:12:00Z',
          'checker_name': 'Islam Ahmed',
          'done_photo_path': 's/p2/a.jpg',
        },
      ],
      'targets': [
        {
          'post_id': 'p3',
          'title': 'Level 3',
          'children': {'total': 4, 'checked': 2},
        },
      ],
      'coming_up': [
        {
          'post_id': 'p4',
          'kind': 'activity',
          'title': 'Site walk',
          'starts_at': DateTime(2026, 10, 16, 9).toUtc().toIso8601String(),
        },
      ],
    });
    expect(r.needsDecision.single.state, DecisionState.sentBack);
    expect(r.needsDecision.single.needsMe, isTrue);
    expect(r.checked.single.photoPath, 's/p2/a.jpg');
    expect((r.targets.single.checked, r.targets.single.total), (2, 4));
    expect(r.comingUp.single.activity, isTrue);
    expect(r.comingUp.single.day, DateTime(2026, 10, 16));
    expect(WeekReport.fromJson(null).isEmpty, isTrue);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final s = DaybookSamples(lang);
    final m = MeetingReportSamples(lang);

    testWidgets('R3: a message of several lines offers Turn lines into work '
        'items; a one-line message doesn\'t [$lang]', (tester) async {
      await _open(tester, lang);
      await tester.longPress(
        _key('chat-message-${MeetingReportSamples.meeting}'),
      );
      await tester.pumpAndSettle();
      expect(_key('chat-action-meeting'), findsOneWidget);
      expect(_key('chat-action-work-item'), findsOneWidget);
      Navigator.of(tester.element(_key('chat-actions'))).pop();
      await tester.pumpAndSettle();
      await tester.longPress(
        _key('chat-message-${MeetingReportSamples.oneLine}'),
      );
      await tester.pumpAndSettle();
      expect(_key('chat-action-meeting'), findsNothing);
      expect(_key('chat-action-work-item'), findsOneWidget);
    });

    testWidgets('R3: a Viewer is not offered it [$lang]', (tester) async {
      await _open(tester, lang, pass: SpacePass.viewer);
      await tester.longPress(
        _key('chat-message-${MeetingReportSamples.meeting}'),
      );
      await tester.pumpAndSettle();
      expect(_key('chat-action-meeting'), findsNothing);
    });

    testWidgets('R3: tick a line, choose who does it; Post sends the ticked '
        'lines under one meeting work item; Open opens it [$lang]', (
      tester,
    ) async {
      final app = await _open(tester, lang);
      await tester.longPress(
        _key('chat-message-${MeetingReportSamples.meeting}'),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('chat-action-meeting'));
      expect(find.text(m.meetingTitle), findsOneWidget);
      for (final line in m.meetingLines) {
        expect(find.text(line), findsOneWidget);
      }
      final post = _key('meeting-post');
      expect(tester.widget<BvButton>(post).onPressed, isNull);

      await _tap(tester, _key('meeting-line-0'));
      await _pickOwner(tester, s.rakeshName);
      await _tap(tester, _key('meeting-line-1'));
      await _pickOwner(tester, s.linaName);
      await _tap(tester, _key('meeting-line-2'));
      await _pickOwner(tester, s.omarName);
      expect(tester.widget<BvButton>(post).label, l10n.meetingPost(3));
      // Change the second line's owner from its face.
      await _tap(tester, _key('meeting-owner-${DaybookSamples.lina}'));
      await _pickOwner(tester, s.saraName);
      // Untick, then tick again with no answer: no tick.
      await _tap(tester, _key('meeting-line-2'));
      expect(tester.widget<BvButton>(post).label, l10n.meetingPost(2));
      await _tap(tester, _key('meeting-line-2'));
      await _pickOwner(tester, s.omarName);

      await _tap(tester, post);
      final sent = app.weekReports.meetings.single;
      expect(sent.messageId, MeetingReportSamples.meeting);
      expect(sent.title, m.meetingTitle);
      expect([for (final l in sent.lines) l.text], m.meetingLines.take(3));
      expect(
        [for (final l in sent.lines) l.ownerId],
        [DaybookSamples.rakesh, DaybookSamples.sara, DaybookSamples.omar],
      );
      expect({for (final l in sent.lines) l.id}, hasLength(3));
      expect(find.text(l10n.meetingPosted(3)), findsOneWidget);
      await tester.tap(find.text(l10n.libraryOpen));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SpaceScreen>(find.byType(SpaceScreen)).target,
        DaybookTarget(sent.parentId),
      );
    });

    testWidgets('R3: in a Team\'s thread only that Team can be given a '
        'line [$lang]', (tester) async {
      final chat = m.chat()
        ..messagesByThread[MeetingReportSamples.mep] = [
          ChatMessage(
            id: 'msg-mep',
            threadId: MeetingReportSamples.mep,
            kind: ChatKind.text,
            createdAt: DateTime(2026, 10, 15, 10),
            authorId: DaybookSamples.islam,
            body: 'MEP check\nHangers at level 4',
          ),
        ];
      await _open(
        tester,
        lang,
        chat: chat,
        path:
            '/spaces/${DaybookSamples.space}/chat/${MeetingReportSamples.mep}',
      );
      await tester.longPress(_key('chat-message-msg-mep'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('chat-action-meeting'));
      await _tap(tester, _key('meeting-line-0'));
      final picker = _key('meeting-owner-picker');
      expect(
        find.descendant(of: picker, matching: find.text(s.rakeshName)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: picker, matching: find.text(s.saraName)),
        findsNothing,
      );
    });

    testWidgets('R3: no signal keeps the ticks; trying again is the same '
        'batch [$lang]', (tester) async {
      final reports = FakeWeekReportRepository()..offline = true;
      final app = await _open(tester, lang, reports: reports);
      await tester.longPress(
        _key('chat-message-${MeetingReportSamples.meeting}'),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('chat-action-meeting'));
      await _tap(tester, _key('meeting-line-0'));
      await _pickOwner(tester, s.rakeshName);
      await _tap(tester, _key('meeting-post'));
      expect(find.text(l10n.meetingNoSignal), findsOneWidget);
      expect(_key('meeting-owner-${DaybookSamples.rakesh}'), findsOneWidget);
      expect(app.weekReports.meetings, isEmpty);
      reports.offline = false;
      await _tap(tester, _key('meeting-post'));
      expect(app.weekReports.meetings, hasLength(1));
    });

    testWidgets('MR1: Week report in Space info for every pass; the '
        'week from Sunday; its four sections, stamps and the clip [$lang]', (
      tester,
    ) async {
      final reports = FakeWeekReportRepository(
        reports: {MeetingReportSamples.week: m.report()},
      );
      final app = await _open(
        tester,
        lang,
        pass: SpacePass.viewer,
        reports: reports,
        path: '/spaces/${DaybookSamples.space}',
      );
      // Review 105 Part 1: in Space info, opened by the Space's name.
      await _tap(tester, _key('space-header'));
      await _tap(tester, find.text(l10n.weekReportTitle));
      expect(app.weekReports.read, [MeetingReportSamples.week]);
      expect(find.text(l10n.weekNeedsDecision), findsOneWidget);
      // Review 86 W1: no LATE stamp; past its due reads "was due".
      expect(_key('week-stamp-late'), findsNothing);
      expect(_key('week-stamp-sent_back'), findsOneWidget);
      expect(_key('week-stamp-done'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('week-needs'),
          matching: find.byType(BvPaperClip),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.daybookReasonPhotoMissing),
        findsOneWidget,
      );
      expect(_key('week-proof-post-sleeves'), findsOneWidget);
      // This week: no week after.
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: _key('week-after'),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      await _seen(tester, 'week-foot');
      expect(find.textContaining(l10n.pageUnderChecked(2, 4)), findsOneWidget);
      expect(_key('week-coming-post-site-walk'), findsOneWidget);
    });

    testWidgets('MR1, review 86 W1: past its due is "was due Tue 13 Oct", '
        'never late; grey unless it waits on me [$lang]', (tester) async {
      final words = DaybookWords(l10n, lang, use24: false);
      final rebar = m.report().needsDecision.first;
      // Waits on me: my own work item, past its due.
      final mine = DecisionRow(
        postId: rebar.postId,
        title: rebar.title,
        state: DecisionState.late,
        ownerName: rebar.ownerName,
        dueDate: rebar.dueDate,
        needsMe: true,
      );
      final theirs = DecisionRow(
        postId: 'post-lift',
        title: 'Lift shaft survey',
        state: DecisionState.late,
        ownerName: s.saraName,
        dueDate: DateTime(2026, 10, 12),
      );
      await _open(
        tester,
        lang,
        reports: FakeWeekReportRepository(
          reports: {
            MeetingReportSamples.week: WeekReport(
              needsDecision: [mine, theirs],
            ),
          },
        ),
        path: '/spaces/${DaybookSamples.space}/week',
      );
      final wasDue = l10n.daybookWasDue(words.shortDate(mine.dueDate!));
      expect(wasDue, contains(lang == 'ar' ? 'كان موعده' : 'was due'));
      final line = tester.widget<Text>(
        _key('week-decision-line-${mine.postId}'),
      );
      expect(line.data, endsWith(wasDue));
      // The owner's own: the action colour; someone else's: grey.
      expect(line.style!.color, BvColors.textAction);
      expect(
        tester.widget<Text>(_key('week-decision-line-post-lift')).style!.color,
        BvColors.textSecondary,
      );
      // No LATE stamp and no "late" word, in either language.
      expect(_key('week-stamp-late'), findsNothing);
      expect(find.byType(BvInkStamp), findsNothing);
      for (final late in ['late', 'Late', 'LATE', 'متأخر']) {
        expect(find.textContaining(late), findsNothing);
      }
    });

    testWidgets('MR1: the week before has no Coming up; an empty week says '
        'so [$lang]', (tester) async {
      final reports = FakeWeekReportRepository(
        reports: {
          MeetingReportSamples.week: m.report(),
          DateTime(2026, 10, 4): m.report(),
        },
      );
      final app = await _open(
        tester,
        lang,
        reports: reports,
        path: '/spaces/${DaybookSamples.space}/week',
      );
      await _tap(tester, _key('week-before'));
      expect(app.weekReports.read.last, DateTime(2026, 10, 4));
      expect(_key('week-needs'), findsOneWidget);
      await _seen(tester, 'week-foot');
      expect(_key('week-coming'), findsNothing);
      await tester.drag(_key('week-list'), const Offset(0, 2000));
      await tester.pumpAndSettle();
      await _tap(tester, _key('week-before'));
      expect(_key('week-empty'), findsOneWidget);
      expect(find.text(l10n.weekEmpty), findsOneWidget);
      await _tap(tester, _key('week-after'));
      await _tap(tester, _key('week-after'));
      await _seen(tester, 'week-coming');
      expect(_key('week-coming'), findsOneWidget);
    });

    testWidgets('MR1: a row opens its card in the daybook [$lang]', (
      tester,
    ) async {
      await _open(
        tester,
        lang,
        reports: FakeWeekReportRepository(
          reports: {MeetingReportSamples.week: m.report()},
        ),
        path: '/spaces/${DaybookSamples.space}/week',
      );
      await _tap(tester, _key('week-decision-post-trays'));
      expect(
        tester.widget<SpaceScreen>(find.byType(SpaceScreen)).target,
        const DaybookTarget('post-trays'),
      );
    });

    testWidgets('Share in chat: pick the thread; the report is a card in the '
        'chat that opens that week [$lang]', (tester) async {
      final app = await _open(
        tester,
        lang,
        reports: FakeWeekReportRepository(
          reports: {
            MeetingReportSamples.week: m.report(),
            DateTime(2026, 10, 4): const WeekReport(),
          },
        ),
        path: '/spaces/${DaybookSamples.space}/week',
      );
      await _tap(tester, _key('week-before'));
      await _tap(tester, _key('week-share'));
      expect(_key('week-share-threads'), findsOneWidget);
      await _tap(tester, _key('week-share-${MeetingReportSamples.everyone}'));
      final shared = app.weekReports.shared.single;
      expect(shared.threadId, MeetingReportSamples.everyone);
      expect(shared.weekStart, DateTime(2026, 10, 4));

      // The chat shows it as a card; a tap opens that week.
      app.chat.messagesByThread[MeetingReportSamples.everyone] = [
        ChatMessage(
          id: shared.id,
          threadId: MeetingReportSamples.everyone,
          kind: ChatKind.report,
          createdAt: DateTime(2026, 10, 15, 10, 50),
          authorId: DaybookSamples.islam,
          reportWeek: DateTime(2026, 10, 4),
        ),
        ...app.chat.messagesByThread[MeetingReportSamples.everyone]!,
      ];
      _router(tester).push(
        '/spaces/${DaybookSamples.space}/chat/${MeetingReportSamples.everyone}',
      );
      await tester.pumpAndSettle();
      expect(_key('chat-week-report'), findsOneWidget);
      await _tap(tester, _key('chat-week-report'));
      expect(app.weekReports.read.last, DateTime(2026, 10, 4));
      expect(_key('week-empty'), findsOneWidget);
    });
  }
}
