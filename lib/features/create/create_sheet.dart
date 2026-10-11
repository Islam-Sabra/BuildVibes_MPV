import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_sheet.dart';

/// Opened by the Create action in the bottom bar. Create is an action, not a
/// tab, so it opens over the current tab. The options come with the features
/// that own them (posts, Spaces, work items).
Future<void> showCreateSheet(BuildContext context) => showBvSheet(
  context: context,
  title: AppLocalizations.of(context).navCreate,
  builder: (_) => const CreateSheet(),
);

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).placeholderBody,
      key: const Key('create-sheet'),
      style: BvType.of(context).bodyMd.copyWith(color: BvColors.textSecondary),
    );
  }
}
