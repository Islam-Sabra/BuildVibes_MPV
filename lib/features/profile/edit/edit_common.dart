import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_page_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_choice_card.dart';
import '../../entry/entry_state.dart';

/// The signed-in id; edit screens are only reachable when signed in.
String? myId(WidgetRef ref) => ref.read(authUserIdProvider).value;

/// After saving: reload the profile and say "Saved".
void afterSave(BuildContext context, WidgetRef ref) {
  final me = myId(ref);
  if (me != null) ref.invalidate(profileViewProvider(me));
  ref.invalidate(myProfileProvider);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).saved)));
}

/// A save that did not go through.
void showSaveError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).errorGeneric)),
  );
}

/// Everyone / Connections only / Only me: one single choice (rule 6).
class ShowToChoice extends StatelessWidget {
  const ShowToChoice({super.key, required this.value, required this.onChanged});

  final ShowTo value;
  final ValueChanged<ShowTo> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BvChoiceList<ShowTo>(
      value: value,
      onChanged: onChanged,
      options: [
        BvChoiceOption(
          key: const Key('show-everyone'),
          value: ShowTo.everyone,
          title: l10n.visibilityEveryone,
          description: l10n.visibilityEveryoneSub,
        ),
        BvChoiceOption(
          key: const Key('show-connections'),
          value: ShowTo.connections,
          title: l10n.visibilityConnections,
          description: l10n.visibilityConnectionsSub,
        ),
        BvChoiceOption(
          key: const Key('show-only-me'),
          value: ShowTo.onlyMe,
          title: l10n.visibilityOnlyMe,
          description: l10n.visibilityOnlyMeSub,
        ),
      ],
    );
  }
}
