// Review 115, small items: the chat outbox. A message that couldn't go
// (a file refused, no signal, or one left from an earlier start, like the
// 9.1 MB PDF that never went before build 1015) shows "Couldn't send · Tap
// to fix" in its Chat; Tap to fix says why, and Try again sends it or
// Remove takes it off the phone with its kept file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/library.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/upload_rules.dart';
import 'package:buildvibes/features/chat/chat_state.dart';
import 'package:buildvibes/features/work/could_not_send.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

const _space = 'space-1';
const _everyone = 'thread-everyone';
const _me = 'user-1';

Finder _key(String k) => find.byKey(Key(k));

Finder _startsWith(String prefix) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix),
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

FakeSpaceRepository _spaces() => FakeSpaceRepository(now: testNow)
  ..details[_space] = const SpaceDetail(
    id: _space,
    name: 'Site team',
    myPass: SpacePass.lead,
    iAmAdmin: true,
    myRights: MemberRights(createItems: true, addFiles: true),
  )
  ..spacePeople[_space] = SpacePeople(
    members: [
      SpaceMember(
        person: const SpacePerson(
          id: _me,
          firstName: 'Omar',
          lastName: 'Haddad',
        ),
        pass: SpacePass.lead,
        isAdmin: true,
        confirmedAt: testNow,
      ),
    ],
  );

FakeChatRepository _chat() => FakeChatRepository(now: testNow)
  ..threadsBySpace[_space] = const [ChatThread(id: _everyone)]
  ..messagesByThread[_everyone] = [];

Future<TestApp> _open(
  WidgetTester tester,
  String lang, {
  required FakeChatRepository chat,
  Map<String, Object> stored = const {},
}) async {
  final app = await pumpApp(
    tester,
    language: lang,
    spaces: _spaces(),
    chat: chat,
    stored: stored,
  );
  unawaited(_router(tester).push('/spaces/$_space/chat/$_everyone'));
  await tester.pumpAndSettle();
  return app;
}

/// The kept copies' places on the phone, from the outbox as stored.
List<String> _kept(TestApp app) => [
  for (final m
      in jsonDecode(app.prefs.getString('chat_outbox') ?? '[]') as List)
    for (final f in (m as Map)['files'] as List) (f as Map)['local'] as String,
];

/// A PDF kept on the phone, as the thread's picker leaves it.
String _keptPdf() {
  final dir = Directory.systemTemp.createTempSync('bv_outbox');
  return File(testPdfPath).copySync('${dir.path}/kept.pdf').path;
}

/// A message with a PDF, kept from an earlier start of the app.
PendingMessage _left({bool failed = false}) => PendingMessage(
  id: 'pending-1',
  threadId: _everyone,
  spaceId: _space,
  body: 'Rev C',
  createdAt: testNow,
  failed: failed,
  files: [
    PendingFile(
      file: PhoneFile(
        local: _keptPdf(),
        name: 'Level 3 plan.pdf',
        mime: 'application/pdf',
        bytes: 9100000,
      ),
    ),
  ],
);

