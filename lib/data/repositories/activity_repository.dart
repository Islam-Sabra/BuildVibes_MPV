import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';
import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// Activity, the Home Spaces tab and Space visits (migration 13). The
/// server writes every notification; the app only reads and marks read.
abstract class ActivityRepository {
  /// The last 7 days, newest first.
  Future<List<ActivityRow>> activity();
  Future<void> markRead();

  /// Yes or no: the dot on the Activity tab.
  Future<bool> unread();

  /// [dayStart] is the phone's midnight.
  Future<List<SpaceToday>> today(DateTime dayStart);
  Future<List<NeedsCard>> needs();
  Future<void> markSpaceSeen(String spaceId);
}

class SupabaseActivityRepository implements ActivityRepository {
  const SupabaseActivityRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  List<Map<String, dynamic>> _rows(Object? data) =>
      (data as List? ?? const []).cast<Map<String, dynamic>>();

  @override
  Future<List<ActivityRow>> activity() => _guard(() async {
    final rows = _rows(await _client.rpc<List<dynamic>>('my_activity'));
    return [
      for (final r in rows)
        if (ActivityKind.fromJson(r['kind']) != null) ActivityRow.fromJson(r),
    ];
  });

  @override
  Future<void> markRead() => _guard(() => _client.rpc('mark_activity_read'));

  @override
  Future<bool> unread() =>
      _guard(() async => await _client.rpc<bool>('unread_activity'));

  @override
  Future<List<SpaceToday>> today(DateTime dayStart) => _guard(() async {
    final rows = _rows(
      await _client.rpc<List<dynamic>>(
        'today_in_spaces',
        params: {'p_day_start': dayStart.toUtc().toIso8601String()},
      ),
    );
    return [for (final r in rows) SpaceToday.fromJson(r)];
  });

  @override
  Future<void> markSpaceSeen(String spaceId) => _guard(
    () => _client.rpc('mark_space_seen', params: {'p_space': spaceId}),
  );

