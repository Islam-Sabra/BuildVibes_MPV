import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BvPlaceholderScreen(title: AppLocalizations.of(context).navHome);
}
