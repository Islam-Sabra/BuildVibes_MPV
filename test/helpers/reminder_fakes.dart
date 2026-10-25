import 'package:buildvibes/core/push/reminders.dart';

/// The phone's reminders (slice 10), kept here instead.
class FakePhoneReminders implements PhoneReminders {
  /// Note id → when, and what it says.
  final onPhone = <String, ({DateTime at, String title, String body})>{};
  final calls = <String>[];
  void Function(String noteId)? _onTap;
  String? launched;

  /// The person taps [noteId]'s reminder while the app runs.
  void tap(String noteId) => _onTap?.call(noteId);

  @override
  Future<void> init({
    required String channel,
    required String channelAbout,
    required void Function(String noteId) onTap,
  }) async {
    _onTap = onTap;
    calls.add('init $channel');
  }

  @override
  Future<String?> launchedBy() async => launched;

  @override
  Future<void> set(
    String noteId, {
    required DateTime at,
    required String title,
    required String body,
  }) async {
    onPhone[noteId] = (at: at, title: title, body: body);
    calls.add('set $noteId');
  }

  @override
  Future<void> cancel(String noteId) async {
    onPhone.remove(noteId);
    calls.add('cancel $noteId');
  }

  /// Whether the phone allows exact alarms (Android 12+ asks the person).
  bool exact = true;

  @override
  Future<bool> canBeExact() async => exact;

  @override
  Future<void> openExactSetting() async => calls.add('exact setting');
}
