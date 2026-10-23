import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/bidi.dart';
import '../../core/push/push_state.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/dm.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dm_repository.dart';
import '../../data/repositories/push_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entry/entry_state.dart';
import 'dm_banner.dart';

/// A direct message thread changed (F81): live, by a push, or because the
/// app came back to the front. A null [threadId] means any thread.
@immutable
class DmChange {
  const DmChange(this.threadId);

  final String? threadId;

  bool touches(String? id) => threadId == null || threadId == id;
}

final dmChangeProvider = NotifierProvider<DmChanges, DmChange?>(DmChanges.new);

class DmChanges extends Notifier<DmChange?> {
  @override
  DmChange? build() => null;

  // A new object each time, so the same thread twice still tells.
  void add(String? threadId) => state = DmChange(threadId);
}

/// The conversation on screen now (DM2), so a push about it shows no
/// banner.
final openDmThreadProvider = NotifierProvider<OpenDmThread, String?>(
  OpenDmThread.new,
);

class OpenDmThread extends Notifier<String?> {
  @override
  String? build() => null;

  // Called a moment after the screen opens or closes: the app may be gone.
  void set(String? threadId) {
    if (ref.mounted) state = threadId;
  }

  /// Only the screen that set it clears it.
  void clear(String? threadId) {
    if (ref.mounted && state == threadId) state = null;
  }
}

/// The kinds of push that are about a direct message (push function). A
/// follow-up (F97) only reads the list again: each of its messages already
/// had its banner, live or by push (F100).
const dmPushKinds = {'dm_message', 'dm_request', 'dm_follow_up'};

/// The pushes that show a banner.
const dmBannerKinds = {'dm_message', 'dm_request'};

/// Keys the phone adds to a push's data: what the notification said.
const pushTitleKey = '_title';
const pushBodyKey = '_body';

/// The waits before a closed, failed or timed-out channel is opened again
/// (F100); the last one again and again. Tests set their own.
final dmLiveRetryDelaysProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ],
);

/// Messages, app-wide while signed in (F81, F100): each thread on the list
/// and the newest request is followed live on its private `dm:` channel,
/// and the list, Home's dot and the tab's dot read again when one changes,
/// when a direct message push arrives, and when the app comes back to the
/// front.
///
/// The channels open only once sign-in is complete, and open again when
/// the sign-in token is new, after signing out and in, when the app comes
/// back to the front, and a little after one closes, errors or times out.
///
/// A new message from the other person, live or by push, in a conversation
/// that isn't on screen, shows the quiet banner ([DmBannerHost]) once.
class DmLiveHost extends ConsumerStatefulWidget {
  const DmLiveHost({super.key, required this.child});

  final Widget child;

  /// Threads followed live at once, newest first.
  static const followMax = 30;

  @override
  ConsumerState<DmLiveHost> createState() => _DmLiveHostState();
}

class _DmLiveHostState extends ConsumerState<DmLiveHost> {
  final _subs = <String, StreamSubscription<DmLiveEvent>>{};

  /// Failed opens in a row, per thread, and the waits before the next.
  final _tries = <String, int>{};
  final _again = <String, Timer>{};

