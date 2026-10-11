import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/market.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/market_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import 'entry_errors.dart';
import 'entry_state.dart';
import 'phone_rules.dart';
import 'widgets/entry_scaffold.dart';

/// E2p · Your phone number. Any country code works: Kuwait and Egypt come
/// from the market pack, others are typed in. Whether a new account can be
/// made is decided by [PhoneRules.canCreateAccount] here and by the server.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _number = TextEditingController();
  String? _dialCode;
  String? _error;
  var _sending = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  List<Market> get _markets => ref.read(marketsProvider).value ?? const [];

  Market? get _market => _dialCode == null
      ? null
      : PhoneRules.marketForDialCode(_markets, _dialCode!);

  CodeChannel get _defaultChannel =>
      _market?.codeChannel ?? CodeChannel.whatsapp;

  Future<void> _pickDialCode() async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    const other = '__other__';
    final picked = await showBvSheet<String>(
      context: context,
      title: l10n.dialCodeTitle,
      builder: (sheetContext) => BvChoiceList<String>(
        value: _market == null && _dialCode != null ? other : _dialCode,
        options: [
          for (final m in _markets)
            BvChoiceOption(
              key: Key('dial-${m.id}'),
              value: m.dialCode,
              title: m.name.of(locale),
              description: ltrRun(m.dialCode),
              badge: m.status == MarketStatus.soon ? l10n.comingSoon : null,
            ),
          BvChoiceOption(
            key: const Key('dial-other'),
            value: other,
            title: l10n.dialCodeOther,
          ),
        ],
        onChanged: (v) => Navigator.of(sheetContext).pop(v),
      ),
    );
    if (!mounted || picked == null) return;
    if (picked != other) {
      setState(() {
        _dialCode = picked;
        _error = null;
      });
      return;
    }
    final typed = await _typeDialCode();
    if (mounted && typed != null) {
      setState(() {
        _dialCode = typed;
        _error = null;
      });
    }
  }

  Future<String?> _typeDialCode() {
    final l10n = AppLocalizations.of(context);
    return showBvSheet<String>(
      context: context,
      title: l10n.dialCodeOther,
      builder: (_) => const _OtherDialCode(),
    );
  }

  Future<void> _send(CodeChannel channel) async {
    final l10n = AppLocalizations.of(context);
    final dial = _dialCode;
    if (dial == null) return;
    final market = _market;
    final national = PhoneRules.national(_number.text);
    if (!PhoneRules.isValid(national, market)) {
      setState(() {
        _error = market?.nationalLength != null
            ? l10n.phoneErrorMarket(
                market!.name.of(Localizations.localeOf(context)),
                market.nationalLength!,
              )
            : l10n.phoneErrorOther;
      });
      return;
    }

    final invite = ref.read(inviteCodeProvider);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPhoneCode(
            phoneE164: '$dial$national',
            channel: channel,
            allowSignUp: PhoneRules.canCreateAccount(
              market: market,
              inviteCode: invite,
            ),
            signUpData: signUpData(
              locale: Localizations.localeOf(context).languageCode,
              market: market,
              inviteCode: invite,
            ),
          );
      ref
          .read(entryDraftProvider.notifier)
          .set(
            EntryDraft(
              method: EntryMethod.phone,
              dialCode: dial,
              national: national,
              market: market,
              channel: channel,
            ),
          );
      if (mounted) context.push(AppRoutes.joinCode);
    } on AuthFailureException catch (e) {
      if (!mounted) return;
      if (e.failure == AuthFailure.signupNotOpen) {
        await showNotOpenSheet(
          context,
          market: market,
          liveMarkets: liveMarkets(_markets),
        );
      } else {
        setState(() => _error = entryErrorText(l10n, e.failure));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    _dialCode ??= defaultMarket(
      markets,
      ref.watch(deviceRegionProvider),
    )?.dialCode;
    final whatsapp = _defaultChannel == CodeChannel.whatsapp;
    final ready = _dialCode != null && !_sending;

    return EntryScaffold(
      title: l10n.phoneTitle,
      footer: BvButton(
        key: const Key('phone-send'),
        label: l10n.sendCode,
        expand: true,
        onPressed: ready ? () => _send(_defaultChannel) : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvPhoneField(
            key: const Key('phone-field'),
            label: l10n.phoneLabel,
            dialCode: _dialCode ?? '+',
            onDialCodeTap: markets.isEmpty ? null : _pickDialCode,
            controller: _number,
            autofocus: true,
            placeholder: _market?.phoneExample,
            helper: whatsapp ? l10n.phoneHelpWhatsapp : l10n.phoneHelpSms,
            error: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (whatsapp)
            BvButton(
              key: const Key('phone-sms'),
              label: l10n.phoneSendSms,
              style: BvButtonStyle.secondary,
              expand: true,
              onPressed: ready ? () => _send(CodeChannel.sms) : null,
            ),
          Center(
            child: BvButton(
              key: const Key('phone-email'),
              label: l10n.phoneUseEmail,
              style: BvButtonStyle.tertiary,
              onPressed: () => context.pushReplacement(AppRoutes.joinEmail),
            ),
          ),
        ],
      ),
    );
  }
}

/// Typing a country code that is not in the market pack, for example +91.
/// Owns its text field, so it lives exactly as long as the sheet.
class _OtherDialCode extends StatefulWidget {
  const _OtherDialCode();

  @override
  State<_OtherDialCode> createState() => _OtherDialCodeState();
}

class _OtherDialCodeState extends State<_OtherDialCode> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = PhoneRules.dialCode(_code.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('dial-other-field'),
          controller: _code,
          autofocus: true,
          prefixText: '+',
          helper: l10n.dialCodeOtherHelp,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.number,
          inputFormatters: const [BvWesternDigitsFormatter()],
          onChanged: (_) => setState(() {}),
        ),
        BvButton(
          key: const Key('dial-other-confirm'),
          label: l10n.commonConfirm,
          expand: true,
          onPressed: code == null
              ? null
              : () => Navigator.of(context).pop(code),
        ),
      ],
    );
  }
}
