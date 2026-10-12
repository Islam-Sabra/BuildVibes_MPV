import 'dart:async';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/chat/voice.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';
import '../../helpers/voice_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

const _space = 'space-1';
const _everyone = 'thread-everyone';

FakeSpaceRepository _spaces({bool addFiles = true}) =>
    FakeSpaceRepository(now: testNow)
      ..details[_space] = SpaceDetail(
        id: _space,
        name: 'Site team',
        myPass: addFiles ? SpacePass.crew : SpacePass.viewer,
        iAmAdmin: false,
        myRights: MemberRights(addFiles: addFiles),
      );

FakeChatRepository _chat() => FakeChatRepository(now: testNow)
  ..threadsBySpace[_space] = const [ChatThread(id: _everyone)]
  ..messagesByThread[_everyone] = [];

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  bool addFiles = true,
  FakeChatRepository? chat,
  FakeLibraryRepository? library,
  FakeVoiceRecorder? recorder,
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: _spaces(addFiles: addFiles),
    chat: chat ?? _chat(),
    library: library,
    recorder: recorder,
  );
  _router(tester).push('/spaces/$_space/chat/$_everyone');
  await tester.pumpAndSettle();
  return app;
}

/// Holds the mic for [hold], sliding by [slide] before letting go.
Future<void> _record(
  WidgetTester tester,
  Duration hold, {
  Offset slide = Offset.zero,
}) async {
  final mic = tester.getCenter(find.byKey(const Key('chat-record')));
  final gesture = await tester.startGesture(mic);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pump(hold);
  if (slide != Offset.zero) {
    await gesture.moveBy(slide);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);

    testWidgets('the mic: empty box only, never for a Viewer [$lang]', (
      tester,
    ) async {
      await _open(tester, lang);
      expect(find.byKey(const Key('chat-record')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('chat-input')), 'Hi');
      await tester.pumpAndSettle();
      // Text to send: the send arrow instead.
      expect(find.byKey(const Key('chat-record')), findsNothing);
      expect(find.byKey(const Key('chat-send')), findsOneWidget);
    });

    testWidgets('a Viewer has no mic [$lang]', (tester) async {
      await _open(tester, lang, addFiles: false);
      expect(find.byKey(const Key('chat-record')), findsNothing);
    });

    testWidgets('hold, release: a voice note with its length [$lang]', (
      tester,
    ) async {
      final chat = _chat();
      final app = await _open(tester, lang, chat: chat);
      final mic = tester.getCenter(find.byKey(const Key('chat-record')));
      final gesture = await tester.startGesture(mic);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('chat-recording')), findsOneWidget);
      expect(find.text(l10n.chatSlideToCancel), findsOneWidget);
      expect(find.text('0:03'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(app.recorder.calls, ['start', 'stop']);
      expect(chat.uploads.single, endsWith('.m4a'));
      expect(chat.calls, contains('post $_everyone  files audio/mp4'));
      expect(chat.posted.single.single.durationMs, 3000);
      expect(find.byKey(const Key('chat-recording')), findsNothing);
    });

    testWidgets('a slip of the thumb is not sent [$lang]', (tester) async {
      final chat = _chat();
      await _open(tester, lang, chat: chat);
      await _record(tester, const Duration(milliseconds: 300));
      expect(find.text(l10n.chatVoiceTooShort), findsOneWidget);
      expect(chat.posted, isEmpty);
    });

    testWidgets('slide away to cancel [$lang]', (tester) async {
      final chat = _chat();
      final app = await _open(tester, lang, chat: chat);
      final mic = tester.getCenter(find.byKey(const Key('chat-record')));
      final gesture = await tester.startGesture(mic);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 2));
      await gesture.moveBy(const Offset(0, -150));
      await tester.pump();
      expect(find.text(l10n.chatReleaseToCancel), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(app.recorder.calls, ['start', 'cancel']);
      expect(chat.posted, isEmpty);
    });

    testWidgets('no microphone, no recording; it says why [$lang]', (
      tester,
    ) async {
      final recorder = FakeVoiceRecorder()..allowedValue = false;
      await _open(tester, lang, recorder: recorder);
      await _record(tester, const Duration(seconds: 2));
      expect(find.text(l10n.chatMicDenied), findsOneWidget);
      expect(recorder.calls, isEmpty);
    });

    testWidgets('it sends itself at two minutes [$lang]', (tester) async {
      final chat = _chat();
      await _open(tester, lang, chat: chat);
      final mic = tester.getCenter(find.byKey(const Key('chat-record')));
      final gesture = await tester.startGesture(mic);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump(maxVoice + const Duration(seconds: 5));
      await tester.pump();
      expect(chat.posted.single.single.durationMs, maxVoice.inMilliseconds);
      await gesture.up();
      await tester.pumpAndSettle();
      // Letting go after that sends nothing more.
      expect(chat.posted, hasLength(1));
    });

    testWidgets('the first hold only asks for the microphone [$lang]', (
      tester,
    ) async {
      // The phone's dialog takes a moment; the thumb is gone before the
      // answer. Nothing may record then.
      final recorder = FakeVoiceRecorder()..askFirst = Completer<bool>();
      final chat = _chat();
      await _open(tester, lang, chat: chat, recorder: recorder);
      final mic = tester.getCenter(find.byKey(const Key('chat-record')));
      final gesture = await tester.startGesture(mic);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();
      recorder.askFirst!.complete(true);
      await tester.pumpAndSettle();
      expect(recorder.calls, isEmpty);
      expect(find.byKey(const Key('chat-recording')), findsNothing);
      expect(chat.posted, isEmpty);
    });

    testWidgets('a tap says how [$lang]', (tester) async {
      await _open(tester, lang);
      await tester.tap(find.byKey(const Key('chat-record')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.chatRecord), findsOneWidget);
    });

    testWidgets('a voice note plays in its bubble [$lang]', (tester) async {
      final chat = _chat()
        ..messagesByThread[_everyone] = [
          ChatMessage(
            id: 'v1',
            threadId: _everyone,
            kind: ChatKind.voice,
            createdAt: testNow,
            authorId: 'p-rakesh',
            authorName: 'Rakesh Nair',
            attachments: const [
              ChatAttachment(
                path: '$_space/chat/v1/a.m4a',
                mime: 'audio/mp4',
                durationMs: 42000,
              ),
            ],
          ),
        ];
      final library = FakeLibraryRepository(now: testNow)..offline = false;
      final app = await _open(tester, lang, chat: chat, library: library);
      expect(find.byKey(const Key('chat-voice-v1')), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-voice-play-v1')));
      await tester.pumpAndSettle();
      expect(
        app.playback.played.single,
        'url https://files.test/$_space/chat/v1/a.m4a',
      );
      expect(find.byTooltip(l10n.chatPause), findsOneWidget);
      app.playback.moveTo(const Duration(seconds: 10));
      // The position arrives, then the next frame shows it.
      await tester.pump();
      await tester.pump();
      expect(find.text('0:10'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-voice-play-v1')));
      await tester.pumpAndSettle();
      expect(app.playback.calls, ['pause']);
    });
  }

  test('voice times read m:ss with Western digits', () {
    expect(voiceTime(const Duration(seconds: 42)), '0:42');
    expect(voiceTime(const Duration(minutes: 1, seconds: 58)), '1:58');
    expect(voiceTime(maxVoice), '2:00');
  });
}
