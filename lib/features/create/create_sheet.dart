import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../spaces/code_sheet.dart';

/// Opened by Create in the My Spaces header (S1). The Create tab itself
/// opens the composer (C1 v2).
Future<void> showSpacesCreateSheet(BuildContext context) => showBvSheet(
  context: context,
  title: AppLocalizations.of(context).navCreate,
  builder: (_) => const CreateSheet(),
);

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The sheet closes first; then the choice opens from the page below.
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    return ClipRRect(
      key: const Key('create-sheet'),
      borderRadius: BvRadius.cardAll,
      child: BvListGroup(
        rows: [
          BvListRow(
            key: const Key('create-new-space'),
            leading: const BvRowIcon(BvIcons.crane),
            title: l10n.spacesNewTitle,
            onTap: () {
              navigator.pop();
              router.push(AppRoutes.spacesNew);
            },
          ),
          BvListRow(
            key: const Key('create-enter-code'),
            leading: const BvRowIcon(BvIcons.team),
            title: l10n.spacesEnterCode,
            onTap: () {
              final page = navigator.context;
              navigator.pop();
              showInviteCodeSheet(page);
            },
          ),
        ],
      ),
    );
  }
}
