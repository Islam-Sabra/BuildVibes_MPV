import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the phone whether it shows 24-hour times; null when it can't say
/// (not Android, or no answer). A provider so tests can stand in.
typedef ReadPhoneClock = Future<bool?> Function();

final readPhoneClockProvider = Provider<ReadPhoneClock>(
  (ref) => () async {
    const channel = MethodChannel('buildvibes/settings');
    try {
      return await channel.invokeMethod<bool>('is24Hour');
    } on PlatformException catch (e) {
      debugPrint('24-hour setting: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  },
);

/// The phone's 24-hour setting as last read; null: as Flutter reports it.
final phoneClockProvider = NotifierProvider<PhoneClock, bool?>(PhoneClock.new);

class PhoneClock extends Notifier<bool?> {
  @override
  bool? build() => null;

  /// Reads the setting again.
  Future<void> read() async {
    final value = await ref.read(readPhoneClockProvider)();
    if (ref.mounted && value != null) state = value;
  }
}

/// Review 50 F37: times follow a change to the phone's 24-hour setting
/// without a restart. Every time is written from
/// `MediaQuery.alwaysUse24HourFormat` as it is built (BvTime); Android
/// passes a change to Flutter only after a restart, so the setting is read
/// again when the app opens and each time it comes back to the front, and
/// put in the MediaQuery under [child].
class PhoneClockScope extends ConsumerStatefulWidget {
  const PhoneClockScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PhoneClockScope> createState() => _PhoneClockScopeState();
}

class _PhoneClockScopeState extends ConsumerState<PhoneClockScope> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _read);
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  void _read() {
    if (mounted) ref.read(phoneClockProvider.notifier).read();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final use24 = ref.watch(phoneClockProvider);
    if (use24 == null) return widget.child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24),
      child: widget.child,
    );
  }
}
