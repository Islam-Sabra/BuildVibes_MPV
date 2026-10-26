import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/push/reminders.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/note.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'notebook_state.dart';

/// The reminders this phone has set, and whose: note id → its time and
/// words. Another account on the same phone has its own; the last one's
/// are taken off first.
const remindersSetKey = 'reminders_set';

/// Whether [note] has a reminder still to come.
bool remindsAt(Note note, DateTime now) {
  final at = note.remindAt;
  return at != null &&
      !note.done &&
      note.kind != NoteKind.voice &&
      at.isAfter(now);
}

/// What the phone's reminder says under "Reminder": the note's words, or
/// a checklist's title, else its first point.
String reminderWords(Note note) {
  final words = note.body.trim().isNotEmpty
      ? note.body.trim()
      : note.points.isEmpty
      ? ''
      : note.points.first.text.trim();
  final line = words.split('\n').first;
  const max = 120;
  return line.length <= max ? line : '${line.substring(0, max - 1)}…';
}

/// Around the tabs while signed in: sets each note's reminder on this
/// phone, moves it when its time changes, takes it off when the note is
/// done, deleted or its reminder removed, and on every start sets again
/// those still to come (after a reinstall, a new phone, or the phone
/// dropping them). A tap opens My notebook.
class ReminderHost extends ConsumerStatefulWidget {
  const ReminderHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends ConsumerState<ReminderHost> {
  var _started = false;
  var _ready = false;

  /// The start's sync sets every reminder again; later ones only changes.
  var _all = true;

  /// One sync at a time, in order.
  Future<void> _chain = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    if (!mounted || _started) return;
    if (ref.read(appGateProvider) != AppGate.ready) return;
    _started = true;
    final l10n = AppLocalizations.of(context);
    final reminders = ref.read(phoneRemindersProvider);
    await reminders.init(
      channel: l10n.reminderChannel,
      channelAbout: l10n.reminderChannelAbout,
      onTap: (_) => _open(),
    );
    if (!mounted) return;
    _ready = true;
    final launched = await reminders.launchedBy();
    if (launched != null) _open();
    final notes = ref.read(notebookProvider).value?.notes;
    if (notes != null) _queue(notes);
  }

  void _queue(List<Note> notes) =>
      _chain = _chain.then((_) => _sync(notes)).catchError((Object _) {});

  void _open() {
    if (!mounted) return;
    unawaited(GoRouter.of(context).push(AppRoutes.notebook));
  }

  Future<void> _sync(List<Note> notes) async {
    if (!_ready || !mounted) return;
    final userId = ref.read(authUserIdProvider).value;
    if (userId == null) return;
    final l10n = AppLocalizations.of(context);
    final prefs = ref.read(sharedPreferencesProvider);
    final reminders = ref.read(phoneRemindersProvider);
    final now = ref.read(clockProvider)();
    var kept = <String, String>{};
    String? keptFor;
    try {
      final j = jsonDecode(prefs.getString(remindersSetKey) ?? '{}') as Map;
      keptFor = j['user'] as String?;
      kept = {
        for (final e in (j['items'] as Map? ?? const {}).entries)
          e.key as String: e.value as String,
      };
    } on Object {
      kept = {};
    }
    if (keptFor != null && keptFor != userId) {
      for (final id in kept.keys) {
        await reminders.cancel(id);
      }
      kept = {};
    }
    final all = _all;
    _all = false;
    final want = <String, String>{};
    for (final n in notes) {
      if (!remindsAt(n, now)) continue;
      final words = reminderWords(n);
      final sign = '${n.remindAt!.toUtc().toIso8601String()} $words';
      want[n.id] = sign;
      if (all || kept[n.id] != sign) {
        await reminders.set(
          n.id,
          at: n.remindAt!,
          title: l10n.reminderTitle,
          body: words,
        );
      }
    }
    for (final id in kept.keys) {
      if (!want.containsKey(id)) await reminders.cancel(id);
    }
    await prefs.setString(
      remindersSetKey,
      jsonEncode({'user': userId, 'items': want}),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(appGateProvider) == AppGate.ready) {
      ref.listen(notebookProvider, (_, next) {
        final notes = next.value?.notes;
        if (notes != null) _queue(notes);
      });
      if (!_started) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => unawaited(_start()),
        );
      }
    }
    return widget.child;
  }
}
