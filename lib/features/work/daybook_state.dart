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

  /// Where the next older page starts: the last row the server sent,
  /// drawn or not.
  DateTime? _cursorAt;
  String? _cursorId;

  void _follow(DaybookPageRows page, int limit) {
    _reachedStart = page.rows < limit;
    if (page.lastAt != null) {
      _cursorAt = page.lastAt;
      _cursorId = page.lastId;
    }
  }

  @override
  Future<List<DaybookRecord>> build() async {
    _reachedStart = false;
    _cursorAt = null;
    _cursorId = null;
    final page = await ref
        .watch(daybookRepositoryProvider)
        .page(spaceId, limit: pageSize);
    _follow(page, pageSize);
    return page.records;
  }

  /// Loads the next older page. True when it added entries.
  Future<bool> loadOlder() async {
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
          .page(
            spaceId,
            before: _cursorAt,
            beforeId: _cursorId,
            limit: pageSize,
          );
      if (!ref.mounted) return false;
      _follow(page, pageSize);
      state = AsyncData([...current, ...page.records]);
      // Rows of kinds this version doesn't draw still move the cursor.
      return page.rows > 0;
    } finally {
      _loadingOlder = false;
    }
  }

  /// The most a page reads at once (daybook_page).
  static const _pageMax = 100;

  /// Reads again what is loaded (after something was sent: a post, a
  /// sign-off, a check, an edit), without showing a load. Older pages
  /// past the first hundred entries are kept as they were.
  Future<void> refresh() async {
    final current = state.value ?? const <DaybookRecord>[];
    final limit = current.length.clamp(pageSize, _pageMax);
    final page = await ref
        .read(daybookRepositoryProvider)
        .page(spaceId, limit: limit);
    if (!ref.mounted) return;
    if (page.rows < limit) {
      _follow(page, limit);
      state = AsyncData(page.records);
      return;
    }
    final oldestAt = page.lastAt!;
    final oldestId = page.lastId!;
    bool older(DaybookRecord r) {
      final t = r.at.compareTo(oldestAt);
      return t < 0 || (t == 0 && r.id.compareTo(oldestId) < 0);
    }

    final kept = current.where(older).toList();
    // The cursor stays where the loaded pages end.
    if (kept.isEmpty) _follow(page, limit);
    state = AsyncData([...page.records, ...kept]);
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
