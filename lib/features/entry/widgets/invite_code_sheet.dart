import 'package:flutter/material.dart';

import '../../../core/design/bv_tokens.dart';
import '../../../data/repositories/space_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_code_field.dart';
import '../../../shared/widgets/bv_sheet.dart';
import '../../spaces/code_sheet.dart'
    show InviteCodeFormatter, inviteCodeLength;

/// "I have an invite code" (OB1), and OB4's Change code (review 107 Q1):
/// the 6 boxes, always left to right, then Continue. Null when closed; the
/// code goes with sign-up, and the request to join is sent once the
/// account has a name and a work (OB5).
Future<String?> showInviteCodeSheet(BuildContext context) =>
    showBvSheet<String>(
      context: context,
      title: AppLocalizations.of(context).obInviteTitle,
      builder: (sheet) => const _InviteSheet(),
    );

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = normalizeInviteCode(_code.text);
    return Column(
      key: const Key('invite-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        Text(
          l10n.obInviteSub,
          style: BvType.of(
            context,
          ).bodyMd.copyWith(color: BvColors.textSecondary),
        ),
        BvCodeField(
          controller: _code,
          semanticLabel: l10n.spacesInviteCode,
          autofocus: true,
          inputFormatters: const [InviteCodeFormatter()],
        ),
        BvButton(
          key: const Key('invite-continue'),
          label: l10n.continueLabel,
          expand: true,
          onPressed: code.length == inviteCodeLength
              ? () => Navigator.of(context).pop(code)
              : null,
        ),
      ],
    );
  }
}
