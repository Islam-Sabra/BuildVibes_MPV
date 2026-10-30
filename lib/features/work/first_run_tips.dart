import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/first_run_tip.dart';
import '../../data/repositories/tips_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_tip.dart';
import '../entry/entry_state.dart';

/// The first-run tips the signed-in account has seen (review 107 OB7),
/// from the server; empty while signed out.
final tipsSeenProvider = FutureProvider<Set<FirstRunTip>>((ref) async {
  final me = ref.watch(authUserIdProvider).value;
  if (me == null) return const {};
  return ref.watch(tipsRepositoryProvider).seen();
});

/// The first time Work opens (OB7): three short tips, one at a time, each
/// with a spotlight on the real control ([BvTipAnchor]s under [child] with
/// a [FirstRunTip] as id): the camera, a card to hold, and Sign as done the
/// first time an item is given to me. A tip whose control isn't on screen
/// waits. Next keeps it as seen and moves on; Skip tips keeps all three.
/// Kept per account on the server, so each shows once on every phone.
class FirstRunTips extends ConsumerStatefulWidget {
  const FirstRunTips({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FirstRunTips> createState() => _FirstRunTipsState();
}

class _FirstRunTipsState extends ConsumerState<FirstRunTips> {
  final _anchors = BvTipAnchors();
  final _portal = OverlayPortalController();

  /// Seen on this phone since the server's list was read.
  final _seenHere = <FirstRunTip>{};
  FirstRunTip? _tip;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    _anchors.addListener(_place);
  }

  @override
  void dispose() {
    _anchors
      ..removeListener(_place)
      ..dispose();
    super.dispose();
  }

  /// The first tip not seen whose control is on screen, and where it is.
  void _place() {
    if (!mounted) return;
    final seen = ref.read(tipsSeenProvider).value;
    final screen = MediaQuery.sizeOf(context);
    FirstRunTip? tip;
    Rect? target;
    if (seen != null) {
      for (final t in FirstRunTip.values) {
        if (seen.contains(t) || _seenHere.contains(t)) continue;
        final rect = _anchors.rectOf(t, screen);
        if (rect == null) continue;
        tip = t;
        target = rect;
        break;
      }
    }
    if (tip == _tip && target == _target) return;
    setState(() {
      _tip = tip;
      _target = target;
    });
    tip == null ? _portal.hide() : _portal.show();
  }

  void _seen(Iterable<FirstRunTip> tips) {
    final repo = ref.read(tipsRepositoryProvider);
    for (final t in tips) {
      if (!_seenHere.add(t)) continue;
      // A tip missed on the server shows again another time: nothing else
      // depends on it.
      unawaited(repo.markSeen(t).catchError((Object _) {}));
    }
    _place();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Once the server's list is in, look for the first tip.
    ref.listen(
      tipsSeenProvider,
      (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) => _place()),
    );
    return BvTipAnchorScope(
      anchors: _anchors,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          final tip = _tip;
          final target = _target;
          if (tip == null || target == null) return const SizedBox.shrink();
          return BvTipLayer(
            target: target,
            count: l10n.obTipOf(tip.index + 1, FirstRunTip.values.length),
            text: switch (tip) {
              FirstRunTip.camera => l10n.obTipCamera,
              FirstRunTip.hold => l10n.obTipHold,
              FirstRunTip.signDone => l10n.obTipSignDone,
            },
            skipLabel: l10n.obTipSkip,
            nextLabel: l10n.obTipNext,
            onSkip: () => _seen(FirstRunTip.values),
            onNext: () => _seen([tip]),
          );
        },
        child: widget.child,
      ),
    );
  }
}
