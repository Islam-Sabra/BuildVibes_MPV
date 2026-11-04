// The lead's check of review 103, D10: a scan's page 1 thumbnail goes up
// with it, and a card or a proof shows that, never downloading the whole
// PDF to draw its first page.
import 'package:buildvibes/data/repositories/library_repository.dart';
import 'package:buildvibes/features/work/daybook_photos.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/library_fakes.dart';

void main() {
  test('a scan with a thumbnail: the preview is the thumbnail, the PDF is '
      'never downloaded', () async {
    final library = FakeLibraryRepository()..offline = false;
    final container = ProviderContainer(
      overrides: [libraryRepositoryProvider.overrideWithValue(library)],
    );
    addTearDown(container.dispose);
    final image = await container.read(
      filePreviewProvider((
        path: 's/library/f/a.pdf',
        mime: 'application/pdf',
        thumb: 's/library/f/t.jpg',
      )).future,
    );
    expect(image, isA<NetworkImage>());
    expect(
      (image! as NetworkImage).url,
      'https://files.test/s/library/f/t.jpg',
    );
    expect(library.calls.where((c) => c.startsWith('download')), isEmpty);
  });
}
