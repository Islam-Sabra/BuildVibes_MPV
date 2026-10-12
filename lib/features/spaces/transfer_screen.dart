import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_controls.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/entry_scaffold.dart';
import '../profile/widgets/profile_parts.dart';
import 'space_errors.dart';
import 'widgets/space_person_row.dart';

/// S15d · Transfer ownership: pick a member (one single choice), then
/// confirm (S15e). They become a Space admin; you stay as a member.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  SpaceMember? _chosen;
  var _busy = false;

  Future<void> _transfer(SpaceDetail space, SpaceMember to) async {
    final l10n = AppLocalizations.of(context);
    final name = to.person.fullName;
    final yes = await showBvDialog(
      context: context,
      title: l10n.spacesTransferTitle(name),
      body: l10n.spacesTransferBody(name, space.name),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.spacesTransferButton,
    );
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(spaceRepositoryProvider)
          .transferOwnership(widget.spaceId, to.person.id);
      ref
        ..invalidate(spaceDetailProvider(widget.spaceId))
        ..invalidate(spacePeopleProvider(widget.spaceId))
        ..invalidate(mySpacesProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.spacesTransferred(name))),
      );
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final people = ref.watch(spacePeopleProvider(widget.spaceId)).value;
    // Admins already are owners: only the other members can be chosen.
    final candidates = [
      for (final m in people?.members ?? const <SpaceMember>[])
        if (m.person.id != me && !m.isAdmin) m,
    ];
    final chosen = _chosen;

    return EntryScaffold(
      title: l10n.spacesTransfer,
      bodyPadding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s16),
      footer: BvButton(
        key: const Key('transfer-button'),
        label: chosen == null
            ? l10n.spacesTransfer
            : l10n.spacesTransferTo(chosen.person.fullName),
        expand: true,
        onPressed: chosen == null || space == null || _busy
            ? null
            : () => _transfer(space, chosen),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            child: EmptyNote(
              candidates.isEmpty && people != null
                  ? l10n.spacesNoOneToTransfer
                  : l10n.spacesTransferIntro,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < candidates.length; i++) ...[
                if (i > 0) const SpaceRowDivider(),
                SpacePersonRow(
                  key: Key('transfer-${candidates[i].person.id}'),
                  person: candidates[i].person,
                  line: joinMeta([
                    for (final t in people!.teamsOf(candidates[i].person.id))
                      t.name,
                  ]),
                  selected: candidates[i] == chosen,
                  trailing: BvRadio(selected: candidates[i] == chosen),
                  onTap: () => setState(() => _chosen = candidates[i]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
