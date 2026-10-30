import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/routing/app_routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import 'entry_state.dart';
import 'widgets/invite_code_sheet.dart';

/// OB1 · Welcome (review 107, 2698:38995): one screen. The language at the
/// top; the whole industry (four role cards, each with a real piece of
/// work); one line; then Continue with email, I have an invite code, and
/// Just looking. Signing in and creating an account are the same email
/// code.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final code = await showInviteCodeSheet(context);
    if (code == null || !context.mounted) return;
    ref.read(inviteCodeProvider.notifier).set(code);
    unawaited(context.push(AppRoutes.joinEmail));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final invite = ref.watch(inviteCodeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BvSpace.gutter,
                  BvSpace.s8,
                  BvSpace.gutter,
                  0,
                ),
                child: _LanguageButton(
                  label: arabic ? l10n.languageEnglish : l10n.languageArabic,
                  onTap: () => ref
                      .read(localeControllerProvider.notifier)
                      .set(Locale(arabic ? 'en' : 'ar')),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.gutter,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: BvSpace.s24),
                    const _RoleCards(),
                    const SizedBox(height: BvSpace.s24),
                    Text(
                      l10n.appTitle,
                      style: type.labelLg.copyWith(color: BvColors.textAction),
                    ),
                    const SizedBox(height: BvSpace.s8),
                    Text(
                      l10n.obWelcomeTitle,
                      textAlign: TextAlign.center,
                      style: type.titleLg,
                    ),
                    const SizedBox(height: BvSpace.s8),
                    Text(
                      l10n.obWelcomeLine,
                      textAlign: TextAlign.center,
                      style: type.bodyMd.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                    if (invite != null && invite.isNotEmpty) ...[
                      const SizedBox(height: BvSpace.s12),
                      Text(
                        l10n.obInviteKept(ltrRun(invite)),
                        key: const Key('welcome-invite-kept'),
                        style: type.labelMd.copyWith(
                          color: BvColors.textAction,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s12,
                BvSpace.gutter,
                BvSpace.s8,
              ),
              child: Column(
                spacing: BvSpace.s8,
                children: [
                  BvButton(
                    key: const Key('welcome-email'),
                    label: l10n.entryContinueEmail,
                    expand: true,
                    onPressed: () => context.push(AppRoutes.joinEmail),
                  ),
                  BvButton(
                    key: const Key('welcome-invite'),
                    label: l10n.obHaveInvite,
                    style: BvButtonStyle.secondary,
                    expand: true,
                    onPressed: () => unawaited(_invite(context, ref)),
                  ),
                  BvButton(
                    key: const Key('welcome-look'),
                    label: l10n.obJustLooking,
                    style: BvButtonStyle.tertiary,
                    onPressed: () {
                      ref.read(guestModeProvider.notifier).enter();
                      context.go(AppRoutes.home);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The other language, at the top end: "العربية" in English, "English" in
/// Arabic.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: BvColors.surfaceElevated,
      shape: const StadiumBorder(
        side: BorderSide(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: InkWell(
        key: const Key('welcome-language'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvEntrySpec.languagePaddingHorizontal,
            vertical: BvEntrySpec.languagePaddingVertical,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s6,
            children: [
              Text(label, style: BvType.of(context).labelMd),
              const Icon(
                BvIcons.language,
                size: BvSize.iconMd,
                color: BvColors.iconPrimary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The whole industry, as four role cards that lie on the stage at a
/// slight turn, each with a real piece of work.
class _RoleCards extends StatelessWidget {
  const _RoleCards();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final cards = [
      (
        BvIcons.ruler,
        BvColors.surfaceSelected,
        l10n.obCardArchitect,
        l10n.obCardArchitectWork,
      ),
      (
        BvIcons.calendar,
        BvAvatarTints.ochre,
        l10n.obCardProjectManager,
        l10n.obCardProjectManagerWork,
      ),
      (
        BvIcons.truck,
        BvAvatarTints.green,
        l10n.obCardSupplier,
        l10n.obCardSupplierWork,
      ),
      (
        BvIcons.workChecked,
        BvAvatarTints.clay,
        l10n.obCardSiteEngineer,
        l10n.obCardSiteEngineerWork,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: BvEntrySpec.cardsHeight,
        child: Stack(
          children: [
            for (final (i, (icon, tint, role, work)) in cards.indexed)
              PositionedDirectional(
                start: box.maxWidth * BvEntrySpec.roleCards[i].$1,
                top: BvEntrySpec.roleCards[i].$2,
                child: Transform.rotate(
                  // Mirrored in Arabic, as the cards are.
                  angle:
                      (rtl ? -1 : 1) *
                      BvEntrySpec.roleCards[i].$3 *
                      math.pi /
                      180,
                  child: _RoleCard(
                    icon: icon,
                    tint: tint,
                    role: role,
                    work: work,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.tint,
    required this.role,
    required this.work,
  });

  final IconData icon;
  final Color tint;
  final String role;
  final String work;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(BvEntrySpec.roleCardPadding),
      decoration: const BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        boxShadow: BvShadow.sheet,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s12,
        children: [
          Container(
            width: BvEntrySpec.roleIconTile,
            height: BvEntrySpec.roleIconTile,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BvRadius.smallAll,
            ),
            child: Icon(icon, size: BvSize.iconSm, color: BvColors.iconPrimary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                role,
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
              Text(work, style: type.labelLg),
            ],
          ),
        ],
      ),
    );
  }
}
