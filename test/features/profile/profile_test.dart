import 'package:buildvibes/core/l10n/bidi.dart';
import 'dart:typed_data';

import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/data/models/profile.dart';
import 'package:buildvibes/data/repositories/profile_page_repository.dart';
import 'package:buildvibes/features/profile/edit/basics_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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

/// Back one screen, the way the app bar's back arrow does.
Future<void> _back(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
  await tester.pumpAndSettle();
}

CvProjectEntry _cv(
  String id,
  String name, {
  required bool confirmed,
  bool show = true,
}) => CvProjectEntry(
  id: 'cv-$id',
  projectId: id,
  projectName: name,
  role: 'BIM Manager',
  showOnProfile: show,
  confirmed: confirmed,
  start: DateTime(2023, 3),
);

/// A second person, Layla, for visitor tests.
void _addLayla(TestApp app) {
  app.profiles.profiles['p-layla'] = const MyProfile(
    id: 'p-layla',
    firstName: 'Layla',
    lastName: 'Haddad',
    locale: 'en',
    tradeId: 'site_engineer',
    homeMarketId: 'kw',
  );
  app.pages.followerCounts['p-layla'] = 12;
  app.pages.about['p-layla'] = 'Site engineer on high-rise concrete works.';
  app.pages.cv['p-layla'] = [
    _cv('pr-1', 'Harbour Tower', confirmed: true),
    _cv('pr-2', 'Hidden Project', confirmed: false, show: false),
  ];
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('own profile: header, counts, empty proof, finish [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      expect(find.text('Omar Haddad'), findsOneWidget);
      expect(
        find.text('${l10n.profileFollowers(0)} · ${l10n.profileFollowing(0)}'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('proof-card')), findsOneWidget);
      expect(find.text(l10n.proofEmptyTitle), findsOneWidget);
      expect(find.text(l10n.finishProfileProgress(0, 5)), findsOneWidget);
      expect(find.text(l10n.workDeliveredEmpty), findsOneWidget);
      // The empty proof card leads to "Is it already here?".
      await _tap(tester, 'proof-add-project');
      expect(find.byKey(const Key('project-search')), findsOneWidget);
      await _back(tester);
      for (final tab in [
        l10n.profileTabOverview,
        l10n.profileTabPosts,
        l10n.profileTabProjects,
        l10n.profileTabExperience,
      ]) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('proof card: confirmed and waiting projects [$lang]', (
      tester,
    ) async {
      await pumpApp(
        tester,
        language: lang,
        setUp: (pages, _) => pages.cv['user-1'] = [
          _cv('pr-1', 'Harbour Tower', confirmed: true),
          _cv('pr-2', 'Salmiya Seafront', confirmed: false),
        ],
      );
      await _tap(tester, 'nav-profile');
      expect(
        find.descendant(
          of: find.byKey(const Key('proof-pr-1')),
          matching: find.text(l10n.proofConfirmed),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('proof-pr-2')),
          matching: find.text(l10n.proofWaiting),
        ),
        findsOneWidget,
      );
      // No aggregate counts on the card (rule 3).
      expect(find.textContaining('confirmed ·'), findsNothing);
    });

    testWidgets(
      'visitor: followers only, shown projects only, follow [$lang]',
      (tester) async {
        final app = await pumpApp(tester, language: lang);
        _addLayla(app);
        _go(tester, '/people/p-layla');
        await tester.pumpAndSettle();
        expect(find.text('Layla Haddad'), findsOneWidget);
        expect(find.text(l10n.profileFollowers(12)), findsOneWidget);
        expect(find.textContaining(l10n.profileFollowing(0)), findsNothing);
        expect(find.text('Harbour Tower'), findsOneWidget);
        expect(find.text('Hidden Project'), findsNothing);
        expect(find.byKey(const Key('proof-card')), findsNothing);

        await _tap(tester, 'profile-follow');
        expect(app.profiles.follows, contains('p-layla'));
        expect(find.text(l10n.following), findsOneWidget);
        await _tap(tester, 'profile-follow');
        expect(app.profiles.follows, isNot(contains('p-layla')));
      },
    );

    testWidgets('visitor: block asks first, then leaves the profile [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      _addLayla(app);
      _go(tester, '/people/p-layla');
      await tester.pumpAndSettle();
      await _tap(tester, 'profile-more');
      await _tap(tester, 'profile-block');
      // The block dialog, as drawn, with the full name.
      expect(
        find.text(l10n.blockConfirmTitle(inOwnDirection('Layla Haddad'))),
        findsOneWidget,
      );
      await _tap(tester, 'bv-dialog-confirm');
      expect(app.safety.calls, contains('block p-layla true'));
      expect(find.text('Layla Haddad'), findsNothing);
      // The toast, with Undo.
      expect(find.byKey(const Key('block-toast')), findsOneWidget);
      await tester.tap(find.text(l10n.postUndo));
      await tester.pumpAndSettle();
      expect(app.safety.calls.last, 'block p-layla false');
    });

    testWidgets('visitor: report the account, then Block from R2 [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      _addLayla(app);
      _go(tester, '/people/p-layla');
      await tester.pumpAndSettle();
      await _tap(tester, 'profile-more');
      await _tap(tester, 'profile-report');
      expect(find.text(l10n.reportTitle('profile')), findsOneWidget);
      expect(find.text(l10n.reportSubtitle), findsOneWidget);
      await _tap(tester, 'report-reason-fake');
      expect(app.safety.calls, ['report profile p-layla fake']);
      await _tap(tester, 'report-block');
      await _tap(tester, 'bv-dialog-confirm');
      expect(app.safety.calls.last, 'block p-layla true');
      expect(find.text('Layla Haddad'), findsNothing);
    });

    testWidgets('edit: headline shows under the name [$lang]', (tester) async {
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-edit');
      await _tap(tester, 'edit-basics');
      await _type(tester, 'basics-headline', 'BIM Manager');
      await _tap(tester, 'basics-save');
      await _back(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('profile-role-line'))).data,
        contains('BIM Manager'),
      );
    });

    testWidgets('edit: a photo is uploaded to your own folder [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        overrides: [
          photoPickerProvider.overrideWithValue(
            () async => XFile.fromData(Uint8List(4)),
          ),
        ],
      );
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-edit');
      await _tap(tester, 'edit-basics');
      expect(find.text(l10n.addPhoto), findsOneWidget);
      await _tap(tester, 'basics-photo');
      expect(app.pages.photo['user-1'], 'user-1/photo.jpg');
      expect(find.text(l10n.changePhoto), findsOneWidget);
      expect(find.text(l10n.removePhoto), findsOneWidget);
    });

    testWidgets('edit: about, then it shows on the profile [$lang]', (
      tester,
    ) async {
      await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-edit');
      await _tap(tester, 'edit-about');
      await _type(tester, 'about-field', 'Coordination on high-rise projects.');
      await _tap(tester, 'about-save');
      await _back(tester);
      expect(find.text('Coordination on high-rise projects.'), findsOneWidget);
      expect(find.text(l10n.profileAbout), findsOneWidget);
    });

    testWidgets('edit: experience with a month and "only me" [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-edit');
      await _tap(tester, 'edit-experience');
      await _tap(tester, 'experience-add');
      await _tap(tester, 'experience-save');
      expect(find.text(l10n.titleRequired), findsOneWidget);
      expect(find.text(l10n.startRequired), findsOneWidget);

      await _type(tester, 'experience-title', 'Site engineer');
      await _tap(tester, 'experience-start');
      await _tap(tester, 'month-year-back');
      await _tap(tester, 'month-3');
      await _tap(tester, 'show-only-me');
      await _tap(tester, 'experience-save');
      final saved = app.pages.experience['user-1']!.single;
      expect(saved.title, 'Site engineer');
      expect(saved.start, DateTime(2025, 3));
      expect(saved.end, isNull, reason: 'still going by default');
      expect(saved.visibility, ShowTo.onlyMe);
      expect(find.text('Site engineer'), findsOneWidget);
    });

    testWidgets('edit: open to, for connections only [$lang]', (tester) async {
      final app = await pumpApp(tester, language: lang);
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-edit');
      await _tap(tester, 'edit-open-to');
      await _tap(tester, 'open-to-consulting');
      await _tap(tester, 'show-connections');
      await _tap(tester, 'open-to-save');
      final saved = app.pages.openTo['user-1']!;
      expect(saved.options, ['consulting']);
      expect(saved.visibility, ShowTo.connections);
      await _back(tester);
      expect(find.text(l10n.openToConsulting), findsOneWidget);
      expect(find.text(l10n.openToConnectionsOnly), findsOneWidget);
    });

    testWidgets('edit: a CV project can be hidden from the profile [$lang]', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        language: lang,
        setUp: (pages, _) => pages.cv['user-1'] = [
          _cv('pr-1', 'Harbour Tower', confirmed: false),
        ],
      );
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'profile-edit');
      await _tap(tester, 'edit-projects');
      expect(find.text(l10n.cvShowOnProfile), findsOneWidget);
      await _tap(tester, 'cv-row-cv-pr-1');
      expect(app.pages.cv['user-1']!.single.showOnProfile, isFalse);
    });
  }

  test('role label: headline first, then the trade', () {
    final p = ProfileView(
      id: 'x',
      firstName: 'A',
      lastName: 'B',
      followerCount: 0,
      followingCount: 0,
      tradeId: 'site_engineer',
      tradeName: const LocalizedText(en: 'Site engineer', ar: 'مهندس موقع'),
    );
    expect(p.roleLabel('en'), 'Site engineer');
    expect(p.roleLabel('ar'), 'مهندس موقع');
    final withHeadline = ProfileView(
      id: 'x',
      firstName: 'A',
      lastName: 'B',
      followerCount: 0,
      followingCount: 0,
      headline: 'BIM Manager',
      tradeId: 'site_engineer',
    );
    expect(withHeadline.roleLabel('ar'), 'BIM Manager');
  });

  test('finish your profile counts five steps', () {
    final p = ProfileView(
      id: 'x',
      firstName: 'A',
      lastName: 'B',
      followerCount: 0,
      followingCount: 0,
      photoPath: 'x/p.jpg',
      about: 'Hi',
      projects: [_cv('a', 'A', confirmed: false)],
    );
    expect(p.completion, (3, 5));
  });

  test(
    'places: each city followed by its areas, areas named with the city',
    () {
      Map<String, dynamic> row(
        String id,
        String level,
        String en,
        int sort, [
        String? parent,
      ]) => {
        'id': id,
        'level': level,
        'name': {'en': en, 'ar': en},
        'sort': sort,
        'parent_id': parent,
      };
      final out = orderPlaces([
        row('jahra-area', 'area', 'Jahra', 1, 'jahra'),
        row('salmiya', 'area', 'Salmiya', 1, 'hawalli'),
        row('jahra', 'city', 'Jahra', 2),
        row('hawalli', 'city', 'Hawalli', 1),
      ]);
      expect(
        [for (final p in out) p.name.en],
        ['Hawalli', 'Salmiya · Hawalli', 'Jahra', 'Jahra · Jahra'],
      );
    },
  );
}
