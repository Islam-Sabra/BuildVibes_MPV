import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_code_field.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../entry/widgets/onboarding_scaffold.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/code_sheet.dart' show InviteCodeFormatter, inviteCodeLength;
import '../spaces/space_errors.dart';

/// OB6 · Join your Space (review 107, 2699:39123; step 3 of 3). The 6
/// boxes of the invite code you were given (always left to right); six
/// characters show the Space it opens. Ask to join sends the request (the
/// Space's admin confirms it), then Home; Skip for now goes Home.
class JoinSpaceScreen extends ConsumerStatefulWidget {
  const JoinSpaceScreen({super.key});

  @override
  ConsumerState<JoinSpaceScreen> createState() => _JoinSpaceScreenState();
}

class _JoinSpaceScreenState extends ConsumerState<JoinSpaceScreen> {
  final _code = TextEditingController();
  InvitePreview? _preview;
  String? _error;
  var _sending = false;

  /// The code a preview or error belongs to, so a late answer for an old
  /// code is ignored.
  String _checked = '';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String typed) async {
    final code = normalizeInviteCode(typed);
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
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(spaceRepositoryProvider)
          .requestJoin(_checked);
      if (!mounted) return;
      ref.invalidate(myJoinRequestsProvider);
      void home(String message) {
        router.go(AppRoutes.home);
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }

      switch (result.status) {
        case JoinStatus.requested:
          home(l10n.spacesRequestSent);
        case JoinStatus.pending:
          home(l10n.spacesAlreadyWaiting);
        case JoinStatus.member:
          router.go(
            result.spaceId == null
                ? AppRoutes.home
                : AppRoutes.space(result.spaceId!),
          );
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    return OnboardingScaffold(
      title: l10n.obSpaceTitle,
      subtitle: l10n.obSpaceSub,
      step: 3,
      button: BvButton(
        key: const Key('space-ask'),
        label: _sending ? l10n.obSending : l10n.spacesAskToJoin,
        expand: true,
        onPressed: preview == null || _sending ? null : _ask,
      ),
      link: BvButton(
        key: const Key('space-skip'),
        label: l10n.obSkipForNow,
        style: BvButtonStyle.tertiary,
        onPressed: _sending ? null : () => context.go(AppRoutes.home),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvCodeField(
            key: const Key('space-code'),
            controller: _code,
            semanticLabel: l10n.spacesInviteCode,
            autofocus: true,
            error: _error,
            inputFormatters: const [InviteCodeFormatter()],
            onChanged: _onChanged,
          ),
          if (preview != null)
            ProfileCard(
              padding: false,
              child: BvListRow(
                key: const Key('space-preview'),
                leading: const BvRowIcon(BvIcons.crane),
                title: preview.spaceName,
                subtitle: preview.invitedByName == null
                    ? l10n.spacesPrivateWork
                    : l10n.obSpaceLetsIn(
                        inOwnDirection(preview.invitedByName!),
                      ),
                trailing: const BvRowTrailing.none(),
              ),
            ),
        ],
      ),
    );
  }
}
