import 'package:buildvibes/core/haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const settings = MethodChannel('buildvibes/settings');

  late List<String> asked;
  late List<String> flutter;

  void phone(Object? Function(MethodCall call)? answer) {
    asked = [];
    flutter = [];
    messenger.setMockMethodCallHandler(
      settings,
      answer == null
          ? null
          : (call) async {
              asked.add('${call.method} ${call.arguments}');
              return answer(call);
            },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        flutter.add(call.arguments as String);
      }
      return null;
    });
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(settings, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('F67: every tick, check and sign-off through one place', () {
    test("the phone's own effect, when it plays it", () async {
      phone((_) => true);
      await bvHaptic(BvHaptic.tick);
      await bvHaptic(BvHaptic.strong);
      expect(asked, ['haptic tick', 'haptic strong']);
      expect(flutter, isEmpty);
    });

    test("the phone's touch feedback off: nothing at all", () async {
      phone((_) => false);
      await bvHaptic(BvHaptic.tick);
      await bvHaptic(BvHaptic.strong);
      expect(asked, hasLength(2));
      expect(flutter, isEmpty);
    });

    test(
      "no such effect on the phone: Flutter's medium or heavy impact",
      () async {
        phone((_) => null);
        await bvHaptic(BvHaptic.tick);
        await bvHaptic(BvHaptic.strong);
        expect(flutter, [
          'HapticFeedbackType.mediumImpact',
          'HapticFeedbackType.heavyImpact',
        ]);
      },
    );

    test('not Android: the same', () async {
      phone(null);
      await bvHaptic(BvHaptic.tick);
      expect(flutter, ['HapticFeedbackType.mediumImpact']);
    });

    test('a failed call still gives the impact', () async {
      phone((_) => throw PlatformException(code: 'x'));
      await bvHaptic(BvHaptic.strong);
      expect(flutter, ['HapticFeedbackType.heavyImpact']);
    });
  });
}
