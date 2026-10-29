// Review 105C part A (SP1 2666:38461, SP2 2667:38511; AR 2666:38593,
// 2667:38891): a Space's places. The writing card's Place row opens a
// picker built like Give to's: a search, the Space's places A to Z, and
// "Add place ‘…’" for who may post work; a Lead renames or deletes one
// from a long press; the pick is saved with set_post_place. A post with a
// place shows its site tag (sand, with a pin); an older post keeps its
// typed place. A tap on a tag filters Work to that place, said by a chip
// with ✕; Search finds places. In English and Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/space_search.dart';
import 'package:buildvibes/features/work/daybook_draft.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/shared/widgets/bv_place_picker.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/shared/widgets/bv_writing_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/search_fakes.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));
Finder _entry(String id) => _key('daybook-card-$id');

const _l3 = SpacePlace(id: 'place-l3', name: 'L3 · Grid B4');
const _l2 = SpacePlace(id: 'place-l2', name: 'L2 · Grid C7');
const _gate = SpacePlace(id: 'place-gate', name: 'Gate 2');

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  List<DaybookCard> posts = const [],
  SpacePass pass = SpacePass.lead,
  SpaceDetail? detail,
  FakeDaybookRepository? daybook,
  FakeSearchRepository? search,
  String me = DaybookSamples.islam,
}) async {
  final s = DaybookSamples(lang);
  final fake = daybook ?? FakeDaybookRepository();
  fake.posts[DaybookSamples.space] = posts;
  fake.placesBySpace.putIfAbsent(DaybookSamples.space, () => [_l3, _gate, _l2]);
  final app = await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] =
          detail ?? s.detail(pass: pass, admin: pass == SpacePass.lead)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: fake,
    search: search,
    now: DaybookSamples.thursday,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await _tap(tester, _key('post-bar-notepad'));
  await _tap(tester, _key('writing-place-row'));
}

