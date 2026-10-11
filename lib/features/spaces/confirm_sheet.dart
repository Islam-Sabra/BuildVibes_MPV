import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_pass_card.dart';
import '../../shared/widgets/bv_sheet.dart';
import 'pass_words.dart';

/// What the admin chose in the confirm sheet.
sealed class ConfirmChoice {
  const ConfirmChoice();
}

class ConfirmWithPass extends ConfirmChoice {
  const ConfirmWithPass(this.pass);
  final SpacePass pass;
}

class DeclineRequest extends ConfirmChoice {
  const DeclineRequest();
}

/// S10k-C · Confirm a member: the request, three passes (one single
/// choice, nothing chosen first), then Decline or "Confirm as {pass}".
/// Teams can be set later on the member's pass (S17k).
Future<ConfirmChoice?> showConfirmSheet(
  BuildContext context, {
  required SpaceJoinRequest request,
  required String askedLine,
}) => showBvSheet<ConfirmChoice>(
  context: context,
  builder: (_) => _ConfirmSheet(request: request, askedLine: askedLine),
);

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.request, required this.askedLine});

  final SpaceJoinRequest request;
  final String askedLine;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  SpacePass? _pass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final person = widget.request.person;
    final pass = _pass;

    return Column(
      key: const Key('confirm-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s12,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvRadius.cardAll,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(BvSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s4,
              children: [
                Text(person.fullName, style: type.titleMd),
                if (joinMeta([
                  ?person.roleLabel(lang),
                  ?person.companyLabel,
                ]).isNotEmpty)
                  Text(
                    joinMeta([?person.roleLabel(lang), ?person.companyLabel]),
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
                Text(
                  widget.askedLine,
                  style: type.metadata.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        Text(
          l10n.spacesGivePass,
          style: type.overline.copyWith(color: BvColors.textSecondary),
        ),
        for (final p in SpacePass.values)
          BvPassCard(
            key: Key('confirm-pass-${p.name}'),
            kind: passKind(p),
            opens: passOpens(l10n, p),
            forWho: passFor(l10n, p),
            selected: p == pass,
            onTap: () => setState(() => _pass = p),
          ),
        Row(
          spacing: BvSpace.s12,
          children: [
            Expanded(
              child: BvButton(
                key: const Key('confirm-sheet-decline'),
                label: l10n.spacesDecline,
                style: BvButtonStyle.secondary,
                expand: true,
                onPressed: () =>
                    Navigator.of(context).pop(const DeclineRequest()),
              ),
            ),
            Expanded(
              child: BvButton(
                key: const Key('confirm-sheet-confirm'),
                label: pass == null
                    ? l10n.spacesConfirm
                    : l10n.spacesConfirmAs(passName(l10n, pass)),
                expand: true,
                onPressed: pass == null
                    ? null
                    : () => Navigator.of(context).pop(ConfirmWithPass(pass)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
