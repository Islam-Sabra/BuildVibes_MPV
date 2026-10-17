import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/post.dart';
import '../../data/models/space.dart';
import '../../data/repositories/post_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../profile/widgets/profile_parts.dart';
import 'post_card.dart';

/// Whose posts a list shows: a person's (R12, R16) or a project's (the
/// project sheet).
@immutable
class PostSource {
  const PostSource.person(String id) : personId = id, projectId = null;
  const PostSource.project(String id) : projectId = id, personId = null;

  final String? personId;
  final String? projectId;

  @override
  bool operator ==(Object other) =>
      other is PostSource &&
      other.personId == personId &&
      other.projectId == projectId;

  @override
  int get hashCode => Object.hash(personId, projectId);
}

final postListProvider = FutureProvider.autoDispose
    .family<PostPage<Post>, PostSource>((ref, source) {
      final repo = ref.watch(postRepositoryProvider);
      return source.personId != null
          ? repo.postsBy(source.personId!)
          : repo.postsTagged(source.projectId!);
    });

/// The cards of [source], 20 at a time with "Show more", inside a page
/// that already scrolls. The project sheet's cards leave out the project.
class PostList extends ConsumerStatefulWidget {
  const PostList({super.key, required this.source, this.empty});

  final PostSource source;

  /// Shown when there are no posts.
  final String? empty;

  @override
  ConsumerState<PostList> createState() => _PostListState();
}

class _PostListState extends ConsumerState<PostList> {
  final _more = <Post>[];
  Map<String, dynamic>? _next;
  var _loadedMore = false;
  var _loading = false;
  final _changed = <String, Post>{};
  final _gone = <String>{};

  Future<void> _loadMore(Map<String, dynamic>? from) async {
    if (_loading || from == null) return;
    setState(() => _loading = true);
    final repo = ref.read(postRepositoryProvider);
    final s = widget.source;
    try {
      final page = s.personId != null
          ? await repo.postsBy(s.personId!, cursor: from)
          : await repo.postsTagged(s.projectId!, cursor: from);
      if (!mounted) return;
      setState(() {
        _more.addAll(page.items);
        _next = page.next;
        _loadedMore = true;
      });
    } on SpaceException {
      // Try again with the button.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = ref.watch(postListProvider(widget.source));
    final page = first.value;
    if (page == null) {
      return first.hasError
          ? EmptyNote(l10n.errorGeneric)
          : const Center(child: CircularProgressIndicator());
    }
    final posts = [
      for (final p in [...page.items, ..._more])
        if (!_gone.contains(p.id)) _changed[p.id] ?? p,
    ];
    final next = _loadedMore ? _next : page.next;
    if (posts.isEmpty) return EmptyNote(widget.empty ?? l10n.postsEmpty);
    return Column(
      key: const Key('post-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s12,
      children: [
        for (final p in posts)
          PostCard(
            post: p,
            tag: widget.source.projectId != null ? PostTag.none : PostTag.shown,
            onOpen: () => context.push(AppRoutes.post(p.id)),
            onChanged: (c) => setState(() => _changed[c.id] = c),
            onGone: () => setState(() => _gone.add(p.id)),
          ),
        if (next != null)
          BvButton(
            key: const Key('post-list-more'),
            label: l10n.deliveredSeeAll,
            style: BvButtonStyle.secondary,
            onPressed: _loading ? null : () => _loadMore(next),
          ),
      ],
    );
  }
}
