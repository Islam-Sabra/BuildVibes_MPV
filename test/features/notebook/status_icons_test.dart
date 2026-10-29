// Review 106 T1 (corrects review 104 N12): an entry's status icons in their
// own row at the bottom of the entry, at its end (right in English, left
// in Arabic): one per kind, pinned · reminder · feed · Space · message, all
// of them, no "+N". Each a 32 round tap target, a 16 icon on the sunk
// colour, 6 apart; the reminder in the accent colour while it is still to
// ring, grey after. The top line holds only the title and the time. A tap
// opens a card under the icon listing every share of that kind ("Kuwait
// City Tower · 08:45"), the icon shown selected (the soft fill, an accent
// ring) while it is open; the reminder's card keeps Change. Screen-reader
// labels as review 104. In English and Arabic (the row mirrors).
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
final _otherAt = DateTime(_now.year, _now.month, _now.day, 9, 2);
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

/// The round disc of [id]'s [kind] status icon.
BoxDecoration _disc(WidgetTester tester, String id, String kind) =>
    tester
            .widget<DecoratedBox>(find.byKey(Key('note-status-$id-$kind-disc')))
            .decoration
        as BoxDecoration;

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final words = DaybookWords(l10n, lang, use24: false);
    String clock(DateTime at) => words.time.clock(at);
    Finder inCard(String text) => find.descendant(
      of: _key('note-status-card'),
      matching: find.text(text),
    );

    group('T1 status row [$lang]', () {
      testWidgets('all five kinds, in their order, no "+N": each a 32 round '
          'target with a 16 icon on the sunk colour, 6 apart', (tester) async {
        await _open(tester, lang, [
          _entry(
            'a',
            pinned: true,
            remindAt: _ringAt,
            shares: [_feed, _space, _sent],
          ),
        ]);
        expect(_icons(tester, 'a', lang), [
          BvIcons.pin,
          BvIcons.remind,
          BvIcons.feed,
          BvIcons.team,
          BvIcons.chat,
        ]);
        expect(_key('note-status-a-more'), findsNothing);
        const kinds = ['pinned', 'reminder', 'feed', 'space', 'message'];
        final rects = [
          for (final k in kinds) tester.getRect(_key('note-status-a-$k')),
        ]..sort((a, b) => a.left.compareTo(b.left));
        for (final r in rects) {
          expect(r.size, const Size(32, 32));
        }
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].left - rects[i - 1].right, 6);
        }
        for (final k in kinds) {
          final icon = tester.widget<Icon>(
            find.descendant(
              of: _key('note-status-a-$k'),
              matching: find.byType(Icon),
            ),
          );
          expect(icon.size, 16, reason: k);
          expect(_disc(tester, 'a', k).color, BvColors.surfaceSubtle);
          expect(_disc(tester, 'a', k).shape, BoxShape.circle);
        }
      });

      testWidgets('the row is at the bottom of the entry, at its end; the '
          'top line holds only the title and the time', (tester) async {
        await _open(tester, lang, [
          _entry('a', pinned: true, shares: [_feed]),
        ]);
        final card = tester.getRect(_key('note-a'));
        final row = tester.getRect(_key('note-status-a'));
        final line = tester.getRect(find.text('Clean the formwork'));
        expect(row.top, greaterThanOrEqualTo(line.bottom));
        expect(card.bottom - row.bottom, lessThanOrEqualTo(14));
        if (lang == 'ar') {
          expect(row.left - card.left, lessThanOrEqualTo(14));
        } else {
          expect(card.right - row.right, lessThanOrEqualTo(14));
        }
        expect(
          find.descendant(
            of: _key('note-head-a'),
            matching: _key('note-status-a'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: _key('note-head-a'),
            matching: find.byIcon(BvIcons.pin),
          ),
          findsNothing,
        );
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

      testWidgets('a tap lists every share of its kind with the names and '
          'times; the icon is selected while open; a tap beside closes it', (
        tester,
      ) async {
        final other = NoteShare(
          target: NoteShareTarget.space,
          at: _otherAt,
          name: 'NBKCH Site team',
        );
        await _open(tester, lang, [
          _entry('a', shares: [_space, other]),
        ]);
        await tester.tap(_key('note-status-a-space'));
        await tester.pumpAndSettle();
        expect(inCard(l10n.notebookStatusTitleSpace), findsOneWidget);
        for (final line in [
          l10n.notebookStatusShareLine('KCT Tower', clock(_spaceAt)),
          l10n.notebookStatusShareLine('NBKCH Site team', clock(_otherAt)),
        ]) {
          expect(inCard(line), findsOneWidget, reason: line);
        }
        // Under the icon.
        expect(
          tester.getRect(_key('note-status-card')).top,
          greaterThanOrEqualTo(
            tester.getRect(_key('note-status-a-space')).bottom,
          ),
        );
        // Selected: the soft fill and the accent ring.
        final disc = _disc(tester, 'a', 'space');
        expect(disc.color, BvColors.surfaceBrandSoft);
        expect((disc.border! as Border).top.color, BvColors.borderSelected);
        // The tap opened the card, not the entry.
        expect(_key('note-tools'), findsNothing);
        // Beside the card: the barrier's corner.
        await tester.tapAt(
          tester.getBottomLeft(_key('line-popover-barrier')) +
              const Offset(4, -4),
        );
        await tester.pumpAndSettle();
        expect(_key('note-status-card'), findsNothing);
        expect(_disc(tester, 'a', 'space').color, BvColors.surfaceSubtle);
      });

      testWidgets('the feed and the messages list each share too', (
        tester,
      ) async {
        final again = NoteShare(target: NoteShareTarget.feed, at: _otherAt);
        final second = NoteShare(
          target: NoteShareTarget.message,
          at: _otherAt,
          name: 'Lina Haddad',
        );
        await _open(tester, lang, [
          _entry('a', shares: [_feed, again, _sent, second]),
        ]);
        await tester.tap(_key('note-status-a-feed'));
        await tester.pumpAndSettle();
        expect(inCard(l10n.notebookStatusTitleFeed), findsOneWidget);
        expect(inCard(clock(_feedAt)), findsOneWidget);
        expect(inCard(clock(_otherAt)), findsOneWidget);
        // Outside the card (K4: Share again makes it taller).
        await tester.tapAt(
          tester.getBottomLeft(_key('line-popover-barrier')) +
              const Offset(4, -4),
        );
        await tester.pumpAndSettle();
        await tester.tap(_key('note-status-a-message'));
        await tester.pumpAndSettle();
        expect(inCard(l10n.notebookStatusTitleMessage), findsOneWidget);
        expect(
          inCard(l10n.notebookStatusShareLine('Ahmed Saleh', clock(_sentAt))),
          findsOneWidget,
        );
        expect(
          inCard(l10n.notebookStatusShareLine('Lina Haddad', clock(_otherAt))),
          findsOneWidget,
        );
      });

      testWidgets('the reminder\'s card has Change, which opens the reminder '
          'picker', (tester) async {
        await _open(tester, lang, [_entry('a', remindAt: _ringAt)]);
        await tester.tap(_key('note-status-a-reminder'));
        await tester.pumpAndSettle();
        expect(inCard(l10n.notebookStatusTitleReminder), findsOneWidget);
        expect(
          inCard(
            l10n.notebookReminderLine(reminderWhen(l10n, words, _ringAt, _now)),
          ),
          findsOneWidget,
        );
        await tester.tap(_key('note-status-change'));
        await tester.pumpAndSettle();
        expect(_key('note-status-card'), findsNothing);
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('a screen reader hears each icon, as in review 104', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, lang, [
          _entry(
            'a',
            pinned: true,
            remindAt: _ringAt,
            shares: [_feed, _space, _sent],
          ),
        ]);
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
          l10n.notebookStatusFeed(clock(_feedAt)),
        );
        expect(
          tester.getSemantics(_key('note-status-a-space')).label,
          l10n.notebookStatusSpace('KCT Tower', clock(_spaceAt)),
        );
        expect(
          tester.getSemantics(_key('note-status-a-message')).label,
          l10n.notebookStatusSent('Ahmed Saleh', clock(_sentAt)),
        );
        semantics.dispose();
      });

      testWidgets('F3: a Space or a person with no name is left out, never '
          'a blank name', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, lang, [
          _entry(
            'a',
            shares: [
              _feed,
              NoteShare(target: NoteShareTarget.space, at: _spaceAt),
              NoteShare(
                target: NoteShareTarget.message,
                at: _sentAt,
                name: '  ',
              ),
            ],
          ),
          _entry(
            'b',
            hour: 8,
            shares: [NoteShare(target: NoteShareTarget.space, at: _spaceAt)],
          ),
        ]);
        expect(_icons(tester, 'a', lang), [BvIcons.feed]);
        expect(_key('note-status-a-space'), findsNothing);
        expect(_key('note-status-a-message'), findsNothing);
        expect(_key('note-status-b'), findsNothing);
        for (final blank in [
          l10n.notebookStatusSpace('', clock(_spaceAt)),
          l10n.notebookStatusSent('  ', clock(_sentAt)),
        ]) {
          expect(find.bySemanticsLabel(blank), findsNothing);
        }
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
