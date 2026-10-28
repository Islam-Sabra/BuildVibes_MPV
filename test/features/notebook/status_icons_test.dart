// Review 104 N12: status icons on an entry instead of text marks. A small
// row of icons at the top end of each card, beside its time: pinned, a
// reminder (the accent colour while it is still to ring, grey after),
// shared to the feed, to a Space, sent to a person; the same glyphs as
// their actions. 14, grey, 4 apart; at most 3, past 3 the third is "+N".
// A tap opens a compact card with the detail ("Shared to the feed ·
// 08:30", "Reminder · …" with Change). The marks under the entry go. Each
// icon has a screen-reader label. In English and Arabic (the row mirrors).
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/post_page.dart';
import 'package:buildvibes/features/notebook/notebook_page_screen.dart'
    show reminderWhen;
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/notebook_fakes.dart';
import '../../helpers/notebook_samples.dart';
import '../../helpers/pump_app.dart';

Finder _key(String k) => find.byKey(Key(k));

const _page = '/notebook/pages/${FakeNotebookRepository.myNotesId}';

final _now = NotebookSamples.now;
final _feedAt = DateTime(_now.year, _now.month, _now.day, 8, 30);
final _spaceAt = DateTime(_now.year, _now.month, _now.day, 8, 45);
final _sentAt = DateTime(_now.year, _now.month, _now.day, 8, 50);
final _ringAt = _now.add(const Duration(days: 1));

Note _entry(
  String id, {
  bool pinned = false,
  DateTime? remindAt,
  List<NoteShare> shares = const [],
  int hour = 9,
}) => Note(
  id: id,
  kind: NoteKind.text,
  title: 'Pour $id',
  blocks: [PageText('$id-1', 'Clean the formwork')],
  body: 'Pour $id',
  pinned: pinned,
  remindAt: remindAt,
  shares: shares,
  createdAt: DateTime(_now.year, _now.month, _now.day, hour),
  pageId: FakeNotebookRepository.myNotesId,
);

final _feed = NoteShare(target: NoteShareTarget.feed, at: _feedAt);
final _space = NoteShare(
  target: NoteShareTarget.space,
  at: _spaceAt,
  name: 'KCT Tower',
);
final _sent = NoteShare(
  target: NoteShareTarget.message,
  at: _sentAt,
  name: 'Ahmed Saleh',
);

Future<void> _open(WidgetTester tester, String lang, List<Note> notes) async {
  await pumpApp(
    tester,
    language: lang,
    now: _now,
    notebook: FakeNotebookRepository(notes: notes),
  );
  GoRouter.of(tester.element(find.byType(Navigator).first)).push(_page);
  await tester.pumpAndSettle();
}

