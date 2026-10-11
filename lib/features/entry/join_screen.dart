import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import 'entry_errors.dart';
import 'entry_state.dart';
import 'welcome_screen.dart';
import 'widgets/entry_hero.dart';

/// E2 · Join or sign in. Phone first; Google and Apple appear once their
/// keys exist (AppConfig.socialSignIn); LinkedIn is not in the MVP.
class JoinScreen extends ConsumerWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final country = entryMarket(ref)?.name.of(Localizations.localeOf(context));

    Future<void> social(SocialProvider provider) async {
      try {
        await ref.read(authRepositoryProvider).signInWith(provider);
      } on AuthFailureException catch (e) {
        if (context.mounted) showEntryError(context, e.failure);
      }
    }

    final socialButtons = [
      if (AppConfig.socialSignIn) ...[
        (l10n.entryGoogle, BvIcons.google, () => social(SocialProvider.google)),
        (l10n.entryApple, BvIcons.apple, () => social(SocialProvider.apple)),
      ],
      if (AppConfig.linkedInSignIn)
        (l10n.entryLinkedIn, BvIcons.linkedIn, () {}),
    ];

    return Scaffold(
      body: Column(
        children: [
          EntryHero(countryName: country),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BvSpace.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.entryJoinTitle,
                    textAlign: TextAlign.center,
                    style: type.headingMd,
                  ),
                  const SizedBox(height: BvSpace.s8),
                  Text(
                    l10n.entryJoinBody,
                    textAlign: TextAlign.center,
                    style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                  ),
                  const SizedBox(height: BvSpace.s16),
                  const _SampleProfileCard(),
                  const SizedBox(height: BvSpace.s16),
                  BvButton(
                    key: const Key('join-phone'),
                    label: l10n.entryContinuePhone,
                    expand: true,
                    onPressed: () => context.push(AppRoutes.joinPhone),
                  ),
                  if (socialButtons.isNotEmpty) ...[
                    const SizedBox(height: BvSpace.s16),
                    Text(
                      l10n.entryOrContinueWith,
                      textAlign: TextAlign.center,
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: BvSpace.s12),
                    Row(
                      key: const Key('join-social'),
                      spacing: BvSpace.s8,
                      children: [
                        for (final (label, icon, onTap) in socialButtons)
                          Expanded(
                            child: BvButton(
                              label: label,
                              icon: icon,
                              style: BvButtonStyle.secondary,
                              size: BvButtonSize.large,
                              expand: true,
                              onPressed: onTap,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: BvSpace.s8),
                  Center(
                    child: BvButton(
                      key: const Key('join-email'),
                      label: l10n.entryUseEmail,
                      style: BvButtonStyle.tertiary,
                      onPressed: () => context.push(AppRoutes.joinEmail),
                    ),
                  ),
                  const SizedBox(height: BvSpace.s8),
                  Text(
                    l10n.entryNoPassword,
                    textAlign: TextAlign.center,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                  const SizedBox(height: BvSpace.s8),
                  Text(
                    l10n.entryTerms,
                    textAlign: TextAlign.center,
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s8),
              child: BvButton(
                key: const Key('join-browse'),
                label: l10n.entryJustLooking,
                style: BvButtonStyle.tertiary,
                onPressed: () {
                  ref.read(guestModeProvider.notifier).enter();
                  context.go(AppRoutes.home);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An illustration of what a profile with confirmed work looks like.
class _SampleProfileCard extends StatelessWidget {
  const _SampleProfileCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsetsDirectional.all(BvSpace.s16),
        decoration: const BoxDecoration(
          color: BvColors.surfaceElevated,
          borderRadius: BvRadius.cardAll,
          boxShadow: BvShadow.sheet,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSpace.s12,
          children: [
            Row(
              spacing: BvSpace.s12,
              children: [
                BvAvatar(name: l10n.entrySampleName, size: BvAvatarSize.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.entrySampleName, style: type.titleMd),
                      Text(
                        l10n.entrySampleRole,
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            BvBadge(
              label: l10n.entrySampleBadge,
              tone: BvBadgeTone.positive,
              icon: BvIcons.confirmed,
            ),
          ],
        ),
      ),
    );
  }
}
