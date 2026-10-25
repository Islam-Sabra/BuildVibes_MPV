import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/entry/entry_state.dart';
import '../design/bv_specs.dart';

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
class SplashHandover extends ConsumerStatefulWidget {
  const SplashHandover({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashHandover> createState() => _SplashHandoverState();
}

class _SplashHandoverState extends ConsumerState<SplashHandover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cover = AnimationController(
    vsync: this,
    duration: BvSplashSpec.fade,
    value: 1,
  )..addStatusListener((_) => setState(() {}));
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AppGate>(appGateProvider, (_, gate) {
      if (gate != AppGate.loading) _decide();
    }, fireImmediately: true);
  }

  void _decide() {
    if (_decided) return;
    _decided = true;
    ref.read(nativeSplashProvider).remove();
    _cover.reverse();
  }

  @override
  void dispose() {
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
              child: const ColoredBox(color: BvSplashSpec.colour),
            ),
          ),
      ],
    );
  }
}
