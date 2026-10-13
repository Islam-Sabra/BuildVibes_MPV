import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/safety_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../account/account_parts.dart';
import '../entry/entry_state.dart';
import '../settings/notifications_screen.dart';
import '../settings/push_host.dart';

/// S1 v2, MVP rows (brief 23 §3): who you are, your settings in words, the
/// account rows, support and Sign out (S15). In debug builds also the
/// Components gallery. Guests see language and support only.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final guest = ref.watch(appGateProvider) == AppGate.guest;
    final me = ref.watch(myProfileProvider).value;
    final market = ref.watch(myMarketProvider);
    final languageName = lang == 'ar'
        ? l10n.languageArabic
        : l10n.languageEnglish;

    // The words rows: the real settings, said in a sentence.
    final languageWords = market == null
        ? _Words(l10n.wordsLanguageOnly(_m1), [languageName])
        : _Words(
            l10n.wordsLanguage(
              _m1,
              weekdayName(market.weekStart, lang),
              market.name.of(Localizations.localeOf(context)),
            ),
            [languageName],
          );
    final blocked = guest ? null : ref.watch(blockedProvider).value;
    final push = guest ? null : ref.watch(pushSettingsProvider).value;
    String onOff(bool on) => on ? l10n.wordsOn : l10n.wordsOff;

    final support = market?.supportEmail;

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
            SettingsHeader(l10n.settingsInWords),
            _WordsGroup(
              rows: [
                if (!guest)
                  _WordsRow(
                    key: const Key('words-privacy'),
                    label: l10n.settingsPrivacyLabel,
                    words: blocked == null
                        ? null
                        : _Words(l10n.wordsPrivacy(_m1), [
                            blocked.isEmpty
                                ? l10n.blockedNone
                                : l10n.wordsBlocked(blocked.length),
                          ]),
                    onTap: () => context.push(AppRoutes.profilePrivacy),
                  ),
                if (!guest)
                  _WordsRow(
                    key: const Key('words-notifications'),
                    label: l10n.settingsNotificationsLabel,
                    words: push == null
                        ? null
                        : _Words(l10n.wordsNotifications(_m1, _m2, _m3), [
                            onOff(push.followers),
                            onOff(push.replies),
                            push.messageText
                                ? l10n.wordsShown
                                : l10n.wordsHidden,
                          ]),
                    onTap: () => context.push(AppRoutes.profileNotifications),
                  ),
                _WordsRow(
                  key: const Key('words-language'),
                  label: l10n.settingsLanguageLabel,
                  words: languageWords,
                  onTap: () => context.push(AppRoutes.profileRegion),
                ),
              ],
            ),
            SettingsHeader(l10n.settingsAccountSection),
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
                  title: l10n.languageRegion,
                  trailing: BvRowTrailing.value(languageName),
                  onTap: () => context.push(AppRoutes.profileRegion),
                ),
              ],
            ),
            SettingsHeader(l10n.supportSection),
            BvListGroup(
              rows: [
                if (support != null)
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
                if (kDebugMode)
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

// Stand-ins for the highlighted words; they never reach the screen.
const _m1 = '\u{E001}';
const _m2 = '\u{E002}';
const _m3 = '\u{E003}';
const _marks = [_m1, _m2, _m3];

/// A sentence from an ARB string with stand-ins, and the words that go in
/// their place, highlighted.
class _Words {
  const _Words(this.text, this.values);

  final String text;
  final List<String> values;

  List<InlineSpan> spans(TextStyle highlight) {
    final out = <InlineSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      var at = -1;
      var which = -1;
      for (var i = 0; i < values.length; i++) {
        final j = rest.indexOf(_marks[i]);
        if (j >= 0 && (at < 0 || j < at)) {
          at = j;
          which = i;
        }
      }
      if (at < 0) {
        out.add(TextSpan(text: rest));
        break;
      }
      if (at > 0) out.add(TextSpan(text: rest.substring(0, at)));
      out.add(TextSpan(text: values[which], style: highlight));
      rest = rest.substring(at + _marks[which].length);
    }
    return out;
  }
}

class _WordsGroup extends StatelessWidget {
  const _WordsGroup({required this.rows});

  final List<_WordsRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const ColoredBox(
              color: BvColors.surfaceElevated,
              child: Divider(
                height: BvStroke.thin,
                thickness: BvStroke.thin,
                color: BvColors.borderDefault,
              ),
            ),
          rows[i],
        ],
      ],
    );
  }
}

/// S1 "Your settings, in words": a label, the sentence, a chevron.
class _WordsRow extends StatelessWidget {
  const _WordsRow({
    super.key,
    required this.label,
    required this.words,
    required this.onTap,
  });

  final String label;

  /// Null while the settings load.
  final _Words? words;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Material(
      color: BvColors.surfaceElevated,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvSpace.gutter,
            vertical: BvSpace.s16,
          ),
          child: Row(
            spacing: BvSpace.s12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s4,
                  children: [
                    Text(
                      label,
                      style: type.overline.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children:
                            words?.spans(
                              type.bodyMd.copyWith(color: BvColors.textAction),
                            ) ??
                            const [TextSpan(text: '')],
                      ),
                      style: type.bodyMd.copyWith(color: BvColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const Icon(
                BvIcons.caretForward,
                size: BvSize.iconMd,
                color: BvColors.iconSecondary,
              ),
            ],
          ),
        ),
      ),
    );
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
    if (terms == null && privacy == null) {
      return Text(
        l10n.legalSoon,
        key: const Key('legal-soon'),
        style: BvType.of(
          context,
        ).bodyMd.copyWith(color: BvColors.textSecondary),
      );
    }
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
