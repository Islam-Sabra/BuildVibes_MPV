import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/push/reminders.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/work_item.dart';
import '../entry/entry_state.dart';

/// What a Work card's gestures need from the server that 105B brings
/// (review 105, the lead's rulings Q1 and Q2): pins per person, Share into
/// one of the Space's Chat threads, and a Lead's Archive of a Checked item.
/// Each is off (null) until its server function is there; tests turn them
/// on to see the gestures.
@immutable
class WorkLater {
  const WorkLater({this.pin, this.share, this.archive});

  /// Pin or unpin a post for me only.
  final Future<void> Function(DaybookPost post, {required bool on})? pin;

  /// Post the selected cards into one of the Space's Chat threads.
  final Future<void> Function(BuildContext context, List<DaybookPost> posts)?
  share;

  /// Hide a Checked item from Work for everyone (Search and the Library
  /// still find it).
  final Future<void> Function(DaybookPost post)? archive;
}

final workLaterProvider = Provider<WorkLater>((ref) => const WorkLater());

/// The cards held and selected on one Space's Work (review 105 SP6): a
/// hold starts it, a tap adds or takes off, ✕ ends it, and so does
/// leaving the Space.
final workSelectionProvider = NotifierProvider.autoDispose
    .family<WorkSelection, Set<String>, String>(WorkSelection.new);

class WorkSelection extends Notifier<Set<String>> {
  WorkSelection(this.spaceId);

  final String spaceId;

  @override
  Set<String> build() => const {};

  void toggle(String id) =>
      state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};

  void clear() => state = const {};
}

/// Delete is offered on my own post that isn't Checked or cancelled; the
/// server refuses it once someone else has added to it.
bool mayDeletePost(DaybookPost post, {required String? me}) =>
    post.authorId != null &&
    post.authorId == me &&
    !post.cancelled &&
    post.item?.status != WorkStatus.checked;

/// A Lead may archive a Checked work item (105B, behind [WorkLater]).
bool mayArchivePost(DaybookPost post, {required bool lead}) =>
    lead && post.isWorkItem && post.item?.status == WorkStatus.checked;

/// The Space reminders set on this phone, by [spaceReminderId], for the
/// account that set them: when each goes off.
const spaceRemindersKey = 'space_reminders';

final spaceRemindersProvider =
    NotifierProvider<SpaceReminders, Map<String, DateTime>>(SpaceReminders.new);

/// The Reminder swipe (review 105 Part 2): a phone notification for me
/// only, set on this phone at the time I pick. It never goes to the
/// server.
class SpaceReminders extends Notifier<Map<String, DateTime>> {
  String? _user;

  @override
  Map<String, DateTime> build() {
    _user = ref.watch(authUserIdProvider).value;
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(spaceRemindersKey);
    if (raw == null) return const {};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final kept = {
        for (final e in (j['items'] as Map? ?? const {}).entries)
          e.key as String: DateTime.parse(e.value as String).toLocal(),
      };
      // Another account's reminders don't stay on this phone.
      if (j['user'] != _user) {
        final phone = ref.read(phoneRemindersProvider);
        for (final id in kept.keys) {
          unawaited(phone.cancel(id));
        }
        unawaited(
          ref.read(sharedPreferencesProvider).remove(spaceRemindersKey),
        );
        return const {};
      }
      return kept;
    } on Object {
      return const {};
    }
  }

  /// When [postId]'s reminder goes off, if it is set.
  DateTime? of(String spaceId, String postId) =>
      state[spaceReminderId(spaceId, postId)];

  /// Sets [post]'s reminder at [at], or takes it off when [at] is null.
  Future<void> set(
    String spaceId,
    DaybookPost post, {
    required DateTime? at,
    required String body,
  }) async {
    final id = spaceReminderId(spaceId, post.id);
    final phone = ref.read(phoneRemindersProvider);
    final next = {...state};
    if (at == null) {
      next.remove(id);
      await phone.cancel(id);
    } else {
      next[id] = at;
      await phone.set(id, at: at, title: post.title, body: body);
    }
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          spaceRemindersKey,
          jsonEncode({
            'user': _user,
            'items': {
              for (final e in next.entries)
                e.key: e.value.toUtc().toIso8601String(),
            },
          }),
        );
  }
}

/// A Space post's reminder tapped (or opening the app): its card, on its
/// Space's Work.
class SpaceReminderHost extends ConsumerStatefulWidget {
  const SpaceReminderHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SpaceReminderHost> createState() => _SpaceReminderHostState();
}

class _SpaceReminderHostState extends ConsumerState<SpaceReminderHost> {
  StreamSubscription<SpaceReminder>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = ref.read(spaceReminderTapsProvider).stream.listen((item) {
      if (!mounted) return;
      unawaited(
        GoRouter.of(
          context,
        ).push(AppRoutes.spaceCard(item.spaceId, item.postId)),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
