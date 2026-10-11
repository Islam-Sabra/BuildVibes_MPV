import 'package:buildvibes/core/l10n/months.dart';
import 'package:buildvibes/data/models/project.dart';
import 'package:buildvibes/features/projects/new_project_screen.dart';
import 'package:buildvibes/features/projects/project_sheet_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key)).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
    text,
  );
  await tester.pump();
}

void _go(WidgetTester tester, String path) {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
}

/// Open "Add a project" and search for [name].
Future<void> _search(WidgetTester tester, String name) async {
  _go(tester, '/projects/add');
  await tester.pumpAndSettle();
  await _type(tester, 'project-search', name);
  await tester.pumpAndSettle(const Duration(milliseconds: 400));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('is it already here: this is it, then add to my CV [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        setUp: (_, projects) =>
            projects.add('Al Kout Mall', placeId: 'kw-fahaheel'),
      );
      await _search(tester, 'al kout');
      expect(find.text(l10n.matchSameName), findsOneWidget);
      expect(find.text('Al Kout Mall'), findsOneWidget);
      expect(find.byKey(const Key('start-new-record')), findsOneWidget);

      await _tap(tester, 'this-is-it-project-0');
      expect(find.text(l10n.cvEntryTitle('Al Kout Mall')), findsOneWidget);
      await _tap(tester, 'cv-add');
      expect(find.text(l10n.roleTitleRequired), findsOneWidget);
      await _type(tester, 'cv-role', 'BIM Manager');
      await _tap(tester, 'cv-add');

      final entry = app.pages.cv['user-1']!.single;
      expect(entry.projectId, 'project-0');
      expect(entry.role, 'BIM Manager');
      // Now on the project sheet, with the CV entry waiting for proof.
      expect(find.byType(ProjectSheetScreen), findsOneWidget);
      expect(find.byKey(const Key('project-my-cv')), findsOneWidget);
      expect(find.text(l10n.proofWaiting), findsOneWidget);
    });

    testWidgets('a project already on the CV is marked, not offered [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        setUp: (pages, projects) {
          final r = projects.add('Harbour Tower');
          projects.addToCv(r.id, const CvEntryInput(role: 'Site engineer'));
        },
      );
      await _search(tester, 'harbour');
      expect(find.text(l10n.onYourCvBadge), findsOneWidget);
      expect(find.byKey(const Key('this-is-it-project-0')), findsNothing);
    });

    testWidgets('none of these: a new record, then add to my CV [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _search(tester, 'Gulf Bank HQ');
      await _tap(tester, 'start-new-record');
      expect(find.byType(NewProjectScreen), findsOneWidget);
      expect(find.text(l10n.draftStamp), findsOneWidget);
      // The name typed in the search carries over.
      expect(find.text('Gulf Bank HQ'), findsOneWidget);

      await _tap(tester, 'new-project-add');
      expect(app.projects.records, isEmpty, reason: 'type and role missing');

      await _tap(tester, 'cell-type');
      await _tap(tester, 'option-commercial');
      await _tap(tester, 'cell-location');
      await _tap(tester, 'option-kw-capital');
      await _tap(tester, 'cell-started');
      await _tap(tester, 'month-1');
      await _tap(tester, 'cell-role');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('text-sheet-field')),
          matching: find.byType(TextField),
        ),
        'Project manager',
      );
      await tester.pump();
      await _tap(tester, 'text-sheet-save');
      await _tap(tester, 'new-project-add');

      final record = app.projects.records.values.single;
      expect(record.name, 'Gulf Bank HQ');
      expect(record.typeId, 'commercial');
      expect(record.placeId, 'kw-capital');
      final cv = app.pages.cv['user-1']!.single;
      expect(cv.role, 'Project manager');
      expect(cv.start, DateTime(2026, 1));
      expect(cv.end, isNull);
      expect(find.text(l10n.sharedRecordStamp), findsOneWidget);
    });

    testWidgets('project sheet: no owner, people, suggest an edit [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        setUp: (_, projects) {
          projects.add('Harbour Tower', typeId: 'mixed_use');
          projects.others['project-0'] = [
            const ProjectPerson(
              profileId: 'p-layla',
              firstName: 'Layla',
              lastName: 'Haddad',
              role: 'Site engineer',
            ),
          ];
        },
      );
      _go(tester, '/projects/project-0');
      await tester.pumpAndSettle();
      expect(find.text(l10n.sharedRecordStamp), findsOneWidget);
      expect(find.text('Harbour Tower'), findsOneWidget);
      expect(find.text(l10n.projectNoOwnerNote), findsOneWidget);
      expect(find.text('Layla Haddad'), findsOneWidget);
      expect(find.byKey(const Key('project-add-to-cv')), findsOneWidget);

      await _tap(tester, 'project-suggest');
      expect(find.text(l10n.suggestTitle('Harbour Tower')), findsOneWidget);
      await _tap(tester, 'suggest-send');
      expect(find.text(l10n.correctValueRequired), findsOneWidget);
      await _tap(tester, 'wrong-dates');
      await _type(tester, 'suggest-value', 'Ended: expected Mar 2027');
      await _tap(tester, 'suggest-send');
      expect(app.projects.suggestions.single, (
        'project-0',
        EditField.dates,
        'Ended: expected Mar 2027',
      ));
      expect(find.text(l10n.suggestionSent), findsOneWidget);
    });

    testWidgets('a person on the project opens their profile [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        setUp: (_, projects) {
          projects.add('Harbour Tower');
          projects.others['project-0'] = [
            const ProjectPerson(
              profileId: 'user-1',
              firstName: 'Omar',
              lastName: 'Haddad',
              role: 'Site engineer',
            ),
          ];
        },
      );
      expect(app.profiles.profiles, contains('user-1'));
      _go(tester, '/projects/project-0');
      await tester.pumpAndSettle();
      await _tap(tester, 'project-person-user-1');
      expect(find.byKey(const Key('person-profile')), findsOneWidget);
    });
  }

  test('months use Western digits in Arabic', () {
    expect(formatMonth(DateTime(2023, 3), 'ar'), contains('2023'));
    expect(formatMonth(DateTime(2023, 3), 'en'), 'Mar 2023');
  });

  test('a future end month is a forecast', () {
    final now = DateTime(2026, 10, 11);
    expect(
      NewProjectInput(
        name: 'X',
        typeId: 't',
        marketId: 'kw',
        end: DateTime(2027, 3),
      ).endExpectedAt(now),
      isTrue,
    );
    expect(
      NewProjectInput(
        name: 'X',
        typeId: 't',
        marketId: 'kw',
        end: DateTime(2025, 3),
      ).endExpectedAt(now),
      isFalse,
    );
  });
}
