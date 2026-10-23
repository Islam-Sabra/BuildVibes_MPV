import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, SupabaseClient;

import '../../core/push/push_state.dart';
import '../../data/models/dm.dart';
import '../../data/repositories/dm_repository.dart';
import '../../data/supabase/supabase_provider.dart';
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

/// The kinds of push that are about a direct message (push function).
const dmPushKinds = {'dm_message', 'dm_request'};

/// Keys the phone adds to a push's data: what the notification said.
const pushTitleKey = '_title';
const pushBodyKey = '_body';

/// Messages, app-wide while signed in (F81): the list, Home's dot and the
/// tab's dot read again when a thread changes live (each thread on the list
/// and the newest request, on their private `dm:` channels), when a direct
/// message push arrives, and when the app comes back to the front. A push
/// for a conversation that isn't on screen shows a quiet banner
/// ([DmBannerHost]); a tap opens it.
class DmLiveHost extends ConsumerStatefulWidget {
  const DmLiveHost({super.key, required this.child});

  final Widget child;

  /// Threads followed live at once, newest first.
  static const followMax = 30;

  @override
  ConsumerState<DmLiveHost> createState() => _DmLiveHostState();
}

class _DmLiveHostState extends ConsumerState<DmLiveHost> {
  final _subs = <String, StreamSubscription<String>>{};
  late final AppLifecycleListener _life;

  StreamSubscription<AuthState>? _authLog;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => _changed(null));
    // F100 diagnostic: when sign-in and the live socket change. Tests have
    // no Supabase client, so they skip it.
    final SupabaseClient client;
    try {
      client = ref.read(supabaseClientProvider);
    } on Object {
      return;
    }
    debugPrint(
      'BV-LIVE host start at=${DateTime.now().toIso8601String()} '
      'session=${client.auth.currentSession != null} '
      'gate=${ref.read(appGateProvider).name}',
    );
    _authLog = client.auth.onAuthStateChange.listen(
      (s) => debugPrint(
        'BV-LIVE auth ${s.event.name} at=${DateTime.now().toIso8601String()} '
        'session=${s.session != null}',
      ),
    );
    client.realtime
      ..onOpen(
        () => debugPrint(
          'BV-LIVE socket open at=${DateTime.now().toIso8601String()}',
        ),
      )
      ..onClose(
        (e) => debugPrint(
          'BV-LIVE socket close at=${DateTime.now().toIso8601String()} $e',
        ),
      )
      ..onError(
        (e) => debugPrint(
          'BV-LIVE socket error at=${DateTime.now().toIso8601String()} $e',
        ),
      );
  }

  @override
  void dispose() {
    unawaited(_authLog?.cancel());
    _life.dispose();
    for (final s in _subs.values) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  bool get _signedIn => ref.read(appGateProvider) == AppGate.ready;

  void _changed(String? threadId) {
    if (!mounted || !_signedIn) return;
    ref.invalidate(dmInboxProvider);
    ref.read(dmChangeProvider.notifier).add(threadId);
  }

  void _follow(DmInbox inbox) {
    final repo = ref.read(dmRepositoryProvider);
    final ids = [
      for (final t in inbox.threads.take(DmLiveHost.followMax)) t.threadId,
      ?inbox.newestRequest?.threadId,
    ];
    final fresh = ids.where((id) => !_subs.containsKey(id)).length;
    if (fresh > 0) {
      debugPrint(
        'BV-LIVE follow $fresh new of ${ids.length} '
        'at=${DateTime.now().toIso8601String()} '
        'gate=${ref.read(appGateProvider).name}',
      );
    }
    for (final id in ids) {
      _subs[id] ??= repo.changes(id).listen((_) => _changed(id));
    }
  }

  void _arrived(PushArrival? push) {
    final data = push?.data;
    if (data == null || !dmPushKinds.contains(data['kind'])) return;
    final id = data['dm_thread_id'];
    _changed(id);
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
    if (ref.watch(appGateProvider) == AppGate.ready) {
      // Each thread on the list is followed once; new ones as they come.
      final inbox = ref.watch(dmInboxProvider).value;
      if (inbox != null) _follow(inbox);
      ref.listen(pushArrivalProvider, (_, push) => _arrived(push));
    }
    return widget.child;
  }
}
