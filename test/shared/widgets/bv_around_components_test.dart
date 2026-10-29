// Slice 1 part 1e components: the Space emblem and header, the Space menu,
// Space info's slips and one-choice track, Needs you rows, the proof card,
// the pill button, the small tabs, and the 9 and 8 px stamps.
import 'package:buildvibes/core/design/around_specs.dart';
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/shared/widgets/bv_info_slip.dart';
import 'package:buildvibes/shared/widgets/bv_needs_row.dart';
import 'package:buildvibes/shared/widgets/bv_paper_clip.dart';
import 'package:buildvibes/shared/widgets/bv_pill_button.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_proof_card.dart';
import 'package:buildvibes/shared/widgets/bv_segmented.dart';
import 'package:buildvibes/shared/widgets/bv_space_emblem.dart';
import 'package:buildvibes/shared/widgets/bv_space_header.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_component.dart';

void main() {
  group('BvSpaceEmblem', () {
    testBoth('keeps the plan\'s 72 × 56 shape at its height', (
      tester,
      lang,
    ) async {
      await pumpComponent(
        tester,
        const Center(child: BvSpaceEmblem(height: BvSpaceEmblemSpec.info)),
        lang: lang,
      );
      expect(
        tester.getSize(find.byKey(const Key('space-emblem'))),
        const Size(72, 56),
      );
    });
  });

  group('BvSpaceHeader', () {
    testBoth('60 high; the name opens Space info; Search, Library and '
        'People at the end (review 105 Part 1)', (tester, lang) async {
      var opened = 0;
      var search = 0;
      var library = 0;
      var people = 0;
      await pumpComponent(
        tester,
        BvSpaceHeader(
          name: 'Kuwait City Tower — Site team',
          line: 'Private work · project Space',
          backLabel: 'Back',
          onOpen: () => opened++,
          searchLabel: 'Search',
          onSearch: () => search++,
          libraryLabel: 'Library',
          onLibrary: () => library++,
          peopleLabel: 'People',
          onPeople: () => people++,
          peopleWaiting: true,
          waitingLabel: 'join requests waiting',
        ),
        lang: lang,
        scroll: false,
      );
      expect(
        tester.getSize(find.byType(BvSpaceHeader)).height,
        BvSpaceHeaderSpec.height,
      );
      expect(find.byType(BvSpaceEmblem), findsOneWidget);
      expect(find.byKey(const Key('space-more')), findsNothing);
      await tester.tap(find.text('Kuwait City Tower — Site team'));
      await tester.tap(find.byKey(const Key('space-search')));
      await tester.tap(find.byKey(const Key('space-library')));
      await tester.tap(find.byKey(const Key('space-people')));
      expect((opened, search, library, people), (1, 1, 1, 1));
      // People is at the end side: right in English, left in Arabic;
      // Library, then Search, before it, each a 48 square with a 24 icon.
      double x(String k) => tester.getCenter(find.byKey(Key(k))).dx;
      expect(
        isRtl(lang) ? x('space-people') < 100 : x('space-people') > 290,
        isTrue,
      );
      expect(
        isRtl(lang)
            ? x('space-search') > x('space-library') &&
                  x('space-library') > x('space-people')
            : x('space-search') < x('space-library') &&
                  x('space-library') < x('space-people'),
        isTrue,
      );
      for (final k in ['space-search', 'space-library', 'space-people']) {
        expect(tester.getSize(find.byKey(Key(k))), const Size(48, 48));
      }
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(const Key('space-search')),
                matching: find.byType(Icon),
              ),
            )
            .size,
        24,
      );
      expect(find.byKey(const Key('space-people-dot')), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      expect(
        find.bySemanticsLabel('People, join requests waiting'),
        findsOneWidget,
      );
    });
  });

  group('BvPopoverMenu.screen', () {
    testBoth('the Space menu: 220 wide, 44 rows, no border', (
      tester,
      lang,
    ) async {
      String? picked;
      await pumpComponent(
        tester,
        Center(
          child: BvPopoverMenu<String>.screen(
            items: const [
              BvMenuItem(
                value: 'info',
                label: 'Space info',
                icon: BvIcons.info,
              ),
            ],
            onSelected: (v) => picked = v,
          ),
        ),
        lang: lang,
      );
      expect(
        tester.getSize(find.byType(BvPopoverMenu<String>)).width,
        BvScreenMenuSpec.width,
      );
      await tester.tap(find.text('Space info'));
      expect(picked, 'info');
    });
  });

  group('BvSegmented', () {
    testBoth('one choice: the chosen segment is white; a tap picks', (
      tester,
      lang,
    ) async {
      var value = 'b';
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, set) => BvSegmented<String>(
            value: value,
            onChanged: (v) => set(() => value = v),
            segments: const [
              BvSegment(value: 'a', label: 'Everything'),
              BvSegment(value: 'b', label: 'Needs you'),
              BvSegment(value: 'c', label: 'Off'),
            ],
          ),
        ),
        lang: lang,
      );
      expect(textStyle(tester, 'Needs you').color, BvColors.textPrimary);
      expect(textStyle(tester, 'Off').color, BvColors.textSecondary);
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(value, 'c');
      expect(textStyle(tester, 'Off').color, BvColors.textPrimary);
    });
  });

  group('BvInfoGroup', () {
    testBoth('a label over a white slip; lines between rows', (
      tester,
      lang,
    ) async {
      var left = false;
      await pumpComponent(
        tester,
        BvInfoGroup(
          label: 'Space',
          rows: [
            const BvInfoRow(title: 'Space admin', value: 'Islam Ahmed'),
            BvInfoRow(
              title: 'Leave Space',
              tone: BvInfoTone.destructive,
              onTap: () => left = true,
            ),
          ],
        ),
        lang: lang,
      );
      expect(find.text('Islam Ahmed'), findsOneWidget);
      expect(textStyle(tester, 'Leave Space').color, BvColors.textDestructive);
      await tester.tap(find.text('Leave Space'));
      expect(left, isTrue);
    });

    testBoth('Copy is small but has a 48 touch area', (tester, lang) async {
      var copied = 0;
      await pumpComponent(
        tester,
        Center(
          child: BvInfoPill(
            key: const Key('copy'),
            label: 'Copy',
            icon: BvIcons.copy,
            onTap: () => copied++,
          ),
        ),
        lang: lang,
      );
      expect(
        tester.getSize(find.byKey(const Key('copy'))).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byKey(const Key('copy')));
      expect(copied, 1);
    });
  });

  group('BvNeedsRow', () {
    testBoth('what to do, the title, who and when, and the small clip', (
      tester,
      lang,
    ) async {
      var opened = false;
      await pumpComponent(
        tester,
        BvNeedsGroup(
          name: 'Kuwait City Tower — Site team',
          rows: [
            BvNeedsRow(
              label: 'Check it',
              title: 'Sleeves at grid C7',
              meta: 'Omar Haddad · 09:40',
              onTap: () => opened = true,
            ),
          ],
        ),
        lang: lang,
      );
      // The Space's emblem, not its first letter (F28).
      expect(find.byType(BvSpaceEmblem), findsOneWidget);
      expect(find.text('K'), findsNothing);
      expect(textStyle(tester, 'Check it').color, BvColors.textAction);
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(BvPaperClip),
            matching: find.byType(CustomPaint),
          ),
        ),
        BvNeedsSpec.clip,
      );
      await tester.tap(find.text('Sleeves at grid C7'));
      expect(opened, isTrue);
    });
  });

  group('BvProofCard', () {
    testBoth('the photo with CHECKED (8 px), the title, the project, who '
        'checked it', (tester, lang) async {
      await pumpComponent(
        tester,
        const BvProofCard(
          id: 'w1',
          title: 'Sleeves at grid C7 before the pour',
          stamp: 'CHECKED',
          project: 'Kuwait City Tower',
          checkerName: 'Islam Ahmed',
          checkedLine: 'Checked by Islam Ahmed · 15 Oct',
        ),
        lang: lang,
      );
      final stamp = tester.widget<BvInkStamp>(find.byType(BvInkStamp));
      expect(stamp.size, BvInkStampSize.xs8);
      expect(stamp.tone, BvInkStampTone.positive);
      expect(textStyle(tester, 'CHECKED').fontSize, BvInkStampSpec.fontSizeXs8);
      expect(find.text('Kuwait City Tower'), findsOneWidget);
      expect(find.text('Checked by Islam Ahmed · 15 Oct'), findsOneWidget);
    });
  });

  group('BvPillButton', () {
    testBoth('32 to look at, 44 to touch', (tester, lang) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Center(
          child: BvPillButton(
            key: const Key('pill'),
            label: 'Edit profile',
            onTap: () => taps++,
          ),
        ),
        lang: lang,
      );
      expect(
        tester.getSize(find.byKey(const Key('pill'))).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byKey(const Key('pill')));
      expect(taps, 1);
    });
  });

  group('BvTabs.small', () {
    testBoth('a short line under the chosen tab only', (tester, lang) async {
      var tab = 0;
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (context, set) => BvTabs.small(
            labels: const ['Feed', 'Spaces'],
            selectedIndex: tab,
            onSelect: (i) => set(() => tab = i),
          ),
        ),
        lang: lang,
      );
      expect(find.byKey(const Key('tab-indicator')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('tab-indicator'))),
        const Size(BvSmallTabsSpec.lineWidth, BvSmallTabsSpec.lineHeight),
      );
      await tester.tap(find.text('Spaces'));
      await tester.pumpAndSettle();
      expect(tab, 1);
    });
  });

  group('BvInkStamp xs9', () {
    testBoth('9 px words', (tester, lang) async {
      await pumpComponent(
        tester,
        const Center(
          child: BvInkStamp(label: 'CONFIRMED', size: BvInkStampSize.xs9),
        ),
        lang: lang,
      );
      expect(
        textStyle(tester, 'CONFIRMED').fontSize,
        BvInkStampSpec.fontSizeXs9,
      );
    });
  });
}
