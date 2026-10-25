import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/entry/entry_state.dart';
import '../design/bv_specs.dart';
import 'splash_cube.dart';

/// The native splash, behind a seam so tests can count [remove].
abstract interface class NativeSplash {
  /// Lets the app's first frame show; the native splash goes.
  void remove();
}

class _PackageNativeSplash implements NativeSplash {
  const _PackageNativeSplash();

  @override
  void remove() => FlutterNativeSplash.remove();
}

final nativeSplashProvider = Provider<NativeSplash>(
  (ref) => const _PackageNativeSplash(),
);

/// Review 91: main() keeps the native splash up while start-up runs. When
/// the gate knows where the app goes (anything but [AppGate.loading]), the
/// splash goes and the first screen fades in from the splash colour.
///
/// Addendum: still loading after [BvSplashSpec.traceAfter], the native
/// splash goes and the cube traces itself on the same terracotta, in the
/// same place. Decided mid-trace, the rest plays in [BvSplashSpec.finishIn];
/// either way the fade starts at most [BvSplashSpec.loaderMax] after the
/// native splash went. Reduce motion: no trace, only the fade.
class SplashHandover extends ConsumerStatefulWidget {
  const SplashHandover({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashHandover> createState() => _SplashHandoverState();
}

class _SplashHandoverState extends ConsumerState<SplashHandover>
    with TickerProviderStateMixin {
  late final AnimationController _cover = AnimationController(
    vsync: this,
    duration: BvSplashSpec.fade,
    value: 1,
    // A fade is not motion: with Reduce motion it keeps its 350 ms.
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener((_) => setState(() {}));

  /// The cube, 0 to 1 over [BvSplashSpec.loader]. At 1 (the start) it is
  /// the native splash's cube, for a seamless fade.
  late final AnimationController _loader = AnimationController(
    vsync: this,
    duration: BvSplashSpec.loader,
    value: 1,
  )..addStatusListener(_loaderStatus);

  bool _decided = false;
  bool _removed = false;
  bool _tracing = false;
  bool _fading = false;
  bool _timed = false;
  Timer? _traceTimer;
  Timer? _capTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AppGate>(appGateProvider, (_, gate) {
      if (gate != AppGate.loading) _decide();
    }, fireImmediately: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timed) return;
    _timed = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_decided && !reduceMotion) {
      _traceTimer = Timer(BvSplashSpec.traceAfter, _startTrace);
    }
  }

  void _removeNative() {
    if (_removed) return;
    _removed = true;
    ref.read(nativeSplashProvider).remove();
  }

  void _startTrace() {
    if (!mounted || _decided) return;
    _tracing = true;
    _removeNative();
    _capTimer = Timer(BvSplashSpec.loaderMax, _fade);
    _loader.forward(from: 0);
  }

  void _loaderStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _decided) _fade();
  }

  void _decide() {
    if (_decided) return;
    _decided = true;
    _traceTimer?.cancel();
    if (!_tracing) {
      _removeNative();
      _fade();
    } else if (_loader.isCompleted) {
      _fade();
    } else {
      _loader.animateTo(1, duration: BvSplashSpec.finishIn);
    }
  }

  void _fade() {
    if (!mounted || _fading) return;
    _fading = true;
    _capTimer?.cancel();
    _loader.stop();
    _cover.reverse();
  }

  @override
  void dispose() {
    _traceTimer?.cancel();
    _capTimer?.cancel();
    _loader.dispose();
    _cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_cover.isDismissed)
          IgnorePointer(
            child: FadeTransition(
              key: const Key('splash-cover'),
              opacity: _cover,
              child: ColoredBox(
                color: BvSplashSpec.colour,
                child: CustomPaint(
                  key: const Key('splash-cube'),
                  painter: SplashCubePainter(_loader),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
