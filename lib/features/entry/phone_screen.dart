import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/market.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/market_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_text_field.dart';
import 'entry_errors.dart';
import 'entry_state.dart';
import 'phone_rules.dart';
import 'widgets/dial_code_picker.dart';
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
    final picked = await pickDialCode(
      context,
      markets: _markets,
      current: _dialCode,
    );
    if (mounted && picked != null) {
      setState(() {
        _dialCode = picked;
        _error = null;
      });
    }
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
