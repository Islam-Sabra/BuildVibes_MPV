import 'dart:convert';

import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/feed/feed_state.dart';
import 'package:buildvibes/features/feed/post_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _post = PendingPost(
  id: 'post-1',
  body: 'First pour on the podium slab is done.',
  lang: 'en',
  madeAt: DateTime(2026, 10, 15, 6, 10),
);

const _draft = PostDraft(id: 'post-2', body: 'Slab poured');

Future<ProviderContainer> _phoneOf(String? userId) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authUserIdProvider.overrideWithValue(AsyncData(userId)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // On a phone a crew shares, the next person never sees (or sends)
  // someone else's post or Draft.
  test(
    'a waiting post and a Draft belong to the account that wrote them',
    () async {
      SharedPreferences.setMockInitialValues({
        'post_outbox:user-omar': jsonEncode([_post.toJson()]),
        'post_draft:user-omar': jsonEncode(_draft.toJson()),
      });
      final omar = await _phoneOf('user-omar');
      expect(omar.read(postOutboxProvider).single.body, _post.body);
      expect(omar.read(postOutboxProvider).single.madeAt, _post.madeAt);
      expect(omar.read(postDraftProvider)?.body, 'Slab poured');
      final rakesh = await _phoneOf('user-rakesh');
      expect(rakesh.read(postOutboxProvider), isEmpty);
      expect(rakesh.read(postDraftProvider), isNull);
      expect((await _phoneOf(null)).read(postOutboxProvider), isEmpty);
    },
  );

  test('the old shared outbox, of unknown accounts, is cleared', () async {
    SharedPreferences.setMockInitialValues({
      'post_outbox': jsonEncode([
        {'id': 'old', 'body': 'Rebar done.', 'lang': 'en', 'failed': true},
      ]),
    });
    expect((await _phoneOf('user-rakesh')).read(postOutboxProvider), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    await Future<void>.delayed(Duration.zero);
    expect(prefs.containsKey('post_outbox'), isFalse);
  });

  test('a Draft: kept with a photo or a project alone; its language', () {
    expect(const PostDraft(id: 'a').isEmpty, isTrue);
    expect(const PostDraft(id: 'a', photos: ['kept.jpg']).isEmpty, isFalse);
    expect(const PostDraft(id: 'a', body: '  ').canPost, isFalse);
    expect(const PostDraft(id: 'a', photos: ['kept.jpg']).canPost, isTrue);
    expect(const PostDraft(id: 'a', body: 'تم صب السقف').postLang, 'ar');
    expect(
      const PostDraft(id: 'a', body: 'تم صب السقف', lang: PostLang.en).postLang,
      'en',
    );
    final back = PostDraft.fromJson(
      jsonDecode(jsonEncode(PostDraft.refused(_post).toJson()))
          as Map<String, dynamic>,
    );
    expect(back.body, _post.body);
    expect(back.couldNotSend, isTrue);
  });
}
