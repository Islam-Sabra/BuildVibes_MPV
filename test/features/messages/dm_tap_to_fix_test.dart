// The lead's check of review 115: a direct message that didn't go shows
// the same "Couldn't send · Tap to fix" line and sheet as Space chat (was
// "Not sent · Retry"): why, then Try again or Remove (with its kept file).
import 'dart:io';

import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/upload_rules.dart';
import 'package:buildvibes/features/work/could_not_send.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 10, 15, 11);

DmThreadPage _omar() => DmThreadPage(
  threadId: 't-omar',
  person: const DmPerson(id: 'p-omar', name: 'Omar Haddad'),
  messages: [
    DmMessage(
      id: 'm1',
      fromMe: false,
      kind: ChatKind.text,
      createdAt: DateTime(2026, 10, 15, 10, 40),
      body: 'At the gate at 7?',
    ),
  ],
);

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

Future<void> _open(
  WidgetTester tester,
  String lang,
  FakeDmRepository dm,
) async {
  await pumpApp(tester, language: lang, dm: dm, now: _now);
  GoRouter.of(
    tester.element(find.byType(Scaffold).first),
  ).push('/messages/t-omar');
  await tester.pumpAndSettle();
}

/// Picks the test PDF (kept on the phone) and sends it.
Future<void> _sendPdf(WidgetTester tester, AppLocalizations l10n) async {
  await _tap(tester, _key('chat-attach'));
  await _tap(tester, find.text(l10n.chatAttachPdf));
  await _tap(tester, _key('chat-send'));
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(lang));

    testWidgets('no signal: Couldn\'t send · Tap to fix (never "Not sent · '
        'Retry"); the sheet, then Try again sends it [$lang]', (tester) async {
      final dm = FakeDmRepository()
        ..pages['t-omar'] = _omar()
        ..failUploadNext = 1;
      await _open(tester, lang, dm);
      await _sendPdf(tester, l10n);
      expect(find.text(l10n.chatCouldNotSend), findsOneWidget);
      expect(
        find.textContaining(lang == 'en' ? 'Not sent' : 'لم تُرسل'),
        findsNothing,
      );
      expect(find.text(l10n.chatSending), findsNothing);
      expect(dm.calls.where((c) => c.startsWith('send')), isEmpty);
      final kept = dm.uploadTried.single;

      await _tap(tester, _startsWith('dm-fix-'));
      expect(_key('could-not-send-fix'), findsOneWidget);
      expect(find.text(l10n.chatCouldNotSendWhy), findsOneWidget);
      await _tap(tester, _key('could-not-send-try-again'));
      expect(dm.calls, contains('send t-omar null files 1'));
      expect(find.text(l10n.chatCouldNotSend), findsNothing);
      // Sent: its kept copy goes from the phone.
      expect(File(kept).existsSync(), isFalse);
    });

    // Review 103: Scan a document on the attach sheet.
    testWidgets('Scan a document sends one PDF [$lang]', (tester) async {
      final dm = FakeDmRepository()..pages['t-omar'] = _omar();
      await _open(tester, lang, dm);
      await _tap(tester, _key('chat-attach'));
      await _tap(tester, find.text(l10n.scanADocument));
      await _tap(tester, _key('scan-add'));
      await _tap(tester, _key('chat-send'));
      expect(dm.calls, contains('send t-omar null files 1'));
      expect(dm.uploadTried.single, endsWith('.pdf'));
    });

    testWidgets('a file refused: the sheet says why; Remove takes the '
        'message off and deletes its kept file [$lang]', (tester) async {
      const refused = FileRefused(UploadProblem.tooBig, bytes: 39000000);
      final dm = FakeDmRepository()
        ..pages['t-omar'] = _omar()
        ..refuseUploadNext = refused;
      await _open(tester, lang, dm);
      await _sendPdf(tester, l10n);
      final kept = dm.uploadTried.single;
      expect(File(kept).existsSync(), isTrue);
      expect(find.text(l10n.chatCouldNotSend), findsOneWidget);
      // The line says it; no toast on top.
      expect(find.byType(SnackBar), findsNothing);

      await _tap(tester, _startsWith('dm-fix-'));
      expect(find.text(fileRefusedText(l10n, refused)), findsOneWidget);
      await _tap(tester, _key('could-not-send-remove'));
      expect(find.text(l10n.chatCouldNotSend), findsNothing);
      expect(_startsWith('dm-fix-'), findsNothing);
      expect(File(kept).existsSync(), isFalse);
      expect(dm.calls.where((c) => c.startsWith('send')), isEmpty);
    });

    testWidgets('its kept file gone from the phone: the sheet says so, '
        'with no Try again, and nothing is sent [$lang]', (tester) async {
      final dm = FakeDmRepository()
        ..pages['t-omar'] = _omar()
        ..failUploadNext = 1;
      await _open(tester, lang, dm);
      await _sendPdf(tester, l10n);
      File(dm.uploadTried.single).deleteSync();

      await _tap(tester, _startsWith('dm-fix-'));
      await _tap(tester, _key('could-not-send-try-again'));
      expect(dm.uploadTried, hasLength(1), reason: 'nothing to upload');
      expect(find.text(l10n.chatCouldNotSend), findsOneWidget);
      await _tap(tester, _startsWith('dm-fix-'));
      expect(
        find.text(fileRefusedText(l10n, const FileRefused(UploadProblem.gone))),
        findsOneWidget,
      );
      expect(
        tester.widget<BvButton>(_key('could-not-send-try-again')).onPressed,
        isNull,
      );
      await _tap(tester, _key('could-not-send-remove'));
      expect(find.text(l10n.chatCouldNotSend), findsNothing);
      expect(dm.calls.where((c) => c.startsWith('send')), isEmpty);
    });
  }
}
