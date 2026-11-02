// Review 113 CV3 (2730:39817): Discard in the top bar; Type · For · Team
// pinned just above the bar, title and details above; added extras as chips
// above the lines; the bar is + · camera · mic · Send (no #); hold the mic
// for a voice note that goes with the post and plays on the card; a long
// press in the text adds Date & time · Bullets · Table, and "/" at the start
// of a line opens the same short menu. In English and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/features/chat/voice.dart';
import 'package:buildvibes/features/work/daybook_card.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  String kind = 'work_item',
  FakeDaybookRepository? daybook,
}) async {
  final s = DaybookSamples(lang);
  final app = await pumpApp(
    tester,
    language: lang,
    composerKind: kind,
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail()
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook:
        daybook ??
        (FakeDaybookRepository()..posts[DaybookSamples.space] = s.d1()),
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  await _tap(tester, _key('post-bar-notepad'));
  return app;
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Navigator).first),
).read(daybookDraftProvider(DaybookSamples.space));

/// Holds the mic for [length], then lets go.
Future<void> _record(
  WidgetTester tester, {
  Duration length = const Duration(seconds: 3),
  Offset slide = Offset.zero,
}) async {
  final mic = tester.getCenter(_key('writing-mic'));
  final hold = await tester.startGesture(mic);
  await tester.pump(const Duration(milliseconds: 550));
  await tester.pump();
  await tester.pump();
  expect(_key('chat-recording'), findsOneWidget);
  await tester.pump(length);
  if (slide != Offset.zero) {
    await hold.moveBy(slide);
    await tester.pump();
  }
  await hold.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('CV3 [$lang]', () {
      testWidgets('Type · For · Team pinned just above the bar, title above; '
          'no # on the bar', (tester) async {
        await _open(tester, lang);
        final lines = tester.getRect(_key('writing-lines'));
        expect(_key('writing-kind'), findsOneWidget);
        expect(
          tester.getTopLeft(_key('writing-kind')).dy,
          lessThan(tester.getTopLeft(_key('writing-who')).dy),
        );
        expect(
          tester.getTopLeft(_key('writing-who')).dy,
          lessThan(tester.getTopLeft(_key('writing-to')).dy),
        );
        expect(
          tester.getRect(_key('writing-title')).bottom,
          lessThan(lines.top),
        );
        expect(
          lines.bottom,
          lessThan(tester.getTopLeft(_key('writing-post')).dy),
        );
        // Type opens the kinds' grid.
        await _tap(tester, _key('writing-kind'));
        expect(_key('composer-kinds'), findsOneWidget);
        expect(find.text(l10n.daybookWorkItem), findsWidgets);
      });

      testWidgets('the same place, however long the words', (tester) async {
        await _open(tester, lang);
        final before = tester.getRect(_key('writing-lines'));
        await tester.enterText(
          _key('writing-body'),
          List.filled(60, 'A long line of details').join('\n'),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(_key('writing-lines')), before);
      });

      testWidgets('activity: When · Team; Thanks: To · For', (tester) async {
        await _open(tester, lang, kind: 'activity');
        expect(_key('writing-when-row'), findsOneWidget);
        expect(_key('writing-to'), findsOneWidget);
      });

      testWidgets('added extras sit just above the three lines', (
        tester,
      ) async {
        final app = await _open(tester, lang);
        await _record(tester);
        expect(app.recorder.calls, contains('stop'));
        final chip = tester.getRect(_key('writing-voice-chip'));
        expect(
          chip.bottom,
          lessThan(tester.getRect(_key('writing-lines')).top),
        );
        expect(
          chip.top,
          greaterThan(tester.getRect(_key('writing-title')).bottom),
        );
      });

      testWidgets('Discard asks once and removes the draft; × keeps it', (
        tester,
      ) async {
        await _open(tester, lang);
        await tester.enterText(_key('writing-title'), 'Words');
        await tester.pumpAndSettle();
        await _tap(tester, _key('composer-close'));
        expect(_draft(tester)?.title, 'Words');
        await _tap(tester, _key('daybook-draft'));
        await _tap(tester, _key('composer-discard'));
        expect(find.text(l10n.cpDiscardTitle), findsOneWidget);
        await _tap(tester, find.text(l10n.cpDiscardKeep));
        expect(_key('composer'), findsOneWidget);
        expect(_draft(tester), isNotNull);
        await _tap(tester, _key('composer-discard'));
        await _tap(tester, find.text(l10n.cpDiscard).last);
        expect(_key('composer'), findsNothing);
        expect(_draft(tester), isNull);
      });

      testWidgets('the bar: + · camera · mic, Send at the end', (tester) async {
        await _open(tester, lang);
        double x(String k) => tester.getCenter(_key(k)).dx;
        final order = [
          x('writing-add'),
          x('writing-camera'),
          x('writing-mic'),
          x('writing-post'),
        ];
        expect(
          order,
          orderedEquals(
            [...order]
              ..sort((a, b) => lang == 'en' ? a.compareTo(b) : b.compareTo(a)),
          ),
        );
      });

      testWidgets('a Check-in has no mic', (tester) async {
        await _open(tester, lang, kind: 'check_in');
        expect(_key('writing-mic'), findsNothing);
      });

      testWidgets('hold the mic: a voice note goes with the post', (
        tester,
      ) async {
        final daybook = FakeDaybookRepository()
          ..posts[DaybookSamples.space] = DaybookSamples(lang).d1();
        await _open(tester, lang, kind: 'note', daybook: daybook);
        await tester.enterText(_key('writing-title'), 'Listen to this');
        await tester.pumpAndSettle();
        await _record(tester);
        expect(_draft(tester)?.voiceLocal, isNotNull);
        expect(_draft(tester)?.voiceMs, greaterThanOrEqualTo(1000));
        await _tap(tester, _key('writing-post'));
        expect(daybook.uploads.where((u) => u.endsWith('.m4a')), hasLength(1));
        final made = daybook.createdPosts.single;
        final files = made.toParams()['p_files']! as List;
        expect(files.single, containsPair('mime', 'audio/mp4'));
        expect(_draft(tester), isNull);
      });

      testWidgets('a slip of the thumb, or sliding away, attaches nothing', (
        tester,
      ) async {
        final app = await _open(tester, lang);
        await _record(tester, length: const Duration(milliseconds: 100));
        expect(_draft(tester)?.voiceLocal, isNull);
        await _record(tester, slide: const Offset(0, -200));
        expect(app.recorder.calls, contains('cancel'));
        expect(_draft(tester)?.voiceLocal, isNull);
      });

      testWidgets('× on the voice chip takes it off', (tester) async {
        await _open(tester, lang);
        await _record(tester);
        await _tap(tester, _key('writing-voice-chip-clear'));
        expect(_key('writing-voice-chip'), findsNothing);
      });

      testWidgets('a card with a voice note plays it', (tester) async {
        final s = DaybookSamples(lang);
        final c = s.rebar();
        await pumpApp(
          tester,
          language: lang,
          spaces: FakeSpaceRepository()
            ..details[DaybookSamples.space] = s.detail()
            ..spacePeople[DaybookSamples.space] = s.people(),
          daybook: FakeDaybookRepository()
            ..posts[DaybookSamples.space] = [
              c.copyWith(
                post: c.post.shownAs(
                  voice: const DaybookVoice(
                    path: 'space/posts/p/v.m4a',
                    durationMs: 12000,
                  ),
                ),
              ),
            ],
          now: DaybookSamples.thursday,
        );
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/spaces/${DaybookSamples.space}');
        await tester.pumpAndSettle();
        await scrollToRow(tester, _key('daybook-card-post-rebar'));
        expect(_key('card-voice-post-rebar'), findsOneWidget);
        expect(find.byType(VoiceNote), findsOneWidget);
        expect(find.byType(DaybookCardView), findsOneWidget);
        expect(find.text('0:12'), findsOneWidget);
      });

      testWidgets('the phone\'s menu keeps its items and adds Date & time · '
          'Bullets · Table; Date & time inserts it as text', (tester) async {
        await _open(tester, lang);
        final field = tester.widget<TextField>(_key('writing-body'));
        await tester.enterText(_key('writing-body'), 'Hello ');
        await tester.pumpAndSettle();
        final editable = tester.state<EditableTextState>(
          find.descendant(
            of: _key('writing-body'),
            matching: find.byType(EditableText),
          ),
        );
        final menu = field.contextMenuBuilder!(
          tester.element(_key('writing-body')),
          editable,
        );
        expect(menu, isA<AdaptiveTextSelectionToolbar>());
        final items = (menu as AdaptiveTextSelectionToolbar).buttonItems!;
        final labels = [for (final i in items) i.label];
        expect(
          labels,
          containsAll([l10n.cpDateTime, l10n.cpBullets, l10n.pageTable]),
        );
        expect(
          items.length,
          greaterThan(3),
          reason: 'the phone\'s own items stay',
        );
        items.firstWhere((i) => i.label == l10n.cpDateTime).onPressed!();
        await tester.pumpAndSettle();
        final text = field.controller!.text;
        expect(text, startsWith('Hello '));
        expect(text.length, greaterThan('Hello '.length + 4));
        expect(_draft(tester)?.body, text);
      });

      testWidgets('"/" at the start of a line opens the same menu; in the '
          'middle of a word it is just a /', (tester) async {
        await _open(tester, lang);
        await tester.enterText(_key('writing-body'), 'A/B');
        await tester.pumpAndSettle();
        expect(_key('composer-quick'), findsNothing);
        await tester.enterText(_key('writing-body'), 'A/B\n');
        await tester.pumpAndSettle();
        await tester.enterText(_key('writing-body'), 'A/B\n/');
        await tester.pumpAndSettle();
        expect(_key('composer-quick'), findsOneWidget);
        expect(_key('quick-dateTime'), findsOneWidget);
        expect(_key('quick-bullets'), findsOneWidget);
        expect(_key('quick-table'), findsOneWidget);
        await _tap(tester, _key('quick-bullets'));
        expect(_key('composer-quick'), findsNothing);
        expect(_draft(tester)?.body, contains('\n'));
        expect(_draft(tester)?.body, isNot(contains('/\n')));
      });
    });
  }

  test('NewSpacePost: a voice note goes in p_files as audio/mp4, with its '
      'length', () {
    final params = const NewSpacePost(
      id: 'p',
      spaceId: 's',
      kind: 'note',
      title: 'T',
      voice: (path: 's/posts/p/v.m4a', durationMs: 4200),
    ).toParams();
    expect((params['p_files']! as List).single, {
      'path': 's/posts/p/v.m4a',
      'mime': 'audio/mp4',
      'duration_ms': 4200,
    });
  });
}
