import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_provider.dart';

/// Review 103, OCR: whose file a text belongs to: a Library file (by its
/// id) or a note's file (by its storage path).
enum FileTextKind {
  library('library'),
  note('note');

  const FileTextKind(this.json);
  final String json;
}

/// The text Extract text read in a file.
@immutable
class FileText {
  const FileText({
    required this.text,
    this.lang,
    this.pages = 0,
    this.partial = false,
  });

  factory FileText.fromJson(Map<String, dynamic> json) => FileText(
    text: json['text'] as String? ?? '',
    lang: json['lang'] as String?,
    pages: (json['pages'] as num?)?.toInt() ?? 0,
    partial: json['partial'] as bool? ?? false,
  );

  final String text;
  final String? lang;
  final int pages;

  /// The lead's check, D3: the file has more than 20 pages and only the
  /// first 20 were read.
  final bool partial;
}

/// Why a file couldn't be read: [tooLarge] is over 10 MB (D7), made
/// smaller on the phone first.
enum FileTextFailure { failed, dailyLimit, tooLarge }

class FileTextException implements Exception {
  const FileTextException(this.failure);
  final FileTextFailure failure;
}

abstract class FileTextRepository {
  /// The text already read, or null (read as the file is: file_texts).
  Future<FileText?> read(FileTextKind kind, String ref);

  /// Extract text: the edge function extract-text reads it now.
  Future<FileText> extract(FileTextKind kind, String ref);
}

class SupabaseFileTextRepository implements FileTextRepository {
  SupabaseFileTextRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FileText?> read(FileTextKind kind, String ref) async {
    final row = await _client
        .from('file_texts')
        .select('text, lang, pages, partial')
        .eq('file_kind', kind.json)
        .eq('file_ref', ref)
        .maybeSingle();
    return row == null ? null : FileText.fromJson(row);
  }

  @override
  Future<FileText> extract(FileTextKind kind, String ref) async {
    try {
      final res = await _client.functions.invoke(
        'extract-text',
        body: {'kind': kind.json, 'ref': ref},
      );
      return FileText.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on FunctionException catch (e) {
      throw FileTextException(switch (e.status) {
        429 => FileTextFailure.dailyLimit,
        413 => FileTextFailure.tooLarge,
        _ => FileTextFailure.failed,
      });
    } on Exception {
      throw const FileTextException(FileTextFailure.failed);
    }
  }
}

final fileTextRepositoryProvider = Provider<FileTextRepository>(
  (ref) => SupabaseFileTextRepository(ref.watch(supabaseClientProvider)),
);

/// A file's text, null while none was read. Read again after Extract text.
final fileTextProvider = FutureProvider.autoDispose
    .family<FileText?, ({FileTextKind kind, String ref})>(
      (ref, file) =>
          ref.watch(fileTextRepositoryProvider).read(file.kind, file.ref),
    );
