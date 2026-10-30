import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/onboarding_scaffold.dart';
import 'onboarding_state.dart';

/// OB4 · What's your name? (review 107, 2698:39095; step 1 of 3): first
/// and last name only, "As people at work know you". Kept until your work
/// is saved with it (OB5). Back signs out, to start again.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  var _filled = false;
  var _showErrors = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  /// Once: the name typed before, else the one the account has.
  void _prefill() {
    if (_filled) return;
    final typed = ref.read(onboardingNameProvider);
    final me = ref.read(myProfileProvider).value;
    if (typed == null && me == null) return;
    _filled = true;
    _first.text = typed?.first ?? me!.firstName;
    _last.text = typed?.last ?? me!.lastName;
  }

  void _continue() {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    ref
        .read(onboardingNameProvider.notifier)
        .set((first: _first.text.trim(), last: _last.text.trim()));
    context.push(AppRoutes.onboardingWork);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(myProfileProvider);
    _prefill();
    String? missing(TextEditingController c, String error) =>
        _showErrors && c.text.trim().isEmpty ? error : null;

    return OnboardingScaffold(
      title: l10n.obNameTitle,
      subtitle: l10n.obNameSub,
      step: 1,
      onBack: () => ref.read(authRepositoryProvider).signOut(),
      button: BvButton(
        key: const Key('name-continue'),
        label: l10n.continueLabel,
        expand: true,
        onPressed: _continue,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          BvTextField(
            key: const Key('name-first'),
            label: l10n.firstName,
            controller: _first,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            error: missing(_first, l10n.firstNameRequired),
            onChanged: (_) => setState(() {}),
          ),
          BvTextField(
            key: const Key('name-last'),
            label: l10n.lastName,
            controller: _last,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            error: missing(_last, l10n.lastNameRequired),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
