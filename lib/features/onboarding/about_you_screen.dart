import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/market.dart';
import '../../data/models/people.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/reference_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../entry/phone_rules.dart';
import '../entry/widgets/dial_code_picker.dart';
import '../entry/widgets/entry_scaffold.dart';
import 'company_sheet.dart';
import 'role_picker_screen.dart';

/// E9 · About you (step 1 of 2): name, country, role, company and an
/// optional private mobile number (decision 04).
class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key});

  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _mobile = TextEditingController();
  final _roleText = TextEditingController();
  final _companyText = TextEditingController();

  String? _marketId;

  /// The mobile number's country code; follows the country until the
  /// person picks one.
  String? _mobileDial;
  String? _mobileError;
  RoleChoice? _role;
  CompanyPick _company = const CompanyPick.none();
  var _filledFromProfile = false;
  var _saving = false;
  var _showErrors = false;
  String? _saveError;

  @override
  void dispose() {
    for (final c in [_first, _last, _mobile, _roleText, _companyText]) {
      c.dispose();
    }
    super.dispose();
  }

  /// With a Space invite any country can be the home market; otherwise
  /// only live markets (the server checks the same).
  bool get _invited {
    final code =
        ref.read(inviteCodeProvider) ??
        ref.read(authRepositoryProvider).signUpInviteCode;
    return code != null && code.isNotEmpty;
  }

  List<Market> _choosable(List<Market> markets) =>
      _invited ? markets : liveMarkets(markets);

  /// Pre-fills once: what the profile already has, then the country from
  /// the phone's region, or the first live market.
  void _prefill(MyProfile? me, List<Market> markets) {
    // Wait for both the markets and the profile, or the names stay blank.
    if (_filledFromProfile || markets.isEmpty || me == null) return;
    _filledFromProfile = true;
    _first.text = me.firstName;
    _last.text = me.lastName;
    final choosable = _choosable(markets);
    final region = ref.read(deviceRegionProvider)?.toLowerCase();
    final chosen =
        choosable.where((m) => m.id == me.homeMarketId).firstOrNull ??
        choosable.where((m) => m.id == region).firstOrNull ??
        liveMarkets(markets).firstOrNull;
    _marketId = chosen?.id;
    // The mobile number's code follows the phone's region, even where the
    // market is not open yet.
    _mobileDial =
        markets.where((m) => m.id == region).firstOrNull?.dialCode ??
        chosen?.dialCode;
    if (me.companyLabel != null) {
      _company = me.companyId != null
          ? CompanyPick.registered(
              CompanySummary(id: me.companyId!, name: me.companyLabel!),
            )
          : CompanyPick.typed(me.companyLabel!);
      _companyText.text = me.companyLabel!;
    }
  }

  Future<void> _pickRole(String marketId, String countryName) async {
    final choice = await context.push<RoleChoice>(
      AppRoutes.onboardingRole,
      extra: RolePickerArgs(
        marketId: marketId,
        countryName: countryName,
        initial: _role,
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _role = choice;
      _roleText.text = choice.label(
        Localizations.localeOf(context).languageCode,
      );
    });
  }

  Future<void> _pickCompany() async {
    final pick = await showCompanySheet(
      context,
      marketId: _marketId,
      initialQuery: _company.name,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _company = pick;
      _companyText.text = pick.name ?? '';
    });
  }

  Future<void> _pickMobileDial(List<Market> markets) async {
    final picked = await pickDialCode(
      context,
      markets: markets,
      current: _mobileDial,
    );
    if (mounted && picked != null) {
      setState(() {
        _mobileDial = picked;
        _mobileError = null;
      });
    }
  }

  /// The mobile number in E.164, null when left empty. Sets [_mobileError]
  /// when something was typed but it is not a valid number.
  String? _checkMobile(List<Market> markets) {
    final national = PhoneRules.national(_mobile.text);
    _mobileError = null;
    if (national.isEmpty) return null;
    final dial = _mobileDial;
    final market = dial == null
        ? null
        : PhoneRules.marketForDialCode(markets, dial);
    if (dial == null || !PhoneRules.isValid(national, market)) {
      final l10n = AppLocalizations.of(context);
      _mobileError = market?.nationalLength != null
          ? l10n.phoneErrorMarket(
              market!.name.of(Localizations.localeOf(context)),
              market.nationalLength!,
            )
          : l10n.phoneErrorOther;
      return null;
    }
    return '$dial$national';
  }

  Future<void> _save(List<Market> markets) async {
    final l10n = AppLocalizations.of(context);
    final mobile = _checkMobile(markets);
    final valid =
        _first.text.trim().isNotEmpty &&
        _last.text.trim().isNotEmpty &&
        _marketId != null &&
        _role != null &&
        _mobileError == null;
    if (!valid) {
      setState(() => _showErrors = true);
      return;
    }
    final userId = ref.read(authUserIdProvider).value;
    if (userId == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveAboutYou(
            userId,
            AboutYouInput(
              firstName: _first.text,
              lastName: _last.text,
              homeMarketId: _marketId!,
              role: _role!,
              locale: Localizations.localeOf(context).languageCode,
              companyId: _company.companyId,
              companyNameText: _company.companyId == null
                  ? _company.name
                  : null,
              mobileE164: mobile,
            ),
          );
      ref.invalidate(myProfileProvider);
      final me = await ref.read(myProfileProvider.future);
      // Step 2 only when there is someone to suggest (review 03): an empty
      // "step 2 of 2" feels unfinished, so go straight Home instead.
      final people = me == null
          ? const <PersonSuggestion>[]
          : await ref.read(profileRepositoryProvider).suggestions(me);
      if (!mounted) return;
      context.go(people.isEmpty ? AppRoutes.home : AppRoutes.onboardingPeople);
    } on Exception {
      if (mounted) setState(() => _saveError = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final me = ref.watch(myProfileProvider).value;
    _prefill(me, markets);

    final market = markets.where((m) => m.id == _marketId).firstOrNull;
    // Resolve a role saved earlier, once the picker data is in.
    if (_role == null && me?.tradeId != null && _marketId != null) {
      final trade = ref
          .watch(rolePickerProvider(_marketId!))
          .value
          ?.allTradesWithOther
          .where((t) => t.id == me!.tradeId)
          .firstOrNull;
      if (trade != null) {
        _role = trade.id == Trade.otherId && (me!.headline ?? '').isNotEmpty
            ? RoleChoice.custom(me.headline, trade: trade)
            : RoleChoice.trade(trade);
        _roleText.text = _role!.label(locale.languageCode);
      }
    }
    final choosable = _choosable(markets).map((m) => m.id).toSet();
    final mobileMarket = _mobileDial == null
        ? null
        : PhoneRules.marketForDialCode(markets, _mobileDial!);
    String? required(bool ok, String message) =>
        _showErrors && !ok ? message : null;

    return EntryScaffold(
      title: l10n.aboutTitle,
      // Going back from step 1 means starting again with another number.
      onBack: () => ref.read(authRepositoryProvider).signOut(),
      footer: BvButton(
        key: const Key('about-continue'),
        label: l10n.continueLabel,
        expand: true,
        onPressed: _saving ? null : () => _save(markets),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          Text(l10n.aboutIntro, style: type.bodyMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s12,
            children: [
              Expanded(
                child: BvTextField(
                  key: const Key('about-first'),
                  label: l10n.firstName,
                  controller: _first,
                  textInputAction: TextInputAction.next,
                  error: required(
                    _first.text.trim().isNotEmpty,
                    l10n.firstNameRequired,
                  ),
                ),
              ),
              Expanded(
                child: BvTextField(
                  key: const Key('about-last'),
                  label: l10n.lastName,
                  controller: _last,
                  textInputAction: TextInputAction.next,
                  error: required(
                    _last.text.trim().isNotEmpty,
                    l10n.lastNameRequired,
                  ),
                ),
              ),
            ],
          ),
          BvSelect<String>(
            key: const Key('about-country'),
            label: l10n.country,
            value: _marketId,
            helper: l10n.countryChangeLater,
            error: required(_marketId != null, l10n.countryRequired),
            options: [
              for (final m in markets)
                BvSelectOption(
                  value: m.id,
                  label: m.name.of(locale),
                  enabled: choosable.contains(m.id),
                  badge: m.status == MarketStatus.soon ? l10n.comingSoon : null,
                ),
            ],
            onChanged: (id) => setState(() {
              if (id != _marketId) {
                _marketId = id;
                // Roles and popular trades differ per market.
                _role = null;
                _roleText.clear();
              }
            }),
          ),
          BvTextField(
            key: const Key('about-role'),
            label: l10n.role,
            placeholder: l10n.rolePlaceholder,
            controller: _roleText,
            readOnly: true,
            suffixIcon: BvIcons.caretDown,
            error: required(_role != null, l10n.roleRequired),
            onTap: market == null
                ? null
                : () => _pickRole(market.id, market.name.of(locale)),
          ),
          BvTextField(
            key: const Key('about-company'),
            label: l10n.companyOptional,
            placeholder: l10n.companyPlaceholder,
            controller: _companyText,
            readOnly: true,
            suffixIcon: BvIcons.caretDown,
            onTap: _pickCompany,
          ),
          BvPhoneField(
            key: const Key('about-mobile'),
            label: l10n.mobileOptional,
            dialCode: _mobileDial ?? '+',
            onDialCodeTap: markets.isEmpty
                ? null
                : () => _pickMobileDial(markets),
            controller: _mobile,
            placeholder: mobileMarket?.phoneExample,
            helper: l10n.mobileHelp,
            error: _showErrors ? _mobileError : null,
            onChanged: (_) {
              if (_mobileError != null) setState(() => _mobileError = null);
            },
          ),
          if (_saveError != null)
            Text(
              _saveError!,
              style: type.bodySm.copyWith(color: BvColors.textDestructive),
            ),
        ],
      ),
    );
  }
}
