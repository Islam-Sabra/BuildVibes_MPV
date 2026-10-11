import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_text_field.dart';
import 'entry_errors.dart';
import 'entry_state.dart';
import 'widgets/entry_scaffold.dart';

/// Email entry: a 6-digit code, never a password. Email sign-ups choose a
/// live home market during onboarding.
class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  static final _shape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValid(String email) => _shape.hasMatch(email.trim());

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _email = TextEditingController();
  String? _error;
  var _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!EmailScreen.isValid(email)) {
      setState(() => _error = l10n.emailError);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendEmailCode(
            email: email,
            signUpData: signUpData(
              locale: Localizations.localeOf(context).languageCode,
              inviteCode: ref.read(inviteCodeProvider),
            ),
          );
      ref
          .read(entryDraftProvider.notifier)
          .set(EntryDraft(method: EntryMethod.email, email: email));
      if (mounted) context.push(AppRoutes.joinCode);
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _error = entryErrorText(l10n, e.failure));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EntryScaffold(
      title: l10n.emailTitle,
      footer: BvButton(
        key: const Key('email-send'),
        label: l10n.sendCode,
        expand: true,
        onPressed: _sending ? null : _send,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvTextField(
            key: const Key('email-field'),
            label: l10n.emailLabel,
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            textDirection: TextDirection.ltr,
            helper: l10n.emailHelp,
            error: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          Center(
            child: BvButton(
              key: const Key('email-phone'),
              label: l10n.emailUsePhone,
              style: BvButtonStyle.tertiary,
              onPressed: () => context.pushReplacement(AppRoutes.joinPhone),
            ),
          ),
        ],
      ),
    );
  }
}
