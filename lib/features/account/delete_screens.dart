import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_code_field.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../entry/entry_errors.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/space_errors.dart';
import 'account_parts.dart';

/// How long a deleted account can still be restored (the server's rule,
/// shown before the server answers).
const _restoreWindow = Duration(days: 30);

/// S12 Before you delete: what happens, Continue or Keep my account.
/// Continue goes to S12b while you are a Space's only admin, else to S13.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  var _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      ref.invalidate(deletionBlockersProvider);
      final blockers = await ref.read(deletionBlockersProvider.future);
      if (!mounted) return;
      await context.push(
        blockers.isEmpty
            ? AppRoutes.profileDeleteConfirm
            : AppRoutes.profileDeleteBlocked,
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
    BvListRow what(String key, IconData icon, String title, [String? sub]) =>
        BvListRow(
          key: Key(key),
          leading: BvRowIcon(icon),
          title: title,
          subtitle: sub,
          trailing: const BvRowTrailing.none(),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccount), centerTitle: true),
      body: ListView(
        key: const Key('delete-account'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          AccountIntro(heading: l10n.deleteHeading, body: l10n.deleteBody),
          SettingsHeader(l10n.deleteWhat),
          BvListGroup(
            rows: [
              what('what-profile', BvIcons.profile, l10n.deleteProfile),
              what(
                'what-space',
                BvIcons.library,
                l10n.deleteSpaceWork,
                l10n.deleteSpaceWorkSub,
              ),
              what(
                'what-messages',
                BvIcons.chat,
                l10n.deleteMessages,
                l10n.deleteSpaceWorkSub,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s24,
              BvSpace.gutter,
              0,
            ),
            child: Column(
              spacing: BvSpace.s12,
              children: [
                BvButton(
                  key: const Key('delete-continue'),
                  label: l10n.deleteContinue,
                  style: BvButtonStyle.destructive,
                  expand: true,
                  onPressed: _busy ? null : _continue,
                ),
                BvButton(
                  key: const Key('delete-keep'),
                  label: l10n.deleteKeep,
                  style: BvButtonStyle.tertiary,
                  expand: true,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// S12b Transfer ownership first: each Space you are the only admin of.
/// Once none is left, it moves on to S13.
class DeleteBlockedScreen extends ConsumerWidget {
  const DeleteBlockedScreen({super.key});

  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    String spaceId,
  ) async {
    await context.push(AppRoutes.spaceTransfer(spaceId));
    ref.invalidate(deletionBlockersProvider);
    final left = await ref.read(deletionBlockersProvider.future);
    if (left.isEmpty && context.mounted) {
      context.pushReplacement(AppRoutes.profileDeleteConfirm);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blockers = ref.watch(deletionBlockersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccount), centerTitle: true),
      body: ListView(
        key: const Key('delete-blocked'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          AccountIntro(
            heading: l10n.transferFirst,
            body: l10n.transferFirstBody,
          ),
          SettingsHeader(l10n.transferOnlyAdmin),
          BvListGroup(
            rows: [
              for (final b in blockers)
                BvListRow(
                  key: Key('blocker-${b.spaceId}'),
                  leading: const BvRowIcon(BvIcons.crane, ink: true),
                  title: inOwnDirection(b.spaceName),
                  onTap: () => _transfer(context, ref, b.spaceId),
                ),
            ],
          ),
          if (blockers.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BvSpace.gutter,
                BvSpace.s24,
                BvSpace.gutter,
                0,
              ),
              child: BvButton(
                key: const Key('blocked-transfer'),
                label: l10n.spacesTransfer,
                expand: true,
                onPressed: () =>
                    _transfer(context, ref, blockers.first.spaceId),
              ),
            ),
        ],
      ),
    );
  }
}

/// S13 Confirm it's you: a code to the account's email (never a
/// password), then the account is hidden and the app shows S14.
class DeleteConfirmScreen extends ConsumerStatefulWidget {
  const DeleteConfirmScreen({super.key});

  @override
  ConsumerState<DeleteConfirmScreen> createState() =>
      _DeleteConfirmScreenState();
}

class _DeleteConfirmScreenState extends ConsumerState<DeleteConfirmScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  var _secondsLeft = 0;
  var _busy = false;
  String? _error;

  String? get _email => ref.read(authRepositoryProvider).currentEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email;
    if (email == null || !mounted) return;
    try {
      await ref.read(authRepositoryProvider).sendConfirmCode(email);
      if (!mounted) return;
      _code.clear();
      setState(() => _error = null);
      _timer?.cancel();
      setState(() => _secondsLeft = BvAuthSpec.resendAfter.inSeconds);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) t.cancel();
      });
    } on AuthFailureException catch (e) {
      if (mounted) showEntryError(context, e.failure);
    }
  }

  Future<void> _delete() async {
    final email = _email;
    if (email == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(email: email, code: _code.text);
      final blockers = await ref
          .read(accountRepositoryProvider)
          .deletionBlockers();
      if (blockers.isNotEmpty) {
        // Someone made you the only admin meanwhile.
        ref.invalidate(deletionBlockersProvider);
        if (mounted) context.pushReplacement(AppRoutes.profileDeleteBlocked);
        return;
      }
      await ref.read(accountRepositoryProvider).requestDeletion();
      // The gate moves to S14.
      ref.invalidate(myProfileProvider);
    } on AuthFailureException catch (e) {
      _code.clear();
      if (mounted) setState(() => _error = entryErrorText(l10n, e.failure));
    } on SpaceException catch (e) {
      _code.clear();
      if (!mounted) return;
      if (e.failure == SpaceFailure.notAllowed) {
        // The server found no fresh code.
        setState(() => _error = l10n.codeExpired);
      } else {
        showSpaceError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final email = ltrRun(ref.watch(authRepositoryProvider).currentEmail ?? '');
    final goneOn = formatLongDate(
      ref.watch(clockProvider)().add(_restoreWindow),
      lang,
    );
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccount), centerTitle: true),
      body: ListView(
        key: const Key('delete-confirm'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          AccountIntro(
            heading: l10n.confirmHeading,
            body: l10n.confirmBody(email),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s16,
              BvSpace.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BvSpace.s16,
              children: [
                BvCodeField(
                  key: const Key('delete-code'),
                  controller: _code,
                  semanticLabel: l10n.codeFieldLabel,
                  autofocus: true,
                  enabled: !_busy,
                  error: _error,
                  onChanged: (_) => setState(() {}),
                ),
                if (_secondsLeft > 0)
                  Text(
                    l10n.codeResendIn('$minutes:$seconds'),
                    key: const Key('delete-code-timer'),
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  )
                else
                  BvButton(
                    key: const Key('delete-code-resend'),
                    label: l10n.codeResend,
                    style: BvButtonStyle.tertiary,
                    size: BvButtonSize.medium,
                    padded: false,
                    onPressed: _send,
                  ),
                BvButton(
                  key: const Key('delete-confirm-button'),
                  label: l10n.deleteMyAccount,
                  style: BvButtonStyle.destructive,
                  expand: true,
                  onPressed:
                      _busy || _code.text.length != BvFieldSpec.codeLength
                      ? null
                      : _delete,
                ),
                Text(
                  l10n.deleteFoot(goneOn),
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// S14: signed in while deletion is scheduled. Restore my account brings
/// everything back; the gate then opens the app.
class DeletionScheduledScreen extends ConsumerStatefulWidget {
  const DeletionScheduledScreen({super.key});

  @override
  ConsumerState<DeletionScheduledScreen> createState() =>
      _DeletionScheduledScreenState();
}

class _DeletionScheduledScreenState
    extends ConsumerState<DeletionScheduledScreen> {
  var _busy = false;

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).restore();
      ref.invalidate(myProfileProvider);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final date = ref.watch(deletionDateProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: AccountResult(
        key: const Key('deletion-scheduled'),
        icon: BvIcons.scheduled,
        title: l10n.scheduledTitle,
        body: date == null
            ? ''
            : l10n.scheduledBody(formatLongDate(date, lang)),
        action: BvButton(
          key: const Key('restore-account'),
          label: l10n.restoreAccount,
          style: BvButtonStyle.secondary,
          size: BvButtonSize.medium,
          onPressed: _busy ? null : _restore,
        ),
      ),
    );
  }
}
