import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How far an upload has gone: [sent] of [total] bytes (F73).
typedef UploadProgress = void Function(int sent, int total);

/// Uploads [file] to [bucket] at [path] as the storage client does (a
/// multipart POST with the signed-in headers, never replacing a file),
/// telling [onProgress] as its bytes go out. Errors as the storage client
/// gives them ([StorageException]).
Future<void> uploadWithProgress(
  SupabaseClient client, {
  required String bucket,
  required String path,
  required File file,
  required String contentType,
  required UploadProgress onProgress,
}) async {
  final api = client.storage.from(bucket);
  final total = await file.length();
  var sent = 0;
  onProgress(0, total);
  final bytes = file.openRead().transform(
    StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (chunk, sink) {
        sent += chunk.length;
        onProgress(sent, total);
        sink.add(chunk);
      },
    ),
  );
  final request =
      http.MultipartRequest(
          'POST',
          Uri.parse('${api.url}/object/$bucket/$path'),
        )
        ..headers.addAll(api.headers)
        ..headers['x-upsert'] = 'false'
        ..fields['cacheControl'] = '3600'
        ..files.add(
          http.MultipartFile(
            '',
            bytes,
            total,
            filename: path.split('/').last,
            contentType: MediaType.parse(contentType),
          ),
        );
  final response = await http.Response.fromStream(await request.send());
  if (response.statusCode >= 300) {
    throw StorageException(response.body, statusCode: '${response.statusCode}');
  }
}
