import 'package:buildvibes/features/messages/dm_live.dart'
    show pushBodyKey, pushTitleKey;
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_message_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/push_fakes.dart';

final _now = DateTime(2026, 10, 15, 10, 30);

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

/// A direct message push with its words hidden (the lock-screen setting is
/// off, as it is until the person turns it on).
Map<String, String> _hiddenPush(String lang, String message) => {
  'kind': 'dm_message',
  'route': '/messages/t-omar',
  'dm_thread_id': 't-omar',
  'message_id': message,
  pushTitleKey: _l10n(lang).dmBannerTitle('Omar Haddad'),
  pushBodyKey: _l10n(lang).dmBannerHidden,
};

Finder get _banner => find.byType(BvMessageBanner);

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    // F101: with the words hidden, a newer message still visibly changes
    // the banner: it counts, with no new slide-in, and the 4 s start again.
    testWidgets('three hidden messages 1 s apart count up on one banner '
        '[$lang]', (tester) async {
      final push = FakePushMessaging();
      await pumpApp(tester, push: push, now: _now, language: lang);

      push.arrive(_hiddenPush(lang, 'm1'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.dmBannerHidden), findsOneWidget);
      final banner = tester.widget<Dismissible>(
        find.ancestor(of: _banner, matching: find.byType(Dismissible)),
      );

      await tester.pump(const Duration(seconds: 1));
      push.arrive(_hiddenPush(lang, 'm2'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.dmBannerHiddenCount(2)), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      push.arrive(_hiddenPush(lang, 'm3'));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.dmBannerHiddenCount(3)), findsOneWidget);
      // The same banner throughout: no new slide-in.
      expect(
        tester
            .widget<Dismissible>(
              find.ancestor(of: _banner, matching: find.byType(Dismissible)),
            )
            .key,
        banner.key,
      );

      // The 4 s start again from the third.
      await tester.pump(const Duration(milliseconds: 3900));
      expect(_banner, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(_banner, findsNothing);
    });
  }

  test('the counting words match the follow-up push (F97)', () {
    final en = _l10n('en');
    expect(en.dmBannerHiddenCount(2), '2 new messages');
    expect(en.dmBannerHiddenCount(11), '11 new messages');
    final ar = _l10n('ar');
    expect(ar.dmBannerHiddenCount(2), 'رسالتان جديدتان');
    expect(ar.dmBannerHiddenCount(3), '3 رسائل جديدة');
    expect(ar.dmBannerHiddenCount(11), '11 رسالة جديدة');
  });
}
