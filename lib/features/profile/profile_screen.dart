import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/profile_page_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_pill_button.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/join_wall.dart';
import 'widgets/profile_body.dart';
import 'widgets/profile_parts.dart';

/// R1 · Your own profile. Guests see a prompt to join instead.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final guest = ref.watch(appGateProvider) == AppGate.guest;

    final settings = IconButton(
      key: const Key('profile-settings'),
      tooltip: l10n.settingsTitle,
      icon: const Icon(BvIcons.settings),
      onPressed: () => context.push(AppRoutes.profileSettings),
    );

    if (guest || me == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navProfile), actions: [settings]),
        body: ListView(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          children: [
            Column(
              key: const Key('guest-card'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BvSpace.s12,
              children: [
                Text(l10n.guestProfileTitle, style: type.titleLg),
                Text(
                  l10n.joinWallBody,
                  style: type.bodyMd.copyWith(color: BvColors.textSecondary),
                ),
                const JoinButtons(),
              ],
            ),
          ],
        ),
      );
    }

    final profile = ref.watch(profileViewProvider(me));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navProfile),
        backgroundColor: BvColors.surfaceApp,
        actions: [
          // R1 v3: My Spaces (S1).
          IconButton(
            key: const Key('profile-spaces'),
            tooltip: l10n.homeMySpaces,
            icon: const Icon(BvIcons.team),
            onPressed: () => context.push(AppRoutes.spaces),
          ),
          settings,
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: BvButton(
            label: l10n.commonRetry,
            style: BvButtonStyle.secondary,
            onPressed: () => ref.invalidate(profileViewProvider(me)),
          ),
        ),
        data: (p) => p == null
            ? Center(child: EmptyNote(l10n.profileNotFound))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(profileViewProvider(me)),
                child: ListView(
                  key: const Key('my-profile'),
                  children: [
                    ProfileHeader(
                      profile: p,
                      showFollowing: true,
                      // Share waits for a web page that opens profiles.
                      actions: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: BvPillButton(
                          key: const Key('profile-edit'),
                          label: l10n.profileEdit,
                          onTap: () => context.push(AppRoutes.profileEdit),
                        ),
                      ),
                    ),
                    ProfileBody(profile: p, own: true),
                  ],
                ),
              ),
      ),
    );
  }
}
