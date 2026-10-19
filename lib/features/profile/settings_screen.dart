import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/build_info.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../account/account_parts.dart';
import '../entry/entry_state.dart';
import '../settings/push_host.dart';

/// The developer rows (the Components gallery): debug builds only, never
/// in a release or profile build. Tests override it to check both.
final devToolsProvider = Provider<bool>((ref) => kDebugMode);

/// S1 v2, MVP rows (brief 23 §3, review 54 A5): who you are, then one
/// list with each entry once (Account and security, Notifications, Privacy
/// and safety, Language, About BuildVibes and legal) and Sign out (S15).
/// Help and feedback (the pack's support email) is in the About sheet. In
/// debug builds only, also the Components gallery ([devToolsProvider]).
/// Guests see Language and About only.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final me = ref.watch(myProfileProvider).value;
    final languageName = lang == 'ar'
        ? l10n.languageArabic
        : l10n.languageEnglish;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle), centerTitle: true),
      // A short, fixed list: built whole, not lazily.
      body: SingleChildScrollView(
        key: const Key('settings'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!guest && me != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BvSpace.gutter,
                  BvSpace.s16,
                  BvSpace.gutter,
                  0,
                ),
                child: Row(
                  spacing: BvSpace.s8,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: BvSpace.s4,
                        children: [
                          Text(
                            inOwnDirection(
                              '${me.firstName} ${me.lastName}'.trim(),
                            ),
                            style: type.headingMd,
                          ),
                          if ([
                            me.roleLabel(lang),
                            me.companyLabel,
                          ].whereType<String>().isNotEmpty)
                            Text(
                              [me.roleLabel(lang), me.companyLabel]
                                  .whereType<String>()
                                  .map(inOwnDirection)
                                  .join(' · '),
                              style: type.bodySm.copyWith(
                                color: BvColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    BvButton(
                      key: const Key('settings-view-profile'),
                      label: l10n.settingsViewProfile,
                      style: BvButtonStyle.tertiary,
                      size: BvButtonSize.medium,
                      padded: false,
                      onPressed: () => context.go(AppRoutes.profile),
                    ),
                  ],
                ),
              ),
            // One list, each entry once (review 54 A5).
            const SizedBox(height: BvSpace.s16),
            BvListGroup(
              rows: [
                if (!guest)
                  BvListRow(
                    key: const Key('row-account'),
                    leading: const BvRowIcon(BvIcons.security),
                    title: l10n.accountSecurity,
                    subtitle: l10n.accountSecuritySub,
                    onTap: () => context.push(AppRoutes.profileAccount),
                  ),
                if (!guest)
                  BvListRow(
                    key: const Key('row-notifications'),
                    leading: const BvRowIcon(BvIcons.notifications),
                    title: l10n.settingsNotifications,
                    onTap: () => context.push(AppRoutes.profileNotifications),
                  ),
                if (!guest)
                  BvListRow(
                    key: const Key('row-privacy'),
                    leading: const BvRowIcon(BvIcons.lock),
                    title: l10n.privacySafety,
                    subtitle: l10n.blockedTitle,
                    onTap: () => context.push(AppRoutes.profilePrivacy),
                  ),
                BvListRow(
                  key: const Key('row-language'),
                  leading: const BvRowIcon(BvIcons.language),
                  title: l10n.settingsLanguageRow,
                  trailing: BvRowTrailing.value(languageName),
                  onTap: () => context.push(AppRoutes.profileRegion),
                ),
                BvListRow(
                  key: const Key('row-about'),
                  leading: const BvRowIcon(BvIcons.about),
                  title: l10n.aboutLegal,
                  subtitle: l10n.aboutLegalSub,
                  onTap: () => showBvSheet<void>(
                    context: context,
                    title: l10n.aboutLegal,
                    builder: (_) => const _LegalSheet(),
                  ),
                ),
                if (ref.watch(devToolsProvider))
                  BvListRow(
                    key: const Key('row-components'),
                    leading: const BvRowIcon(BvIcons.settings),
                    title: l10n.componentsGallery,
                    onTap: () => context.push(AppRoutes.components),
                  ),
              ],
            ),
            if (!guest) ...[
              const SizedBox(height: BvSpace.s16),
              BvListGroup(
                rows: [
                  BvListRow(
                    key: const Key('row-sign-out'),
                    leading: const BvRowIcon(BvIcons.signOut),
                    title: l10n.signOut,
                    trailing: const BvRowTrailing.none(),
                    onTap: () => _signOut(context, ref),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// S15: no passwords, so the dialog says a code is needed to come back.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.signOutTitle,
      body: l10n.signOutBody,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.signOut,
    );
    if (!yes) return;
    // This phone stops getting pushes for the account first.
    await unregisterPush(ref);
    await ref.read(authRepositoryProvider).signOut();
  }
}

/// About BuildVibes and legal: the pack's Terms and Privacy links, or a
/// note while the pages are being written.
class _LegalSheet extends ConsumerWidget {
  const _LegalSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final market = ref.watch(myMarketProvider);
    final terms = market?.legalLink('terms', locale);
    final privacy = market?.legalLink('privacy', locale);
    final build = ref.watch(buildInfoProvider).value;
    final support = market?.supportEmail;
    final legal = terms == null && privacy == null
        ? Text(
            l10n.legalSoon,
            key: const Key('legal-soon'),
            style: BvType.of(
              context,
            ).bodyMd.copyWith(color: BvColors.textSecondary),
          )
        : _legalLinks(context, ref, l10n, terms, privacy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s16,
      children: [
        legal,
        // Help and feedback: the pack's support email (review 54 A5 keeps
        // Settings to one list; it moved here from its own section).
        if (support != null)
          ClipRRect(
            borderRadius: BvRadius.cardAll,
            child: BvListGroup(
              rows: [
                BvListRow(
                  key: const Key('row-help'),
                  leading: const BvRowIcon(BvIcons.help),
                  title: l10n.helpFeedback,
                  subtitle: ltrRun(support),
                  onTap: () => openLink(
                    context,
                    ref,
                    Uri(scheme: 'mailto', path: support),
                  ),
                ),
              ],
            ),
          ),
        // Which build is on this phone (review 53 Part D).
        if (build != null)
          Text(
            l10n.aboutBuild(
              ltrRun(build.version),
              ltrRun(build.build),
              ltrRun(build.commit),
            ),
            key: const Key('about-build'),
            style: BvType.of(
              context,
            ).metadata.copyWith(color: BvColors.textSecondary),
          ),
      ],
    );
  }

  Widget _legalLinks(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Uri? terms,
    Uri? privacy,
  ) {
    return ClipRRect(
      borderRadius: BvRadius.cardAll,
      child: BvListGroup(
        rows: [
          if (terms != null)
            BvListRow(
              key: const Key('legal-terms'),
              title: l10n.legalTerms,
              onTap: () => openLink(context, ref, terms),
            ),
          if (privacy != null)
            BvListRow(
              key: const Key('legal-privacy'),
              title: l10n.legalPrivacy,
              onTap: () => openLink(context, ref, privacy),
            ),
        ],
      ),
    );
  }
}
