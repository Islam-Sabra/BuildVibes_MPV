// Review 110 F (HV1 2721:39795, HV2 2721:39906): the short card, the same
// rule for every kind. Title 2 lines, details 2 lines, one info line, up
// to 3 photos then "+N", and the rest in one quiet line ("2 files · 1
// table · 6 tasks") with See more, which opens the whole post in place. A
// checklist shows its first 3 lines, then "4 of 9 ticked". In English and
// Arabic.
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_photo_strip.dart';
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
Finder _card(String id) => _key('daybook-card-$id');
Finder _in(String id, Finder f) => find.descendant(of: _card(id), matching: f);

final _now = DaybookSamples.thursday;

Future<void> _open(
  WidgetTester tester,
  String lang,
  List<DaybookCard> posts,
) async {
  final s = DaybookSamples(lang);
  await pumpApp(
    tester,
    language: lang,
    auth: FakeAuthRepository(
      userId: DaybookSamples.islam,
      phone: '+96550000001',
    ),
    spaces: FakeSpaceRepository()
      ..details[DaybookSamples.space] = s.detail(pass: SpacePass.lead)
      ..spacePeople[DaybookSamples.space] = s.people(),
    daybook: FakeDaybookRepository()
      ..posts[DaybookSamples.space] = posts
      ..pointsByPost[DaybookSamples.handoverId] = s.handoverPoints(),
    now: _now,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/${DaybookSamples.space}');
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));
    final s = DaybookSamples(lang);
    final long = List.filled(
      12,
      s.t(
        'the membrane is torn along the parapet',
        'الغشاء ممزق على طول الدروة',
      ),
    ).join(' ');

    DaybookPost item() => DaybookPost(
      id: 'post-terrace',
      kind: DaybookPost.workItemKind,
      createdAt: _now.subtract(const Duration(hours: 1)),
      title: long,
      body: long,
      authorId: DaybookSamples.islam,
      authorName: s.nameOf(DaybookSamples.islam),
      item: DaybookItem(
        status: WorkStatus.open,
        ownerId: DaybookSamples.omar,
        ownerName: s.nameOf(DaybookSamples.omar),
      ),
      tableCount: 1,
      attachments: const [
        DaybookAttachment(name: 'Terrace-detail-D12.pdf'),
        DaybookAttachment(name: 'Membrane-datasheet.pdf'),
      ],
    );

    group('HV1 the short card [$lang]', () {
      testWidgets('a work item: title and details 2 lines each, its info on '
          'one line, no file chips; the rest in one quiet line with See '
          'more', (tester) async {
        await _open(tester, lang, [s.card(item())]);
        await scrollToRow(tester, _card('post-terrace'));
        final title = tester.widget<Text>(
          _in('post-terrace', find.text(long)).first,
        );
        expect(title.maxLines, 2);
        expect(title.overflow, TextOverflow.ellipsis);
        final details = tester.widget<Text>(
          _in('post-terrace', find.text(long)).last,
        );
        expect(details.maxLines, 2);
        expect(
          _in('post-terrace', find.text('Terrace-detail-D12.pdf')),
          findsNothing,
        );
        expect(
          _in(
            'post-terrace',
            find.text('${l10n.cardFiles(2)} · ${l10n.cardTables(1)}'),
          ),
          findsOneWidget,
        );
        expect(_key('card-see-more-post-terrace'), findsOneWidget);
      });

      testWidgets('a checklist: its first 3 lines, then "x of y ticked" with '
          'See more', (tester) async {
        await _open(tester, lang, [s.handover()]);
        await scrollToRow(tester, _card(DaybookSamples.handoverId));
        final points = s.handoverPoints();
        expect(points.length, greaterThan(3));
        for (final (i, p) in points.indexed) {
          expect(
            _in(DaybookSamples.handoverId, find.text(p.text)),
            i < 3 ? findsOneWidget : findsNothing,
            reason: p.text,
          );
        }
        expect(
          _key('card-see-more-${DaybookSamples.handoverId}'),
          findsOneWidget,
        );
      });
    });

    group('HV2 See more [$lang]', () {
      testWidgets('opens the whole post in place', (tester) async {
        await _open(tester, lang, [s.card(item())]);
        await scrollToRow(tester, _card('post-terrace'));
        await tester.tap(_key('card-see-more-post-terrace'));
        await tester.pumpAndSettle();
        expect(_key('daybook-page'), findsOneWidget);
      });
    });
  }

  group('HV1 photos: up to 3, then "+N"', () {
    testWidgets('8 photos: three, and +5 that opens them all', (tester) async {
      final opened = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BvPhotoStrip(
              photos: [
                for (var i = 0; i < 8; i++) (image: null, waiting: false),
              ],
              onOpen: opened.add,
              moreLabel: (n) => '+$n',
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('photo-strip-2')), findsOneWidget);
      expect(find.byKey(const Key('photo-strip-3')), findsNothing);
      expect(find.text('+5'), findsOneWidget);
      await tester.tap(find.text('+5'));
      expect(opened, [3]);
    });
  });
}
