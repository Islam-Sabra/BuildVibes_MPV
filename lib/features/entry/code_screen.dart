import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/market.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_code_field.dart';
import 'entry_errors.dart';
import 'entry_state.dart';
import 'phone_rules.dart';
import 'widgets/entry_scaffold.dart';

/// E3 · Check WhatsApp (or messages) and E3e · Check your email. The code is
/// checked as soon as the sixth digit is in. After that the router moves on
/// by itself: to onboarding for a new account, to Home otherwise.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  var _secondsLeft = 0;
  String? _error;
  var _checking = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = BvAuthSpec.resendAfter.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify(EntryDraft draft, String code) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (draft.method == EntryMethod.phone) {
        await auth.verifyPhoneCode(phoneE164: draft.phoneE164!, code: code);
      } else {
        await auth.verifyEmailCode(email: draft.email!, code: code);
      }
      ref.read(guestModeProvider.notifier).leave();
      ref.read(entryDraftProvider.notifier).clear();
    } on AuthFailureException catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(
        () => _error = entryErrorText(AppLocalizations.of(context), e.failure),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend(EntryDraft draft) async {
    final auth = ref.read(authRepositoryProvider);
    final invite = ref.read(inviteCodeProvider);
    final locale = Localizations.localeOf(context).languageCode;
    try {
      if (draft.method == EntryMethod.phone) {
        await auth.sendPhoneCode(
          phoneE164: draft.phoneE164!,
          channel: draft.channel,
          allowSignUp: PhoneRules.canCreateAccount(
            market: draft.market,
            inviteCode: invite,
          ),
          signUpData: signUpData(
            locale: locale,
            market: draft.market,
            inviteCode: invite,
          ),
        );
      } else {
        await auth.sendEmailCode(
          email: draft.email!,
          signUpData: signUpData(locale: locale, inviteCode: invite),
        );
      }
      _code.clear();
      setState(() => _error = null);
      _startTimer();
    } on AuthFailureException catch (e) {
      if (mounted) showEntryError(context, e.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final draft = ref.watch(entryDraftProvider);
    if (draft == null) {
      // Signed in: the router is about to move on.
      return const Scaffold(body: SizedBox.shrink());
    }

    final byEmail = draft.method == EntryMethod.email;
    final sms = draft.channel == CodeChannel.sms;
    final destination = ltrRun(
      byEmail
          ? draft.email!
          : '${draft.dialCode} '
                '${PhoneRules.format(draft.national!, example: draft.market?.phoneExample)}',
    );
    final title = byEmail
        ? l10n.codeTitleEmail
        : sms
        ? l10n.codeTitleSms
        : l10n.codeTitleWhatsapp;
    final sent = byEmail
        ? l10n.codeSentEmail(destination)
        : sms
        ? l10n.codeSentSms(destination)
        : l10n.codeSentWhatsapp(destination);
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return EntryScaffold(
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s16,
        children: [
          Text(
            sent,
            style: type.bodyMd.copyWith(color: BvColors.textSecondary),
          ),
          BvCodeField(
            key: const Key('code-field'),
            controller: _code,
            semanticLabel: l10n.codeFieldLabel,
            autofocus: true,
            enabled: !_checking,
            error: _error,
            onCompleted: (code) => _verify(draft, code),
          ),
          if (_secondsLeft > 0)
            Text(
              l10n.codeResendIn('$minutes:$seconds'),
              key: const Key('code-timer'),
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            )
          else
            BvButton(
              key: const Key('code-resend'),
              label: l10n.codeResend,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              padded: false,
              onPressed: () => _resend(draft),
            ),
          BvButton(
            key: const Key('code-different'),
            label: byEmail ? l10n.codeDifferentEmail : l10n.codeDifferentNumber,
            style: BvButtonStyle.tertiary,
            size: BvButtonSize.medium,
            padded: false,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
