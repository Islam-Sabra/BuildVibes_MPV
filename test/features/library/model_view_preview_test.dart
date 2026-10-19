import 'dart:convert';

import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

const _space = 'space-1';

/// A 1 × 1 PNG: the stand-in for a model view's view.jpg.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// "Supply Air" as BuildVibes 360 published it (migration 27): a Library
/// row of source model_view, its picture at view.jpg.
LibraryFile _supplyAir() => LibraryFile.fromJson({
  'id': 'mv-1',
  'space_id': _space,
  'name': 'Supply Air',
  'storage_path': '$_space/library/mv-1/view.jpg',
  'mime': 'image/jpeg',
  'bytes': 101376,
  'rev_label': 'V1',
  'source': 'model_view',
  'uploaded_by': 'user-1',
  'created_at': '2026-10-19T15:06:00+00:00',
  'uploader': {'first_name': 'Islam', 'last_name': 'Ahmed'},
});

Future<FakeLibraryRepository> _open(WidgetTester tester, String lang) async {
  final library = FakeLibraryRepository(now: testNow)
    ..filesBySpace[_space] = [_supplyAir()]
    ..bytesByPath['$_space/library/mv-1/view.jpg'] = _png;
  await pumpApp(
    tester,
    language: lang,
    spaces: FakeSpaceRepository(now: testNow)
      ..details[_space] = const SpaceDetail(
        id: _space,
        name: 'Site team',
        myPass: SpacePass.lead,
        iAmAdmin: true,
        myRights: MemberRights(createItems: true, addFiles: true),
      ),
    library: library,
  );
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).push('/spaces/$_space/library/mv-1');
  await tester.pumpAndSettle();
  return library;
}

void main() {
  test('a model_view row reads as a model view', () {
    expect(_supplyAir().source, LibrarySource.modelView);
    expect(_supplyAir().isImage, isTrue);
  });

  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('review 61 G4: a model view\'s picture is drawn from its '
        'bytes, with no link to wait on [$lang]', (tester) async {
      final library = await _open(tester, lang);
      // The fake has no network for links: the picture still shows.
      expect(library.offline, isTrue);
      expect(library.calls, contains('download $_space/library/mv-1/view.jpg'));
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('preview-image')),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, isA<MemoryImage>());
      expect(find.text(l10n.previewCantShow), findsNothing);
    });

    testWidgets('review 61 G4: its versions come from BuildVibes 360, so no '
        'Upload a new revision [$lang]', (tester) async {
      await _open(tester, lang);
      expect(find.byKey(const Key('preview-new-revision')), findsNothing);
      expect(find.text(l10n.previewModelViewVersions), findsOneWidget);
    });
  }
}