  late final AppLifecycleListener _life;
  StreamSubscription<void>? _renewed;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _resumed);
    _renewed = ref
        .read(authRepositoryProvider)
        .sessionRenewed()
        .listen((_) => _reopenAll());
  }

  @override
  void dispose() {
    _life.dispose();
    unawaited(_renewed?.cancel());
    _closeAll();
    super.dispose();
  }

  bool get _signedIn =>
      ref.read(appGateProvider) == AppGate.ready &&
      ref.read(authUserIdProvider).value != null;

  void _changed(String? threadId) {
    if (!mounted || !_signedIn) return;
    ref.invalidate(dmInboxProvider);
    ref.read(dmChangeProvider.notifier).add(threadId);
  }

  void _resumed() {
    _changed(null);
    _reopenAll();
  }

  /// The threads to follow now: the newest on the list, the newest
  /// request, and the conversation on screen.
  List<String> _wanted(DmInbox? inbox) => {
    for (final t
        in inbox?.threads.take(DmLiveHost.followMax) ?? const <DmRow>[])
      t.threadId,
    ?inbox?.newestRequest?.threadId,
    ?ref.read(openDmThreadProvider),
  }.toList();

  void _follow(DmInbox? inbox) {
    if (!_signedIn) return;
    for (final id in _wanted(inbox)) {
      if (!_subs.containsKey(id) && !_again.containsKey(id)) _open(id);
    }
  }

  void _open(String id) {
    _again.remove(id)?.cancel();
    _subs[id] = ref
        .read(dmRepositoryProvider)
        .changes(id)
        .listen(
          (e) => _event(id, e),
          onError: (Object e) => _lost(id, e),
          onDone: () => _lost(id, null),
          cancelOnError: true,
        );
  }

  /// The channel closed, errored or timed out: opened again a little
  /// later, waiting longer each time it fails in a row.
  void _lost(String id, Object? why) {
    final sub = _subs.remove(id);
    if (sub == null || !mounted) return;
    unawaited(sub.cancel());
    debugPrint('BV-LIVE lost dm:$id ${why ?? 'done'}');
    if (!_signedIn) return;
    final waits = ref.read(dmLiveRetryDelaysProvider);
    final n = _tries[id] ?? 0;
    _tries[id] = n + 1;
    _again[id] = Timer(waits[n.clamp(0, waits.length - 1)], () {
      _again.remove(id);
      if (!mounted || !_signedIn) return;
      if (_wanted(ref.read(dmInboxProvider).value).contains(id)) _open(id);
    });
  }

  void _closeAll() {
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    _subs.clear();
    for (final t in _again.values) {
      t.cancel();
    }
    _again.clear();
    _tries.clear();
  }

  /// Every channel again, from the first wait: a new token, a new sign-in,
  /// the app back in front.
  void _reopenAll() {
    if (!mounted) return;
    _closeAll();
    _follow(ref.read(dmInboxProvider).value);
  }

  void _event(String id, DmLiveEvent e) {
    switch (e) {
      case DmLiveJoined():
        _tries.remove(id);
      case DmLiveRow():
        _changed(id);
        if (e.inserted) unawaited(_liveBanner(id, e));
    }
  }

  /// F100: a new message from the other person shows the banner, as its
  /// push would: their name, and its words only if the lock-screen setting
  /// shows message text.
  Future<void> _liveBanner(String id, DmLiveRow row) async {
    final me = ref.read(authUserIdProvider).value;
    if (row.deleted || row.authorId == null || row.authorId == me) return;
    if (ref.read(openDmThreadProvider) == id) return;
    final inbox = ref.read(dmInboxProvider).value;
    final person = [
      ...?inbox?.threads,
      ?inbox?.newestRequest,
    ].where((t) => t.threadId == id).firstOrNull?.person;
    var showText = false;
    try {
      showText =
          (await ref.read(pushRepositoryProvider).settings()).messageText;
    } on Object {
      // Unknown: the words stay hidden, as on the lock screen.
    }
    if (!mounted || !_signedIn || ref.read(openDmThreadProvider) == id) return;
    final l10n = AppLocalizations.of(context);
    final words = switch (row.kind) {
      'photo' => l10n.chatPhoto,
      'file' => l10n.chatFile,
      'voice' => l10n.chatVoice,
      _ => row.body?.trim() ?? '',
    };
    ref
        .read(dmBannerProvider.notifier)
        .show(
          threadId: id,
          messageId: row.id,
          title: l10n.dmBannerTitle(
            inOwnDirection(person?.name ?? l10n.activitySomeone),
          ),
          body: showText && words.isNotEmpty ? words : l10n.dmBannerHidden,
          route: AppRoutes.messagesThread(id),
        );
  }

  void _arrived(PushArrival? push) {
    final data = push?.data;
    if (data == null || !dmPushKinds.contains(data['kind'])) return;
    final id = data['dm_thread_id'];
    _changed(id);
    if (!dmBannerKinds.contains(data['kind'])) return;
    final route = data['route'];
    if (id == null || route == null || ref.read(openDmThreadProvider) == id) {
      return;
    }
    final title = data[pushTitleKey];
    if (title == null || title.isEmpty) return;
    ref
        .read(dmBannerProvider.notifier)
        .show(
          threadId: id,
          messageId: data['message_id'],
          title: title,
          body: data[pushBodyKey] ?? '',
          route: route,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Signed out: no channel stays open; signed in again, they open (the
    // list follows below). Another account: all again.
    ref.listen(appGateProvider, (_, gate) {
      if (gate != AppGate.ready) _closeAll();
    });
    ref.listen(authUserIdProvider, (was, now) {
      final a = was?.value;
      final b = now.value;
      if (a != null && b != null && a != b) _reopenAll();
    });
    if (ref.watch(appGateProvider) == AppGate.ready) {
      // Each thread on the list is followed once; new ones as they come.
      final inbox = ref.watch(dmInboxProvider).value;
      if (inbox != null) _follow(inbox);
      ref.listen(pushArrivalProvider, (_, push) => _arrived(push));
      // The conversation on screen, even one not on the list yet.
      ref.listen(openDmThreadProvider, (_, id) {
        if (id != null) _follow(ref.read(dmInboxProvider).value);
      });
    }
    return widget.child;
  }
}
