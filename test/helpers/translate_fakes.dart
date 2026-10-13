import 'package:buildvibes/data/repositories/translate_repository.dart';

/// Translations by post and target, and the calls made.
class FakeTranslateRepository implements TranslateRepository {
  FakeTranslateRepository({Map<String, String>? texts}) : texts = texts ?? {};

  /// "postId:target" → the translation.
  final Map<String, String> texts;
  final calls = <String>[];

  /// The next call fails this way, once.
  TranslateFailure? failNext;

  @override
  Future<Translation> translate(String postId, String target) async {
    calls.add('$postId $target');
    final fail = failNext;
    if (fail != null) {
      failNext = null;
      throw TranslateException(fail);
    }
    final body = texts['$postId:$target'];
    if (body == null) throw const TranslateException(TranslateFailure.failed);
    return Translation(body: body);
  }
}
