import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/bv_tokens.dart';
import '../../../core/routing/app_routes.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_sheet.dart';
import '../entry_state.dart';

/// The join wall (prototype H7): a guest tried something that needs an
/// account.
Future<void> showJoinWall(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showBvSheet(
    context: context,
    title: l10n.joinWallTitle,
    subtitle: l10n.joinWallBody,
    builder: (_) => const JoinButtons(),
  );
}

/// Create account and Sign in, which leave guest mode for the email code
/// (review 107: the two are the same), over the welcome.
class JoinButtons extends ConsumerWidget {
  const JoinButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void join() {
      ref.read(guestModeProvider.notifier).leave();
      final router = GoRouter.of(context);
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
      router
        ..go(AppRoutes.welcome)
        ..push(AppRoutes.joinEmail);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s8,
      children: [
        BvButton(
          key: const Key('join-create'),
          label: l10n.entryCreateAccount,
          expand: true,
          onPressed: join,
        ),
        BvButton(
          key: const Key('join-sign-in'),
          label: l10n.entrySignIn,
          style: BvButtonStyle.secondary,
          expand: true,
          onPressed: join,
        ),
      ],
    );
  }
}