DaybookPostDraft? _draft(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(daybookDraftProvider(DaybookSamples.space));

BvWritingRow _placeRow(WidgetTester tester) => tester
    .widget<BvWritingRows>(find.byType(BvWritingRows))
    .rows
    .firstWhere((r) => r.key == const Key('writing-place-row'));

/// A work item tagged [placeId], raised at [h]:[m] on Thursday.
DaybookCard _tagged(
  DaybookSamples s,
  String id,
  String title,
  String? placeId, {
  int h = 9,
  int m = 0,
  String? place,
}) => s.card(
  s.item(
    id: id,
    at: DateTime(2026, 10, 15, h, m),
    title: title,
    authorId: DaybookSamples.islam,
    ownerId: DaybookSamples.omar,
    placeId: placeId,
    place: place,
  ),
);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);

    group('105C the Place picker [$lang]', () {
      testWidgets('Place opens the picker: a search, then the Space\'s '
          'places A to Z', (tester) async {
        await _open(tester, lang);
        await _openPicker(tester);
        expect(find.byType(BvPlacePicker), findsOneWidget);
        expect(_key('place-search'), findsOneWidget);
        final ys = [
          for (final p in [_gate, _l2, _l3])
            tester.getTopLeft(_key('place-row-${p.id}')).dy,
        ];
        expect(ys, [...ys]..sort());
        // Typing filters.
        await tester.enterText(
          find.descendant(
            of: _key('place-search'),
            matching: find.byType(TextField),
          ),
          'grid',
        );
        await tester.pumpAndSettle();
        expect(_key('place-row-${_gate.id}'), findsNothing);
        expect(_key('place-row-${_l2.id}'), findsOneWidget);
        expect(_key('place-row-${_l3.id}'), findsOneWidget);
      });

      testWidgets('the lead\'s check O1: a bottom sheet like Give to\'s: '
          'its grabber and "Place", the search on top, A to Z with a check on '
          'the chosen one; "Add place" first when nothing matches', (
        tester,
      ) async {
        await _open(tester, lang);
        await _openPicker(tester);
        final sheet = _key('bv-sheet');
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.byType(BvPlacePicker)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: _key('bv-sheet-handle')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text(l10n.daybookRowPlace)),
          findsOneWidget,
        );
        // Not the popover over the writing card's rows.
        expect(find.byType(BvPopoverMenu<int>), findsNothing);
        final search = tester.getTopLeft(_key('place-search')).dy;
        final ys = [
          for (final p in [_gate, _l2, _l3])
            tester.getTopLeft(_key('place-row-${p.id}')).dy,
        ];
        expect(ys.every((y) => y > search), isTrue);
        expect(ys, [...ys]..sort());
        // The chosen one has its check.
        await _tap(tester, _key('place-row-${_l2.id}'));
        expect(_key('bv-sheet'), findsNothing);
        await _tap(tester, _key('writing-place-row'));
        expect(
          find.descendant(
            of: _key('place-row-${_l2.id}'),
            matching: find.byIcon(BvIcons.check),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('place-row-${_gate.id}'),
            matching: find.byIcon(BvIcons.check),
          ),
          findsNothing,
        );
        // A name the Space hasn't got: "Add place" is the first row.
        await tester.enterText(
          find.descendant(
            of: _key('place-search'),
            matching: find.byType(TextField),
          ),
          'Roof',
        );
        await tester.pumpAndSettle();
        expect(_key('place-add'), findsOneWidget);
        expect(find.text(l10n.daybookPlaceAdd('Roof')), findsOneWidget);
        expect(tester.getTopLeft(_key('place-add')).dy, greaterThan(search));
      });

      testWidgets('a pick is the row\'s value, and the post goes with it '
          '(set_post_place)', (tester) async {
        final app = await _open(tester, lang);
        await _openPicker(tester);
        await _tap(tester, _key('place-row-${_l3.id}'));
        expect(find.byType(BvPlacePicker), findsNothing);
        expect(_placeRow(tester).value, _l3.name);
        expect(_draft(tester)?.placeId, _l3.id);
        await tester.enterText(_key('writing-title'), 'Rebar spacing');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-who'));
        await _tap(tester, find.text(s.omarName).last);
        await _tap(tester, _key('writing-post'));
        final id = app.daybook.created.single.id;
        expect(app.daybook.calls, contains('set-place $id ${_l3.id}'));
        // The lead's check M1: its name goes too, as place_text.
        expect(app.daybook.created.single.place, _l3.name);
      });

      testWidgets('the lead\'s check M1: the item is made but its place is '
          'refused: it counts as sent, with its name and no refused card', (
        tester,
      ) async {
        final app = await _open(tester, lang);
        app.daybook.refusePlace = true;
        await _openPicker(tester);
        await _tap(tester, _key('place-row-${_l3.id}'));
        await tester.enterText(_key('writing-title'), 'Rebar spacing');
        await tester.pumpAndSettle();
        await _tap(tester, _key('writing-who'));
        await _tap(tester, find.text(s.omarName).last);
        await _tap(tester, _key('writing-post'));
        expect(app.daybook.created.single.place, _l3.name);
        expect(
          app.daybook.calls.where((c) => c.startsWith('set-place')),
          isEmpty,
        );
        final outbox = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        ).read(workOutboxProvider);
        expect(outbox.where((i) => i.refused), isEmpty);
        expect(find.text(l10n.daybookCouldNotSend), findsNothing);
      });

      for (final refuse in [false, true]) {
        testWidgets('the lead\'s check M1: an edit to another place sends '
            'its name too${refuse ? '; refused, the edit stays saved with no '
                      'error' : ''}', (tester) async {
          final app = await _open(
            tester,
            lang,
            posts: [
              _tagged(s, 'post-a', 'Rebar spacing', _l2.id, place: _l2.name),
            ],
          );
          app.daybook.refusePlace = refuse;
          await _tap(tester, find.text('Rebar spacing'));
          await _tap(tester, _key('page-title'));
          await _tap(tester, _key('writing-place-row'));
          await _tap(tester, _key('place-row-${_l3.id}'));
          await _tap(tester, _key('writing-post'));
          expect(
            app.daybook.calls,
            contains('edit post-a {"place":"${_l3.name}"}'),
          );
          expect(
            app.daybook.calls.contains('set-place post-a ${_l3.id}'),
            !refuse,
          );
          expect(find.text(l10n.spacesNotAllowed), findsNothing);
          expect(find.byType(BvWritingCard), findsNothing);
        });
      }

      testWidgets('"Add place ‘…’" for who may post work: the new place is '
          'added and picked', (tester) async {
        final app = await _open(tester, lang);
        await _openPicker(tester);
        await tester.enterText(
          find.descendant(
            of: _key('place-search'),
            matching: find.byType(TextField),
          ),
          'Roof',
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('place-add'),
            matching: find.text(l10n.daybookPlaceAdd('Roof')),
          ),
          findsOneWidget,
        );
        await _tap(tester, _key('place-add'));
        expect(
          app.daybook.calls,
          contains('add-place ${DaybookSamples.space} Roof'),
        );
        expect(_placeRow(tester).value, 'Roof');
        expect(_draft(tester)?.placeId, isNotNull);
      });

      testWidgets('a name the Space has, whatever its case: no Add', (
        tester,
      ) async {
        await _open(tester, lang);
        await _openPicker(tester);
        await tester.enterText(
          find.descendant(
            of: _key('place-search'),
            matching: find.byType(TextField),
          ),
          ' gate  2',
        );
        await tester.pumpAndSettle();
        expect(_key('place-add'), findsNothing);
        expect(_key('place-row-${_gate.id}'), findsOneWidget);
      });

      testWidgets('who may write but not post work (a Viewer let write): '
          'no Add', (tester) async {
        await _open(
          tester,
          lang,
          me: DaybookSamples.mona,
          detail: SpaceDetail(
            id: DaybookSamples.space,
            name: s.spaceName,
            myPass: SpacePass.viewer,
            iAmAdmin: false,
            myRights: const MemberRights(createItems: true),
          ),
        );
        await _openPicker(tester);
        await tester.enterText(
          find.descendant(
            of: _key('place-search'),
            matching: find.byType(TextField),
          ),
          'Roof',
        );
        await tester.pumpAndSettle();
        expect(_key('place-add'), findsNothing);
      });

      testWidgets('a Lead renames a place from a long press', (tester) async {
        final app = await _open(tester, lang);
        await _openPicker(tester);
        await tester.longPress(_key('place-row-${_gate.id}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('place-rename'));
        await tester.enterText(_key('place-rename-field'), 'Gate 2 (north)');
        await tester.pumpAndSettle();
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(
          app.daybook.calls,
          contains('rename-place ${_gate.id} Gate 2 (north)'),
        );
        expect(find.text('Gate 2 (north)'), findsOneWidget);
      });

      testWidgets('a Lead deletes a place, asked first', (tester) async {
        final app = await _open(tester, lang);
        await _openPicker(tester);
        await tester.longPress(_key('place-row-${_gate.id}'));
        await tester.pumpAndSettle();
        await _tap(tester, _key('place-delete'));
        expect(find.text(l10n.daybookPlaceDeleteTitle(_gate.name)), findsOne);
        await _tap(tester, _key('bv-dialog-confirm'));
        expect(app.daybook.calls, contains('delete-place ${_gate.id}'));
        expect(_key('place-row-${_gate.id}'), findsNothing);
      });

      testWidgets('Crew: a long press does nothing', (tester) async {
        final app = await _open(
          tester,
          lang,
          pass: SpacePass.crew,
          me: DaybookSamples.omar,
        );
        await _openPicker(tester);
        await tester.longPress(_key('place-row-${_gate.id}'));
        await tester.pumpAndSettle();
        expect(_key('place-rename'), findsNothing);
        expect(_key('place-delete'), findsNothing);
        expect(app.daybook.calls.where((c) => c.contains('-place')), isEmpty);
      });
    });

    group('105C site tags and the place filter [$lang]', () {
      testWidgets('a post with a place shows its site tag; an older one '
          'keeps its typed place', (tester) async {
        await _open(
          tester,
          lang,
          posts: [
            _tagged(s, 'post-a', 'Rebar spacing', _l3.id),
            _tagged(s, 'post-old', 'Old item', null, h: 8, place: 'Basement'),
          ],
        );
        await scrollToRow(tester, _entry('post-a'));
        final tag = _key('site-tag-post-a');
        expect(tag, findsOneWidget);
        expect(
          find.descendant(of: tag, matching: find.text(_l3.name)),
          findsOneWidget,
        );
        await scrollToRow(tester, _entry('post-old'));
        expect(_key('site-tag-post-old'), findsNothing);
        expect(
          find.descendant(
            of: _entry('post-old'),
            matching: find.text('Basement'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a tap on a tag filters Work to that place; the chip\'s ✕ '
          'shows everything again', (tester) async {
        await _open(
          tester,
          lang,
          posts: [
            _tagged(s, 'post-a', 'Rebar spacing', _l3.id, h: 10),
            _tagged(s, 'post-b', 'Formwork check', _l2.id, h: 9),
            _tagged(s, 'post-c', 'Pour sequence', _l3.id, h: 8),
          ],
        );
        await scrollToRow(tester, _entry('post-a'));
        await _tap(tester, _key('site-tag-post-a'));
        final chip = _key('place-filter');
        expect(chip, findsOneWidget);
        expect(
          find.descendant(of: chip, matching: find.text(_l3.name)),
          findsOneWidget,
        );
        expect(_entry('post-b'), findsNothing);
        await scrollToRow(tester, _entry('post-c'));
        expect(_entry('post-c'), findsOneWidget);
        await _tap(tester, _key('place-filter-clear'));
        expect(chip, findsNothing);
        await scrollToRow(tester, _entry('post-b'));
        expect(_entry('post-b'), findsOneWidget);
      });

      testWidgets('the chip sits under the Work · Chat switch, above the '
          'cards', (tester) async {
        await _open(
          tester,
          lang,
          posts: [_tagged(s, 'post-a', 'Rebar spacing', _l3.id)],
        );
        await scrollToRow(tester, _entry('post-a'));
        await _tap(tester, _key('site-tag-post-a'));
        final chip = tester.getRect(_key('place-filter'));
        expect(
          chip.top,
          greaterThanOrEqualTo(tester.getRect(_key('space-switch')).bottom),
        );
        expect(
          chip.bottom,
          lessThanOrEqualTo(tester.getRect(_entry('post-a')).top),
        );
      });

      testWidgets('Search finds a place; a tap opens Work filtered to it', (
        tester,
      ) async {
        final search = FakeSearchRepository()
          ..hits.add(
            SpaceSearchHit(
              kind: SpaceSearchKind.place,
              id: _l3.id,
              title: _l3.name,
              createdAt: DaybookSamples.thursday,
            ),
          );
        await _open(
          tester,
          lang,
          search: search,
          posts: [
            _tagged(s, 'post-a', 'Rebar spacing', _l3.id, h: 10),
            _tagged(s, 'post-b', 'Formwork check', _l2.id, h: 9),
          ],
        );
        await _tap(tester, _key('space-search'));
        await tester.enterText(find.byType(TextField).first, 'grid b4');
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.searchPlaces), findsOneWidget);
        await _tap(tester, _key('search-place-${_l3.id}'));
        expect(_key('place-filter'), findsOneWidget);
        expect(_entry('post-b'), findsNothing);
      });
    });
  }
}
