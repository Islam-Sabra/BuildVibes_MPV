import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';

/// Opened by the Create action in the bottom bar. Create is an action, not a
/// tab, so it opens over the current tab. The options come with the features
/// that own them (posts, Spaces, work items).
Future<void> showCreateSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  useRootNavigator: true,
  builder: (_) => const CreateSheet(),
);

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          BvSpace.s8,
          BvSpace.gutter,
          BvSpace.s24,
        ),
        child: Column(
          key: const Key('create-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.navCreate, style: type.headingMd),
            const SizedBox(height: BvSpace.s8),
            Text(
              l10n.placeholderBody,
              style: type.bodyMd.copyWith(color: BvColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
