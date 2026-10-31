// Review 107: onboarding v2, OB1 → OB6. One welcome (language at the top,
// Continue with email · I have an invite code · Just looking), the email,
// the code ("Checking…", Try another way), your name, your work (tiles from
// the market pack), then join your Space by code, or straight on with the
// invite. The home market is taken without asking. Waiting states are on
// the buttons. In English and Arabic.
import 'dart:async';

import 'package:buildvibes/core/design/bv_specs.dart';
import 'package:buildvibes/core/l10n/bidi.dart';
import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/features/profile/edit/basics_screen.dart';
import 'package:buildvibes/l10n/gen/app_localizations.dart';
import 'package:buildvibes/shared/widgets/bv_button.dart';
import 'package:buildvibes/shared/widgets/bv_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/space_fakes.dart';

AppLocalizations _l10n(String lang) => lookupAppLocalizations(Locale(lang));

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key).first);
  await tester.pumpAndSettle();
  await tester.tap(_key(key).first);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: _key(key),
    matching: find.byType(TextField),
  );
  await tester.enterText(field.first, text);
  await tester.pumpAndSettle();
}

/// OB1 → OB2 → OB3 with [email]; the code goes in and is checked.
Future<void> _signIn(
  WidgetTester tester, {
  String email = 'sami@gulfbuild.co',
  bool fromWelcome = true,
}) async {
  if (fromWelcome) await _tap(tester, 'welcome-email');
  await _type(tester, 'email-field', email);
  await _tap(tester, 'email-send');
  await tester.enterText(_key('code-input'), '123456');
  await tester.pumpAndSettle();
}

/// OB4: both names, then Continue.
Future<void> _name(WidgetTester tester) async {
  await _type(tester, 'name-first', 'Sami');
  await _type(tester, 'name-last', 'Al-Mansour');
  await _tap(tester, 'name-continue');
}

const _tower = 'Kuwait City Tower — Site team';

/// K7Q4MD opens the tower; C41R0X opens a Space whose project is in Egypt.
FakeSpaceRepository _spaces() => FakeSpaceRepository()
  ..invites['K7Q4MD'] = const FakeInvite(
    spaceId: 'space-kct',
    spaceName: _tower,
    invitedBy: 'Islam Sabra',
  )
  ..invites['C41R0X'] = const FakeInvite(
    spaceId: 'space-cairo',
    spaceName: 'Cairo Tower',
    marketId: 'eg',
  );

/// OB1: I have an invite code, [code], then Continue.
Future<void> _keepInvite(WidgetTester tester, String code) async {
  await _tap(tester, 'welcome-invite');
  await tester.enterText(_key('code-input'), code);
  await tester.pumpAndSettle();
  await _tap(tester, 'invite-continue');
}

