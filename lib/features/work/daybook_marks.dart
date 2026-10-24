import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/network/signal_state.dart';
import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart' show mySpacesProvider;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'daybook_state.dart';
import 'work_outbox.dart';

/// What sits above a Space's daybook today (daybook_extras): the
/// announcements pinned now, and the activities starting today.
final daybookExtrasProvider = FutureProvider.autoDispose
    .family<DaybookExtras, String>((ref, spaceId) {
      final now = ref.watch(clockProvider)();
      return ref.watch(daybookRepositoryProvider).extras(spaceId, now);
    });

/// A checklist's points with who ticked each when. Read again with the
/// page ([refreshMarks]).
final checklistPointsProvider = FutureProvider.autoDispose
    .family<List<DaybookPoint>, String>(
      (ref, postId) => ref.watch(daybookRepositoryProvider).points(postId),
    );

/// A post's own photos and files (F51), read when its card shows them.
final postFilesProvider = FutureProvider.autoDispose
    .family<List<DaybookPostFile>, String>(
      (ref, postId) => ref.watch(daybookRepositoryProvider).postFiles(postId),
    );

/// Who acknowledged a post, as the server lets the reader see
/// (post_acks_for). Read again with the page ([refreshMarks]).
final postAcksProvider = FutureProvider.autoDispose
    .family<List<DaybookAckFace>, String>(
      (ref, postId) => ref.watch(daybookRepositoryProvider).acks(postId),
    );

/// The page read again: the points, the faces and what sits above it too.
void refreshMarks(WidgetRef ref, String spaceId) {
  ref
    ..invalidate(checklistPointsProvider)
    ..invalidate(postAcksProvider)
    ..invalidate(postFilesProvider)
    ..invalidate(daybookExtrasProvider(spaceId));
}

/// A tick or an acknowledgement made here, shown at once while it goes to
/// the server.
@immutable
class DaybookMark {
  const DaybookMark({
    required this.spaceId,
    required this.postId,
    required this.on,
    required this.at,
    this.pointId,
    this.pointText,
    this.ack,
    this.waiting = false,
    this.again = false,
  });

  /// One kept on the phone while it waits (review 88 S2).
  factory DaybookMark.fromJson(Map<String, dynamic> json) => DaybookMark(
    spaceId: json['space_id'] as String,
    postId: json['post_id'] as String,
    on: json['on'] as bool,
    at: DateTime.parse(json['at'] as String),
    pointId: json['point_id'] as String?,
    pointText: json['point_text'] as String?,
    ack: DaybookAck.fromJson(json['ack']),
    waiting: true,
    again: json['again'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'space_id': spaceId,
    'post_id': postId,
    'on': on,
    'at': at.toUtc().toIso8601String(),
    'point_id': pointId,
    'point_text': pointText,
    'ack': ack?.json,
    'again': again,
  };

  /// A kept one the app can still send: a tick, or a known acknowledgement.
  static bool isKnown(Map<String, dynamic> json) =>
      json['point_id'] != null || DaybookAck.fromJson(json['ack']) != null;

  final String spaceId;
  final String postId;

  /// Ticked or given ([on]), or unticked or taken back.
  final bool on;
  final DateTime at;

  /// A tick's point.
  final String? pointId;
  final String? pointText;

  /// An acknowledgement's kind.
  final DaybookAck? ack;

  /// No signal took it (slice 10): it stays on the card, "Waiting to
  /// send", and goes when the signal is back.
  final bool waiting;

  /// The old acknowledgement is taken back first (review 61 G1).
  final bool again;

  DaybookMark waitingNow() => DaybookMark(
    spaceId: spaceId,
    postId: postId,
    on: on,
    at: at,
    pointId: pointId,
    pointText: pointText,
    ack: ack,
    waiting: true,
    again: again,
  );

  bool get isTick => pointId != null;

  /// A card moves for what everyone who sees it can see (review 60 S1): a
  /// tick, an un-tick and a Received, never a Got it, an On my way or an
  /// In my calendar, which only the author sees. A take-back moves
  /// nothing.
  bool get moves => isTick || (ack == DaybookAck.received && on);

  /// The same mark of the same thing: one point, or one acknowledgement.
  String get key => isTick ? 'tick $pointId' : 'ack $postId ${ack!.json}';
}

final daybookMarksProvider = NotifierProvider<DaybookMarks, List<DaybookMark>>(
  DaybookMarks.new,
);

/// Ticks and acknowledgements on their way to the server. Each shows on
/// its card at once; once the server has it the page reads again and the
/// mark goes. A refusal says why ([refusalsProvider]) and takes it back.
/// With no signal it stays, "Waiting to send" (slice 10), and is sent
/// again a little later and when the signal is back; a newer tap of the
/// same thing replaces it. The waiting ones are kept on the phone between
/// starts (review 88 S2), each account its own, and sent when the app
/// opens ([flushAll]).
class DaybookMarks extends Notifier<List<DaybookMark>> {
  late final _retry = OutboxRetry(flushAll);

