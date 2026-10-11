import 'package:flutter/material.dart';

import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/bidi.dart';
import '../../../data/models/market.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_button.dart';
import '../../../shared/widgets/bv_choice_card.dart';
import '../../../shared/widgets/bv_sheet.dart';
import '../../../shared/widgets/bv_text_field.dart';
import '../phone_rules.dart';

/// The country code sheet: the market pack's codes, plus "Other country
/// code" to type any code. Returns the chosen code ("+965"), or null.
Future<String?> pickDialCode(
  BuildContext context, {
  required List<Market> markets,
  String? current,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context);
  const other = '__other__';
  final known = markets.any((m) => m.dialCode == current);
  final picked = await showBvSheet<String>(
    context: context,
    title: l10n.dialCodeTitle,
    builder: (sheetContext) => BvChoiceList<String>(
      value: current != null && !known ? other : current,
      options: [
        for (final m in markets)
          BvChoiceOption(
            key: Key('dial-${m.id}'),
            value: m.dialCode,
            title: m.name.of(locale),
            description: ltrRun(m.dialCode),
            badge: m.status == MarketStatus.soon ? l10n.comingSoon : null,
          ),
        BvChoiceOption(
          key: const Key('dial-other'),
          value: other,
          title: l10n.dialCodeOther,
        ),
      ],
      onChanged: (v) => Navigator.of(sheetContext).pop(v),
    ),
  );
  if (picked == null || !context.mounted) return null;
  if (picked != other) return picked;
  return showBvSheet<String>(
    context: context,
    title: l10n.dialCodeOther,
    builder: (_) => const _OtherDialCode(),
  );
}

/// Typing a country code that is not in the market pack, for example +91.
/// Owns its text field, so it lives exactly as long as the sheet.
class _OtherDialCode extends StatefulWidget {
  const _OtherDialCode();

  @override
  State<_OtherDialCode> createState() => _OtherDialCodeState();
}

class _OtherDialCodeState extends State<_OtherDialCode> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = PhoneRules.dialCode(_code.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('dial-other-field'),
          controller: _code,
          autofocus: true,
          prefixText: '+',
          helper: l10n.dialCodeOtherHelp,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.number,
          inputFormatters: const [BvWesternDigitsFormatter()],
          onChanged: (_) => setState(() {}),
        ),
        BvButton(
          key: const Key('dial-other-confirm'),
          label: l10n.commonConfirm,
          expand: true,
          onPressed: code == null
              ? null
              : () => Navigator.of(context).pop(code),
        ),
      ],
    );
  }
}