void main() {
  for (final lang in ['en', 'ar']) {
    final l10n = _l10n(lang);
    final locale = Locale(lang);
    String trade(String id) => testRolePicker.byId(id)!.name.of(locale);

    group('OB1 Welcome [$lang]', () {
      testWidgets('one welcome: the whole industry, Continue with email · I '
          'have an invite code · Just looking; no Create account, no Sign '
          'in', (tester) async {
        await pumpApp(tester, language: lang, signedIn: false);
        expect(find.text(l10n.obWelcomeTitle), findsOneWidget);
        expect(find.text(l10n.obWelcomeLine), findsOneWidget);
        for (final card in [
          l10n.obCardArchitect,
          l10n.obCardProjectManager,
          l10n.obCardSupplier,
          l10n.obCardSiteEngineer,
        ]) {
          expect(find.text(card), findsOneWidget);
        }
        expect(
          find.descendant(
            of: _key('welcome-email'),
            matching: find.text(l10n.entryContinueEmail),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.obHaveInvite), findsOneWidget);
        expect(find.text(l10n.obJustLooking), findsOneWidget);
        expect(find.text(l10n.entryCreateAccount), findsNothing);
        expect(find.text(l10n.entrySignIn), findsNothing);
        // The language at the top names the other one.
        expect(
          find.descendant(
            of: _key('welcome-language'),
            matching: find.text(
              lang == 'en' ? l10n.languageArabic : l10n.languageEnglish,
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('the language at the top switches the app', (tester) async {
        await pumpApp(tester, language: lang, signedIn: false);
        await _tap(tester, 'welcome-language');
        final other = _l10n(lang == 'en' ? 'ar' : 'en');
        expect(find.text(other.obWelcomeTitle), findsOneWidget);
        expect(
          appDirection(tester),
          lang == 'en' ? TextDirection.rtl : TextDirection.ltr,
        );
      });

      testWidgets('Just looking browses Home without an account', (
        tester,
      ) async {
        await pumpApp(tester, language: lang, signedIn: false);
        await _tap(tester, 'welcome-look');
        expect(_key('nav-home'), findsOneWidget);
      });
    });

    group('OB2 · OB3 the email and the code [$lang]', () {
      testWidgets('one field, Send code with "Sending…"; the code masked, '
          '"Checking…", then your name', (tester) async {
        final auth = FakeAuthRepository();
        final send = Completer<void>();
        final check = Completer<void>();
        auth
          ..sendGate = send.future
          ..verifyGate = check.future;
        await pumpApp(tester, language: lang, signedIn: false, auth: auth);
        await _tap(tester, 'welcome-email');
        expect(find.text(l10n.emailTitle), findsOneWidget);
        expect(find.text(l10n.obEmailSub), findsOneWidget);
        await _type(tester, 'email-field', 'sami@gulfbuild.co');
        await tester.tap(_key('email-send'));
        await tester.pump();
        expect(
          find.descendant(
            of: _key('email-send'),
            matching: find.text(l10n.obSending),
          ),
          findsOneWidget,
        );
        send.complete();
        await tester.pumpAndSettle();

        // OB3: the address masked, the boxes, the timer, Try another way.
        expect(find.text(l10n.codeTitleEmail), findsOneWidget);
        expect(
          find.text(l10n.obCodeSent(ltrRun('s•••@gulfbuild.co'))),
          findsOneWidget,
        );
        expect(_key('code-timer'), findsOneWidget);
        expect(find.text(l10n.obTryAnotherWay), findsOneWidget);
        await tester.enterText(_key('code-input'), '123456');
        await tester.pump();
        expect(find.text(l10n.obChecking), findsOneWidget);
        check.complete();
        await tester.pumpAndSettle();
        expect(_key('name-first'), findsOneWidget);
      });

      testWidgets('Try another way: a different email, or a new code', (
        tester,
      ) async {
        final app = await pumpApp(tester, language: lang, signedIn: false);
        await _tap(tester, 'welcome-email');
        await _type(tester, 'email-field', 'sami@gulfbuild.co');
        await _tap(tester, 'email-send');
        // A new code only after the server's minute between codes.
        await tester.pump(const Duration(seconds: 61));
        await _tap(tester, 'code-other-way');
        expect(find.text(l10n.codeDifferentEmail), findsOneWidget);
        expect(find.text(l10n.codeResend), findsOneWidget);
        await _tap(tester, 'other-resend');
        expect(app.auth.sent, hasLength(2));
        await _tap(tester, 'code-other-way');
        await _tap(tester, 'other-email');
        expect(find.text(l10n.emailTitle), findsOneWidget);
      });

      testWidgets('the lead\'s check R1: Try another way is always active; '
          'a different email at once, a new code only after the timer', (
        tester,
      ) async {
        final auth = FakeAuthRepository();
        final check = Completer<void>();
        auth.verifyGate = check.future;
        await pumpApp(tester, language: lang, signedIn: false, auth: auth);
        await _tap(tester, 'welcome-email');
        await _type(tester, 'email-field', 'sami@gulfbuild.co');
        await _tap(tester, 'email-send');
        BvButton other() => tester.widget<BvButton>(_key('code-other-way'));
        // While the timer runs.
        expect(_key('code-timer'), findsOneWidget);
        expect(other().onPressed, isNotNull);
        // And while the code is checked.
        await tester.enterText(_key('code-input'), '000000');
        await tester.pump();
        expect(find.text(l10n.obChecking), findsOneWidget);
        expect(other().onPressed, isNotNull);
        check.complete();
        await tester.pumpAndSettle();
        await _tap(tester, 'code-other-way');
        // A new code waits for the timer, greyed, with how long.
        final resend = tester.widget<BvListRow>(_key('other-resend'));
        expect(resend.onTap, isNull);
        expect(
          tester
              .widget<Opacity>(
                find
                    .ancestor(
                      of: _key('other-resend'),
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity,
          BvEntrySpec.waitingOpacity,
        );
        expect(find.textContaining(l10n.codeResendIn('').trim()), findsWidgets);
        // A different email at once.
        await _tap(tester, 'other-email');
        expect(find.text(l10n.emailTitle), findsOneWidget);
      });

      testWidgets('an existing account goes from the code straight Home', (
        tester,
      ) async {
        final profiles = FakeProfileRepository();
        profiles.profiles[FakeAuthRepository.newUserId] = completeProfile(
          FakeAuthRepository.newUserId,
        );
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          profiles: profiles,
        );
        await _signIn(tester);
        expect(_key('name-first'), findsNothing);
        expect(_key('nav-home'), findsOneWidget);
      });
    });

    group('OB4 · OB5 your name, your work [$lang]', () {
      testWidgets('OB4: first and last name only, step 1 of 3; both are '
          'asked for', (tester) async {
        await pumpApp(tester, language: lang, signedIn: false);
        await _signIn(tester);
        expect(find.text(l10n.obNameTitle), findsOneWidget);
        expect(find.text(l10n.obNameSub), findsOneWidget);
        expect(find.text(l10n.stepOf(1, 3)), findsOneWidget);
        // No country, role, company or mobile here.
        expect(find.byType(TextField), findsNWidgets(2));
        await _tap(tester, 'name-continue');
        expect(find.text(l10n.firstNameRequired), findsOneWidget);
        await _name(tester);
        expect(find.text(l10n.obWorkTitle), findsOneWidget);
      });

      testWidgets('OB5: tiles from the market pack, popular first; one is '
          'picked, Continue says "Saving…", and the market is taken without '
          'asking', (tester) async {
        final profiles = FakeProfileRepository();
        final save = Completer<void>();
        profiles.saveGate = save.future;
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          profiles: profiles,
        );
        await _signIn(tester);
        await _name(tester);
        expect(find.text(l10n.obWorkSub), findsOneWidget);
        expect(find.text(l10n.stepOf(2, 3)), findsOneWidget);
        // The market's popular trades first, then the rest; never "Other".
        final ids = ['site_engineer', 'electrician', 'steel_fixer', 'foreman'];
        for (final id in ids) {
          expect(
            find.descendant(
              of: _key('work-tile-$id'),
              matching: find.text(trade(id)),
            ),
            findsOneWidget,
          );
        }
        expect(_key('work-tile-other'), findsNothing);
        final ys = [
          for (final id in ids) tester.getTopLeft(_key('work-tile-$id')),
        ];
        expect(ys.first.dy, lessThanOrEqualTo(ys.last.dy));
        // Nothing picked: it asks.
        await _tap(tester, 'work-continue');
        expect(find.text(l10n.obWorkChoose), findsOneWidget);
        await _tap(tester, 'work-tile-steel_fixer');
        await tester.tap(_key('work-continue'));
        await tester.pump();
        expect(
          find.descendant(
            of: _key('work-continue'),
            matching: find.text(l10n.obSaving),
          ),
          findsOneWidget,
        );
        save.complete();
        await tester.pumpAndSettle();
        final saved = profiles.lastSaved!;
        expect(saved.firstName, 'Sami');
        expect(saved.lastName, 'Al-Mansour');
        expect(saved.role.trade.id, 'steel_fixer');
        expect(saved.role.customText, isNull);
        expect(saved.homeMarketId, 'kw');
        expect(saved.locale, lang);
        expect(saved.companyId, isNull);
        expect(saved.mobileE164, isNull);
        // OB6 next: no invite.
        expect(find.text(l10n.obSpaceTitle), findsOneWidget);
      });

      testWidgets('OB5: search, and "Not listed? Type it" saves your own '
          'words', (tester) async {
        final profiles = FakeProfileRepository();
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          profiles: profiles,
        );
        await _signIn(tester);
        await _name(tester);
        await _type(tester, 'work-search', lang == 'en' ? 'fore' : 'رئيس');
        expect(_key('work-tile-foreman'), findsOneWidget);
        expect(_key('work-tile-electrician'), findsNothing);
        await _tap(tester, 'work-not-listed');
        await _type(tester, 'work-own', 'Shuttering lead');
        await _tap(tester, 'work-continue');
        final saved = profiles.lastSaved!;
        expect(saved.role.trade.id, Trade.otherId);
        expect(saved.role.customText, 'Shuttering lead');
      });

      testWidgets('a phone in a market that isn\'t open yet: the first live '
          'market, not asked', (tester) async {
        final profiles = FakeProfileRepository();
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          profiles: profiles,
          region: 'EG',
        );
        await _signIn(tester);
        await _name(tester);
        await _tap(tester, 'work-tile-foreman');
        await _tap(tester, 'work-continue');
        expect(profiles.lastSaved!.homeMarketId, 'kw');
      });

      testWidgets('back on your name signs out to start again', (tester) async {
        final app = await pumpApp(tester, language: lang, signedIn: false);
        await _signIn(tester);
        await _tap(tester, 'entry-back');
        expect(app.auth.signOuts, 1);
        expect(find.text(l10n.obWelcomeTitle), findsOneWidget);
      });
    });

    group('OB6 join your Space [$lang]', () {
      Future<TestApp> toSpace(WidgetTester tester) async {
        final app = await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          spaces: _spaces(),
        );
        await _signIn(tester);
        await _name(tester);
        await _tap(tester, 'work-tile-foreman');
        await _tap(tester, 'work-continue');
        return app;
      }

      testWidgets('6 characters show the Space; Ask to join sends the '
          'request, then Home', (tester) async {
        final app = await toSpace(tester);
        expect(find.text(l10n.obSpaceSub), findsOneWidget);
        expect(find.text(l10n.stepOf(3, 3)), findsOneWidget);
        // The boxes read left to right, in Arabic too.
        expect(
          Directionality.of(tester.element(_key('code-box-0'))),
          TextDirection.ltr,
        );
        await tester.enterText(_key('code-input'), 'k7q4md');
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _key('space-preview'),
            matching: find.text(_tower),
          ),
          findsOneWidget,
        );
        expect(
          find.text(l10n.obSpaceLetsIn(inOwnDirection('Islam Sabra'))),
          findsOneWidget,
        );
        await _tap(tester, 'space-ask');
        expect(app.spaces.requests.single.spaceId, 'space-kct');
        expect(find.text(l10n.spacesRequestSent), findsOneWidget);
        expect(_key('nav-home'), findsOneWidget);
      });

      testWidgets('a wrong code says so; Skip for now goes Home', (
        tester,
      ) async {
        final app = await toSpace(tester);
        await tester.enterText(_key('code-input'), 'ZZZZZZ');
        await tester.pumpAndSettle();
        expect(find.text(l10n.spacesCodeNotValid), findsOneWidget);
        await _tap(tester, 'space-skip');
        expect(app.spaces.requests, isEmpty);
        expect(_key('nav-home'), findsOneWidget);
      });
    });

    group('the lead\'s check: the invite right after sign-in (Q1), retries '
        '(Q2), the market (Q3) [$lang]', () {
      testWidgets('Q1: OB4 says which Space; its market is home', (
        tester,
      ) async {
        final profiles = FakeProfileRepository();
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          profiles: profiles,
          spaces: _spaces(),
        );
        await _keepInvite(tester, 'C41R0X');
        await _signIn(tester, fromWelcome: false);
        expect(find.text(l10n.obJoining('Cairo Tower')), findsOneWidget);
        await _name(tester);
        await _tap(tester, 'work-tile-foreman');
        await _tap(tester, 'work-continue');
        // The Space's market, not the phone's (Kuwait).
        expect(profiles.lastSaved!.homeMarketId, 'eg');
      });

      testWidgets('Q1: a code that doesn\'t work says so on OB4, with '
          'Change code · Skip; Skip goes on to step 3', (tester) async {
        final app = await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          spaces: _spaces(),
        );
        await _keepInvite(tester, 'ZZZZZZ');
        await _signIn(tester, fromWelcome: false);
        expect(find.text(l10n.obInviteFailed), findsOneWidget);
        expect(_key('invite-change'), findsOneWidget);
        await _tap(tester, 'invite-skip');
        expect(find.text(l10n.obInviteFailed), findsNothing);
        await _name(tester);
        await _tap(tester, 'work-tile-foreman');
        await _tap(tester, 'work-continue');
        expect(app.spaces.requests, isEmpty);
        expect(find.text(l10n.obSpaceTitle), findsOneWidget);
      });

      testWidgets('Q1: Change code: another code, and it says which Space', (
        tester,
      ) async {
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          spaces: _spaces(),
        );
        await _keepInvite(tester, 'ZZZZZZ');
        await _signIn(tester, fromWelcome: false);
        await _tap(tester, 'invite-change');
        await tester.enterText(_key('code-input'), 'K7Q4MD');
        await tester.pumpAndSettle();
        await _tap(tester, 'invite-continue');
        expect(find.text(l10n.obInviteFailed), findsNothing);
        expect(find.text(l10n.obJoining(_tower)), findsOneWidget);
      });

      testWidgets('Q2: no signal for the request: the code stays, it says '
          'why, and Continue tries again', (tester) async {
        final spaces = _spaces()..joinFailure = SpaceFailure.network;
        await pumpApp(tester, language: lang, signedIn: false, spaces: spaces);
        await _keepInvite(tester, 'K7Q4MD');
        await _signIn(tester, fromWelcome: false);
        await _name(tester);
        await _tap(tester, 'work-tile-foreman');
        await _tap(tester, 'work-continue');
        expect(spaces.requests, isEmpty);
        expect(_key('work-error'), findsOneWidget);
        expect(find.text(l10n.obWorkTitle), findsOneWidget);
        await _tap(tester, 'work-continue');
        expect(spaces.requests.single.spaceId, 'space-kct');
        expect(find.text(l10n.spacesRequestSent), findsOneWidget);
      });

      testWidgets('Q3: a market the server refuses: the first live market '
          'is saved, never a dead end', (tester) async {
        final profiles = FakeProfileRepository()..refusedMarkets.add('eg');
        await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          profiles: profiles,
          spaces: _spaces(),
        );
        await _keepInvite(tester, 'C41R0X');
        await _signIn(tester, fromWelcome: false);
        await _name(tester);
        await _tap(tester, 'work-tile-foreman');
        await _tap(tester, 'work-continue');
        expect(profiles.lastSaved!.homeMarketId, 'kw');
        expect(_key('nav-home'), findsOneWidget);
      });
    });

    group('the lead\'s check Q5: the old routes, once onboarded [$lang]', () {
      for (final (from, toEdit) in [
        ('/onboarding', false),
        ('/onboarding/about', false),
        ('/onboarding/people', false),
        ('/onboarding/name', true),
        ('/onboarding/work', true),
      ]) {
        testWidgets('$from goes ${toEdit ? 'to Edit profile' : 'Home'}', (
          tester,
        ) async {
          await pumpApp(tester, language: lang);
          GoRouter.of(tester.element(find.byType(Navigator).first)).go(from);
          await tester.pumpAndSettle();
          expect(
            find.byType(BasicsScreen),
            toEdit ? findsOneWidget : findsNothing,
          );
          if (!toEdit) expect(_key('nav-home'), findsOneWidget);
        });
      }
    });

    group('an invite [$lang]', () {
      testWidgets('I have an invite code: kept for sign-up; after your work '
          'the request goes, with no OB6, and any market may be home', (
        tester,
      ) async {
        final profiles = FakeProfileRepository();
        final app = await pumpApp(
          tester,
          language: lang,
          signedIn: false,
          profiles: profiles,
          spaces: _spaces(),
          region: 'EG',
        );
        await _tap(tester, 'welcome-invite');
        expect(find.text(l10n.obInviteTitle), findsOneWidget);
        // The invite's boxes read left to right too.
        expect(
          Directionality.of(tester.element(_key('code-box-0'))),
          TextDirection.ltr,
        );
        await tester.enterText(_key('code-input'), 'K7Q4MD');
        await tester.pumpAndSettle();
        await _tap(tester, 'invite-continue');
        // Straight to the email.
        expect(find.text(l10n.emailTitle), findsOneWidget);
        await _signIn(tester, fromWelcome: false);
        expect(app.auth.sent.single.data['invite_code'], 'K7Q4MD');
        await _name(tester);
        await _tap(tester, 'work-tile-foreman');
        await _tap(tester, 'work-continue');
        // With an invite, the phone's own market may be home.
        expect(profiles.lastSaved!.homeMarketId, 'eg');
        expect(app.spaces.requests.single.spaceId, 'space-kct');
        expect(find.text(l10n.obSpaceTitle), findsNothing);
        expect(find.text(l10n.spacesRequestSent), findsOneWidget);
      });
    });
  }
}
