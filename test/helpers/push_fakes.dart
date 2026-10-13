import 'dart:async';

import 'package:buildvibes/core/push/push_messaging.dart';
import 'package:buildvibes/data/repositories/push_repository.dart';

/// The phone's push side, in memory. Tests set the permission and the
/// answer to the prompt, and add taps.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.current = PushPermission.notAsked,
    this.answer = PushPermission.granted,
    this.phoneToken = 'fcm-test-token-0123456789',
    this.firstTap,
  });

  PushPermission current;

  /// What the person answers to the system prompt.
  PushPermission answer;
  String? phoneToken;
  Map<String, String>? firstTap;
  var asked = 0;
  var openedSettings = 0;
  final _taps = StreamController<Map<String, String>>.broadcast();
  final _foreground = StreamController<Map<String, String>>.broadcast();
  final _refresh = StreamController<String>.broadcast();

  void tap(Map<String, String> data) => _taps.add(data);
  void refreshToken(String token) => _refresh.add(token);

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    asked++;
    return current = answer;
  }

  @override
  Future<String?> token() async => phoneToken;

  @override
  Stream<String> get tokenRefresh => _refresh.stream;

  @override
  Future<Map<String, String>?> initialTap() async => firstTap;

  @override
  Stream<Map<String, String>> get taps => _taps.stream;

  @override
  Stream<Map<String, String>> get foreground => _foreground.stream;

  @override
  Future<void> openSettings() async => openedSettings++;

  @override
  String get platform => 'android';
}

class FakePushRepository implements PushRepository {
  final calls = <String>[];
  PushSettings saved = const PushSettings();

  @override
  Future<void> register(String token, String platform, String locale) async =>
      calls.add('register $token $platform $locale');

  @override
  Future<void> unregister(String token) async => calls.add('unregister $token');

  @override
  Future<PushSettings> settings() async => saved;

  @override
  Future<void> setSettings(PushSettings s) async {
    saved = s;
    calls.add('settings ${s.followers} ${s.replies} ${s.messageText}');
  }
}
