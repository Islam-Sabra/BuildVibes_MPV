import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/market.dart';
import '../../data/models/space.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/market_repository.dart';
import '../../data/repositories/safety_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/entry_state.dart';
import '../spaces/space_errors.dart';
import 'account_parts.dart';

/// S2 Account and security, MVP rows: Download my data and Delete account.
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountSecurity), centerTitle: true),
      body: ListView(
        key: const Key('account-security'),
        children: [
          SettingsHeader(l10n.accountYourData),
          BvListGroup(
            rows: [
              BvListRow(
                key: const Key('row-download'),
                leading: const BvRowIcon(BvIcons.download),
                title: l10n.downloadData,
                subtitle: l10n.downloadDataSub,
                onTap: () => context.push(AppRoutes.profileDownload),
              ),
            ],
          ),
          SettingsHeader(l10n.dangerZone),
          BvListGroup(
            rows: [
              BvListRow(
                key: const Key('row-delete'),
                leading: const BvRowIcon(BvIcons.delete, destructive: true),
                title: l10n.deleteAccount,
                subtitle: l10n.deleteAccountSub,
                destructive: true,
                onTap: () => context.push(AppRoutes.profileDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// S5 Privacy and safety, MVP: Blocked accounts (your own count is
/// allowed) and where Space work lives.
class PrivacySafetyScreen extends ConsumerWidget {
  const PrivacySafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(blockedProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacySafety), centerTitle: true),
      body: ListView(
        key: const Key('privacy-safety'),
        children: [
          SettingsHeader(l10n.privacySafetySection),
          BvListGroup(
            rows: [
              BvListRow(
                key: const Key('row-blocked'),
                leading: const BvRowIcon(BvIcons.block),
                title: l10n.blockedTitle,
                trailing: blocked == null || blocked.isEmpty
                    ? const BvRowTrailing.chevron()
                    : BvRowTrailing.value('${blocked.length}'),
                onTap: () => context.push(AppRoutes.profileBlocked),
              ),
            ],
          ),
          SettingsNote(l10n.privacyNote),
        ],
      ),
    );
  }
}

/// S8 Language and region: the app language (one single choice), the
/// country (live markets only), and the pack's week start, read-only.
class LanguageRegionScreen extends ConsumerWidget {
  const LanguageRegionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final market = ref.watch(myMarketProvider);
    final lang = locale.languageCode;

    Widget language(String code, String title, String description) =>
        BvChoiceCard(
          key: Key('language-$code'),
          icon: BvIcons.language,
          title: title,
          description: description,
          selected: lang == code,
          onTap: () =>
              ref.read(localeControllerProvider.notifier).set(Locale(code)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageRegion), centerTitle: true),
      body: ListView(
        key: const Key('language-region'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          SettingsHeader(l10n.settingsLanguageLabel),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            child: Column(
              spacing: BvSpace.s12,
              children: [
                language('en', l10n.languageEnglish, l10n.languageEnglishDir),
                language('ar', l10n.languageArabic, l10n.languageArabicDir),
              ],
            ),
          ),
          if (!guest) ...[
            SettingsHeader(l10n.regionSection),
            BvListGroup(
              rows: [
                BvListRow(
                  key: const Key('row-country'),
                  leading: const BvRowIcon(BvIcons.country),
                  title: l10n.regionCountry,
                  trailing: market == null
                      ? const BvRowTrailing.chevron()
                      : BvRowTrailing.value(market.name.of(locale)),
                  onTap: () => _pickCountry(context, ref, market),
                ),
                if (market != null)
                  BvListRow(
                    key: const Key('row-week-start'),
                    leading: const BvRowIcon(BvIcons.calendar),
                    title: l10n.regionWeekStart,
                    trailing: BvRowTrailing.badge(
                      Text(
                        weekdayName(market.weekStart, lang),
                        style: type.bodyMd.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SettingsNote(l10n.regionNote),
        ],
      ),
    );
  }

  Future<void> _pickCountry(
    BuildContext context,
    WidgetRef ref,
    Market? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final markets = liveMarkets(await ref.read(marketsProvider.future));
    if (!context.mounted) return;
    final picked = await showBvSheet<Market>(
      context: context,
      title: l10n.regionCountry,
      builder: (sheet) => BvChoiceList<Market>(
        value: current,
        options: [
          for (final m in markets)
            BvChoiceOption(
              key: Key('country-${m.id}'),
              value: m,
              title: m.name.of(locale),
            ),
        ],
        onChanged: (m) => Navigator.of(sheet).pop(m),
      ),
    );
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (picked == null || picked.id == current?.id || userId == null) return;
    try {
      await ref
          .read(accountRepositoryProvider)
          .setHomeMarket(userId, picked.id);
    } on SpaceException catch (e) {
      if (context.mounted) showSpaceError(context, e);
      return;
    }
    ref.invalidate(myProfileProvider);
  }
}

/// S10 Download my data, then S11 while a request is open.
class DownloadDataScreen extends ConsumerStatefulWidget {
  const DownloadDataScreen({super.key});

  @override
  ConsumerState<DownloadDataScreen> createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends ConsumerState<DownloadDataScreen> {
  var _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).requestMyData();
      ref.invalidate(dataRequestProvider);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final email = ltrRun(ref.watch(authRepositoryProvider).currentEmail ?? '');
    final request = ref.watch(dataRequestProvider);

    Widget body;
    if (request.isLoading && !request.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (request.value?.status == DataRequestStatus.open) {
      body = AccountResult(
        key: const Key('data-request-received'),
        icon: BvIcons.received,
        title: l10n.requestReceived,
        body: l10n.requestReceivedBody(email),
      );
    } else {
      BvListRow included(String key, IconData icon, String title) => BvListRow(
        key: Key(key),
        leading: BvRowIcon(icon),
        title: title,
        trailing: const BvRowTrailing.none(),
      );
      body = ListView(
        key: const Key('download-data'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          AccountIntro(heading: l10n.downloadHeading, body: l10n.downloadBody),
          SettingsHeader(l10n.downloadIncluded),
          BvListGroup(
            rows: [
              included('incl-profile', BvIcons.profile, l10n.downloadProfile),
              included('incl-posts', BvIcons.document, l10n.downloadPosts),
              included('incl-messages', BvIcons.chat, l10n.downloadMessages),
              included('incl-work', BvIcons.workItems, l10n.downloadWork),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s24,
              BvSpace.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s12,
              children: [
                BvButton(
                  key: const Key('download-request'),
                  label: l10n.downloadRequest,
                  expand: true,
                  onPressed: _busy ? null : _request,
                ),
                Text(
                  l10n.downloadFoot(email),
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadData), centerTitle: true),
      body: body,
    );
  }
}
