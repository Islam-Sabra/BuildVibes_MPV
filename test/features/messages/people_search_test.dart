// F78 (review 80): New message and Search people.
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/messages/dm_thread_screen.dart';
import 'package:buildvibes/features/profile/person_profile_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/people_search_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

const _omar = SpacePerson(
  id: 'p-omar',
  firstName: 'Omar',
  lastName: 'Haddad',
  headline: 'Site Engineer',
  companyLabel: 'Al Hamra Contracting',
);
const _sara = SpacePerson(
  id: 'p-sara',
  firstName: 'سارة',
  lastName: 'المطيري',
  headline: 'Foreman',
);
const _blocked = SpacePerson(id: 'p-bad', firstName: 'Omar', lastName: 'Bad');
const _stranger = SpacePerson(
  id: 'p-ali',
  firstName: 'Ali',
  lastName: 'Mansour',
  headline: 'Electrician',
);

FakePeopleSearchRepository _people() => FakePeopleSearchRepository(
  people: const [_stranger, _omar, _sara, _blocked],
  shared: const {'p-omar', 'p-sara'},
  blocked: const {'p-bad'},
);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('people-search-field')),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('+ in Messages opens New message: the people in my Spaces '
        'A–Z; a search by part of a name finds Omar; a tap writes to him '
        '[$lang]', (tester) async {
      await pumpApp(tester, language: lang, peopleSearch: _people());
      await tester.tap(find.byKey(const Key('home-messages')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('messages-new')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.messagesNew), findsOneWidget);
      expect(find.text(l10n.peopleInYourSpaces), findsOneWidget);
      expect(find.byKey(const Key('people-search-p-omar')), findsOneWidget);
      expect(find.byKey(const Key('people-search-p-sara')), findsOneWidget);
      expect(find.byKey(const Key('people-search-p-ali')), findsNothing);
      await _type(tester, 'had');
      expect(find.byKey(const Key('people-search-p-omar')), findsOneWidget);
      expect(find.byKey(const Key('people-search-p-sara')), findsNothing);
      await tester.tap(find.byKey(const Key('people-search-p-omar')));
      await tester.pumpAndSettle();
      expect(find.byType(DmThreadScreen), findsOneWidget);
    });

    testWidgets('a search by role finds someone outside my Spaces; someone '
        'I blocked never shows; Arabic names stay as written [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, peopleSearch: _people());
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pumpAndSettle();
      await _type(tester, 'electric');
      expect(find.byKey(const Key('people-search-p-ali')), findsOneWidget);
      await _type(tester, 'omar');
      expect(find.byKey(const Key('people-search-p-omar')), findsOneWidget);
      expect(find.byKey(const Key('people-search-p-bad')), findsNothing);
      await _type(tester, 'سارة');
      expect(find.textContaining('سارة المطيري'), findsOneWidget);
      await _type(tester, 'zzz');
      expect(find.textContaining('zzz'), findsWidgets);
    });

    testWidgets('Home\'s Search people opens a profile [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang, peopleSearch: _people());
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeSearch), findsWidgets);
      await tester.tap(find.byKey(const Key('people-search-p-omar')));
      await tester.pumpAndSettle();
      expect(find.byType(PersonProfileScreen), findsOneWidget);
    });
  }
}
