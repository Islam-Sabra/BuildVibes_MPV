import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_router.dart';
import '../../shared/widgets/bv_message_banner.dart';
import '../entry/entry_state.dart';
import 'dm_live.dart' show openDmThreadProvider;

/// The direct-message banner on screen now (F81, F99).
@immutable
class DmBanner {
  const DmBanner({
    required this.serial,
    required this.threadId,
    required this.title,
    required this.body,
    required this.route,
    this.messageId,
  });

  /// A new one for each conversation shown: it slides in once. The same
  /// conversation's next message keeps it, and only the words change.
  final int serial;
  final String threadId;
  final String? messageId;
  final String title;
  final String body;
  final String route;
}

final dmBannerProvider = NotifierProvider<DmBanners, DmBanner?>(DmBanners.new);

/// F99: the banner's life is kept here, not in a widget, so nothing that
/// builds the app's screens again (a Messages refresh, the shell, the
/// router) can take it away early. It stays [BvMessageBannerSpec.shown],
/// from its last message.
class DmBanners extends Notifier<DmBanner?> {
  Timer? _timer;
  var _serial = 0;

  /// The messages already shown (F100): the live update and the push for
  /// the same message show one banner, whichever comes first.
  final _seen = <String>[];
  static const _seenMax = 100;

  @override
  DmBanner? build() {
    ref.onDispose(() => _timer?.cancel());
    // Never over the conversation it is about; never once signed out.
    ref.listen(openDmThreadProvider, (_, id) {
      if (id != null && id == state?.threadId) hide();
    });
    ref.listen(appGateProvider, (_, gate) {
      if (gate != AppGate.ready) hide();
    });
    return null;
  }

  /// A message of [threadId]. The same message again (a second push, or
  /// its push after its live update) changes nothing, even after its
  /// banner went; a newer one of the same conversation changes the
  /// words and starts the time again; another conversation replaces it.
  void show({
    required String threadId,
    required String title,
    required String body,
    required String route,
    String? messageId,
  }) {
    final now = state;
    if (messageId != null) {
      if (_seen.contains(messageId)) return;
      _seen.add(messageId);
      if (_seen.length > _seenMax) _seen.removeAt(0);
    }
    state = DmBanner(
      serial: now != null && now.threadId == threadId ? now.serial : ++_serial,
      threadId: threadId,
      messageId: messageId,
      title: title,
      body: body,
      route: route,
    );
    _timer?.cancel();
    _timer = Timer(BvMessageBannerSpec.shown, hide);
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (state != null) state = null;
  }
}

/// Holds the banner above every screen of the app (under MaterialApp, over
/// the router): it slides down, slides back up when it goes, opens its
/// conversation on a tap, and goes at once when swiped up. No sound.
class DmBannerHost extends ConsumerStatefulWidget {
  const DmBannerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DmBannerHost> createState() => _DmBannerHostState();
}

class _DmBannerHostState extends ConsumerState<DmBannerHost>
    with SingleTickerProviderStateMixin {
  late final _slide = AnimationController(
    vsync: this,
    duration: BvMessageBannerSpec.slide,
  );
  late final _position =
      Tween(begin: BvMessageBannerSpec.from, end: Offset.zero).animate(
        CurvedAnimation(
          parent: _slide,
          curve: BvMotion.enter,
          reverseCurve: BvMotion.exit,
        ),
      );

  /// What shows: the banner, or the one sliding away.
  DmBanner? _shown;

  @override
  void initState() {
    super.initState();
    // Built again while one shows: it is there at once.
    _shown = ref.read(dmBannerProvider);
    _slide.value = _shown == null ? 0 : 1;
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _changed(DmBanner? was, DmBanner? now) {
    if (now == null) {
      if (_shown == null) return;
      unawaited(
        _slide.reverse().then((_) {
          if (mounted && ref.read(dmBannerProvider) == null) {
            setState(() => _shown = null);
          }
        }),
      );
      return;
    }
    final again = _shown != null && _shown!.serial == now.serial;
    setState(() => _shown = now);
    if (!again) unawaited(_slide.forward(from: 0));
  }

  void _swiped() {
    _slide.value = 0;
    setState(() => _shown = null);
    ref.read(dmBannerProvider.notifier).hide();
  }

  void _open(DmBanner banner) {
    ref.read(dmBannerProvider.notifier).hide();
    ref.read(appRouterProvider).push(banner.route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DmBanner?>(dmBannerProvider, _changed);
    final banner = _shown;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (banner != null)
          PositionedDirectional(
            start: BvMessageBannerSpec.margin,
            end: BvMessageBannerSpec.margin,
            top: MediaQuery.paddingOf(context).top + BvMessageBannerSpec.margin,
            child: SlideTransition(
              key: const Key('dm-banner-slide'),
              position: _position,
              child: Dismissible(
                key: ValueKey('dm-banner-${banner.serial}'),
                direction: DismissDirection.up,
                onDismissed: (_) => _swiped(),
                child: BvMessageBanner(
                  title: banner.title,
                  body: banner.body,
                  onTap: () => _open(banner),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
