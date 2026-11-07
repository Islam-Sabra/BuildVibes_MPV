import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_specs.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/design/people_library_specs.dart';
import '../../../data/models/key_people.dart';
import '../../../data/models/market.dart';
import '../../../data/models/space.dart';
import '../../../data/repositories/key_people_repository.dart';
import '../../../data/repositories/market_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_controls.dart';
import '../../../shared/widgets/bv_section_scaffold.dart';
import '../../../shared/widgets/bv_text_field.dart';
import '../../entry/entry_state.dart';
import '../../entry/phone_rules.dart';
import '../../spaces/space_errors.dart';

/// Review 121 NUM1: Profile → Phone number. Optional; the dial code and
/// the format come from the market pack (rule 5); saved in E.164, checked
/// on the server. Who sees my number is one choice (rule 6), Nobody by
/// default. The number never shows in search, on the public profile or in
/// any list: Call reads it one person at a time.
class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  final _number = TextEditingController();
  final _focus = FocusNode();
  var _filled = false;
  var _visibility = PhoneVisibility.nobody;
  String? _saved;
  String? _error;

  /// The saved number's market, else mine (set in [build]).
  Market? _market;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) unawaited(_save());
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The typed number in E.164; null for none. False when it doesn't fit
  /// the market pack.
  ({bool ok, String? phone}) _typed(Market? market) {
    final text = _number.text.trim();
    if (text.isEmpty) return (ok: true, phone: null);
    if (market == null) return (ok: false, phone: null);
    final national = PhoneRules.nationalIn(text, market);
    return market.isMobileNumber(national)
        ? (ok: true, phone: market.toE164(national))
        : (ok: false, phone: null);
  }

  Future<void> _save({PhoneVisibility? visibility}) async {
    final l10n = AppLocalizations.of(context);
    final market = _market;
    final typed = _typed(market);
    if (!typed.ok) {
      setState(() => _error = l10n.phoneCheck);
      return;
    }
    final choice = visibility ?? _visibility;
    if (typed.phone == _saved && choice == _visibility) {
      setState(() => _error = null);
      return;
    }
    final before = (_saved, _visibility);
    setState(() {
      _error = null;
      _saved = typed.phone;
      _visibility = choice;
    });
    try {
      await ref
          .read(keyPeopleRepositoryProvider)
          .setMyPhone(typed.phone, visibility: choice);
      ref.invalidate(myPhoneProvider);
    } on SpaceException catch (e) {
      if (!mounted) return;
      final refused = e.failure == SpaceFailure.badInput;
      setState(() {
        _saved = before.$1;
        _visibility = before.$2;
        if (refused) _error = l10n.phoneCheck;
      });
      if (!refused) showSpaceError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final home = ref.watch(myProfileProvider).value?.homeMarketId;
    final mine = ref.watch(myPhoneProvider).value;
    if (mine != null && !_filled) {
      _filled = true;
      _saved = mine.phone;
      _visibility = mine.visibility;
      final phone = mine.phone;
      final m = phone == null
          ? null
          : PhoneRules.marketForNumber(markets, phone);
      if (phone != null) {
        _number.text = m == null
            ? phone
            : PhoneRules.format(
                phone.substring(m.dialCode.length),
                example: m.phoneExample,
              );
      }
    }
    final saved = _saved;
    final market = _market =
        (saved == null ? null : PhoneRules.marketForNumber(markets, saved)) ??
        markets.where((m) => m.id == home).firstOrNull;
    final label = type.bodySm.copyWith(color: BvColors.textSecondary);

    Widget choice(PhoneVisibility v, String title, String line) {
      final on = _visibility == v;
      return InkWell(
        key: Key('phone-see-${v.name}'),
        onTap: () => unawaited(_save(visibility: v)),
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: BvKeyPeopleSpec.choicePadding,
          child: Row(
            spacing: BvSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(title, style: on ? type.emphasis : type.bodyMd),
                    Text(
                      line,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              BvRadio(key: Key('phone-see-${v.name}-radio'), selected: on),
            ],
          ),
        ),
      );
    }

    const divider = Divider(
      height: BvStroke.thin,
      thickness: BvStroke.thin,
      color: BvColors.borderDefault,
    );

    return BvSectionScaffold(
      title: l10n.phoneTitle,
      subtitle: l10n.phoneWhere,
      body: ListView(
        key: const Key('phone-screen'),
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        children: [
          Text(l10n.phoneMine, style: label),
          const SizedBox(height: BvSpace.s8),
          BvTextField(
            key: const Key('phone-field'),
            controller: _number,
            focusNode: _focus,
            prefixText: market?.dialCode,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            // Numbers read left to right, in Arabic too; Western digits.
            textDirection: TextDirection.ltr,
            inputFormatters: [
              BvWesternDigitsFormatter(),
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            error: _error,
            invalid: _error != null,
            onSubmitted: (_) => unawaited(_save()),
          ),
          const SizedBox(height: BvSpace.s16),
          Text(l10n.phoneWhoSees, style: label),
          const SizedBox(height: BvSpace.s8),
          ClipRRect(
            borderRadius: BvRadius.cardAll,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BvColors.surfaceElevated,
                borderRadius: BvRadius.cardAll,
                border: Border.all(
                  color: BvColors.borderDefault,
                  width: BvStroke.thin,
                ),
              ),
              child: Column(
                children: [
                  choice(
                    PhoneVisibility.nobody,
                    l10n.phoneNobody,
                    l10n.phoneNobodyLine,
                  ),
                  divider,
                  choice(
                    PhoneVisibility.spaces,
                    l10n.phoneSpaces,
                    l10n.phoneSpacesLine,
                  ),
                  divider,
                  choice(PhoneVisibility.dms, l10n.phoneDms, l10n.phoneDmsLine),
                ],
              ),
            ),
          ),
          const SizedBox(height: BvSpace.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvKeyPeopleSpec.noteGap,
            children: [
              const Icon(
                BvIcons.lock,
                size: BvSize.iconSm,
                color: BvColors.iconSecondary,
              ),
              Expanded(child: Text(l10n.phoneNever, style: label)),
            ],
          ),
        ],
      ),
    );
  }
}
