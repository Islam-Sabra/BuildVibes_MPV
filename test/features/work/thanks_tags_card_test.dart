// Review 110 E on the Work cards: a Thanks (TH2 2715:39608) with its green
// THANKS stamp, its words, who it is to and what for, and "Show on my
// profile" only for the person thanked; a work item's one tag (TG1) next
// to its place, Safety in red. Read from the server's card JSON. In
// English and Arabic.
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_rows.dart';
import '../../helpers/daybook_samples.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

final _now = DaybookSamples.thursday;

Future<FakeDaybookRepository> _open(
  WidgetTester tester,
  String lang,
  List<DaybookCard> posts, {
  String me = DaybookSamples.islam,
}) async {
  final s = DaybookSamples(lang);
  final fake = FakeDaybookRepository()..posts[DaybookSamples.space] = posts;
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(userId: me, phone: '+96550000001'),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: fake,
    now: _now,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);
    final words = s.t(
      'Thank you for the fast fix on the stair, before the client visit.',
      'شكرًا على الإصلاح السريع للدرج قبل زيارة العميل.',
    );

    DaybookPost thanks({required bool mine, bool shown = false}) =>
        DaybookPost.fromJson({
          'id': 'post-thanks',
          'kind': 'thanks',
          'created_at': _now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'title': '',
          'body': words,
          'author_id': DaybookSamples.islam,
          'author_name': s.nameOf(DaybookSamples.islam),
          'thanks': {
            'to_kind': 'person',
            'to_profile_id': DaybookSamples.omar,
            'to_profile_name': s.omarName,
            'for': {
              'id': 'post-tile',
              'title': s.t('Fix the cracked tile', 'إصلاح البلاطة المكسورة'),
              'ref': 'KCT-016',
            },
            'show_on_profile': shown,
            'mine': mine,
          },
        });

    group('TH2 the Thanks card [$lang]', () {
      testWidgets('THANKS, the words, To and For; no Show on my profile for '
          'anyone else', (tester) async {
        await _open(tester, lang, [s.card(thanks(mine: false))]);
        await scrollToRow(tester, _key('thanks-post-thanks'));
        expect(find.text(l10n.thanksStamp), findsOneWidget);
        expect(find.text(words), findsOneWidget);
        expect(
          find.descendant(
            of: _key('thanks-to-post-thanks'),
            matching: find.text(s.omarName),
          ),
          findsOneWidget,
        );
        expect(_key('thanks-for-post-thanks'), findsOneWidget);
        expect(_key('thanks-show-post-thanks'), findsNothing);
        expect(find.text(l10n.thanksOnlyYou), findsNothing);
      });

      testWidgets('the person thanked: Show on my profile, said only to '
          'them; a tap shows it', (tester) async {
        final fake = await _open(tester, lang, [
          s.card(thanks(mine: true)),
        ], me: DaybookSamples.omar);
        await scrollToRow(tester, _key('thanks-show-post-thanks'));
        expect(find.text(l10n.thanksShow), findsOneWidget);
        expect(find.text(l10n.thanksOnlyYou), findsOneWidget);
        await tester.tap(_key('thanks-show-post-thanks'));
        await tester.pumpAndSettle();
        expect(fake.calls, contains('thanks post-thanks true'));
      });

      testWidgets('shown: Remove from my profile', (tester) async {
        await _open(tester, lang, [
          s.card(thanks(mine: true, shown: true)),
        ], me: DaybookSamples.omar);
        await scrollToRow(tester, _key('thanks-show-post-thanks'));
        expect(find.text(l10n.thanksHide), findsOneWidget);
      });
    });

    group('TG1 the tag on a work item [$lang]', () {
      DaybookPost tagged(String id, bool danger) => DaybookPost.fromJson({
        'id': 'post-guard',
        'kind': 'work_item',
        'created_at': _now.subtract(const Duration(hours: 1)).toIso8601String(),
        'title': s.t(
          'Missing edge guard at the L4 slab',
          'حاجز الحافة مفقود في بلاطة الدور 4',
        ),
        'author_id': DaybookSamples.islam,
        'author_name': s.nameOf(DaybookSamples.islam),
        'item': {'status': 'open', 'owner_id': DaybookSamples.omar},
        'tag': {
          'id': id,
          'name': {
            'en': id == 'safety' ? 'Safety' : 'Quality',
            'ar': id == 'safety' ? 'سلامة' : 'جودة',
          },
          'danger': danger,
        },
      });

      testWidgets('Safety shows red, in the tag\'s own words', (tester) async {
        await _open(tester, lang, [s.card(tagged('safety', true))]);
        await scrollToRow(tester, _key('card-tag-post-guard'));
        final tag = tester.widget<BvSiteTag>(_key('card-tag-post-guard'));
        expect(tag.name, lang == 'en' ? 'Safety' : 'سلامة');
        expect(tag.danger, isTrue);
        final text = tester.widget<Text>(
          find.descendant(
            of: _key('card-tag-post-guard'),
            matching: find.byType(Text),
          ),
        );
        expect(text.style?.color, BvColors.textDestructive);
      });

      testWidgets('another tag is not red', (tester) async {
        await _open(tester, lang, [s.card(tagged('quality', false))]);
        await scrollToRow(tester, _key('card-tag-post-guard'));
        expect(
          tester.widget<BvSiteTag>(_key('card-tag-post-guard')).danger,
          isFalse,
        );
      });
    });
  }
}
