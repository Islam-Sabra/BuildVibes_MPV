import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone reaches the server, as the last try showed (OF,
/// review 87 Q1). The app has no other way to know: only a try that failed
/// for want of a signal says it is lost, and anything that gets through
/// says it is back. True while it reaches the server.
final signalProvider = NotifierProvider<SignalState, bool>(SignalState.new);

class SignalState extends Notifier<bool> {
  @override
  bool build() => true;

  /// A try failed for want of a signal.
  void lost() {
    if (state) state = false;
  }

  /// Something got through.
  void back() {
    if (!state) state = true;
  }
}
