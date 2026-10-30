import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/market.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../core/design/bv_icons.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_code_field.dart';
import '../../shared/widgets/bv_list_row.dart';
import 'entry_errors.dart';
import 'entry_state.dart';
import 'phone_rules.dart';
import '../../shared/widgets/bv_sheet.dart';
import 'widgets/onboarding_scaffold.dart';

/// OB3 · Check your email (review 107, 2698:39057), and E3 · Check
/// WhatsApp (or messages) while phone sign-in is on. The code is checked as
/// soon as the sixth digit is in, with "Checking…" under the boxes. After
/// that the router moves on by itself: to your name for a new account, to
/// Home otherwise. Try another way: a different email, or a new code.
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

  /// Try another way: a different email (or number), or a new code once
  /// the server's minute between codes is over.
  Future<void> _otherWay(EntryDraft draft) async {
    final l10n = AppLocalizations.of(context);
    final byEmail = draft.method == EntryMethod.email;
    final choice = await showBvSheet<_Other>(
      context: context,
      title: l10n.obTryAnotherWay,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BvListRow(
            key: const Key('other-email'),
            leading: const BvRowIcon(BvIcons.edit),
            title: byEmail ? l10n.codeDifferentEmail : l10n.codeDifferentNumber,
            onTap: () => Navigator.of(sheet).pop(_Other.different),
          ),
          BvListRow(
            key: const Key('other-resend'),
            leading: const BvRowIcon(BvIcons.send),
            title: l10n.codeResend,
            subtitle: _secondsLeft > 0 ? _resendIn(l10n) : null,
            onTap: _secondsLeft > 0
                ? null
                : () => Navigator.of(sheet).pop(_Other.resend),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _Other.different:
        await Navigator.of(context).maybePop();
      case _Other.resend:
        await _resend(draft);
    }
  }

  String _resendIn(AppLocalizations l10n) {
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return l10n.codeResendIn('$minutes:$seconds');
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
    final title = byEmail
        ? l10n.codeTitleEmail
        : sms
        ? l10n.codeTitleSms
        : l10n.codeTitleWhatsapp;
    final sent = byEmail
        // Contact details stay masked (review 107).
        ? l10n.obCodeSent(ltrRun(maskedEmail(draft.email!)))
        : sms
        ? l10n.codeSentSms(_number(draft))
        : l10n.codeSentWhatsapp(_number(draft));

    return OnboardingScaffold(
      title: title,
      subtitle: sent,
      button: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          if (_secondsLeft > 0)
            Text(
              _resendIn(l10n),
              key: const Key('code-timer'),
              textAlign: TextAlign.center,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          BvButton(
            key: const Key('code-other-way'),
            label: l10n.obTryAnotherWay,
            style: BvButtonStyle.secondary,
            expand: true,
            onPressed: _checking ? null : () => _otherWay(draft),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvCodeField(
            key: const Key('code-field'),
            controller: _code,
            semanticLabel: l10n.codeFieldLabel,
            autofocus: true,
            enabled: !_checking,
            error: _error,
            onCompleted: (code) => _verify(draft, code),
          ),
          if (_checking)
            Row(
              key: const Key('code-checking'),
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: BvSpace.s8,
              children: [
                const SizedBox.square(
                  dimension: BvSize.iconMd,
                  child: CircularProgressIndicator(
                    strokeWidth: BvStroke.thick,
                    color: BvColors.iconAction,
                  ),
                ),
                Text(
                  l10n.obChecking,
                  style: type.bodyMd.copyWith(color: BvColors.textAction),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// The phone number as typed, in its own direction.
  String _number(EntryDraft draft) => ltrRun(
    '${draft.dialCode} '
    '${PhoneRules.format(draft.national!, example: draft.market?.phoneExample)}',
  );
}

enum _Other { different, resend }
