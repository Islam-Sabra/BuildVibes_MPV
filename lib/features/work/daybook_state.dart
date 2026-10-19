import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daybook.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_repository.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;

final daybookCardsProvider = AsyncNotifierProvider.autoDispose
    .family<DaybookCards, List<DaybookCard>, String>(DaybookCards.new);

/// A Space's daybook as loaded so far: one card per post, newest activity
/// first (daybook_cards, review 53 Part B). Every kind of post is kept
/// (they page the list); the page shows work items only until slice 2.
class DaybookCards extends AsyncNotifier<List<DaybookCard>> {
  DaybookCards(this.spaceId);

  final String spaceId;

  static const pageSize = 30;
  var _loadingOlder = false;
  var _reachedStart = false;

  /// False once the Space's first post is loaded.
  bool get hasOlder => !_reachedStart;

  /// Where the next older page starts: the last card the server sent.
  DateTime? _cursorAt;
  String? _cursorId;

  /// History lines "Show earlier" loaded past a card's first 50, by post,
  /// with whether there are more still. Kept while the card's activity
  /// stays as it was.
  final _earlier =
      <String, ({DateTime activity, List<DaybookEvent> lines, bool more})>{};

  void _follow(DaybookCardsPage page, int limit) {
    _reachedStart = page.cards.length < limit;
    if (page.lastAt != null) {
      _cursorAt = page.lastAt;
      _cursorId = page.lastId;
    }
  }

  /// [card] with the lines loaded earlier. New activity shifts its first
  /// 50, so they are dropped then, and Show earlier reads them again.
  DaybookCard _withEarlier(DaybookCard card) {
    final earlier = _earlier[card.id];
    if (earlier == null) return card;
    if (earlier.activity != card.lastActivityAt) {
      _earlier.remove(card.id);
      return card;
    }
    return card.copyWith(
      history: [...card.history, ...earlier.lines],
      historyMore: earlier.more,
    );
  }

  @override
  Future<List<DaybookCard>> build() async {
    _reachedStart = false;
    _cursorAt = null;
    _cursorId = null;
    _earlier.clear();
    final page = await ref
        .watch(daybookRepositoryProvider)
        .cards(spaceId, limit: pageSize);
    _follow(page, pageSize);
    return page.cards;
  }

  /// Loads the next older page ([limit] cards, a page by default). True
  /// when it added cards.
  Future<bool> loadOlder({int limit = pageSize}) async {
    final current = state.value;
    if (_loadingOlder ||
        _reachedStart ||
        current == null ||
        _cursorAt == null) {
      return false;
    }
    _loadingOlder = true;
    try {
      final page = await ref
          .read(daybookRepositoryProvider)
          .cards(spaceId, before: _cursorAt, beforeId: _cursorId, limit: limit);
      if (!ref.mounted) return false;
      _follow(page, limit);
      // A card that moved since is already loaded, at its new place.
      final known = {for (final c in current) c.id};
      state = AsyncData([
        ...current,
        for (final c in page.cards)
          if (!known.contains(c.id)) c,
      ]);
      return page.cards.isNotEmpty;
    } finally {
      _loadingOlder = false;
    }
  }

  /// The most a page reads at once (daybook_cards).
  static const _pageMax = 100;

  /// How many pages [find] reads at most before it gives up.
  static const findPagesMax = 50;
  static const _waitStep = Duration(milliseconds: 16);

  /// Loads the cards down to [postId]'s (F20: an Activity row, a push or a
  /// Needs you card opens the daybook at that card). The pages stay
  /// whole from Now down to it, so the days between are right too. First
  /// post_history says whether the post can still be seen at all: a
  /// deleted post, or one the reader may no longer see, has none. Then the
  /// pages are read, a hundred cards at a time, until the card is in.
  /// True when it is loaded.
  Future<bool> find(String postId) async {
    bool loaded() => state.value?.any((c) => c.id == postId) ?? false;
    if (state.value == null) await future;
    if (!ref.mounted) return false;
    if (loaded()) return true;
    final newest = await ref
        .read(daybookRepositoryProvider)
        .history(postId, limit: 1);
    if (!ref.mounted || newest.isEmpty) return false;
    var pages = 0;
    while (!loaded() && hasOlder && pages < findPagesMax) {
      // Another read is under way (scrolling back): wait for it.
      if (_loadingOlder) {
        await Future<void>.delayed(_waitStep);
        if (!ref.mounted) return false;
        continue;
      }
      pages++;
      await loadOlder(limit: _pageMax);
      if (!ref.mounted) return false;
    }
    return loaded();
  }

