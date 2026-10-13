import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/share.dart';
import '../../data/models/market.dart';
import '../../data/repositories/market_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../entry/entry_state.dart';

/// The signed-in person's home market pack, if they have one.
final myMarketProvider = Provider<Market?>((ref) {
  final id = ref.watch(myProfileProvider).value?.homeMarketId;
  final markets = ref.watch(marketsProvider).value ?? const <Market>[];
  return markets.where((m) => m.id == id).firstOrNull;
});

/// An overline above a group of rows ("ACCOUNT", "WHAT HAPPENS").
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s16,
        BvSpace.gutter,
        BvSpace.s8,
      ),
      child: Text(
        text,
        style: type.overline.copyWith(color: BvColors.textSecondary),
      ),
    );
  }
}

/// A small grey note under a group (S5, S8).
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s12,
        BvSpace.gutter,
        0,
      ),
      child: Text(
        text,
        style: type.bodySm.copyWith(color: BvColors.textSecondary),
      ),
    );
  }
}

/// The heading and short body at the top of S10, S12, S12b and S13.
class AccountIntro extends StatelessWidget {
  const AccountIntro({super.key, required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvSpace.gutter,
        BvSpace.s16,
        BvSpace.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BvSpace.s8,
        children: [
          Text(heading, style: type.headingMd),
          Text(
            body,
            style: type.bodyMd.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// S11 and S14: an icon, a title, a line of text and maybe one button,
/// centred.
class AccountResult extends StatelessWidget {
  const AccountResult({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Align(
      alignment: BvAccountSpec.resultAlignment,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: BvSpace.s12,
          children: [
            Icon(icon, size: BvSize.iconLg, color: BvColors.iconSecondary),
            Text(title, style: type.headingMd, textAlign: TextAlign.center),
            Text(
              body,
              textAlign: TextAlign.center,
              style: type.bodyMd.copyWith(color: BvColors.textSecondary),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// Opens [uri] with the phone; says so when nothing can open it.
Future<void> openLink(BuildContext context, WidgetRef ref, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = AppLocalizations.of(context).linkFailed;
  var opened = false;
  try {
    opened = await ref.read(openLinkProvider)(uri);
  } on Exception {
    opened = false;
  }
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(text)));
}
