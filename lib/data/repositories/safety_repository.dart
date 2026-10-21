import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/space.dart';
import '../supabase/supabase_provider.dart';
import 'space_repository.dart';

/// What can be reported (R1).
enum ReportKind {
  post('post'),
  reply('reply'),
  profile('profile'),
  message('message'),

  /// A direct message (migration 22): hidden for the reporter at once.
  dmMessage('dm_message');

  const ReportKind(this.json);
  final String json;
}

/// The six R1 reasons, as drawn.
enum ReportReason {
  spam('spam'),
  harassment('harassment'),
  misleading('misleading'),
  fake('fake'),
  privateInfo('private_info'),
  other('other');

  const ReportReason(this.json);

  final String json;

  static ReportReason fromJson(Object? value) =>
      values.where((r) => r.json == value).firstOrNull ?? other;
}

/// Someone you blocked (S7).
@immutable
class BlockedPerson {
  const BlockedPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.headline,
  });

  factory BlockedPerson.fromJson(Map<String, dynamic> j) => BlockedPerson(
    id: j['profile_id'] as String,
    firstName: j['first_name'] as String? ?? '',
    lastName: j['last_name'] as String? ?? '',
    headline: j['headline'] as String?,
  );

  final String id;
  final String firstName;
  final String lastName;
  final String? headline;

  String get fullName => '$firstName $lastName'.trim();
}

enum AppealStatus { none, open, upheld, reversed }

/// R3: something of yours that was removed, for you only.
@immutable
class Removal {
  const Removal({
    required this.id,
    required this.kind,
    required this.reason,
    required this.removedAt,
    required this.appealStatus,
    required this.canAppeal,
    this.excerpt,
    this.appealAt,
    this.postedAt,
  });

  factory Removal.fromJson(Map<String, dynamic> j) => Removal(
    id: j['id'] as String,
    kind: ReportKind.values.byName(j['target_kind'] as String),
    reason: ReportReason.fromJson(j['reason']),
    removedAt: DateTime.parse(j['removed_at'] as String),
    appealStatus: AppealStatus.values.byName(j['appeal_status'] as String),
    canAppeal: j['can_appeal'] as bool? ?? false,
    excerpt: j['excerpt'] as String?,
    appealAt: j['appeal_at'] == null
        ? null
        : DateTime.parse(j['appeal_at'] as String),
    postedAt: j['posted_at'] == null
        ? null
        : DateTime.parse(j['posted_at'] as String),
  );

  final String id;
  final ReportKind kind;
  final ReportReason reason;
  final DateTime removedAt;
  final AppealStatus appealStatus;
  final bool canAppeal;
  final String? excerpt;
  final DateTime? appealAt;

  /// When it was written: R3's "Your post · 12 Sep".
  final DateTime? postedAt;
}

/// Report, block and appeal (migration 15). Deciding is never in the app.
abstract class SafetyRepository {
  Future<void> report(
    ReportKind kind,
    String id,
    ReportReason reason, {
    String? note,
  });
  Future<void> block(String personId, bool on);
  Future<List<BlockedPerson>> blocked();

  /// Null when it isn't yours, or isn't there.
  Future<Removal?> removal(String id);
  Future<void> appeal(String removalId, String note);
}

class SupabaseSafetyRepository implements SafetyRepository {
  const SupabaseSafetyRepository(this._client);

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

  @override
  Future<void> report(
    ReportKind kind,
    String id,
    ReportReason reason, {
    String? note,
  }) => _guard(
    () => _client.rpc(
      'report',
      params: {
        'p_kind': kind.json,
        'p_id': id,
        'p_reason': reason.json,
        'p_note': note,
      },
    ),
  );

  @override
  Future<void> block(String personId, bool on) => _guard(
    () => _client.rpc('block', params: {'p_person': personId, 'p_on': on}),
  );

  @override
  Future<List<BlockedPerson>> blocked() => _guard(() async {
    final rows = (await _client.rpc<List<dynamic>>(
      'my_blocks',
    )).cast<Map<String, dynamic>>();
    return [for (final r in rows) BlockedPerson.fromJson(r)];
  });

  @override
  Future<Removal?> removal(String id) => _guard(() async {
    final rows = (await _client.rpc<List<dynamic>>(
      'my_removal',
      params: {'p_id': id},
    )).cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : Removal.fromJson(rows.first);
  });

  @override
  Future<void> appeal(String removalId, String note) => _guard(
    () =>
        _client.rpc('appeal', params: {'p_removal': removalId, 'p_note': note}),
  );
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => SupabaseSafetyRepository(ref.watch(supabaseClientProvider)),
);

final blockedProvider = FutureProvider.autoDispose<List<BlockedPerson>>(
  (ref) => ref.watch(safetyRepositoryProvider).blocked(),
);

final removalProvider = FutureProvider.autoDispose.family<Removal?, String>(
  (ref, id) => ref.watch(safetyRepositoryProvider).removal(id),
);
