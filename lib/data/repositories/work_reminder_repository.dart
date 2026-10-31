import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart' show spaceFailureFor;

/// One of a work item's waiting reminders for someone (review 108 RM2):
/// who set it, when, its note, the people it reminds, and whether the
/// reader may take it off.
@immutable
class WorkReminder {
  const WorkReminder({
    required this.id,
    required this.remindAt,
    required this.people,
    this.setById,
    this.setByName,
    this.note,
    this.canRemove = false,
  });

  factory WorkReminder.fromJson(Map<String, dynamic> json) => WorkReminder(
    id: json['id'] as String,
    setById: json['set_by'] as String?,
    setByName: json['set_by_name'] as String?,
    remindAt: DateTime.parse(json['remind_at'] as String).toLocal(),
    note: json['note'] as String?,
    people: [
      for (final p in (json['recipients'] as List? ?? const []))
        (id: (p as Map)['id'] as String, name: p['name'] as String? ?? ''),
    ],
    canRemove: json['can_remove'] as bool? ?? false,
  );

  final String id;
  final String? setById;
  final String? setByName;
  final DateTime remindAt;
  final String? note;
  final List<({String id, String name})> people;
  final bool canRemove;
}

/// Reminders for someone else on a work item (review 108 RM1, RM2). The
/// server checks every rule: the item's creator, owner or a Lead; people
/// who can see it; at most 5 waiting.
abstract class WorkReminderRepository {
  /// set_work_reminder. The same [id] again is the same reminder.
  Future<void> set({
    required String id,
    required String postId,
    required List<String> people,
    required DateTime at,
    String? note,
  });

  /// remove_work_reminder: its setter, the item's creator or a Lead.
  Future<void> remove(String id);

  /// post_work_reminders: the ones still waiting that the reader may read.
  Future<List<WorkReminder>> forPost(String postId);
}

class SupabaseWorkReminderRepository implements WorkReminderRepository {
  const SupabaseWorkReminderRepository(this._client);

  final SupabaseClient _client;

  /// As the Space repository's: the server's refusal by its code; no
  /// connection is SpaceFailure.network.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw SpaceException(spaceFailureFor(e.code), e.message);
    } on SpaceException {
      rethrow;
    } on Exception catch (e) {
      final network = e is SocketException || '$e'.contains('SocketException');
      throw SpaceException(
        network ? SpaceFailure.network : SpaceFailure.unknown,
        '$e',
      );
    }
  }

  @override
  Future<void> set({
    required String id,
    required String postId,
    required List<String> people,
    required DateTime at,
    String? note,
  }) => _guard(
    () => _client.rpc<void>(
      'set_work_reminder',
      params: {
        'p_id': id,
        'p_post': postId,
        'p_recipients': people,
        'p_at': at.toUtc().toIso8601String(),
        'p_note': note,
      },
    ),
  );

  @override
  Future<void> remove(String id) => _guard(
    () => _client.rpc<void>('remove_work_reminder', params: {'p_id': id}),
  );

  @override
  Future<List<WorkReminder>> forPost(String postId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'post_work_reminders',
      params: {'p_post': postId},
    );
    return [
      for (final r in rows) WorkReminder.fromJson(r as Map<String, dynamic>),
    ];
  });
}

final workReminderRepositoryProvider = Provider<WorkReminderRepository>(
  (ref) => SupabaseWorkReminderRepository(ref.watch(supabaseClientProvider)),
);

/// A work item's waiting reminders for someone (RM2), read again after a
/// change.
final postRemindersProvider = FutureProvider.autoDispose
    .family<List<WorkReminder>, String>(
      (ref, postId) =>
          ref.watch(workReminderRepositoryProvider).forPost(postId),
    );
