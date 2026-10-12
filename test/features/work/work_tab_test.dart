import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/project.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/features/spaces/space_screen.dart';
import 'package:buildvibes/features/work/work_item_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/work_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)).first);
  await tester.pumpAndSettle();
}

const _space = 'space-1';
const _me = 'user-1';

WorkItem _item(
  String ref, {
  required WorkStatus status,
  String owner = 'p-rakesh',
  String ownerName = 'Rakesh Nair',
  String creator = 'p-sara',
  String creatorName = 'Sara Ali',
  DateTime? due,
  DateTime? checkedAt,
  String? note,
  List<String> photos = const [],
  String? team,
}) => WorkItem(
  id: 'item-$ref',
  spaceId: _space,
  ref: ref,
  title: 'Item $ref',
  status: status,
  createdAt: testNow,
  ownerId: owner,
  ownerName: ownerName,
  createdById: creator,
  createdByName: creatorName,
  teamName: team,
  place: 'Level 2 · Grid C7',
  due: due,
  checkedAt: checkedAt,
  checkedByName: checkedAt == null ? null : 'Sara Ali',
  doneNote: note,
  photoPaths: photos,
);

/// Omar (signed in) runs the Space. The server says KCT-021 waits for his
/// sign-off and KCT-017 for his check.
FakeWorkRepository _work({bool empty = false, bool needsNothing = false}) {
  final work = FakeWorkRepository();
  work.itemsBySpace[_space] = empty
      ? []
      : [
          _item(
            'KCT-021',
            status: WorkStatus.open,
            owner: _me,
            ownerName: 'Omar Haddad',
            due: testNow.add(const Duration(days: 1)),
            team: 'Structure',
          ),
          _item(
            'KCT-017',
            status: WorkStatus.done,
            creator: _me,
            creatorName: 'Omar Haddad',
            note: 'Sleeves fixed',
            photos: ['$_space/item-KCT-017/done.jpg'],
          ),
          _item(
            'KCT-019',
            status: WorkStatus.open,
            due: testNow.subtract(const Duration(days: 2)),
          ),
          _item('KCT-020', status: WorkStatus.done),
          _item(
            'KCT-012',
            status: WorkStatus.checked,
            checkedAt: testNow.subtract(const Duration(days: 2)),
          ),
          _item(
            'KCT-005',
            status: WorkStatus.checked,
            checkedAt: testNow.subtract(const Duration(days: 20)),
          ),
        ];
  work.needsBySpace[_space] = needsNothing
      ? const WorkNeeds()
      : const WorkNeeds(toSign: {'item-KCT-021'}, toCheck: {'item-KCT-017'});
  return work;
}

FakeSpaceRepository _spaces({bool canCreate = true}) =>
    FakeSpaceRepository()
      ..details[_space] = SpaceDetail(
        id: _space,
        name: 'Site team',
        projectId: 'proj-1',
        projectName: 'Kuwait City Tower',
        myPass: SpacePass.lead,
        iAmAdmin: canCreate,
        myRights: MemberRights(createItems: canCreate, checkItems: canCreate),
      );