  /// needs_you() gives ids; the cards read the items, their latest
  /// events, the requests and the names, all as the signed-in member.
  @override
  Future<List<NeedsCard>> needs() => _guard(() async {
    final needs = _rows(await _client.rpc<List<dynamic>>('needs_you'));
    if (needs.isEmpty) return const [];
    final itemIds = {
      for (final n in needs)
        if (n['work_item_id'] != null) n['work_item_id'] as String,
    }.toList();
    final requestIds = {
      for (final n in needs)
        if (n['request_id'] != null) n['request_id'] as String,
    }.toList();
    // Checklists given to me with points left (checklist_for_you): their
    // title, author and due, as the member reads them.
    final checklistIds = {
      for (final n in needs)
        if (n['kind'] == 'checklist_for_you' && n['space_post_id'] != null)
          n['space_post_id'] as String,
    }.toList();

    final spaces = {
      for (final s in _rows(await _client.rpc<List<dynamic>>('my_spaces')))
        s['space_id'] as String: s['name'] as String,
    };
    final items = itemIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('work_items')
                .select('id, ref, title, due_date')
                .inFilter('id', itemIds),
          );
    final events = itemIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('work_item_events')
                .select('id, work_item_id, kind, actor_id, created_at')
                .inFilter('work_item_id', itemIds)
                .order('created_at', ascending: false),
          );
    // The work items' due times and covers (their posts), and the photos
    // of the sign-offs waiting for a check: the rows of Needs you.
    final posts = itemIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('space_posts')
                .select('id, due_at')
                .inFilter('id', itemIds),
          );
    final covers = itemIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('post_files')
                .select('post_id, storage_path, sort, created_at')
                .inFilter('post_id', itemIds)
                .like('mime', 'image/%')
                .not('storage_path', 'is', null)
                .order('sort', ascending: true)
                .order('created_at', ascending: true),
          );
    final doneIds = [
      for (final e in events)
        if (e['kind'] == 'done') e['id'] as String,
    ];
    final proofs = doneIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('work_item_evidence')
                .select('event_id, storage_path, created_at')
                .inFilter('event_id', doneIds)
                .order('created_at', ascending: true),
          );
    final checklists = checklistIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('space_posts')
                .select('id, title, author_id, due_date, due_at')
                .inFilter('id', checklistIds),
          );
    final requests = requestIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await _client
                .from('space_join_requests')
                .select('id, profile_id')
                .inFilter('id', requestIds),
          );

    final peopleIds = {
      for (final e in events)
        if (e['actor_id'] != null) e['actor_id'] as String,
      for (final r in requests) r['profile_id'] as String,
      for (final c in checklists)
        if (c['author_id'] != null) c['author_id'] as String,
    }.toList();
    final names = peopleIds.isEmpty
        ? const <String, String>{}
        : {
            for (final p in _rows(
              await _client
                  .from('profiles')
                  .select('id, first_name, last_name')
                  .inFilter('id', peopleIds),
            ))
              p['id'] as String:
                  '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim(),
          };

    final me = _client.auth.currentUser?.id;
    final itemById = {for (final i in items) i['id'] as String: i};
    final dueAtById = {
      for (final p in posts)
        if (p['due_at'] != null)
          p['id'] as String: DateTime.parse(p['due_at'] as String),
    };
    final coverById = <String, String>{};
    for (final f in covers) {
      coverById.putIfAbsent(
        f['post_id'] as String,
        () => f['storage_path'] as String,
      );
    }
    final proofByEvent = <String, String>{};
    for (final f in proofs) {
      proofByEvent.putIfAbsent(
        f['event_id'] as String,
        () => f['storage_path'] as String,
      );
    }
    // Newest event of each kind per item.
    Map<String, dynamic>? latest(String item, Set<String> kinds) => events
        .where((e) => e['work_item_id'] == item && kinds.contains(e['kind']))
        .firstOrNull;
    String? nameOf(Object? id) =>
        id == null || id == me ? null : names[id as String];

    final cards = <NeedsCard>[];
    for (final n in needs) {
      final spaceId = n['space_id'] as String;
      final at = DateTime.parse(n['created_at'] as String);
      final itemId = n['work_item_id'] as String?;
      final item = itemId == null ? null : itemById[itemId];
      if (itemId != null && item == null) continue;
      final due = item?['due_date'] as String?;
      NeedsCard card(NeedsKind kind, String? actor, {String? photo}) =>
          NeedsCard(
            kind: kind,
            spaceId: spaceId,
            spaceName: spaces[spaceId] ?? '',
            at: at,
            workItemId: itemId,
            workItemRef: item?['ref'] as String?,
            workItemTitle: item?['title'] as String?,
            due: due == null ? null : DateTime.parse(due),
            requestId: n['request_id'] as String?,
            actorName: actor,
            dueAt: itemId == null ? null : dueAtById[itemId],
            photoPath: photo ?? (itemId == null ? null : coverById[itemId]),
          );
      switch (n['kind']) {
        case 'open_owned':
          final last = latest(itemId!, const {
            'raised',
            'reassigned',
            'sent_back',
          });
          cards.add(
            last?['kind'] == 'sent_back'
                ? card(NeedsKind.sentBack, nameOf(last?['actor_id']))
                : card(NeedsKind.forYou, nameOf(last?['actor_id'])),
          );
        case 'to_check':
          final done = latest(itemId!, const {'done'});
          cards.add(
            card(
              NeedsKind.youCheck,
              nameOf(done?['actor_id']),
              photo: done == null ? null : proofByEvent[done['id']],
            ),
          );
        case 'owner_left':
          cards.add(card(NeedsKind.ownerLeft, null));
        case 'checklist_for_you':
          final post = checklists
              .where((c) => c['id'] == n['space_post_id'])
              .firstOrNull;
          if (post == null) continue;
          final day = post['due_date'] as String?;
          final dueAt = post['due_at'] as String?;
          cards.add(
            NeedsCard(
              kind: NeedsKind.checklist,
              spaceId: spaceId,
              spaceName: spaces[spaceId] ?? '',
              at: at,
              postId: post['id'] as String,
              workItemTitle: post['title'] as String?,
              due: day == null ? null : DateTime.parse(day),
              dueAt: dueAt == null ? null : DateTime.parse(dueAt).toLocal(),
              actorName: nameOf(post['author_id']),
            ),
          );
        case 'join_request':
          final r = requests
              .where((r) => r['id'] == n['request_id'])
              .firstOrNull;
          if (r != null) {
            cards.add(card(NeedsKind.joinRequest, names[r['profile_id']]));
          }
      }
    }
    cards.sort((a, b) => b.at.compareTo(a.at));
    return cards;
  });
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => SupabaseActivityRepository(ref.watch(supabaseClientProvider)),
);
