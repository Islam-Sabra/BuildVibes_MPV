import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daybook.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/daybook_repository.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;

final daybookPageProvider = AsyncNotifierProvider.autoDispose
    .family<DaybookPages, List<DaybookRecord>, String>(DaybookPages.new);

/// A Space's daybook as loaded so far, newest first: posts, sign-offs and
/// updates. Every kind of post is kept (they page the list); the page shows
/// work items only until slice 2.
class DaybookPages extends AsyncNotifier<List<DaybookRecord>> {
  DaybookPages(this.spaceId);

  final String spaceId;

  static const pageSize = 30;
  var _loadingOlder = false;
  var _reachedStart = false;

  /// False once the Space's first post is loaded.
  bool get hasOlder => !_reachedStart;

  @override
  Future<List<DaybookRecord>> build() async {
    _reachedStart = false;
    final page = await ref
        .watch(daybookRepositoryProvider)
        .page(spaceId, limit: pageSize);
    _reachedStart = page.length < pageSize;
    return page;
  }

  /// Loads the next older page. True when it added posts.
  Future<bool> loadOlder() async {
    final current = state.value;
    if (_loadingOlder || _reachedStart || current == null || current.isEmpty) {
      return false;
    }
    _loadingOlder = true;
    try {
      final last = current.last;
      final page = await ref
          .read(daybookRepositoryProvider)
          .page(spaceId, before: last.at, beforeId: last.id, limit: pageSize);
      if (!ref.mounted) return false;
      _reachedStart = page.length < pageSize;
      state = AsyncData([...current, ...page]);
      return page.isNotEmpty;
    } finally {
      _loadingOlder = false;
    }
  }

  /// Reads the newest page again (after a post was sent) and keeps the
  /// older pages already loaded, without showing a load.
  Future<void> refreshNewest() async {
    final page = await ref
        .read(daybookRepositoryProvider)
        .page(spaceId, limit: pageSize);
    if (!ref.mounted) return;
    final current = state.value ?? const <DaybookRecord>[];
    if (page.length < pageSize) {
      _reachedStart = true;
      state = AsyncData(page);
      return;
    }
    final oldest = page.last;
    bool older(DaybookRecord r) {
      final t = r.at.compareTo(oldest.at);
      return t < 0 || (t == 0 && r.id.compareTo(oldest.id) < 0);
    }

    state = AsyncData([...page, ...current.where(older)]);
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