Future<void> _open(
  WidgetTester tester,
  String lang, {
  FakeWorkRepository? work,
  FakeSpaceRepository? spaces,
}) async {
  await pumpApp(
    tester,
    language: lang,
    spaces: spaces ?? _spaces(),
    work: work ?? _work(),
    setUp: (_, projects) => projects.records['proj-1'] = const ProjectRecord(
      id: 'proj-1',
      name: 'Kuwait City Tower',
      typeId: 'construction',
      marketId: 'kw',
      typeName: LocalizedText(en: 'Construction', ar: 'إنشاءات'),
      placeName: LocalizedText(en: 'Sharq', ar: 'شرق'),
    ),
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space');
  await tester.pumpAndSettle();
}

bool _shown(String ref) =>
    find.byKey(Key('work-item-item-$ref')).evaluate().isNotEmpty;

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('All: Needs you, Open, Checked this week [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      expect(find.byType(SpaceScreen), findsOneWidget);
      // The title block and the privacy line.
      expect(find.text('Kuwait City Tower'), findsOneWidget);
      expect(
        find.text(lang == 'ar' ? 'إنشاءات' : 'CONSTRUCTION'),
        findsOneWidget,
      );
      expect(find.text(l10n.workPrivacyLine), findsOneWidget);

      // Needs you first, with the action the server says is yours.
      expect(find.text(l10n.workSectionNeedsYou), findsOneWidget);
      expect(_shown('KCT-021') && _shown('KCT-017'), isTrue);
      expect(find.text(l10n.workSignAsDone), findsOneWidget);
      expect(find.text(l10n.workCheckIt), findsOneWidget);
      expect(find.text(l10n.workStatusDoneYouCheck), findsOneWidget);

      // Then Open: the others' items, including Done ones waiting.
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text(l10n.workSectionOpen),
        200,
        scrollable: list,
      );
      for (final ref in ['KCT-019', 'KCT-020', 'KCT-012']) {
        await tester.scrollUntilVisible(
          find.byKey(Key('work-item-item-$ref')),
          200,
          scrollable: list,
        );
        expect(_shown(ref), isTrue, reason: ref);
      }
      expect(find.text(l10n.workSectionCheckedWeek), findsOneWidget);
      expect(find.text(l10n.workStatusDoneWaiting), findsWidgets);
      // Older checked work is only under Checked.
      expect(_shown('KCT-005'), isFalse);
    });

    testWidgets('filters: Mine, Open, To check, Checked [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);

      await _tap(tester, 'work-filter-mine');
      expect(_shown('KCT-021') && _shown('KCT-017'), isTrue);
      expect(_shown('KCT-019') || _shown('KCT-020'), isFalse);

      await _tap(tester, 'work-filter-open');
      expect(_shown('KCT-021') && _shown('KCT-019'), isTrue);
      expect(_shown('KCT-017') || _shown('KCT-020'), isFalse);

      await _tap(tester, 'work-filter-toCheck');
      expect(_shown('KCT-017') && _shown('KCT-020'), isTrue);
      expect(find.text(l10n.workSectionWaitingCheck), findsOneWidget);

      await _tap(tester, 'work-filter-checked');
      expect(_shown('KCT-012') && _shown('KCT-005'), isTrue);
      expect(find.text(l10n.workSectionCheckedEarlier), findsOneWidget);
    });

    testWidgets('an Open item past its due date says so [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      await _tap(tester, 'work-filter-open');
      expect(
        find.textContaining(l10n.workStatusOverdue('').trim()),
        findsWidgets,
      );
    });

    testWidgets('nothing yet: an empty state, and New item to start [$lang]', (
      tester,
    ) async {
      await _open(tester, lang, work: _work(empty: true));
      expect(find.text(l10n.workEmptyTitle), findsOneWidget);
      expect(find.text(l10n.workEmptyCanCreate), findsOneWidget);
      expect(find.byKey(const Key('work-new-item')), findsOneWidget);
    });

    testWidgets('no right to create: no New item [$lang]', (tester) async {
      await _open(
        tester,
        lang,
        work: _work(empty: true),
        spaces: _spaces(canCreate: false),
      );
      expect(find.text(l10n.workEmptyCannot), findsOneWidget);
      expect(find.byKey(const Key('work-new-item')), findsNothing);
    });

    testWidgets('nothing needs you right now [$lang]', (tester) async {
      await _open(tester, lang, work: _work(needsNothing: true));
      expect(find.text(l10n.workNothingNeedsYou), findsOneWidget);
      expect(find.text(l10n.workSignAsDone), findsNothing);
    });

    testWidgets('an item whose owner left: Owner left · reassign [$lang]', (
      tester,
    ) async {
      final work = _work(needsNothing: true);
      work.needsBySpace[_space] = const WorkNeeds(toReassign: {'item-KCT-019'});
      await _open(tester, lang, work: work);
      expect(find.text(l10n.workStatusOwnerLeft), findsOneWidget);
      expect(find.text(l10n.workReassign), findsOneWidget);
    });

    testWidgets('the last card scrolls clear of New item [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      final list = tester.widget<ListView>(find.byKey(const Key('work-tab')));
      final bottom = (list.padding! as EdgeInsetsDirectional).bottom;
      final button = tester.getSize(find.byKey(const Key('work-new-item')));
      expect(bottom, greaterThanOrEqualTo(button.height + 16));
    });

    testWidgets('a card opens its item [$lang]', (tester) async {
      await _open(tester, lang);
      await _tap(tester, 'work-item-item-KCT-021');
      expect(find.byType(WorkItemScreen), findsOneWidget);
      expect(find.text('KCT-021'), findsOneWidget);
    });
  }

  test('My Spaces counts everything that needs you', () {
    final s = SpaceSummary.fromJson(const {
      'space_id': 's',
      'name': 'S',
      'pass': 'lead',
      'is_admin': true,
      'pending_requests': 1,
      'needs_you': 3,
    });
    expect(s.needsYou, 3);
  });
}