Map<String, Object> _stored(PendingMessage m) => {
  'chat_outbox': jsonEncode([m.toJson()]),
};

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('no signal: Couldn\'t send · Tap to fix; the sheet, then '
        'Try again sends it with its file [$lang]', (tester) async {
      final chat = _chat()..failUploadNext = 3;
      final app = await _open(tester, lang, chat: chat);
      await _tap(tester, _key('chat-attach'));
      await _tap(tester, _key('chat-attach-pdf'));
      await _tap(tester, _key('chat-send'));
      expect(find.text(l10n.chatCouldNotSend), findsOneWidget);
      expect(find.text(l10n.chatSending), findsNothing);
      expect(chat.uploads, isEmpty);
      final kept = _kept(app).single;

      await _tap(tester, _startsWith('chat-fix-'));
      expect(_key('could-not-send-fix'), findsOneWidget);
      expect(find.text(l10n.chatCouldNotSendWhy), findsOneWidget);
      await _tap(tester, _key('could-not-send-try-again'));
      expect(chat.calls, contains('post $_everyone  files application/pdf'));
      expect(find.text(l10n.chatCouldNotSend), findsNothing);
      expect(app.prefs.getString('chat_outbox'), '[]');
      expect(File(kept).existsSync(), isFalse);
    });

    testWidgets('a file refused: the sheet says why; Remove takes the '
        'message off and deletes the kept file [$lang]', (tester) async {
      const refused = FileRefused(UploadProblem.tooBig, bytes: 39000000);
      final chat = _chat()..refuseUploadNext = refused;
      final app = await _open(tester, lang, chat: chat);
      await _tap(tester, _key('chat-attach'));
      await _tap(tester, _key('chat-attach-pdf'));
      await _tap(tester, _key('chat-send'));
      final kept = _kept(app).single;
      expect(File(kept).existsSync(), isTrue);
      expect(find.text(l10n.chatCouldNotSend), findsOneWidget);

      await _tap(tester, _startsWith('chat-fix-'));
      expect(find.text(fileRefusedText(l10n, refused)), findsOneWidget);
      await _tap(tester, _key('could-not-send-remove'));
      expect(find.text(l10n.chatCouldNotSend), findsNothing);
      expect(_startsWith('chat-fix-'), findsNothing);
      expect(app.prefs.getString('chat_outbox'), '[]');
      expect(File(kept).existsSync(), isFalse);
      expect(chat.calls.where((c) => c.startsWith('post')), isEmpty);
    });

    testWidgets('one left waiting from an earlier start (the app closed '
        'while it went) shows, with Tap to fix, never "Sending…" for ever; '
        'Try again sends it [$lang]', (tester) async {
      final m = _left();
      final chat = _chat();
      final app = await _open(tester, lang, chat: chat, stored: _stored(m));
      expect(find.text('Rev C'), findsOneWidget);
      expect(find.text(l10n.chatSending), findsNothing);
      expect(_key('chat-fix-${m.id}'), findsOneWidget);
      await _tap(tester, _key('chat-fix-${m.id}'));
      await _tap(tester, _key('could-not-send-try-again'));
      expect(
        chat.calls,
        contains('post $_everyone Rev C files application/pdf'),
      );
      expect(chat.posted.single.single.name, 'Level 3 plan.pdf');
      expect(app.prefs.getString('chat_outbox'), '[]');
      expect(File(m.files.single.file.local).existsSync(), isFalse);
    });

    testWidgets('one that failed before (stored as failed) can be removed '
        '[$lang]', (tester) async {
      final m = _left(failed: true);
      final chat = _chat();
      final app = await _open(tester, lang, chat: chat, stored: _stored(m));
      expect(find.text(l10n.chatCouldNotSend), findsOneWidget);
      await _tap(tester, _key('chat-fix-${m.id}'));
      await _tap(tester, _key('could-not-send-remove'));
      expect(find.text('Rev C'), findsNothing);
      expect(app.prefs.getString('chat_outbox'), '[]');
      expect(File(m.files.single.file.local).existsSync(), isFalse);
      expect(chat.calls.where((c) => c.startsWith('post')), isEmpty);
    });

    testWidgets('its kept file gone from the phone: the sheet says so, and '
        'nothing is sent [$lang]', (tester) async {
      final m = _left();
      File(m.files.single.file.local).deleteSync();
      final chat = _chat();
      await _open(tester, lang, chat: chat, stored: _stored(m));
      await _tap(tester, _key('chat-fix-${m.id}'));
      await _tap(tester, _key('could-not-send-try-again'));
      expect(chat.uploads, isEmpty);
      expect(find.text(l10n.chatCouldNotSend), findsOneWidget);
      await _tap(tester, _key('chat-fix-${m.id}'));
      expect(
        find.text(fileRefusedText(l10n, const FileRefused(UploadProblem.gone))),
        findsOneWidget,
      );
    });
  }
}
