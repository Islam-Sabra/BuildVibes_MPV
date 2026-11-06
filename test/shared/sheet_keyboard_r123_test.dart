// Review 123, in English and Arabic: with the keyboard up, a sheet's main
// button sits above it, in view and tappable, with no scrolling.
import 'package:buildvibes/data/models/key_people.dart';
import 'package:buildvibes/data/models/project.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/projects/widgets/project_sheets.dart';
import 'package:buildvibes/features/spaces/need_you_sheet.dart';
import 'package:buildvibes/shared/widgets/bv_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../features/library/library_folders_test.dart' show openLibrary;
import '../helpers/key_people_fakes.dart';
import '../helpers/need_you_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tapIn(WidgetTester tester, String k) async {
  await tester.ensureVisible(_key(k));
  await tester.pumpAndSettle();
  await tester.tap(_key(k));
  await tester.pumpAndSettle();
}

Future<void> _typeIn(WidgetTester tester, String k, String text) async {
  await tester.enterText(
    find.descendant(of: _key(k), matching: find.byType(TextField)),
    text,
  );
  await tester.pumpAndSettle();
}

/// The 1 px line over the main button: only while the fields run under it.
bool _lineShows(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(_key('bv-sheet-form-action'));
  return (box.decoration as BoxDecoration).border != null;
}

const _space = 'space-1';
const _keyboard = 300.0;

FakeSpaceRepository _spaces() {
  final spaces = FakeSpaceRepository(now: testNow);
  spaces.details[_space] = const SpaceDetail(
    id: _space,
    name: 'NBKCH Site',
    myPass: SpacePass.lead,
    iAmAdmin: true,
    myRights: MemberRights(invite: true, createItems: true),
    marketId: 'kw',
  );
  spaces.spaces.add(
    const SpaceSummary(
      id: _space,
      name: 'NBKCH Site',
      pass: SpacePass.lead,
      isAdmin: true,
    ),
  );
  return spaces;
}

void _keyboardUp(WidgetTester tester) {
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  addTearDown(tester.view.resetViewInsets);
}

/// [k] is on screen above the keyboard, whole, and a tap reaches it.
void _aboveKeyboard(WidgetTester tester, String k) {
  final rect = tester.getRect(_key(k));
  final top = tester.view.physicalSize.height - _keyboard;
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(top), reason: '$k under the keyboard');
  expect(_key(k).hitTestable(), findsOneWidget);
}

