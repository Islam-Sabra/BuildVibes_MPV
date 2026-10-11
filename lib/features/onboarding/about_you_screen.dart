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
import '../entry/email_screen.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/entry_scaffold.dart';
import 'company_sheet.dart';
import 'role_picker_screen.dart';

/// E9 · About you (step 1 of 2): name, country, role, company and a
/// recovery email for people who signed up by phone.
class AboutYouScreen extends ConsumerStatefulWidget {
  const AboutYouScreen({super.key});

  @override
  ConsumerState<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends ConsumerState<AboutYouScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _recovery = TextEditingController();
  final _roleText = TextEditingController();
  final _companyText = TextEditingController();

  String? _marketId;
  var _marketFromPhone = false;
  RoleChoice? _role;
  CompanyPick _company = const CompanyPick.none();
  var _filledFromProfile = false;
  var _saving = false;
  var _showErrors = false;
  String? _saveError;

  @override
  void dispose() {
    for (final c in [_first, _last, _recovery, _roleText, _companyText]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pre-fills once: what the profile already has, then the country from
  /// the sign-in phone, the phone's region, or the first live market.
  void _prefill(MyProfile? me, List<Market> markets) {
    // Wait for both the markets and the profile, or the names stay blank.
    if (_filledFromProfile || markets.isEmpty || me == null) return;
    _filledFromProfile = true;
    _first.text = me.firstName;
    _last.text = me.lastName;
    final live = liveMarkets(markets);
    final phone = ref.read(authRepositoryProvider).currentPhone;
    final byPhone = phone == null
        ? null
        : live.where((m) => phone.startsWith(m.dialCode)).firstOrNull;
    final region = ref.read(deviceRegionProvider)?.toLowerCase();
    final saved = live.where((m) => m.id == me.homeMarketId).firstOrNull;
    final chosen =
        saved ??
        byPhone ??
        live.where((m) => m.id == region).firstOrNull ??
        live.firstOrNull;
    _marketId = chosen?.id;
    _marketFromPhone = chosen != null && chosen == byPhone;
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final recovery = _recovery.text.trim();
    final valid =
        _first.text.trim().isNotEmpty &&
        _last.text.trim().isNotEmpty &&
        _marketId != null &&
        _role != null &&
        (recovery.isEmpty || EmailScreen.isValid(recovery));
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
              recoveryEmail: recovery.isEmpty ? null : recovery,
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
    final signedUpByPhone =
        ref.read(authRepositoryProvider).currentPhone != null;
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
        onPressed: _saving ? null : _save,
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
            helper: _marketFromPhone ? l10n.countryFromPhone : null,
            error: required(_marketId != null, l10n.countryRequired),
            options: [
              for (final m in markets)
                BvSelectOption(
                  value: m.id,
                  label: m.name.of(locale),
                  enabled: m.status == MarketStatus.live,
                  badge: m.status == MarketStatus.soon ? l10n.comingSoon : null,
                ),
            ],
            onChanged: (id) => setState(() {
              if (id != _marketId) {
                _marketId = id;
                _marketFromPhone = false;
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
          if (signedUpByPhone)
            BvTextField(
              key: const Key('about-recovery'),
              label: l10n.recoveryEmail,
              controller: _recovery,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              helper: l10n.recoveryEmailHelp,
              error: required(
                _recovery.text.trim().isEmpty ||
                    EmailScreen.isValid(_recovery.text),
                l10n.emailError,
              ),
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
