// F5 (review 50): the soft "sent" sound with a light haptic; on silent or
// vibrate, the haptic only.
import 'package:buildvibes/core/sound/sent_chime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SentChime chime(List<String> heard, {required bool ringer}) => SentChime(
    soundOn: () async => ringer,
    playSound: () async => heard.add('sound'),
    haptic: () async => heard.add('haptic'),
  );

  test('the ringer on: the haptic and the sound', () async {
    final heard = <String>[];
    await chime(heard, ringer: true).play();
    expect(heard, ['haptic', 'sound']);
  });

  test('silent or vibrate: the haptic only', () async {
    final heard = <String>[];
    await chime(heard, ringer: false).play();
    expect(heard, ['haptic']);
  });

  test('a ringer or speaker that fails is never an error', () async {
    final heard = <String>[];
    await SentChime(
      soundOn: () async => throw MissingPluginException(),
      playSound: () async => heard.add('sound'),
      haptic: () async => throw PlatformException(code: 'no'),
    ).play();
    expect(heard, isEmpty);
  });

  test('Android asks AudioManager for the ringer mode', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('buildvibes/sound');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final asked = <String>[];
    var normal = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      asked.add(call.method);
      return normal;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(await phoneRingerAllowsSound(), isTrue);
    normal = false;
    expect(await phoneRingerAllowsSound(), isFalse);
    expect(asked, ['ringerNormal', 'ringerNormal']);
  });
}