void main() {
  for (final lang in ['en', 'ar']) {
    group('123 the main button above the keyboard [$lang]', () {
      testWidgets('KP4: Save, and the name being typed, stay in view', (
        tester,
      ) async {
        final keys = FakeKeyPeopleRepository()
          ..spaces[_space] = const KeyPeople();
        await pumpApp(
          tester,
          language: lang,
          spaces: _spaces(),
          keyPeople: keys,
        );
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/spaces/$_space/key-people');
        await tester.pumpAndSettle();
        await tester.tap(_key('key-people-add'));
        await tester.pumpAndSettle();
        _keyboardUp(tester);
        await tester.pumpAndSettle();
        // As it opens: every example showing, nothing typed yet.
        _aboveKeyboard(tester, 'key-role-name');
        _aboveKeyboard(tester, 'key-role-save');

        await tester.enterText(_key('key-role-name'), 'Crane');
        await tester.pumpAndSettle();
        await tester.enterText(_key('key-role-name'), 'Crane operator');
        await tester.pumpAndSettle();
        _aboveKeyboard(tester, 'key-role-name');
        _aboveKeyboard(tester, 'key-role-save');
        await tester.tap(_key('key-role-save'));
        await tester.pumpAndSettle();
        expect(keys.saved.single.name, 'Crane operator');
      });

      testWidgets('New folder: Save above the keyboard, the name in view', (
        tester,
      ) async {
        final app = await openLibrary(tester, lang, folders: const []);
        await _tapIn(tester, 'library-add');
        await _tapIn(tester, 'library-new-folder');
        _keyboardUp(tester);
        await tester.pumpAndSettle();
        await tester.showKeyboard(
          find.descendant(
            of: _key('folder-name'),
            matching: find.byType(TextField),
          ),
        );
        await _typeIn(tester, 'folder-name', 'Drawings');
        _aboveKeyboard(tester, 'folder-name');
        _aboveKeyboard(tester, 'folder-save');
        await tester.tap(_key('folder-save'));
        await tester.pumpAndSettle();
        expect(app.library.folderCalls.single, startsWith('create Drawings'));
      });

      testWidgets('Edit Space: Save above the keyboard, About in view', (
        tester,
      ) async {
        final spaces = _spaces();
        await pumpApp(tester, language: lang, spaces: spaces);
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/spaces/$_space');
        await tester.pumpAndSettle();
        await _tapIn(tester, 'space-header');
        await _tapIn(tester, 'space-edit');
        _keyboardUp(tester);
        await tester.pumpAndSettle();
        await tester.showKeyboard(
          find.descendant(
            of: _key('edit-space-about'),
            matching: find.byType(TextField),
          ),
        );
        await _typeIn(tester, 'edit-space-about', 'Block B finishes');
        _aboveKeyboard(tester, 'edit-space-about');
        _aboveKeyboard(tester, 'edit-space-save');
        await tester.tap(_key('edit-space-save'));
        await tester.pumpAndSettle();
        expect(spaces.calls.last, startsWith('update NBKCH Site'));
      });

      testWidgets('Suggest an edit: Send above the keyboard, the value in '
          'view', (tester) async {
        await pumpApp(tester, language: lang);
        (EditField, String)? sent;
        showSuggestEditSheet(
          tester.element(find.byType(Navigator).first),
          projectName: 'Harbour Tower',
        ).then((v) => sent = v);
        await tester.pumpAndSettle();
        await _tapIn(tester, 'wrong-dates');
        _keyboardUp(tester);
        await tester.pumpAndSettle();
        await tester.showKeyboard(
          find.descendant(
            of: _key('suggest-value'),
            matching: find.byType(TextField),
          ),
        );
        await _typeIn(tester, 'suggest-value', 'Ended: Mar 2027');
        _aboveKeyboard(tester, 'suggest-value');
        _aboveKeyboard(tester, 'suggest-send');
        await tester.tap(_key('suggest-send'));
        await tester.pumpAndSettle();
        expect(sent, (EditField.dates, 'Ended: Mar 2027'));
      });

      testWidgets('Your role: Add above the keyboard, the role in view', (
        tester,
      ) async {
        await pumpApp(tester, language: lang);
        CvEntryInput? added;
        showCvEntrySheet(
          tester.element(find.byType(Navigator).first),
          projectName: 'Harbour Tower',
        ).then((v) => added = v);
        await tester.pumpAndSettle();
        _keyboardUp(tester);
        await tester.pumpAndSettle();
        await tester.showKeyboard(
          find.descendant(
            of: _key('cv-role'),
            matching: find.byType(TextField),
          ),
        );
        await _typeIn(tester, 'cv-role', 'BIM Manager');
        _aboveKeyboard(tester, 'cv-role');
        _aboveKeyboard(tester, 'cv-add');
        await tester.tap(_key('cv-add'));
        await tester.pumpAndSettle();
        expect(added?.role, 'BIM Manager');
      });

      testWidgets('Need you: Send above the keyboard, the place in view', (
        tester,
      ) async {
        final needYou = FakeNeedYouRepository();
        await pumpApp(tester, language: lang, needYou: needYou);
        showNeedYouSheet(
          tester.element(find.byType(Navigator).first),
          spaceId: _space,
          member: SpaceMember(
            person: const SpacePerson(
              id: 'p-omar',
              firstName: 'Omar',
              lastName: 'Haddad',
            ),
            pass: SpacePass.crew,
            isAdmin: false,
            confirmedAt: testNow,
          ),
        );
        await tester.pumpAndSettle();
        await _typeIn(tester, 'need-you-reason', 'Truck waiting');
        await _tapIn(tester, 'need-you-add-place');
        _keyboardUp(tester);
        await tester.pumpAndSettle();
        await tester.showKeyboard(
          find.descendant(
            of: _key('need-you-place'),
            matching: find.byType(TextField),
          ),
        );
        await _typeIn(tester, 'need-you-place', 'Gate 2');
        _aboveKeyboard(tester, 'need-you-place');
        _aboveKeyboard(tester, 'need-you-send');
        await tester.tap(_key('need-you-send'));
        await tester.pumpAndSettle();
        expect(needYou.sent.single.place, 'Gate 2');
      });

      testWidgets('the line over the button shows only while the fields '
          'run under it', (tester) async {
        final keys = FakeKeyPeopleRepository()
          ..spaces[_space] = const KeyPeople();
        await pumpApp(
          tester,
          language: lang,
          spaces: _spaces(),
          keyPeople: keys,
        );
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).push('/spaces/$_space/key-people');
        await tester.pumpAndSettle();
        await tester.tap(_key('key-people-add'));
        await tester.pumpAndSettle();
        // No keyboard: everything fits, no line (the sheet as before).
        expect(find.byType(BvSheetForm), findsOneWidget);
        expect(_lineShows(tester), isFalse);
        _keyboardUp(tester);
        await tester.pumpAndSettle();
        expect(_lineShows(tester), isTrue);
      });
    });
  }
}
