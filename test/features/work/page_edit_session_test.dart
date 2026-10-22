import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/features/work/daybook_card.dart';
import 'package:buildvibes/features/work/daybook_words.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

DaybookEvent _edit(
  String id,
  DateTime at, {
  String by = 'p-islam',
  Map<String, dynamic> changes = const {'page': true},
}) => DaybookEvent.fromJson({
  'id': id,
  'kind': 'edited',
  'at': at.toUtc().toIso8601String(),
  'by_id': by,
  'by_name': 'Islam Ahmed',
  'changes': changes,
});

void main() {
  final t = DateTime(2026, 10, 22, 9);

  test('F93: an edit of the page only, files with it too', () {
    expect(_edit('a', t).pageOnly, isTrue);
    expect(_edit('b', t, changes: {'page': true, 'files': 1}).pageOnly, isTrue);
    expect(
      _edit('c', t, changes: {'page': true, 'title': 'x'}).pageOnly,
      isFalse,
    );
    expect(_edit('d', t, changes: {'title': 'x'}).pageOnly, isFalse);
  });

  test('F93: one line per page edit session: the same person within ten '
      'minutes folds into the latest', () {
    final events = [
      _edit('1', t),
      _edit('2', t.add(const Duration(minutes: 3))),
      _edit('3', t.add(const Duration(minutes: 9))),
      // Someone else: a line of their own.
      _edit('4', t.add(const Duration(minutes: 10)), by: 'p-omar'),
      // The first person again, after Omar: a new line.
      _edit('5', t.add(const Duration(minutes: 11))),
      // More than ten minutes after their last edit: a new session.
      _edit('6', t.add(const Duration(minutes: 30))),
      // The title changed too: not a page-only line.
      _edit('7', t.add(const Duration(minutes: 31)), changes: {'title': 'x'}),
    ];
    expect(foldPageEdits(events).map((e) => e.id), ['3', '4', '5', '6', '7']);
  });

  for (final lang in ['en', 'ar']) {
    test('F93: the line says the page was edited [$lang]', () {
      final l10n = lookupAppLocalizations(Locale(lang));
      final words = DaybookWords(l10n, lang, use24: false);
      final e = _edit('1', t);
      expect(
        words.eventPhrase(e, me: 'p-islam', now: t),
        l10n.daybookLineYouEditedPage,
      );
    });
  }
}
