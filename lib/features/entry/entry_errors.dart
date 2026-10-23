import 'package:flutter/material.dart';

import '../../core/design/bv_tokens.dart';
import '../../data/models/market.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_sheet.dart';

/// The words for an entry error.
String entryErrorText(AppLocalizations l10n, AuthFailure failure) =>
    switch (failure) {
      AuthFailure.wrongCode => l10n.codeWrong,
      AuthFailure.tooManyRequests => l10n.errorTooMany,
      AuthFailure.network => l10n.errorNetwork,
      AuthFailure.sendFailed => l10n.errorSendFailed,
      AuthFailure.signupNotOpen || AuthFailure.unknown => l10n.errorGeneric,
    };

void showEntryError(BuildContext context, AuthFailure failure) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(entryErrorText(AppLocalizations.of(context), failure)),
    ),
  );
}

/// New accounts are not open for this phone number: a market coming soon,
/// or a country with no market. A Space invite opens it.
Future<void> showNotOpenSheet(
  BuildContext context, {
  required Market? market,
  required List<Market> liveMarkets,
}) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
  final body = market != null
      ? l10n.notOpenSoon(market.name.of(locale))
      : l10n.notOpenOther(
          liveMarkets
              .map((m) => m.name.of(locale))
              .join(l10n.daybookNamesComma),
        );
  return showBvSheet(
    context: context,
    title: l10n.notOpenTitle,
    builder: (sheetContext) => Column(
      key: const Key('not-open-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        Text(
          body,
          style: BvType.of(
            sheetContext,
          ).bodyMd.copyWith(color: BvColors.textSecondary),
        ),
        BvButton(
          label: l10n.commonOk,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
    ),
  );
}
