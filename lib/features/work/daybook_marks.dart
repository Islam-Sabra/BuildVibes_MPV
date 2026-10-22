import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/daybook.dart';
import '../../data/models/space.dart';
import '../../data/repositories/daybook_live.dart';
import '../../data/repositories/daybook_repository.dart';
import '../../data/repositories/space_repository.dart' show mySpacesProvider;
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
  });

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
/// mark goes. A refusal says why ([refusalsProvider]); no signal says so.
/// Neither keeps it: a tick isn't worth a queue, and the card shows
/// what the server has.
class DaybookMarks extends Notifier<List<DaybookMark>> {
  @override
  List<DaybookMark> build() => const [];

  void _drop(DaybookMark mark) => state = [
    for (final m in state)
      if (m.key != mark.key) m,
  ];

  /// Sends [mark]. Rethrows a lost signal for the screen to say. [again]
  /// takes the old acknowledgement back first, so the new one has this
  /// time (review 61 G1); the card shows it given at once all the same
  /// (F44: the pinned note folds on the tap). [sayHere]: a refusal is
  /// rethrown too, for the screen that sent it to say where the person
  /// is (the file page, review 79), and the daybook isn't told.
  Future<void> send(
    DaybookMark mark, {
    bool again = false,
    bool sayHere = false,
  }) async {
    state = [
      for (final m in state)
        if (m.key != mark.key) m,
      mark,
    ];
    final repo = ref.read(daybookRepositoryProvider);
    try {
      if (mark.isTick) {
        await repo.tickPoint(mark.pointId!, on: mark.on);
      } else {
        if (again) await repo.ack(mark.postId, mark.ack!, on: false);
        await repo.ack(mark.postId, mark.ack!, on: mark.on);
      }
    } on SpaceException catch (e) {
      _drop(mark);
      if (e.failure == SpaceFailure.network) rethrow;
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
    // The Space's other open daybooks read it at once (F47).
    unawaited(ref.read(daybookLiveProvider).changed(mark.spaceId, mark.postId));
    await _readAgain(mark);
    _drop(mark);
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
