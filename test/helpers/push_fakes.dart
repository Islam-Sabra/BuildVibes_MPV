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
    this.tokenFailures = 0,
    this.makers = const ['google', 'google'],
  });

  PushPermission current;

  /// What the person answers to the system prompt.
  PushPermission answer;
  String? phoneToken;
  Map<String, String>? firstTap;
  var asked = 0;
  var openedSettings = 0;
  var openedAppSettings = 0;

  /// The next token asks fail as Firebase does on some Xiaomi phones
  /// ("FCM Registration failed!").
  int tokenFailures;
  var tokenAsks = 0;
  var noTokenReports = 0;
  List<String> makers;
  final _taps = StreamController<Map<String, String>>.broadcast();
  final _foreground = StreamController<Map<String, String>>.broadcast();
  final _refresh = StreamController<String>.broadcast();

  void tap(Map<String, String> data) => _taps.add(data);
  void arrive(Map<String, String> data) => _foreground.add(data);
  void refreshToken(String token) => _refresh.add(token);

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    asked++;
    return current = answer;
  }

  @override
  Future<String?> token() async {
    tokenAsks++;
    if (tokenFailures > 0) {
      tokenFailures--;
      throw Exception('FCM Registration failed!');
    }
    return phoneToken;
  }

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
  Future<void> openAppSettings() async => openedAppSettings++;

  @override
  Future<List<String>> phoneMakers() async => makers;

  @override
  void reportNoToken() => noTokenReports++;

  @override
  String get platform => 'android';
}

class FakePushRepository implements PushRepository {
  final calls = <String>[];
  PushSettings saved = const PushSettings();

  /// The next register fails for want of a signal.
  var failNext = false;

  @override
  Future<void> register(
    String token,
    String platform,
    String locale, {
    String? installId,
  }) async {
    if (failNext) {
      failNext = false;
      throw Exception('SocketException: no signal');
    }
    calls.add('register $token $platform $locale');
    installIds.add(installId);
  }

  /// The install id each register sent (F81).
  final installIds = <String?>[];

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
