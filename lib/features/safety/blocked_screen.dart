import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/safety_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';

/// S7: the people you blocked, with Unblock. Your own count is allowed.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final blocked = ref.watch(blockedProvider);

    Future<void> unblock(BlockedPerson p) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(safetyRepositoryProvider).block(p.id, false);
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
        return;
      }
      ref.invalidate(blockedProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.unblocked(inOwnDirection(p.fullName)))),
        );
    }

    final note = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s12,
        BvSpace.gutter,
        0,
      ),
      child: Text(
        l10n.blockedNote,
        style: type.bodySm.copyWith(color: BvColors.textSecondary),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedTitle), centerTitle: true),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(l10n.errorGeneric),
        ),
        data: (people) => ListView(
          key: const Key('blocked'),
          padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s16,
                BvSpace.gutter,
                BvSpace.s8,
              ),
              child: Text(
                people.isEmpty
                    ? l10n.blockedNone
                    : l10n.blockedCount(people.length),
                style: type.overline.copyWith(color: BvColors.textSecondary),
              ),
            ),
            if (people.isNotEmpty)
              BvListGroup(
                rows: [
                  for (final p in people)
                    BvListRow(
                      key: Key('blocked-${p.id}'),
                      leading: const BvRowIcon(BvIcons.profile),
                      title: inOwnDirection(p.fullName),
                      subtitle: p.headline,
                      trailing: BvRowTrailing.badge(
                        BvButton(
                          key: Key('unblock-${p.id}'),
                          label: l10n.unblock,
                          style: BvButtonStyle.tertiary,
                          size: BvButtonSize.medium,
                          onPressed: () => unblock(p),
                        ),
                      ),
                      onTap: () => context.push('${AppRoutes.people}/${p.id}'),
                    ),
                ],
              ),
            note,
          ],
        ),
      ),
    );
  }
}
