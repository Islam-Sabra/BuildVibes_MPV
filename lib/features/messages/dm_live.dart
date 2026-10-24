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

/// What the in-app banner says for a direct message push (app open; the
/// phone shows no notification then). F102's pushes are written for the
/// lock screen: text on, "Omar Haddad · 3 new messages" over the newest
/// words (review 89 M3); text off, "Message from Omar Haddad" over "3 new
/// messages". The banner
/// stays as F99/F101 drew it: "Message from Omar Haddad" over the newest
/// words, or over "New message" (then counting up itself) when the words
/// are hidden.
///
/// [data] is the push's data with what it said ([pushTitleKey],
/// [pushBodyKey]). `shown` marks a body that holds the words; a push
/// without `count` (sent before migration 41) keeps its title and body,
/// hidden as [showText] says.
({String title, String body, bool hidden}) dmPushBanner(
  Map<String, String> data,
  AppLocalizations l10n, {
  required bool showText,
}) {
  final title = data[pushTitleKey] ?? '';
  final body = data[pushBodyKey] ?? '';
  if (data['kind'] != 'dm_message' || !data.containsKey('count')) {
    return (title: title, body: body, hidden: !showText);
  }
  if (data['shown'] != '1') {
    return (title: title, body: l10n.dmBannerHidden, hidden: true);
  }
  final count = int.tryParse(data['count'] ?? '') ?? 1;
  // The server adds " · 3 new messages" after the name when count > 1.
  final cut = count > 1 ? title.lastIndexOf(pushCountSeparator) : -1;
  return (
    // The name, already in its own direction.
    title: l10n.dmBannerTitle(cut > 0 ? title.substring(0, cut) : title),
    body: body,
    hidden: false,
  );
}

/// Between the name and the count in a push title (strings.json).
const pushCountSeparator = ' · ';

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
  /// shows message text. The broadcast carries only ids (migration 40), so
  /// the message is read again by id, under the thread's read rule: one
  /// that can't be read, or was deleted meanwhile, shows nothing.
  Future<void> _liveBanner(String id, DmLiveRow row) async {
    final me = ref.read(authUserIdProvider).value;
    if (row.deleted || row.authorId == null || row.authorId == me) return;
    if (ref.read(openDmThreadProvider) == id) return;
    final inbox = ref.read(dmInboxProvider).value;
    final person = [
      ...?inbox?.threads,
      ?inbox?.newestRequest,
    ].where((t) => t.threadId == id).firstOrNull?.person;
    DmLiveText? text;
    try {
      text = await ref.read(dmRepositoryProvider).liveText(row.id);
      if (text == null) return;
    } on Object {
      // Unknown: the banner still tells, with the words hidden.
    }
    var showText = false;
    try {
      showText =
          (await ref.read(pushRepositoryProvider).settings()).messageText;
    } on Object {
      // Unknown: the words stay hidden, as on the lock screen.
    }
    if (!mounted || !_signedIn || ref.read(openDmThreadProvider) == id) return;
    final l10n = AppLocalizations.of(context);
    final words = switch (text?.kind) {
      'photo' => l10n.chatPhoto,
      'file' => l10n.chatFile,
      'voice' => l10n.chatVoice,
      _ => text?.body?.trim() ?? '',
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
          hidden: !(showText && words.isNotEmpty),
        );
  }

  /// The push's banner (F101): its words are hidden exactly when the
  /// lock-screen setting is off, so the banner can count what came. F102:
  /// the push's own words are read by [dmPushBanner].
  Future<void> _pushBanner({
    required String threadId,
    required String? messageId,
    required Map<String, String> data,
    required String route,
  }) async {
    var showText = false;
    try {
      showText =
          (await ref.read(pushRepositoryProvider).settings()).messageText;
    } on Object {
      // Unknown: counted as hidden, as on the lock screen.
    }
    if (!mounted || !_signedIn || ref.read(openDmThreadProvider) == threadId) {
      return;
    }
    final banner = dmPushBanner(
      data,
      AppLocalizations.of(context),
      showText: showText,
    );
    ref
        .read(dmBannerProvider.notifier)
        .show(
          threadId: threadId,
          messageId: messageId,
          title: banner.title,
          body: banner.body,
          route: route,
          hidden: banner.hidden,
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
    unawaited(
      _pushBanner(
        threadId: id,
        messageId: data['message_id'],
        data: data,
        route: route,
      ),
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
