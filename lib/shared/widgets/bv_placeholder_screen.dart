import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../l10n/gen/app_localizations.dart';

/// Temporary screen for a tab that is not built yet. Remove each use when
/// the real screen lands.
class BvPlaceholderScreen extends StatelessWidget {
  const BvPlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: Text(
          AppLocalizations.of(context).placeholderBody,
          style: BvType.of(
            context,
          ).bodyMd.copyWith(color: BvColors.textSecondary),
        ),
      ),
    );
  }
}
