import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/safety_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../activity/activity_state.dart';
import '../profile/widgets/profile_parts.dart';
import '../spaces/space_errors.dart';

/// R3: something of yours was removed. Only you see this notice. With the
/// appeal still possible, "Appeal this decision" (R4).
class RemovedScreen extends ConsumerWidget {
  const RemovedScreen({super.key, required this.removalId});

  final String removalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final removal = ref.watch(removalProvider(removalId));
    final r = removal.value;

    if (!removal.hasValue) {
      return Scaffold(
        appBar: AppBar(),
        body: removal.hasError
            ? Padding(
                padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                child: EmptyNote(l10n.errorGeneric),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(l10n.removedGone),
        ),
      );
    }

    final status = switch (r.appealStatus) {
      AppealStatus.open => l10n.removedAppealOpen(
        formatDay(r.appealAt!.toLocal(), locale),
      ),
      AppealStatus.upheld => l10n.removedUpheld,
      AppealStatus.reversed => l10n.removedReversed,
      AppealStatus.none =>
        r.canAppeal ? l10n.removedAppealNote : l10n.removedClosed,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.removedTitle(r.kind.json)),
        centerTitle: true,
      ),
      body: ListView(
        key: const Key('removed'),
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        children: [
          Center(
            child: Container(
              width: BvSize.avatarLg,
              height: BvSize.avatarLg,
              decoration: const BoxDecoration(
                color: BvColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                BvIcons.warning,
                size: BvSize.iconLg,
                color: BvColors.iconPrimary,
              ),
            ),
          ),
          const SizedBox(height: BvSpace.s12),
          Text(
            l10n.removedHeading(r.kind.json),
            textAlign: TextAlign.center,
            style: type.headingMd,
          ),
          const SizedBox(height: BvSpace.s8),
          Text(
            l10n.removedBody(l10n.reasonPhrase(r.reason.json)),
            textAlign: TextAlign.center,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          const SizedBox(height: BvSpace.s24),
          if ((r.excerpt ?? '').isNotEmpty)
            ProfileCard(
              child: Column(
                key: const Key('removed-excerpt'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s4,
                children: [
                  Text(
                    // When it was posted, not when it was removed.
                    l10n.removedYour(
                      r.kind.json,
                      formatDayMonth(
                        (r.postedAt ?? r.removedAt).toLocal(),
                        locale,
                      ),
                    ),
                    style: type.metadata.copyWith(
                      color: BvColors.textSecondary,
                    ),
                  ),
                  Text(
                    r.excerpt!,
                    textDirection: directionOf(r.excerpt!),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: type.bodyMd,
                  ),
                ],
              ),
            ),
          const SizedBox(height: BvSpace.s12),
          Text(
            status,
            key: const Key('removed-status'),
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
      bottomNavigationBar: r.canAppeal
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
                child: BvButton(
                  key: const Key('removed-appeal'),
                  label: l10n.removedAppeal,
                  expand: true,
                  onPressed: () =>
                      context.push(AppRoutes.removalAppeal(removalId)),
                ),
              ),
            )
          : null,
    );
  }
}

/// R4, then R5 in place: why it was a mistake (1–500 characters), once.
class AppealScreen extends ConsumerStatefulWidget {
  const AppealScreen({super.key, required this.removalId});

  final String removalId;

  @override
  ConsumerState<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends ConsumerState<AppealScreen> {
  final _note = TextEditingController();
  var _busy = false;
  var _sent = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .appeal(widget.removalId, _note.text.trim());
      ref.invalidate(removalProvider(widget.removalId));
      ref.invalidate(activityProvider);
      if (mounted) setState(() => _sent = true);
    } on SpaceException catch (e) {
      if (mounted) showSpaceError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final text = _note.text.trim();

    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.appealTitle), centerTitle: true),
        body: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.s24),
          child: Column(
            key: const Key('appeal-received'),
            spacing: BvSpace.s12,
            children: [
              const Icon(
                BvIcons.check,
                size: BvSize.iconLg,
                color: BvColors.iconSecondary,
              ),
              Text(l10n.appealReceived, style: type.headingMd),
              Text(
                l10n.appealReceivedBody,
                textAlign: TextAlign.center,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
              BvButton(
                key: const Key('appeal-done'),
                label: l10n.reportDone,
                style: BvButtonStyle.secondary,
                size: BvButtonSize.medium,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appealTitle), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              children: [
                Text(l10n.appealHeading, style: type.headingMd),
                const SizedBox(height: BvSpace.s4),
                Text(
                  l10n.appealHelp,
                  style: type.bodySm.copyWith(color: BvColors.textSecondary),
                ),
                const SizedBox(height: BvSpace.s16),
                BvTextField(
                  key: const Key('appeal-note'),
                  controller: _note,
                  label: l10n.appealLabel,
                  helper: l10n.appealLimit,
                  maxLines: 5,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
              child: BvButton(
                key: const Key('appeal-send'),
                label: l10n.appealSend,
                expand: true,
                onPressed: text.isEmpty || _busy ? null : _send,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
