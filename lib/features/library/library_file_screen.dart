import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart' show DaybookAck;
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_ack_pill.dart';
import '../../shared/widgets/bv_faces.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_slip.dart' show BvSlipPhoto;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import '../spaces/space_errors.dart';
import '../work/daybook_marks.dart';
import '../work/daybook_photos.dart' show filePreviewProvider;
import '../work/daybook_words.dart';
import 'library_actions.dart';
import 'library_parts.dart';

enum _FileMenu { share, download }

/// LV2 · A file and its versions (2543:35101), on a light page: the
/// preview (a tap opens it full screen, F1), who received it with the
/// Received pill, the versions (the one in use first), Add a new version
/// for people who may add files, and Used in. Share in chat and Download
/// under ⋯.
///
/// Received acts on the newest post carrying this version
/// (library_file_post); with no post (a file from chat) there is no pill
/// and no line. Add a new version pops this version, and the Space opens
/// the writing card replacing it: a new version always goes with its post
/// (review 69 1b).
class LibraryFileScreen extends ConsumerWidget {
  const LibraryFileScreen({
    super.key,
    required this.spaceId,
    required this.fileId,
  });

  final String spaceId;
  final String fileId;

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    LibraryFile f, {
    required bool canShare,
  }) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showBvScreenMenu<_FileMenu>(
      context,
      key: const Key('file-menu'),
      items: [
        // The server shares a file in chat only for people who may add
        // files (share_library_file).
        if (canShare)
          BvMenuItem(
            value: _FileMenu.share,
            label: l10n.previewShare,
            icon: BvIcons.chat,
          ),
        BvMenuItem(
          value: _FileMenu.download,
          label: l10n.previewDownload,
          icon: BvIcons.download,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (picked) {
      case _FileMenu.share:
        await shareLibraryFileInChat(context, ref, spaceId, f);
      case _FileMenu.download:
        await downloadLibraryFile(context, ref, f);
      case null:
        break;
    }
  }

  Future<void> _receive(
    BuildContext context,
    WidgetRef ref, {
    required String postId,
    required bool on,
  }) async {
    try {
      await ref
          .read(daybookMarksProvider.notifier)
          .send(
            DaybookMark(
              spaceId: spaceId,
              postId: postId,
              on: on,
              at: ref.read(clockProvider)(),
              ack: DaybookAck.received,
            ),
          );
    } on SpaceException catch (e) {
      if (context.mounted) showSpaceError(context, e);
    }
    ref
      ..invalidate(libraryReceiptsProvider(fileId))
      ..invalidate(libraryOverviewProvider(spaceId))
      ..invalidate(postAcksProvider(postId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final detail = ref.watch(libraryFileProvider(fileId));
    final d = detail.value;

    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: detail.isLoading
              ? const Center(child: CircularProgressIndicator())
              : EmptyNote(l10n.errorGeneric),
        ),
      );
    }

    final f = d.file;
    final me = ref.watch(authUserIdProvider).value;
    final rights = ref.watch(spaceDetailProvider(spaceId)).value?.myRights;
    // A new version goes with its post, for the whole Space (posts are
    // for Everyone in this slice); a model view's come only from
    // BuildVibes 360.
    final canAddVersion =
        d.isCurrent &&
        (rights?.addFiles ?? false) &&
        (rights?.createItems ?? false) &&
        f.teamId == null &&
        f.source == LibrarySource.upload;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          inOwnDirection(f.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const Key('file-more'),
            tooltip: l10n.libraryFileMenu,
            icon: const Icon(BvIcons.more),
            onPressed: () =>
                _menu(context, ref, f, canShare: rights?.addFiles ?? false),
          ),
        ],
      ),
      body: ListView(
        key: const Key('library-file'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          BvSpace.s8,
          BvSpace.gutter,
          BvSpace.s32,
        ),
        children: [
          _Preview(
            file: f,
            onTap: () => context.push(AppRoutes.libraryFile(spaceId, f.id)),
          ),
          _Received(
            fileId: fileId,
            mineToMark: f.uploadedById == null || f.uploadedById != me,
            onReceive: (postId, on) =>
                _receive(context, ref, postId: postId, on: on),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: BvLibrarySpec.sectionTop,
            ),
            child: Text(
              l10n.libraryVersions,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          ),
          _VersionRow(
            key: Key('version-${f.id}'),
            file: f,
            current: d.isCurrent,
            onOpen: () => context.push(AppRoutes.libraryFile(spaceId, f.id)),
          ),
          for (final o in d.older)
            _VersionRow(
              key: Key('version-${o.id}'),
              file: o,
              current: false,
              onOpen: () => context.push(AppRoutes.libraryFile(spaceId, o.id)),
            ),
          if (canAddVersion)
            InkWell(
              key: const Key('file-add-version'),
              onTap: () => context.pop(f),
              splashFactory: NoSplash.splashFactory,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: BvLibrarySpec.versionPaddingVertical,
                ),
                child: Row(
                  spacing: BvLibrarySpec.versionGap,
                  children: [
                    const Icon(
                      BvIcons.create,
                      size: BvSize.iconSm,
                      color: BvColors.iconSecondary,
                    ),
                    Expanded(
                      child: Text(
                        l10n.libraryAddVersion,
                        style: type.bodyMd.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (d.usedIn.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: BvLibrarySpec.sectionTop,
                bottom: BvSpace.s4,
              ),
              child: Text(
                l10n.previewUsedIn,
                style: type.bodySm.copyWith(color: BvColors.textSecondary),
              ),
            ),
            for (final u in d.usedIn)
              InkWell(
                key: Key('file-used-${u.itemId}'),
                // At its card in the daybook, where the work item lives.
                onTap: () =>
                    context.push(AppRoutes.spaceCard(spaceId, u.itemId)),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: BvSpace.s8,
                  ),
                  child: Text(
                    joinMeta([u.ref, u.title]),
                    style: type.bodyMd.copyWith(color: BvColors.textAction),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The file on a light card: its first page or the photo; a tap opens it
/// full screen.
class _Preview extends ConsumerWidget {
  const _Preview({required this.file, required this.onTap});

  final LibraryFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final image = ref
        .watch(filePreviewProvider((path: file.path, mime: file.mime)))
        .value;
    return Semantics(
      button: true,
      label: l10n.libraryOpenFull,
      child: GestureDetector(
        key: const Key('file-preview'),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BvLibrarySpec.previewRadius,
          child: Stack(
            children: [
              BvSlipPhoto(height: BvLibrarySpec.previewHeight, image: image),
              if (image == null)
                Positioned.fill(
                  child: Center(
                    child: Icon(
                      file.isImage ? BvIcons.image : BvIcons.document,
                      size: BvSize.iconLg,
                      color: BvColors.iconSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Received by Islam and Omar" with their faces, and the Received pill
/// (the same ack as on the file post). No post: nothing at all.
class _Received extends ConsumerWidget {
  const _Received({
    required this.fileId,
    required this.mineToMark,
    required this.onReceive,
  });

  final String fileId;

  /// The one who added this version is not asked (as on its post).
  final bool mineToMark;
  final void Function(String postId, bool on) onReceive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final postId = ref.watch(libraryFilePostProvider(fileId)).value;
    if (postId == null) return const SizedBox.shrink();
    final receipts =
        ref.watch(libraryReceiptsProvider(fileId)).value ?? const [];
    // A tap shows at once while it goes to the server.
    final pending = ref
        .watch(daybookMarksProvider)
        .where((m) => m.postId == postId && m.ack == DaybookAck.received)
        .lastOrNull;
    final given = pending?.on ?? receipts.any((r) => r.mine);
    final words = DaybookWords(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    // Newest first, as the faces in the list.
    final newest = [...receipts]..sort((a, b) => b.at.compareTo(a.at));

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: BvLibrarySpec.receivedTop),
      child: Row(
        spacing: BvLibrarySpec.receivedGap,
        children: [
          if (newest.isNotEmpty) ...[
            BvFaces(key: const Key('file-received-faces'), [
              for (final r in newest)
                (
                  name: personName(l10n, r.name),
                  tint: BvAvatarTints.forId(r.profileId),
                ),
            ], large: true),
            Expanded(
              child: Text(
                l10n.daybookReceivedBy(
                  words.someNames([
                    for (final r in receipts) personFirstName(l10n, r.name),
                  ]),
                ),
                key: const Key('file-received-by'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BvType.of(
                  context,
                ).metadata.copyWith(color: BvColors.textSecondary),
              ),
            ),
          ] else
            const Spacer(),
          if (mineToMark)
            BvAckPill(
              key: const Key('file-received'),
              label: l10n.daybookReceived,
              icon: BvIcons.check,
              tone: given ? BvAckPillTone.done : BvAckPillTone.primary,
              onTap: () => onReceive(postId, !given),
            ),
        ],
      ),
    );
  }
}

/// A version: the one in use with an orange dot ("Rev D · in use"), an
/// older one with Open; who added it and when.
class _VersionRow extends ConsumerWidget {
  const _VersionRow({
    super.key,
    required this.file,
    required this.current,
    required this.onOpen,
  });

  final LibraryFile file;
  final bool current;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = ref.watch(clockProvider)();
    final at = file.createdAt.toLocal();
    final words = DaybookWords(
      l10n,
      locale,
      use24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final day = libraryDay(l10n, locale, at, now);
    final when = DateUtils.isSameDay(at, now)
        ? '$day ${words.time.clock(at)}'
        : day;
    final rev = file.revLabel ?? l10n.libraryVersion;
    return InkWell(
      onTap: onOpen,
      splashFactory: NoSplash.splashFactory,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: BvColors.borderDefault,
              width: BvStroke.thin,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            vertical: BvLibrarySpec.versionPaddingVertical,
          ),
          child: Row(
            spacing: BvLibrarySpec.versionGap,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current
                      ? BvColors.actionPrimary
                      : BvColors.borderDefault,
                ),
                child: const SizedBox.square(
                  dimension: BvLibrarySpec.versionDot,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(
                      current ? l10n.libraryInUse(rev) : rev,
                      style: type.bodyMd.copyWith(
                        color: current
                            ? BvColors.textPrimary
                            : BvColors.textSecondary,
                      ),
                    ),
                    Text(
                      joinMeta([
                        inOwnDirection(personName(l10n, file.uploadedByName)),
                        when,
                      ]),
                      style: type.metadata.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!current)
                Text(
                  l10n.libraryOpen,
                  key: Key('version-open-${file.id}'),
                  style: type.bodySm.copyWith(color: BvColors.textAction),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
