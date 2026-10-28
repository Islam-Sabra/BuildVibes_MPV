// Review 100 Parts 4 and 5 (BH6–BH8, BH10): one compact card everywhere;
// the bar above the keyboard is + · Photo · Add · Voice · Send; + and /
// open the same block list; 📎 holds File · Location · Date · Reminder, each
// with its value and a ✕; Discard while writing a new entry; Done inside a
// saved one. In English and Arabic.
import 'dart:convert';

import 'package:buildvibes/core/design/daybook_writing_specs.dart'
    show BvLineMenuSpec;
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/note_draft.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_page_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

const _siteA = '/notebook/pages/${NotebookPageSamples.siteA}';

NoteDraft _draft({NoteLocation? location, DateTime? remindAt}) => NoteDraft(
  id: 'draft-1',
  startedAt: NotebookPageSamples.now,
  title: 'Before the pour',
  blocks: [PageNumbered('l-1', 'Clean the formwork'), PageText('l-2', '')],
  pageId: NotebookPageSamples.siteA,
  location: location,
  remindAt: remindAt,
);

Future<FakeNotebookRepository> _write(
  WidgetTester tester,
  String lang, {
  NoteDraft? draft,
}) async {
  final repo = NotebookPageSamples(lang).repository();
  await pumpApp(
    tester,
    language: lang,
    now: NotebookPageSamples.now,
    notebook: repo,
    stored: {'notebook_draft:user-1': jsonEncode((draft ?? _draft()).toJson())},
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_siteA);
  await tester.pumpAndSettle();
  await _tap(tester, _key('note-draft-card-draft-1'));
  await tester.tap(find.text('Clean the formwork'));
  await tester.pumpAndSettle();
  return repo;
}

bool _typing() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

