import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_tokens.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../profile/widgets/profile_parts.dart';

/// W3 · the item page. Week 5 part 2 builds it; for now it names the item.
class WorkItemScreen extends ConsumerWidget {
  const WorkItemScreen({
    super.key,
    required this.spaceId,
    required this.itemId,
  });

  final String spaceId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref
        .watch(workItemsProvider(spaceId))
        .value
        ?.where((i) => i.id == itemId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(item?.ref ?? '', textDirection: TextDirection.ltr),
      ),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSpace.s8,
          children: [
            Text(item?.title ?? '', style: BvType.of(context).titleLg),
            EmptyNote(AppLocalizations.of(context).placeholderBody),
          ],
        ),
      ),
    );
  }
}

/// W2 · New work item. Week 5 part 2 builds it.
class NewWorkItemScreen extends StatelessWidget {
  const NewWorkItemScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.workNewItem)),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(l10n.placeholderBody),
      ),
    );
  }
}