  String? _key;

  @override
  List<DaybookMark> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final userId = ref.watch(authUserIdProvider).value;
    ref.onDispose(() => _retry.cancel());
    ref.listen(signalProvider, (was, has) {
      if (was == false && has) unawaited(flushAll());
    });
    _key = userId == null ? null : 'daybook_marks:$userId';
    final raw = _key == null ? null : prefs.getString(_key!);
    if (raw == null) return const [];
    try {
      return [
        for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          if (DaybookMark.isKnown(j)) DaybookMark.fromJson(j),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// The marks now; the waiting ones are kept on the phone too.
  void _set(List<DaybookMark> marks) {
    state = marks;
    final key = _key;
    if (key == null) return;
    final waiting = [
      for (final m in marks)
        if (m.waiting) m.toJson(),
    ];
    final prefs = ref.read(sharedPreferencesProvider);
    unawaited(
      waiting.isEmpty
          ? prefs.remove(key)
          : prefs.setString(key, jsonEncode(waiting)),
    );
  }

  /// Every mark that waits for a signal, once more: on opening the app,
  /// when the signal is back, and a little later after a failed try.
  Future<void> flushAll() async {
    for (final m in state.where((m) => m.waiting).toList()) {
      // Never one twice at once: the try in flight has it.
      if (!_sending.add(m.key)) continue;
      try {
        await send(m, again: m.again);
      } finally {
        _sending.remove(m.key);
      }
    }
  }

  /// The waiting ones being sent again now.
  final _sending = <String>{};

  void _drop(DaybookMark mark) => _set([
    for (final m in state)
      if (m.key != mark.key) m,
  ]);

  /// Sends [mark]. With no signal it waits (above). [again] takes the old
  /// acknowledgement back first, so the new one has this time (review 61
  /// G1); the card shows it given at once all the same (F44: the pinned
  /// note folds on the tap). [sayHere]: a refusal is rethrown, for the
  /// screen that sent it to say where the person is (the file page,
  /// review 79), and the daybook isn't told.
  Future<void> send(
    DaybookMark mark, {
    bool again = false,
    bool sayHere = false,
  }) async {
    final sent = DaybookMark(
      spaceId: mark.spaceId,
      postId: mark.postId,
      on: mark.on,
      at: mark.at,
      pointId: mark.pointId,
      pointText: mark.pointText,
      ack: mark.ack,
      // A waiting one stays kept on the phone until the server has it.
      waiting: mark.waiting,
      again: again,
    );
    _set([
      for (final m in state)
        if (m.key != mark.key) m,
      sent,
    ]);
    final repo = ref.read(daybookRepositoryProvider);
    try {
      if (mark.isTick) {
        await repo.tickPoint(mark.pointId!, on: mark.on);
      } else {
        if (again) await repo.ack(mark.postId, mark.ack!, on: false);
        await repo.ack(mark.postId, mark.ack!, on: mark.on);
      }
    } on SpaceException catch (e) {
      if (e.failure == SpaceFailure.network) {
        // Unless a newer tap of the same thing came meanwhile.
        if (state.any((m) => identical(m, sent))) {
          _set([
            for (final m in state) identical(m, sent) ? sent.waitingNow() : m,
          ]);
        }
        ref.read(signalProvider.notifier).lost();
        _retry.later(ref.read(outboxRetryLaterProvider));
        return;
      }
      _drop(mark);
      if (sayHere) {
        await _readAgain(mark);
        rethrow;
      }
      ref
          .read(refusalsProvider.notifier)
          .add(
            DaybookRefusal(
              action: mark.isTick ? RefusedAction.tick : RefusedAction.ack,
              spaceId: mark.spaceId,
              postId: mark.postId,
              why: RefusalWhy.of(e),
            ),
          );
      await _readAgain(mark);
      return;
    }
    _retry.reached();
    ref.read(signalProvider.notifier).back();
    await _readAgain(mark);
    // Unless a newer tap of the same thing waits.
    _set([
      for (final m in state)
        if (!identical(m, sent)) m,
    ]);
  }

  /// The card's points, faces and place, as the server has them now.
  Future<void> _readAgain(DaybookMark mark) async {
    ref
      ..invalidate(checklistPointsProvider(mark.postId))
      ..invalidate(postAcksProvider(mark.postId))
      ..invalidate(mySpacesProvider);
    final page = daybookCardsProvider(mark.spaceId);
    if (!ref.exists(page)) return;
    // Kept read while the mark waits for it, so the point never blinks.
    final points = checklistPointsProvider(mark.postId);
    final keep = mark.isTick ? ref.listen(points, (_, _) {}) : null;
    try {
      await ref.read(page.notifier).refresh();
      if (keep != null) await ref.read(points.future);
    } on SpaceException {
      // The page catches up on its next read.
    } finally {
      keep?.close();
    }
  }
}