/// The status icons of [id], start to end in the reading direction.
List<IconData> _icons(WidgetTester tester, String id, String lang) {
  final found = find.descendant(
    of: _key('note-status-$id'),
    matching: find.byType(Icon),
  );
  final icons = [
    for (final e in found.evaluate())
      ((e.widget as Icon).icon!, tester.getCenter(find.byWidget(e.widget)).dx),
  ]..sort((a, b) => lang == 'ar' ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2));
  return [for (final (i, _) in icons) i];
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    group('N12 status icons [$lang]', () {
      testWidgets('feed, Space and person: three icons, the actions\' own '
          'glyphs, 14 and grey; no text marks under the entry', (tester) async {
        await _open(tester, lang, [
          _entry('a', shares: [_feed, _space, _sent]),
        ]);
        expect(_icons(tester, 'a', lang), [
          BvIcons.feed,
          BvIcons.team,
          BvIcons.chat,
        ]);
        for (final icon in tester.widgetList<Icon>(
          find.descendant(
            of: _key('note-status-a'),
            matching: find.byType(Icon),
          ),
        )) {
          expect(icon.size, 14);
          expect(icon.color, BvColors.iconSecondary);
        }
        expect(_key('note-share-mark-a'), findsNothing);
        final words = DaybookWords(l10n, lang, use24: false);
        expect(
          find.text(l10n.notebookMarkFeed(words.time.clock(_feedAt))),
          findsNothing,
        );
      });

      testWidgets('they sit in the top line, between the title and the '
          'time; the row mirrors in Arabic', (tester) async {
        await _open(tester, lang, [
          _entry('a', shares: [_feed]),
        ]);
        final head = tester.getRect(_key('note-head-a'));
        final icons = tester.getRect(_key('note-status-a'));
        final title = tester.getRect(find.text('Pour a'));
        expect(icons.center.dy, closeTo(head.center.dy, head.height / 2));
        final words = DaybookWords(l10n, lang, use24: false);
        final time = tester.getRect(
          find.descendant(
            of: _key('note-head-a'),
            matching: find.text(
              words.time.clock(DateTime(_now.year, _now.month, _now.day, 9)),
            ),
          ),
        );
        if (lang == 'ar') {
          expect(icons.right, lessThanOrEqualTo(title.left));
          expect(time.right, lessThanOrEqualTo(icons.left));
        } else {
          expect(icons.left, greaterThanOrEqualTo(title.right));
          expect(time.left, greaterThanOrEqualTo(icons.right));
        }
      });

      testWidgets('a reminder still to ring is in the accent colour; one '
          'passed is grey; no "Reminder ·" line', (tester) async {
        await _open(tester, lang, [
          _entry('a', remindAt: _ringAt),
          _entry(
            'b',
            remindAt: _now.subtract(const Duration(hours: 1)),
            hour: 8,
          ),
        ]);
        Icon remind(String id) => tester.widget<Icon>(
          find.descendant(
            of: _key('note-status-$id-reminder'),
            matching: find.byType(Icon),
          ),
        );
        expect(remind('a').icon, BvIcons.remind);
        expect(remind('a').color, BvColors.iconAction);
        expect(remind('b').color, BvColors.iconSecondary);
        expect(_key('note-reminder-a'), findsNothing);
      });

      testWidgets('past three, the third is "+N"', (tester) async {
        await _open(tester, lang, [
          _entry(
            'a',
            pinned: true,
            remindAt: _ringAt,
            shares: [_feed, _space, _sent],
          ),
        ]);
        expect(_icons(tester, 'a', lang), [BvIcons.pin, BvIcons.remind]);
        expect(
          find.descendant(
            of: _key('note-status-a-more'),
            matching: find.text('+3'),
          ),
          findsOneWidget,
        );
        // "+3" opens the rest.
        await tester.tap(_key('note-status-a-more'));
        await tester.pumpAndSettle();
        final words = DaybookWords(l10n, lang, use24: false);
        for (final line in [
          l10n.notebookMarkFeed(words.time.clock(_feedAt)),
          l10n.notebookMarkTo('KCT Tower', words.time.clock(_spaceAt)),
          l10n.notebookMarkSent('Ahmed Saleh', words.time.clock(_sentAt)),
        ]) {
          expect(
            find.descendant(
              of: _key('note-status-card'),
              matching: find.text(line),
            ),
            findsOneWidget,
            reason: line,
          );
        }
      });

      testWidgets('a tap opens its detail; a tap beside closes it', (
        tester,
      ) async {
        await _open(tester, lang, [
          _entry('a', shares: [_space]),
        ]);
        await tester.tap(_key('note-status-a-space'));
        await tester.pumpAndSettle();
        final words = DaybookWords(l10n, lang, use24: false);
        expect(
          find.descendant(
            of: _key('note-status-card'),
            matching: find.text(
              l10n.notebookMarkTo('KCT Tower', words.time.clock(_spaceAt)),
            ),
          ),
          findsOneWidget,
        );
        // The tap opened the detail, not the entry.
        expect(_key('note-tools'), findsNothing);
        await tester.tap(_key('line-popover-barrier'));
        await tester.pumpAndSettle();
        expect(_key('note-status-card'), findsNothing);
      });

      testWidgets('the reminder\'s card has Change, which opens the reminder '
          'picker', (tester) async {
        await _open(tester, lang, [_entry('a', remindAt: _ringAt)]);
        await tester.tap(_key('note-status-a-reminder'));
        await tester.pumpAndSettle();
        final words = DaybookWords(l10n, lang, use24: false);
        expect(
          find.descendant(
            of: _key('note-status-card'),
            matching: find.text(
              l10n.notebookReminderLine(
                reminderWhen(l10n, words, _ringAt, _now),
              ),
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(_key('note-status-change'));
        await tester.pumpAndSettle();
        expect(_key('note-status-card'), findsNothing);
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('a screen reader hears each icon', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, lang, [
          _entry('a', pinned: true, remindAt: _ringAt, shares: [_feed]),
        ]);
        final words = DaybookWords(l10n, lang, use24: false);
        expect(
          tester.getSemantics(_key('note-status-a-pinned')).label,
          l10n.notebookPinnedLabel,
        );
        expect(
          tester.getSemantics(_key('note-status-a-reminder')).label,
          l10n.notebookStatusReminder(reminderWhen(l10n, words, _ringAt, _now)),
        );
        expect(
          tester.getSemantics(_key('note-status-a-feed')).label,
          l10n.notebookStatusFeed(words.time.clock(_feedAt)),
        );
        semantics.dispose();
      });

      testWidgets('an entry with nothing to say has no icon row', (
        tester,
      ) async {
        await _open(tester, lang, [_entry('a')]);
        expect(_key('note-status-a'), findsNothing);
      });
    });
  }
}
