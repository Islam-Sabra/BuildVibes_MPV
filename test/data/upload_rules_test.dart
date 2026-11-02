import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/upload_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

PhoneFile _file(
  String name, {
  String mime = 'application/octet-stream',
  int? bytes,
}) => PhoneFile(local: '/tmp/$name', name: name, mime: mime, bytes: bytes);

void main() {
  group('Review 113 bug 7: the space-files bucket, before uploading', () {
    test('the limit is the bucket\'s file_size_limit (25 MB)', () {
      expect(spaceFilesMaxBytes, 26214400);
    });

    test('the type comes from the extension, whatever the picker said', () {
      expect(spaceFileType(_file('A-501 plan.PDF')), 'application/pdf');
      expect(spaceFileType(_file('site.jpg')), 'image/jpeg');
      expect(spaceFileType(_file('site.jpeg')), 'image/jpeg');
      expect(spaceFileType(_file('site.png')), 'image/png');
      expect(spaceFileType(_file('site.webp')), 'image/webp');
      expect(spaceFileType(_file('site.heic')), 'image/heic');
      expect(spaceFileType(_file('note.m4a')), 'audio/mp4');
      expect(spaceFileType(_file('note.aac')), 'audio/aac');
      expect(spaceFileType(_file('note.mp3')), 'audio/mpeg');
      expect(
        spaceFileType(_file('check-ins.xlsx')),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    test('every type it sends is one the bucket allows, and the reverse', () {
      // The bucket's allowed_mime_types (migrations 20261012140000 and
      // 20261120120000), exactly.
      const bucket = {
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/heic',
        'application/pdf',
        'audio/mp4',
        'audio/aac',
        'audio/mpeg',
        'audio/x-m4a',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      };
      expect(spaceFilesAllowedTypes, bucket);
      for (final t in spaceFilesTypesByExtension.values) {
        expect(bucket, contains(t));
      }
    });

    test('no extension: the picker\'s type when the bucket takes it', () {
      expect(
        spaceFileType(_file('scan', mime: 'application/pdf')),
        'application/pdf',
      );
      expect(spaceFileType(_file('scan')), isNull);
      expect(
        spaceFileType(_file('drawing.dwg', mime: 'image/vnd.dwg')),
        isNull,
        reason: 'a type the bucket refuses is refused',
      );
      expect(
        spaceFileType(_file('A-501 Rev.C', mime: 'application/pdf')),
        'application/pdf',
        reason: 'a dot in the name is not a type',
      );
    });

    test('a PDF over 25 MB is refused before it goes, with its size', () {
      final big = _file('A-501.pdf', bytes: 38 * 1024 * 1024);
      final problem = checkSpaceFile(big);
      expect(problem, isA<FileRefused>());
      expect(problem!.problem, UploadProblem.tooBig);
      expect(problem.megabytes, 38);
      expect(
        problem.failure,
        SpaceFailure.badInput,
        reason: 'a SpaceException, so every caller still catches it',
      );
    });

    test('the Library takes only a PDF or a photo (add_library_file), '
        'narrower than the bucket', () {
      expect(libraryFileTypes, {
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/heic',
        'application/pdf',
      });
      final sheet = _file('check-ins.xlsx', bytes: 10);
      expect(checkSpaceFile(sheet), isNull, reason: 'the bucket takes it');
      expect(
        checkSpaceFile(sheet, library: true)!.problem,
        UploadProblem.notPdfOrPhoto,
      );
      expect(checkSpaceFile(_file('a.pdf', bytes: 10), library: true), isNull);
      expect(checkSpaceFile(_file('a.heic', bytes: 10), library: true), isNull);
    });

    test('exactly 25 MB goes', () {
      expect(checkSpaceFile(_file('a.pdf', bytes: spaceFilesMaxBytes)), isNull);
    });

    test('a type the bucket refuses is refused before it goes', () {
      final p = checkSpaceFile(_file('model.dwg', bytes: 10));
      expect(p!.problem, UploadProblem.wrongType);
    });

    test('a size just over a whole megabyte says the next one up', () {
      final p = checkSpaceFile(_file('a.pdf', bytes: 25 * 1024 * 1024 + 1));
      expect(p!.megabytes, 26);
    });
  });

  group('Review 113 bug 7: storage\'s refusals in plain words', () {
    test('HTTP 400 with an inner 413 is too big', () {
      final e = uploadRefusalOf(
        const StorageException(
          'The object exceeded the maximum allowed size',
          error: 'Payload too large',
          statusCode: '413',
        ),
        _file('a.pdf', bytes: 30 * 1024 * 1024),
      );
      expect(e!.problem, UploadProblem.tooBig);
      expect(e.megabytes, 30);
    });

    test('a plain 413 is too big', () {
      final e = uploadRefusalOf(
        const StorageException('Request Entity Too Large', statusCode: '413'),
        _file('a.pdf'),
      );
      expect(e!.problem, UploadProblem.tooBig);
    });

    test('a raw 400 body (the progress upload) is read too', () {
      final e = uploadRefusalOf(
        const StorageException(
          '{"statusCode":"413","error":"Payload too large",'
          '"message":"The object exceeded the maximum allowed size"}',
          statusCode: '400',
        ),
        _file('a.pdf'),
      );
      expect(e!.problem, UploadProblem.tooBig);
    });

    test('a type storage refuses is the wrong type', () {
      final e = uploadRefusalOf(
        const StorageException(
          'mime type application/octet-stream is not supported',
          error: 'invalid_mime_type',
          statusCode: '415',
        ),
        _file('a.pdf'),
      );
      expect(e!.problem, UploadProblem.wrongType);
    });

    test('anything else is not ours to name', () {
      expect(
        uploadRefusalOf(
          const StorageException(
            'new row violates row-level security',
            statusCode: '403',
          ),
          _file('a.pdf'),
        ),
        isNull,
      );
    });

    test(
      'the upload sends the extension\'s type, never the picker\'s',
      () async {
        final sent = <String>[];
        final path = await uploadSpaceFile(_file('A-501.pdf', bytes: 1000), (
          type,
        ) async {
          sent.add(type);
          return 'p';
        });
        expect(path, 'p');
        expect(sent, ['application/pdf']);
      },
    );

    test('too big: nothing is sent', () async {
      var sent = false;
      await expectLater(
        uploadSpaceFile(_file('a.pdf', bytes: 38 * 1024 * 1024), (_) async {
          sent = true;
        }),
        throwsA(isA<FileRefused>()),
      );
      expect(sent, isFalse);
    });

    test('a fake storage answering 400 (inner 413) is too big', () async {
      await expectLater(
        uploadSpaceFile(_file('a.pdf', bytes: 1000), (_) async {
          throw const StorageException(
            'The object exceeded the maximum allowed size',
            error: 'Payload too large',
            statusCode: '413',
          );
        }),
        throwsA(
          isA<FileRefused>().having(
            (e) => e.problem,
            'problem',
            UploadProblem.tooBig,
          ),
        ),
      );
    });

    test('another storage error stays as it was', () async {
      await expectLater(
        uploadSpaceFile(_file('a.pdf', bytes: 1000), (_) async {
          throw const StorageException('row-level security', statusCode: '403');
        }),
        throwsA(isA<StorageException>()),
      );
    });

    test('a refusal travels as a code and comes back the same', () {
      const r = FileRefused(
        UploadProblem.tooBig,
        bytes: 38 * 1024 * 1024,
        fileId: 'f1',
      );
      final back = FileRefused.fromCode(r.code);
      expect(back!.problem, UploadProblem.tooBig);
      expect(back.megabytes, 38);
      expect(back.fileId, 'f1');
      expect(FileRefused.fromCode('forSomeoneElse'), isNull);
      expect(FileRefused.fromCode(null), isNull);
      final type = FileRefused.fromCode(
        const FileRefused(UploadProblem.wrongType, fileId: 'f2').code,
      );
      expect(type!.problem, UploadProblem.wrongType);
      expect(type.fileId, 'f2');
    });
  });
}