/// The tools on the bar, in their order across it.
List<String> _bar(WidgetTester tester) {
  final keys = [
    'note-tool-categories',
    'note-tool-image',
    'note-tool-add',
    'note-tool-indent',
    'note-tool-outdent',
    'note-tool-voice',
    'writing-post',
  ];
  final shown = [
    for (final k in keys)
      if (_key(k).evaluate().isNotEmpty) k,
  ];
  final rtl =
      Directionality.of(tester.element(_key('note-tools'))) ==
      TextDirection.rtl;
  double x(String k) => tester.getCenter(_key(k)).dx;
  return shown
    ..sort((a, b) => rtl ? x(b).compareTo(x(a)) : x(a).compareTo(x(b)));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('BH6 the bar [$lang]', () {
      testWidgets('+ · Photo · Add · Voice · Send, nothing else; the voice '
          'and Send at the far end', (tester) async {
        await _write(tester, lang);
        expect(_bar(tester), [
          'note-tool-categories',
          'note-tool-image',
          'note-tool-add',
          'note-tool-voice',
          'writing-post',
        ]);
        for (final gone in [
          'note-tool-location',
          'note-tool-file',
          'note-tool-date',
          'note-tool-remind',
        ]) {
          expect(_key(gone), findsNothing, reason: gone);
        }
        // Voice sits by Send, away from Add.
        final voice = tester.getCenter(_key('note-tool-voice')).dx;
        final add = tester.getCenter(_key('note-tool-add')).dx;
        final send = tester.getCenter(_key('writing-post')).dx;
        expect((send - voice).abs(), lessThan((voice - add).abs() / 2));
      });

      testWidgets('⇥ ⇤ come in after Add on a list line that can move', (
        tester,
      ) async {
        await _write(
          tester,
          lang,
          draft: NoteDraft(
            id: 'draft-1',
            startedAt: NotebookPageSamples.now,
            title: 'Before the pour',
            blocks: [
              PageNumbered('l-1', 'Clean the formwork'),
              PageNumbered('l-2', 'Check the rebar'),
            ],
            pageId: NotebookPageSamples.siteA,
          ),
        );
        await tester.tap(find.text('Check the rebar'));
        await tester.pumpAndSettle();
        expect(_bar(tester), [
          'note-tool-categories',
          'note-tool-image',
          'note-tool-add',
          'note-tool-indent',
          'note-tool-voice',
          'writing-post',
        ]);
      });

      testWidgets('a short tap on the mic says to hold it', (tester) async {
        await _write(tester, lang);
        await _tap(tester, _key('note-tool-voice'));
        expect(find.text(l10n.notebookHoldToRecord), findsWidgets);
      });
    });

    group('BH8 + opens the block list [$lang]', () {
      testWidgets('the same card as /: TEXT, LISTS, INSERT, the shortcuts at '
          'the end, the current kind ticked; the keyboard stays up', (
        tester,
      ) async {
        await _write(tester, lang);
        await _tap(tester, _key('note-tool-categories'));
        expect(_key('page-add-menu'), findsOneWidget);
        expect(_key('note-categories'), findsNothing);
        expect(_typing(), isTrue);
        for (final g in [
          l10n.notebookGroupText,
          l10n.notebookGroupLists,
          l10n.notebookGroupInsert,
        ]) {
          expect(find.text(g), findsOneWidget, reason: g);
        }
        final rows = [
          'text',
          'heading',
          'subheading',
          'quote',
          'todo',
          'numbers',
          'bullets',
          'toggle',
          'table',
          'divider',
        ];
        // In the card's order (it scrolls inside).
        final shown = [
          for (final e
              in find
                  .descendant(
                    of: _key('page-add-menu'),
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w.key is ValueKey<String> &&
                          (w.key! as ValueKey<String>).value.startsWith(
                            'page-add-',
                          ),
                    ),
                  )
                  .evaluate())
            (e.widget.key! as ValueKey<String>).value.substring(9),
        ];
        expect(shown, rows);
        expect(_key('page-add-callout'), findsNothing);
        expect(
          find.descendant(
            of: _key('page-add-text'),
            matching: _key('menu-checked'),
          ),
          findsOneWidget,
        );
        // The card is the compact one, its width a token.
        expect(
          tester.getSize(_key('page-add-menu')).width,
          BvLineMenuSpec.width,
        );
        await _tap(tester, _key('page-add-numbers'));
        expect(_key('page-add-menu'), findsNothing);
        expect(_typing(), isTrue);
        final draft = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(noteDraftProvider)!;
        expect(draft.blocks.whereType<PageNumbered>(), hasLength(2));
      });

      testWidgets('/ shows the same groups', (tester) async {
        await _write(tester, lang);
        await tester.tap(find.byKey(const Key('page-field-t:l-2')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('page-field-t:l-2')), '/');
        await tester.pumpAndSettle();
        expect(_key('page-add-menu'), findsOneWidget);
        expect(find.text(l10n.notebookGroupText), findsOneWidget);
        expect(_key('page-add-callout'), findsNothing);
      });
    });

    group('BH7 📎 Add [$lang]', () {
      testWidgets('File · Location · Date · Reminder over the bar; a value '
          'set shows at its row\'s end with ✕, which takes it off', (
        tester,
      ) async {
        await _write(
          tester,
          lang,
          draft: _draft(
            location: const NoteLocation(text: 'Gate 2'),
            remindAt: DateTime(2026, 10, 16, 7),
          ),
        );
        // In use: a dot on 📎.
        expect(_key('note-tool-add-dot'), findsOneWidget);
        await _tap(tester, _key('note-tool-add'));
        expect(_key('note-add-menu'), findsOneWidget);
        expect(_typing(), isTrue);
        final rows = [
          'note-add-file',
          'note-add-location',
          'note-add-date',
          'note-add-remind',
        ];
        var top = double.negativeInfinity;
        for (final r in rows) {
          final y = tester.getRect(_key(r)).top;
          expect(y, greaterThan(top), reason: r);
          top = y;
        }
        // Over the bar.
        expect(
          tester.getRect(_key('note-add-menu')).bottom,
          lessThanOrEqualTo(tester.getRect(_key('note-tools')).top),
        );
        expect(
          find.descendant(
            of: _key('note-add-location'),
            matching: find.text('Gate 2'),
          ),
          findsOneWidget,
        );
        expect(_key('note-add-date-clear'), findsNothing);
        await _tap(tester, _key('note-add-location-clear'));
        await _tap(tester, _key('note-tool-add'));
        await _tap(tester, _key('note-add-remind-clear'));
        final draft = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(noteDraftProvider)!;
        expect(draft.location, isNull);
        expect(draft.remindAt, isNull);
        expect(_key('note-tool-add-dot'), findsNothing);
      });

      testWidgets('📷 opens its own compact card (Camera, Gallery), not a '
          'sheet', (tester) async {
        await _write(tester, lang);
        await _tap(tester, _key('note-tool-image'));
        expect(_key('note-image-menu'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(_key('note-image-camera'), findsOneWidget);
        expect(_key('note-image-gallery'), findsOneWidget);
      });
    });

    group('Discard and Done [$lang]', () {
      testWidgets('a new entry: Discard at the top bar\'s end, in red; '
          '"Discarded · Undo"', (tester) async {
        await _write(tester, lang);
        expect(_key('writing-discard'), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.descendant(
                  of: _key('writing-discard'),
                  matching: find.byType(Text),
                ),
              )
              .style
              ?.color,
          isNot(isNull),
        );
        await _tap(tester, _key('writing-discard'));
        expect(_key('note-tools'), findsNothing);
        expect(_key('note-draft-card-draft-1'), findsNothing);
        expect(find.text(l10n.notebookDiscarded), findsOneWidget);
        await tester.tap(find.text(l10n.daybookUndo));
        await tester.pumpAndSettle();
        expect(_key('note-draft-card-draft-1'), findsOneWidget);
      });

      testWidgets('a saved entry: no Discard; Send reads Done and saves it '
          'in place', (tester) async {
        final repo = NotebookPageSamples(lang).repository();
        await pumpApp(
          tester,
          language: lang,
          now: NotebookPageSamples.now,
          notebook: repo,
        );
        GoRouter.of(tester.element(find.byType(Navigator).first)).push(_siteA);
        await tester.pumpAndSettle();
        await _tap(tester, _key('note-entry-pour'));
        expect(_key('writing-discard'), findsNothing);
        final post = tester.getSemantics(_key('writing-post'));
        expect(post.label, l10n.notebookDone);
        await tester.enterText(
          find.byKey(const Key('note-title')),
          'Before the pour, level 4',
        );
        await _tap(tester, _key('writing-post'));
        expect(_key('note-tools'), findsNothing);
        expect(find.text(l10n.notebookSavedEdit), findsOneWidget);
        expect(repo.bases['entry-pour'], 1);
        expect(repo.kept['entry-pour']!.title, 'Before the pour, level 4');
      });
    });

    group('BH10 the line menu [$lang]', () {
      testWidgets('Turn into › turns the same card into the kinds, with a ‹ '
          'back row on top', (tester) async {
        await _write(tester, lang);
        await _tap(tester, _key('page-handle-l-1'));
        await _tap(tester, _key('page-turn-into'));
        expect(_key('page-block-menu'), findsNothing);
        expect(_key('page-turn-menu'), findsOneWidget);
        expect(_key('menu-back'), findsOneWidget);
        expect(
          tester.getRect(_key('menu-back')).top,
          lessThan(tester.getRect(_key('page-turn-text')).top),
        );
        await _tap(tester, _key('menu-back'));
        expect(_key('page-block-menu'), findsOneWidget);
        expect(_key('page-turn-menu'), findsNothing);
      });
    });
  }
}
