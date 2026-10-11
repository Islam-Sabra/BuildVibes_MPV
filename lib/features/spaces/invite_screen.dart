import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/months.dart';
import '../../core/share.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_code_tag.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../entry/widgets/entry_scaffold.dart';
import '../profile/widgets/profile_parts.dart';
import 'space_errors.dart';

/// S16 · Invite people, MVP version: the invite code only. No people
/// search, no Suggested and no link (they need the web page; review 06).
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final space = ref.watch(spaceDetailProvider(spaceId)).value;
    final invite = ref.watch(spaceInviteProvider(spaceId));
    final code = invite.value;

    Future<void> share(SpaceInvite code) => ref.read(shareTextProvider)(
      l10n.spacesShareText(space?.name ?? '', code.code),
    );

    Future<void> renew() async {
      final yes = await showBvSheet<bool>(
        context: context,
        title: l10n.spacesNewCodeTitle,
        footer: BvSheetFooter(
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.spacesNewCode,
          onConfirm: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
        builder: (sheetContext) => Text(
          l10n.spacesNewCodeNote,
          style: BvType.of(
            sheetContext,
          ).bodyMd.copyWith(color: BvColors.textSecondary),
        ),
      );
      if (yes != true) return;
      try {
        await ref.read(spaceRepositoryProvider).renewInvite(spaceId);
        ref.invalidate(spaceInviteProvider(spaceId));
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    return EntryScaffold(
      title: l10n.spacesInviteTitle(space?.name ?? ''),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          if (invite.hasError)
            EmptyNote(
              invite.error is SpaceException
                  ? spaceErrorText(l10n, invite.error! as SpaceException)
                  : l10n.errorGeneric,
            )
          else if (code == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            BvCodeTag(
              key: const Key('invite-code'),
              label: l10n.spacesInviteCodeTag,
              code: code.grouped,
              note: l10n.spacesCodeWorksUntil(
                formatDay(code.expiresAt.toLocal(), locale),
              ),
            ),
            Text(
              l10n.spacesInviteHow,
              style: type.bodyMd.copyWith(color: BvColors.textSecondary),
            ),
            BvButton(
              key: const Key('invite-share'),
              label: l10n.spacesShareCode,
              icon: BvIcons.share,
              expand: true,
              onPressed: () => share(code),
            ),
            if (space?.iAmAdmin ?? false)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s8,
                children: [
                  BvButton(
                    key: const Key('invite-new-code'),
                    label: l10n.spacesNewCode,
                    style: BvButtonStyle.secondary,
                    expand: true,
                    onPressed: renew,
                  ),
                  Text(
                    l10n.spacesNewCodeNote,
                    textAlign: TextAlign.center,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
