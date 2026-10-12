import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../create/create_sheet.dart';
import 'my_spaces_view.dart';

/// S1 v2: My Spaces as its own page, from the Profile top bar. Create
/// (New Space, Enter an invite code) sits in its header, so a member can
/// still join a second Space.
class MySpacesScreen extends StatelessWidget {
  const MySpacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeSpaces),
        centerTitle: true,
        actions: [
          BvButton(
            key: const Key('spaces-create'),
            label: l10n.navCreate,
            style: BvButtonStyle.tertiary,
            size: BvButtonSize.medium,
            onPressed: () => showSpacesCreateSheet(context),
          ),
        ],
      ),
      body: const MySpacesView(),
    );
  }
}
