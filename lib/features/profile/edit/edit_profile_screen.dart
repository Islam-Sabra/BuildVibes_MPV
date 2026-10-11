import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/bv_icons.dart';
import '../../../core/design/bv_tokens.dart';
import '../../../core/l10n/bidi.dart';
import '../../../core/routing/app_routes.dart';
import '../../../data/repositories/profile_page_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/bv_list_row.dart';
import '../../entry/entry_state.dart';
import '../widgets/profile_parts.dart';

/// R8 · Edit profile: one row per part of the profile. CV import,
/// credentials, recommendations and the other parts not in the MVP are
/// left out.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(authUserIdProvider).value;
    final p = me == null ? null : ref.watch(profileViewProvider(me)).value;

    String? firstLine(String? text) {
      final t = (text ?? '').trim();
      if (t.isEmpty) return null;
      final line = t.split('\n').first;
      return line.length > 60 ? '${line.substring(0, 60)}…' : line;
    }

    final openTo = p?.openTo;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEdit)),
      body: ListView(
        padding: const EdgeInsetsDirectional.symmetric(vertical: BvSpace.s8),
        children: [
          BvListGroup(
            rows: [
              BvListRow(
                key: const Key('edit-basics'),
                leading: const BvRowIcon(BvIcons.profile),
                title: l10n.editBasics,
                subtitle: p == null
                    ? null
                    : joinMeta(
                        [p.fullName, p.roleLabel(lang)].whereType<String>(),
                      ),
                onTap: () => context.push(AppRoutes.profileEditBasics),
              ),
              BvListRow(
                key: const Key('edit-about'),
                leading: const BvRowIcon(BvIcons.clipboard),
                title: l10n.profileAbout,
                subtitle: firstLine(p?.about) ?? l10n.editAboutEmpty,
                onTap: () => context.push(AppRoutes.profileEditAbout),
              ),
              BvListRow(
                key: const Key('edit-experience'),
                leading: const BvRowIcon(BvIcons.company),
                title: l10n.profileTabExperience,
                subtitle: p == null || p.experience.isEmpty
                    ? l10n.experienceEmpty
                    : p.experience.first.title,
                onTap: () => context.push(AppRoutes.profileEditExperience),
              ),
              BvListRow(
                key: const Key('edit-projects'),
                leading: const BvRowIcon(BvIcons.crane),
                title: l10n.profileTabProjects,
                subtitle: l10n.editProjectsSub,
                onTap: () => context.push(AppRoutes.profileEditProjects),
              ),
              BvListRow(
                key: const Key('edit-open-to'),
                leading: const BvRowIcon(BvIcons.briefcase),
                title: l10n.openToTitle,
                subtitle: openTo == null || openTo.isEmpty
                    ? l10n.editOpenToEmpty
                    : openTo.options
                          .map((o) => openToLabel(l10n, o))
                          .join(lang == 'ar' ? '، ' : ', '),
                onTap: () => context.push(AppRoutes.profileEditOpenTo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
