import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/space.dart';
import '../../data/models/template.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../work/daybook_draft.dart' show DaybookKind;
import '../work/daybook_templates.dart';
import '../work/daybook_writing.dart' show kindIcon;
import 'space_errors.dart';

/// Space info › Templates (slice 7, review 78 §3): for a Lead or a Space
/// admin, the built-ins (which stay) and the Space's own, each with its
/// kind and its Team; Delete asks first. Others never reach it: they use
/// templates from the writing card.
class SpaceTemplatesScreen extends ConsumerWidget {
  const SpaceTemplatesScreen({super.key, required this.spaceId});

  final String spaceId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PostTemplate t,
  ) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showBvDialog(
      context: context,
      title: l10n.templateDelete,
      body: l10n.templateDeleteAsk(t.name ?? ''),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!yes || !context.mounted) return;
    try {
      await ref.read(templateRepositoryProvider).delete(t.id);
    } on SpaceException catch (e) {
      if (context.mounted) showSpaceError(context, e);
      return;
    }
    ref.invalidate(spaceTemplatesProvider(spaceId));
    if (context.mounted) showSpaceMessage(context, l10n.templateDeleted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final space = ref.watch(spaceDetailProvider(spaceId)).value;
    final list = ref.watch(spaceTemplatesProvider(spaceId));
    final manage = mayManageTemplates(space);
    final Widget body;
    if (list.value case final templates?) {
      body = ListView(
        key: const Key('templates-list'),
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        children: [
          TemplateList(
            spaceId: spaceId,
            templates: templates,
            empty: l10n.templatesNoneOwn,
            rowFor: (t, name, line) => BvListRow(
              key: Key('template-${t.id}'),
              leading: Icon(
                kindIcon(DaybookKind.fromJson(t.kind)),
                size: BvSize.iconMd,
                color: BvColors.iconSecondary,
              ),
              title: name,
              subtitle: line,
              trailing: t.isBuiltin || !manage
                  ? const BvRowTrailing.none()
                  : BvRowTrailing.badge(
                      IconButton(
                        key: Key('template-delete-${t.id}'),
                        tooltip: l10n.templateDelete,
                        icon: const Icon(
                          BvIcons.delete,
                          size: BvSize.iconMd,
                          color: BvColors.iconSecondary,
                        ),
                        onPressed: () => unawaited(_delete(context, ref, t)),
                      ),
                    ),
            ),
          ),
        ],
      );
    } else if (list.error case final SpaceException e) {
      body = Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(spaceErrorText(l10n, e)),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.templatesTitle)),
      body: body,
    );
  }
}