  /// Reads "Show earlier" on [postId]'s card until its history holds
  /// [eventId], or there is nothing older. True when it does.
  Future<bool> findLine(String postId, String eventId) async {
    DaybookCard? card() =>
        state.value?.where((c) => c.id == postId).firstOrNull;
    bool has() => card()?.history.any((e) => e.id == eventId) ?? false;
    for (var i = 0; i < findPagesMax && !has(); i++) {
      if (!(card()?.historyMore ?? false)) break;
      await loadEarlier(postId);
      if (!ref.mounted) return false;
    }
    return has();
  }

  /// Reads again what is loaded (after something was sent: a post, a
  /// sign-off, a check, an edit), without showing a load. A card with new
  /// activity comes back at the top; older pages past the first hundred
  /// cards are kept as they were.
  Future<void> refresh() async {
    final current = state.value ?? const <DaybookCard>[];
    final limit = current.length.clamp(pageSize, _pageMax);
    final page = await ref
        .read(daybookRepositoryProvider)
        .cards(spaceId, limit: limit);
    if (!ref.mounted) return;
    final fresh = [for (final c in page.cards) _withEarlier(c)];
    if (page.cards.length < limit) {
      _follow(page, limit);
      state = AsyncData(fresh);
      return;
    }
    final oldestAt = page.lastAt!;
    final oldestId = page.lastId!;
    final read = {for (final c in page.cards) c.id};
    bool older(DaybookCard c) {
      final t = c.lastActivityAt.compareTo(oldestAt);
      return t < 0 || (t == 0 && c.id.compareTo(oldestId) < 0);
    }

    final kept = [
      for (final c in current)
        if (older(c) && !read.contains(c.id)) c,
    ];
    // The cursor stays where the loaded pages end.
    if (kept.isEmpty) _follow(page, limit);
    state = AsyncData([...fresh, ...kept]);
  }

  /// Show earlier, past the card's loaded lines (post_history).
  Future<void> loadEarlier(String postId) async {
    final card = state.value?.where((c) => c.id == postId).firstOrNull;
    final last = card?.history.lastOrNull;
    if (card == null || last == null || !card.historyMore) return;
    final lines = await ref
        .read(daybookRepositoryProvider)
        .history(postId, before: last.at, beforeId: last.id);
    if (!ref.mounted) return;
    final more = lines.length >= DaybookRepository.historyPage;
    final kept = _earlier[postId];
    _earlier[postId] = (
      activity: card.lastActivityAt,
      lines: [...?kept?.lines, ...lines],
      more: more,
    );
    state = AsyncData([
      for (final c in state.value ?? const <DaybookCard>[])
        c.id == postId
            ? c.copyWith(history: [...c.history, ...lines], historyMore: more)
            : c,
    ]);
  }
}

/// The marks of one month in a Space's month drop-down.
final daybookMonthProvider = FutureProvider.autoDispose
    .family<DaybookMonth, ({String spaceId, DateTime month})>(
      (ref, key) =>
          ref.watch(daybookRepositoryProvider).month(key.spaceId, key.month),
    );

/// The open work items due later today in this Space that are mine to
/// sign or written by me (L1's "Due today" strip). Late ones say so on
/// their slip instead.
final daybookDueTodayProvider = FutureProvider.autoDispose
    .family<List<CalendarWorkItem>, String>((ref, spaceId) async {
      final now = ref.watch(clockProvider)();
      final items = await ref.watch(daybookRepositoryProvider).dueOn(now);
      return [
        for (final i in items)
          if (i.spaceId == spaceId &&
              i.status == WorkStatus.open &&
              (i.dueAt == null || !now.isAfter(i.dueAt!)))
            i,
      ];
    });
