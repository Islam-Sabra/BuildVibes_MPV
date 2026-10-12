import 'package:flutter/material.dart';

import '../../../core/design/bv_specs.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/bidi.dart';
import '../../../data/models/space.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_avatar.dart';

/// A person in a Space list (S10k, S11k, S12, S15d): avatar, name, role ·
/// company, an optional third [line] (pass, Teams, Owner), and an optional
/// [trailing] control (a radio or a checkbox). [selected] tints the row.
class SpacePersonRow extends StatelessWidget {
  const SpacePersonRow({
    super.key,
    required this.person,
    this.line,
    this.isMe = false,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final SpacePerson person;
  final String? line;
  final bool isMe;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final role = joinMeta([?person.roleLabel(lang), ?person.companyLabel]);
    return Material(
      color: selected ? BvColors.surfaceBrandSoft : BvColors.surfaceElevated,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BvListRowSpec.paddingHorizontal,
            vertical: BvListRowSpec.paddingVertical,
          ),
          child: Row(
            spacing: BvListRowSpec.gap,
            children: [
              BvAvatar(name: person.fullName),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvListRowSpec.textGap,
                  children: [
                    Text(
                      isMe
                          ? joinMeta([person.fullName, l10n.spacesYouTag])
                          : person.fullName,
                      style: type.titleMd,
                    ),
                    if (role.isNotEmpty)
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.bodySm.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    if ((line ?? '').isNotEmpty)
                      Text(
                        line!,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A 1 px divider that starts after the avatar, on the row colour.
class SpaceRowDivider extends StatelessWidget {
  const SpaceRowDivider({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: BvColors.surfaceElevated,
    child: Padding(
      padding: EdgeInsetsDirectional.only(start: BvListRowSpec.dividerInset),
      child: Divider(
        height: BvStroke.thin,
        thickness: BvStroke.thin,
        color: BvColors.borderDefault,
      ),
    ),
  );
}
