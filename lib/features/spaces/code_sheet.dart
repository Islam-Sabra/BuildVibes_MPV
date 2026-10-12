import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../profile/widgets/profile_parts.dart';
import 'space_errors.dart';

/// Invite codes are 6 characters.
const inviteCodeLength = 6;

/// "Enter an invite code" (review 06, 2b; no Figma frame). After 6
/// characters it shows the Space and who shared the code, then Ask to join.
Future<void> showInviteCodeSheet(BuildContext context) => showBvSheet<void>(
  context: context,
  title: AppLocalizations.of(context).spacesEnterCode,
  builder: (_) => const _CodeSheet(),
);

/// Upper case, Western digits, letters and digits only, at most 6. Pasted
/// codes with spaces or dashes ("K7Q 4MD") are cleaned up.
class InviteCodeFormatter extends TextInputFormatter {
  const InviteCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var code = normalizeInviteCode(newValue.text);
    if (code.length > inviteCodeLength) {
      code = code.substring(0, inviteCodeLength);
    }
    return TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }
}

class _CodeSheet extends ConsumerStatefulWidget {
  const _CodeSheet();

  @override
  ConsumerState<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends ConsumerState<_CodeSheet> {
  final _code = TextEditingController();
  InvitePreview? _preview;
  String? _error;
  var _busy = false;

  /// The code a preview or error belongs to, so a late answer for an old
  /// code is ignored.
  String _checked = '';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String code) async {
    if (code == _checked) return;
    setState(() {
      _preview = null;
      _error = null;
    });
    if (code.length < inviteCodeLength) {
      _checked = '';
      return;
    }
    _checked = code;
    final l10n = AppLocalizations.of(context);
    try {
      final preview = await ref
          .read(spaceRepositoryProvider)
          .invitePreview(code);
      if (!mounted || _checked != code) return;
      setState(() {
        _preview = preview;
        _error = preview == null ? l10n.spacesCodeNotValid : null;
      });
    } on SpaceException catch (e) {
      if (mounted && _checked == code) {
        setState(() => _error = spaceErrorText(l10n, e));
      }
    }
  }

  Future<void> _ask() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(spaceRepositoryProvider)
          .requestJoin(_code.text);
      if (!mounted) return;
      ref.invalidate(myJoinRequestsProvider);
      final navigator = Navigator.of(context);
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      void done(String message) {
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }

      switch (result.status) {
        case JoinStatus.requested:
          done(l10n.spacesRequestSent);
        case JoinStatus.pending:
          done(l10n.spacesAlreadyWaiting);
        case JoinStatus.member:
          navigator.pop();
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.spacesAlreadyMember)),
          );
          if (result.spaceId != null) {
            router.push(AppRoutes.space(result.spaceId!));
          }
        case JoinStatus.declined:
          setState(() => _error = l10n.spacesDeclinedWait);
        case JoinStatus.notValid:
          setState(() {
            _preview = null;
            _error = l10n.spacesCodeNotValid;
          });
        case JoinStatus.tooManyTries:
          setState(() {
            _preview = null;
            _error = l10n.spacesTooManyTries;
          });
      }
    } on SpaceException catch (e) {
      if (mounted) setState(() => _error = spaceErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    return Column(
      key: const Key('code-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('invite-code-field'),
          label: l10n.spacesInviteCode,
          helper: l10n.spacesCodeHint,
          error: _error,
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.characters,
          suggestions: false,
          textDirection: TextDirection.ltr,
          inputFormatters: const [InviteCodeFormatter()],
          valueStyle: BvType.of(context).titleLg,
          onChanged: _onChanged,
        ),
        if (preview != null)
          ProfileCard(
            padding: false,
            child: BvListRow(
              key: const Key('invite-preview'),
              leading: const BvRowIcon(BvIcons.team),
              title: preview.spaceName,
              subtitle: preview.invitedByName == null
                  ? null
                  : l10n.spacesInvitedBy(
                      inOwnDirection(preview.invitedByName!),
                    ),
              trailing: const BvRowTrailing.none(),
            ),
          ),
        BvButton(
          key: const Key('ask-to-join'),
          label: l10n.spacesAskToJoin,
          expand: true,
          onPressed: preview == null || _busy ? null : _ask,
        ),
      ],
    );
  }
}
