import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_tokens.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import 'entry_state.dart';

/// Shown while the app finds out who is signed in, or when the profile
/// could not be loaded (offline).
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final failed = ref.watch(appGateProvider) == AppGate.profileError;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: BvSpace.s16,
            children: [
              Text(
                l10n.appTitle,
                style: BvType.latin.displayBrand.copyWith(
                  color: BvColors.brandInk,
                ),
              ),
              if (!failed)
                const CircularProgressIndicator()
              else ...[
                Text(
                  l10n.errorNetwork,
                  key: const Key('loading-error'),
                  textAlign: TextAlign.center,
                  style: BvType.of(context).bodyMd,
                ),
                BvButton(
                  label: l10n.commonRetry,
                  onPressed: () => ref.invalidate(myProfileProvider),
                ),
                BvButton(
                  label: l10n.signOut,
                  style: BvButtonStyle.tertiary,
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
