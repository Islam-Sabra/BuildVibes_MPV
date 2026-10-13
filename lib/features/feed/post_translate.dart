import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/post.dart';
import '../../data/repositories/translate_repository.dart';
import '../../l10n/gen/app_localizations.dart';

enum _Phase { loading, shown, original, failed, limit }

@immutable
class _PostTranslation {
  const _PostTranslation(this.phase, {this.body});

  final _Phase phase;
  final String? body;
}

/// What each post's Translate line shows, for this session. Keyed by post
/// and target language, so switching the app language starts afresh.
final _translationsProvider =
    NotifierProvider<_Translations, Map<String, _PostTranslation>>(
      _Translations.new,
    );

class _Translations extends Notifier<Map<String, _PostTranslation>> {
  @override
  Map<String, _PostTranslation> build() => const {};

  void _set(String key, _PostTranslation t) => state = {...state, key: t};

  Future<void> translate(String postId, String target) async {
    final key = '$postId:$target';
    final known = state[key];
    // Shown before: show it again, without asking the server.
    if (known?.body != null) {
      _set(key, _PostTranslation(_Phase.shown, body: known!.body));
      return;
    }
    _set(key, const _PostTranslation(_Phase.loading));
    try {
      final t = await ref
          .read(translateRepositoryProvider)
          .translate(postId, target);
      _set(key, _PostTranslation(_Phase.shown, body: t.body));
    } on TranslateException catch (e) {
      _set(
        key,
        _PostTranslation(
          e.failure == TranslateFailure.limit ? _Phase.limit : _Phase.failed,
        ),
      );
    }
  }

  void showOriginal(String postId, String target) {
    final key = '$postId:$target';
    _set(key, _PostTranslation(_Phase.original, body: state[key]?.body));
  }
}

/// The post's words (L1–L4): in the language they were written in, with
/// "Translate" when that isn't the app language; after translating, the
/// translation in its own direction with "Translated from … · Show
/// original". On failure the original stays.
class PostBody extends ConsumerWidget {
  const PostBody({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final target = Localizations.localeOf(context).languageCode;
    final other = post.lang != target;
    final t = other
        ? ref.watch(_translationsProvider)['${post.id}:$target']
        : null;
    final translated = t?.phase == _Phase.shown;
    final words = translated ? t!.body! : post.body!;
    final wordsLang = translated ? target : post.lang;
    final notifier = ref.read(_translationsProvider.notifier);

    Widget link(String key, String text, VoidCallback? onTap) => InkWell(
      key: Key(key),
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      child: Text(
        text,
        style: type.bodySm.copyWith(color: BvColors.textAction),
      ),
    );
    final quiet = type.bodySm.copyWith(color: BvColors.textSecondary);

    final Widget? line = !other
        ? null
        : switch (t?.phase) {
            _Phase.shown => Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: BvSpace.s4,
              children: [
                Text(
                  l10n.translatedFrom(
                    post.lang == 'ar'
                        ? l10n.languageNameArabic
                        : l10n.languageNameEnglish,
                  ),
                  style: quiet,
                ),
                Text('·', style: quiet),
                link(
                  'post-show-original-${post.id}',
                  l10n.showOriginal,
                  () => notifier.showOriginal(post.id, target),
                ),
              ],
            ),
            _Phase.loading => Text(
              l10n.translating,
              key: Key('post-translating-${post.id}'),
              style: quiet,
            ),
            _Phase.failed => link(
              'post-translate-${post.id}',
              l10n.translateFailed,
              () => notifier.translate(post.id, target),
            ),
            _Phase.limit => Text(
              l10n.translateLimit,
              key: Key('post-translate-limit-${post.id}'),
              style: quiet,
            ),
            _ => link(
              'post-translate-${post.id}',
              l10n.translate,
              () => notifier.translate(post.id, target),
            ),
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s4,
      children: [
        Text(
          words,
          key: Key('post-body-${post.id}'),
          // In the language the words are in.
          textDirection: wordsLang == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          textAlign: TextAlign.start,
          style: type.bodyMd,
        ),
        if (line != null)
          Row(
            spacing: BvSpace.s4,
            children: [
              Icon(
                BvIcons.language,
                size: BvSize.iconSm,
                color: translated
                    ? BvColors.iconSecondary
                    : BvColors.iconAction,
              ),
              Flexible(child: line),
            ],
          ),
      ],
    );
  }
}
