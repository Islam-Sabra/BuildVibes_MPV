import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/photo_privacy.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/models/market.dart';
import '../../../data/models/people.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/market_repository.dart';
import '../../../data/repositories/profile_page_repository.dart';
import '../../../data/repositories/reference_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_avatar.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_text_field.dart';
import '../../entry/widgets/entry_scaffold.dart';
import '../../onboarding/company_sheet.dart';
import '../../onboarding/role_picker_screen.dart';
import 'edit_common.dart';

/// Picks a photo, made safe to leave the phone (cleanPhoto); overridden in
/// tests.
final photoPickerProvider = Provider<Future<PickedPhotos> Function()>(
  (ref) => () async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    return cleanPicked([?photo], from: 'profile');
  },
);

/// "Name, photo and headline": name, photo, headline, role, company and
/// city or area.
class BasicsScreen extends ConsumerStatefulWidget {
  const BasicsScreen({super.key});

  @override
  ConsumerState<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends ConsumerState<BasicsScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _headline = TextEditingController();
  final _roleText = TextEditingController();
  final _companyText = TextEditingController();
  String? _placeId;
  String? _tradeId;
  CompanyPick _company = const CompanyPick.none();
  var _filled = false;
  var _saving = false;
  var _showErrors = false;
  var _photoBusy = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _headline, _roleText, _companyText]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(ProfileView p, String lang) {
    if (_filled) return;
    _filled = true;
    _first.text = p.firstName;
    _last.text = p.lastName;
    _headline.text = p.headline ?? '';
    _placeId = p.placeId;
    _tradeId = p.tradeId;
    _roleText.text = p.tradeName?.of(Locale(lang)) ?? '';
    if (p.companyLabel != null) {
      _company = p.companyId != null
          ? CompanyPick.registered(
              CompanySummary(id: p.companyId!, name: p.companyLabel!),
            )
          : CompanyPick.typed(p.companyLabel!);
      _companyText.text = p.companyLabel!;
    }
  }

  Future<void> _pickPhoto() async {
    final me = myId(ref);
    if (me == null) return;
    final picked = await ref.read(photoPickerProvider)();
    if (!mounted) return;
    // Review 74 H1: a photo nobody could open doesn't go.
    if (picked.refused > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).photoCannotOpen)),
      );
    }
    final file = picked.photos.firstOrNull;
    if (file == null) return;
    setState(() => _photoBusy = true);
    try {
      final bytes = await file.readAsBytes();
      // Some pickers give no file name; default to JPEG.
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      await ref.read(profilePageRepositoryProvider).savePhoto(me, bytes, ext);
      if (mounted) afterSave(context, ref);
    } on Exception {
      if (mounted) showSaveError(context);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto(String path) async {
    final me = myId(ref);
    if (me == null) return;
    setState(() => _photoBusy = true);
    try {
      await ref.read(profilePageRepositoryProvider).removePhoto(me, path);
      if (mounted) afterSave(context, ref);
    } on Exception {
      if (mounted) showSaveError(context);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _pickRole(String marketId, String countryName) async {
    final picker = ref.read(rolePickerProvider(marketId)).value;
    final current = picker?.byId(_tradeId);
    final choice = await context.push<RoleChoice>(
      AppRoutes.onboardingRole,
      extra: RolePickerArgs(
        marketId: marketId,
        countryName: countryName,
        initial: current == null ? null : RoleChoice.trade(current),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _tradeId = choice.trade.id;
      _roleText.text = choice.trade.id == Trade.otherId
          ? (choice.customText ?? '')
          : choice.label(Localizations.localeOf(context).languageCode);
      // A typed role is the headline (it shows under the name).
      if (choice.customText != null) _headline.text = choice.customText!;
    });
  }

  Future<void> _pickCompany(String? marketId) async {
    final pick = await showCompanySheet(
      context,
      marketId: marketId,
      initialQuery: _company.name,
    );
    if (pick == null || !mounted) return;
    setState(() {
      _company = pick;
      _companyText.text = pick.name ?? '';
    });
  }

  Future<void> _save() async {
    final me = myId(ref);
    if (me == null) return;
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(profilePageRepositoryProvider)
          .saveBasics(
            me,
            BasicsInput(
              firstName: _first.text,
              lastName: _last.text,
              headline: _headline.text,
              placeId: _placeId,
              tradeId: _tradeId,
              companyId: _company.companyId,
              companyNameText: _company.companyId == null
                  ? _company.name
                  : null,
            ),
          );
      if (!mounted) return;
      afterSave(context, ref);
      context.pop();
    } on Exception {
      if (mounted) showSaveError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final me = myId(ref);
    final p = me == null ? null : ref.watch(profileViewProvider(me)).value;
    if (p != null) _fill(p, locale.languageCode);
    final markets = ref.watch(marketsProvider).value ?? const <Market>[];
    final market = markets.where((m) => m.id == p?.homeMarketId).firstOrNull;
    final places = market == null
        ? null
        : ref.watch(placesProvider(market.id)).value;

    return EntryScaffold(
      title: l10n.editBasics,
      footer: BvButton(
        key: const Key('basics-save'),
        label: l10n.save,
        expand: true,
        onPressed: _saving || p == null ? null : _save,
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s16,
              children: [
                Row(
                  spacing: BvSpace.s16,
                  children: [
                    BvAvatar(
                      name: p.fullName,
                      size: BvAvatarSize.lg,
                      image: p.photoUrl == null
                          ? null
                          : NetworkImage(p.photoUrl!),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: BvSpace.s8,
                        runSpacing: BvSpace.s8,
                        children: [
                          BvButton(
                            key: const Key('basics-photo'),
                            label: p.photoPath == null
                                ? l10n.addPhoto
                                : l10n.changePhoto,
                            icon: BvIcons.camera,
                            style: BvButtonStyle.secondary,
                            size: BvButtonSize.medium,
                            onPressed: _photoBusy ? null : _pickPhoto,
                          ),
                          if (p.photoPath != null)
                            BvButton(
                              key: const Key('basics-photo-remove'),
                              label: l10n.removePhoto,
                              style: BvButtonStyle.tertiary,
                              size: BvButtonSize.medium,
                              onPressed: _photoBusy
                                  ? null
                                  : () => _removePhoto(p.photoPath!),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s12,
                  children: [
                    Expanded(
                      child: BvTextField(
                        key: const Key('basics-first'),
                        label: l10n.firstName,
                        controller: _first,
                        error: _showErrors && _first.text.trim().isEmpty
                            ? l10n.firstNameRequired
                            : null,
                      ),
                    ),
                    Expanded(
                      child: BvTextField(
                        key: const Key('basics-last'),
                        label: l10n.lastName,
                        controller: _last,
                        error: _showErrors && _last.text.trim().isEmpty
                            ? l10n.lastNameRequired
                            : null,
                      ),
                    ),
                  ],
                ),
                BvTextField(
                  key: const Key('basics-headline'),
                  label: l10n.headline,
                  placeholder: l10n.headlineHint,
                  controller: _headline,
                  maxLength: 120,
                ),
                BvTextField(
                  key: const Key('basics-role'),
                  label: l10n.role,
                  placeholder: l10n.rolePlaceholder,
                  controller: _roleText,
                  readOnly: true,
                  suffixIcon: BvIcons.caretDown,
                  onTap: market == null
                      ? null
                      : () => _pickRole(market.id, market.name.of(locale)),
                ),
                BvTextField(
                  key: const Key('basics-company'),
                  label: l10n.companyOptional,
                  placeholder: l10n.companyPlaceholder,
                  controller: _companyText,
                  readOnly: true,
                  suffixIcon: BvIcons.caretDown,
                  onTap: () => _pickCompany(p.homeMarketId),
                ),
                if (places != null)
                  BvSelect<String>(
                    key: const Key('basics-place'),
                    label: l10n.placeOptional,
                    value: _placeId,
                    options: [
                      for (final pl in places)
                        BvSelectOption(value: pl.id, label: pl.name.of(locale)),
                    ],
                    onChanged: (v) => setState(() => _placeId = v),
                  ),
              ],
            ),
    );
  }
}

/// Places of a market, cities first.
final placesProvider =
    FutureProvider.family<
      List<({String id, LocalizedText name, bool isCity})>,
      String
    >(
      (ref, marketId) =>
          ref.watch(profilePageRepositoryProvider).places(marketId),
    );
