import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_page_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/daybook.dart';
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/models/work_item.dart';
import '../../data/repositories/page_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_photo_strip.dart' show BvPhotoViewer;
import '../../shared/widgets/bv_quote_block.dart';
import '../../shared/widgets/bv_slip.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_torn_edge.dart';
import '../entry/entry_state.dart';
import '../library/library_parts.dart' show fileSize;
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import '../spaces/former_member.dart';
import 'daybook_kinds.dart';
import 'daybook_loop.dart';
import 'daybook_page_editor.dart';
import 'daybook_photos.dart';
import 'daybook_words.dart';

/// Opens [post]'s page as a sheet rising over the daybook (N1): the same
/// paper as its card, with a torn top. [edit] opens it for its author to
/// edit (N2).
Future<void> showDaybookPage(
  BuildContext context, {
  required SpaceDetail space,
  required DaybookPost post,
  bool edit = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: BvColors.overlayScrim,
  builder: (_) => DaybookPageSheet(space: space, post: post, edit: edit),
);

/// The author may edit [post]'s page now: theirs, they may post, it can
/// still be edited (a work item while Open), and it isn't a file post.
/// The server decides again on every save.
bool mayEditPage(
  SpaceDetail space,
  DaybookPost post,
  String? me, {
  required DateTime now,
}) =>
    post.authorId != null &&
    post.authorId == me &&
    space.myRights.createItems &&
    !post.cancelled &&
    post.kind != DaybookPost.fileKind &&
    (!post.isWorkItem || post.isOpen) &&
    (post.kind != DaybookPost.activityKind ||
        post.activityEnd == null ||
        post.activityEnd!.isAfter(now));

/// N1/N2 · A post's page: who and when, the title, its facts and words,
/// then its blocks; read by everyone who sees the post, edited by its
/// author.
class DaybookPageSheet extends ConsumerStatefulWidget {
  const DaybookPageSheet({
    super.key,
    required this.space,
    required this.post,
    this.edit = false,
  });

  final SpaceDetail space;

  /// The post as its card shows it, until the page is read.
  final DaybookPost post;
  final bool edit;

  @override
  ConsumerState<DaybookPageSheet> createState() => _DaybookPageSheetState();
}

class _DaybookPageSheetState extends ConsumerState<DaybookPageSheet> {
  late var _editing = widget.edit;
  final _editor = GlobalKey<DaybookPageEditorState>();

  String get _postId => widget.post.id;

  Future<void> _done() async {
    final saved = await _editor.currentState?.save() ?? true;
    if (saved && mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final read = ref.watch(postPageProvider(_postId));
    final page = read.value;
    final post = page?.post ?? widget.post;
    final canEdit = mayEditPage(
      widget.space,
      post,
      me,
      now: ref.watch(clockProvider)(),
    );

    final Widget body;
    if (page == null) {
      body = read.hasError
          ? Padding(
              padding: const EdgeInsetsDirectional.all(BvPageSpec.padding),
              child: EmptyNote(l10n.errorGeneric),
            )
          : const Center(child: CircularProgressIndicator());
    } else if (_editing && canEdit) {
      body = DaybookPageEditor(key: _editor, space: widget.space, page: page);
    } else {
      body = _PageView(space: widget.space, page: page, me: me);
    }

    // Its own messenger: Undo and "no signal" show on the sheet, not
    // under it.
    return FractionallySizedBox(
      heightFactor: BvPageSpec.heightFactor,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Material(
            key: const Key('daybook-page'),
            color: BvColors.surfaceElevated,
            shape: BvSlipBorder.forId(
              _postId,
              edgeHeight: BvPageSpec.tearHeight,
            ).copyWith(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: BvPageSpec.tearHeight),
                Center(
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(
                      top: BvPageSpec.grabberTop,
                    ),
                    width: BvPageSpec.grabberWidth,
                    height: BvPageSpec.grabberHeight,
                    decoration: const BoxDecoration(
                      color: BvColors.borderDefault,
                      borderRadius: BvRadius.roundAll,
                    ),
                  ),
                ),
                _Head(
                  post: post,
                  me: me,
                  editing: _editing && canEdit,
                  canEdit: canEdit && page != null,
                  onEdit: () => setState(() => _editing = true),
                  onDone: _done,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "You · 08:14", then ✕; for its author, Edit page, and Done while
/// editing.
class _Head extends ConsumerWidget {
  const _Head({
    required this.post,
    required this.me,
    required this.editing,
    required this.canEdit,
    required this.onEdit,
    required this.onDone,
  });

  final DaybookPost post;
  final String? me;
  final bool editing;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final words = _words(context);
    final mine = post.authorId != null && post.authorId == me;
    final name = mine ? l10n.daybookYou : personName(l10n, post.authorName);
    Widget action(String key, String label, VoidCallback onTap) => TextButton(
      key: Key(key),
      onPressed: onTap,
      child: Text(
        label,
        style: type.bodyMd.copyWith(color: BvColors.textAction),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvPageSpec.padding,
        BvPageSpec.headTop,
        BvSpace.s4,
        0,
      ),
      child: Row(
        spacing: BvPageSpec.headGap,
        children: [
          BvAvatar(
            name: personName(l10n, post.authorName),
            size: BvAvatarSize.face,
            tint: post.authorId == null
                ? BvAvatarTints.plain
                : BvAvatarTints.forId(post.authorId!),
          ),
          Expanded(
            child: Text(
              joinMeta([name, words.time.clock(post.createdAt.toLocal())]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.metadata.copyWith(color: BvColors.textSecondary),
            ),
          ),
          if (editing)
            action('page-done', l10n.pageDone, onDone)
          else ...[
            if (canEdit) action('page-edit', l10n.pageEdit, onEdit),
            IconButton(
              key: const Key('page-close'),
              tooltip: l10n.pageClose,
              icon: const Icon(BvIcons.close, size: BvSize.iconMd),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ],
      ),
    );
  }
}

DaybookWords _words(BuildContext context) => DaybookWords(
  AppLocalizations.of(context),
  Localizations.localeOf(context).toLanguageTag(),
  use24: MediaQuery.alwaysUse24HourFormatOf(context),
);

/// The page read (N1): the title, the facts, the words and every block.
class _PageView extends ConsumerWidget {
  const _PageView({required this.space, required this.page, required this.me});

  final SpaceDetail space;
  final PostPage page;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = page.post;
    return ListView(
      key: const Key('page-blocks'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        BvPageSpec.padding,
        BvPageSpec.titleTop,
        BvPageSpec.padding,
        BvPageSpec.bottom,
      ),
      children: [
        ...pageTop(context, ref, post, me: me, spaceId: space.id),
        ...pageBlockViews(context, ref, space: space, page: page, me: me),
      ],
    );
  }
}

/// The title, its facts (owner, due, place) and the words: the same as
/// on the card.
List<Widget> pageTop(
  BuildContext context,
  WidgetRef ref,
  DaybookPost post, {
  required String? me,
  required String spaceId,
}) {
  final words = _words(context);
  final now = ref.watch(clockProvider)();
  final body = (post.body ?? '').trim();
  final quote = post.quote;
  final message = post.sourceMessageId;
  return [
    BvSlipTitle(post.title, cancelled: post.cancelled),
    if (post.isWorkItem || (post.place ?? '').isNotEmpty)
      Padding(
        padding: const EdgeInsetsDirectional.only(top: BvPageSpec.factsTop),
        child: BvSlipFacts(
          children: [
            if (post.isWorkItem)
              BvSlipFact(
                icon: BvIcons.person,
                text: words.meta(post, me: me, now: now),
              ),
            if ((post.place ?? '').isNotEmpty)
              BvSlipFact(icon: BvIcons.place, text: post.place!),
          ],
        ),
      ),
    // F91: the quote where the card has it, opening its message (F87).
    if (quote != null)
      Padding(
        padding: const EdgeInsetsDirectional.only(top: BvPageSpec.blockGap),
        child: BvQuoteBlock(
          key: const Key('page-quote'),
          from: words.quoteFrom(quote, now),
          text: quote.text,
          onTap: message == null
              ? null
              : () => unawaited(
                  openQuotedMessage(
                    context,
                    ref,
                    spaceId: spaceId,
                    messageId: message,
                  ),
                ),
        ),
      ),
    if (body.isNotEmpty)
      Padding(
        padding: const EdgeInsetsDirectional.only(top: BvPageSpec.blockGap),
        child: Text(
          body,
          textDirection: directionOf(body),
          style: BvType.of(context).bodyMd,
        ),
      ),
  ];
}

/// Every block of [page], read (N1), each [BvPageSpec.blockGap] apart.
/// Work items under this one that follow each other are one group, under
/// its label and "1 of 2 checked".
List<Widget> pageBlockViews(
  BuildContext context,
  WidgetRef ref, {
  required SpaceDetail space,
  required PostPage page,
  required String? me,
}) {
  final blocks = page.shown;
  final out = <Widget>[];
  var i = 0;
  while (i < blocks.length) {
    final b = blocks[i];
    if (b is PageChildItem) {
      final run = <PageChildItem>[];
      while (i < blocks.length && blocks[i] is PageChildItem) {
        run.add(blocks[i] as PageChildItem);
        i++;
      }
      out.add(_gap(_UnderGroup(space: space, page: page, items: run, me: me)));
      continue;
    }
    out.add(
      _gap(
        PageBlockView(
          key: Key('page-block-${b.id}'),
          space: space,
          page: page,
          block: b,
          me: me,
        ),
      ),
    );
    i++;
  }
  return out;
}

Widget _gap(Widget child) => Padding(
  padding: const EdgeInsetsDirectional.only(top: BvPageSpec.blockGap),
  child: child,
);

/// One block, read.
class PageBlockView extends ConsumerWidget {
  const PageBlockView({
    super.key,
    required this.space,
    required this.page,
    required this.block,
    required this.me,
  });

  final SpaceDetail space;
  final PostPage page;
  final PageBlock block;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = BvType.of(context);
    final post = page.post;
    return switch (block) {
      PageText(:final text) => Text(
        text,
        textDirection: directionOf(text),
        style: type.bodyMd,
      ),
      PageHeading(:final text, :final level) => Text(
        text,
        textDirection: directionOf(text),
        style: level == 1 ? type.titleMd : type.emphasis,
      ),
      PageToggle() => PageToggleView(
        toggle: block as PageToggle,
        child: (b) => PageBlockView(space: space, page: page, block: b, me: me),
      ),
      PageTable(:final rows) => PageTableView(rows: rows),
      PagePhoto(:final path, :final caption) => _PhotoView(
        path: path,
        caption: caption,
      ),
      PageFile(:final libraryFileId) => _FileView(
        spaceId: space.id,
        file: page.files
            .where((f) => f.libraryFileId == libraryFileId)
            .firstOrNull,
        libraryFileId: libraryFileId,
      ),
      PageChecklist(:final pointIds) => _ChecklistView(
        space: space,
        post: post,
        pointIds: pointIds,
        me: me,
      ),
      PageChildItem() || PageOtherBlock() => const SizedBox.shrink(),
    };
  }
}

/// A toggle: closed, its words after a caret; a tap opens it in place.
class PageToggleView extends StatefulWidget {
  const PageToggleView({super.key, required this.toggle, required this.child});

  final PageToggle toggle;
  final Widget Function(PageBlock block) child;

  @override
  State<PageToggleView> createState() => _PageToggleViewState();
}

class _PageToggleViewState extends State<PageToggleView> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final t = widget.toggle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            key: Key('page-toggle-${t.id}'),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BvSpace.s4,
              ),
              child: Row(
                spacing: BvPageSpec.caretGap,
                children: [
                  Icon(
                    _open ? BvIcons.caretDown : BvIcons.caretForward,
                    size: BvPageSpec.caret,
                    color: BvColors.iconPrimary,
                  ),
                  Expanded(
                    child: Text(
                      t.text,
                      textDirection: directionOf(t.text),
                      style: type.bodyMd,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          for (final c in t.children)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: BvPageSpec.toggleIndent,
                top: BvSpace.s8,
              ),
              child: widget.child(c),
            ),
      ],
    );
  }
}

/// A table: hairlines in a rounded frame, the first row the header on a
/// subtle fill; wider than the page, it scrolls sideways.
class PageTableView extends StatelessWidget {
  const PageTableView({super.key, required this.rows, this.cell});

  final List<List<String>> rows;

  /// The editor's cell; null: the words.
  final Widget Function(int row, int column)? cell;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.first.length;
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth / columns).clamp(
          BvPageSpec.columnWidth,
          double.infinity,
        );
        final table = Table(
          defaultColumnWidth: FixedColumnWidth(width),
          border: const TableBorder(
            horizontalInside: BorderSide(
              color: BvColors.borderDefault,
              width: BvStroke.thin,
            ),
          ),
          children: [
            for (final (r, row) in rows.indexed)
              TableRow(
                decoration: r == 0
                    ? const BoxDecoration(color: BvColors.surfaceSubtle)
                    : null,
                children: [
                  for (final (c, text) in row.indexed)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: BvPageSpec.cellPaddingHorizontal,
                        vertical: BvPageSpec.cellPaddingVertical,
                      ),
                      child:
                          cell?.call(r, c) ??
                          Text(
                            text,
                            textDirection: directionOf(text),
                            style: r == 0
                                ? type.metadata.copyWith(
                                    color: BvColors.textSecondary,
                                  )
                                : type.bodySm,
                          ),
                    ),
                ],
              ),
          ],
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BvPageSpec.tableRadius,
            border: Border.all(
              color: BvColors.borderDefault,
              width: BvStroke.thin,
            ),
          ),
          child: ClipRRect(
            borderRadius: BvPageSpec.tableRadius,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          ),
        );
      },
    );
  }
}

class _PhotoView extends ConsumerWidget {
  const _PhotoView({required this.path, this.caption});

  final String path;
  final String? caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = BvType.of(context);
    final image = ref.watch(daybookPhotoProvider(path));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvSpace.s4,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => Consumer(
                builder: (context, ref, _) => BvPhotoViewer(
                  images: [ref.watch(daybookPhotoProvider(path))],
                  closeLabel: MaterialLocalizations.of(
                    context,
                  ).closeButtonLabel,
                ),
              ),
            ),
          ),
          child: BvSlipPhoto(height: BvPageSpec.photoHeight, image: image),
        ),
        if ((caption ?? '').isNotEmpty)
          Text(
            caption!,
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
      ],
    );
  }
}

/// A Library file on the post: its name and size; a tap opens it (F1).
class _FileView extends StatelessWidget {
  const _FileView({
    required this.spaceId,
    required this.file,
    required this.libraryFileId,
  });

  final String spaceId;
  final PageFileRow? file;
  final String libraryFileId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final size = fileSize(l10n, file?.bytes);
    return Material(
      color: BvColors.surfaceSubtle,
      borderRadius: BvPageSpec.rowRadius,
      child: InkWell(
        borderRadius: BvPageSpec.rowRadius,
        onTap: () =>
            context.push(AppRoutes.libraryFile(spaceId, libraryFileId)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvPageSpec.rowPadding),
          child: Row(
            spacing: BvPageSpec.rowGap,
            children: [
              const Icon(
                BvIcons.document,
                size: BvSize.iconLg,
                color: BvColors.iconPrimary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inOwnDirection(file?.name ?? l10n.pageFile),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodyMd,
                    ),
                    if (size.isNotEmpty)
                      Text(
                        size,
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A checklist block: its points, ticked in place by whoever may tick
/// (Lead and Crew), as on the card.
class _ChecklistView extends ConsumerWidget {
  const _ChecklistView({
    required this.space,
    required this.post,
    required this.pointIds,
    required this.me,
  });

  final SpaceDetail space;
  final DaybookPost post;
  final List<String> pointIds;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = space.myPass == SpacePass.viewer;
    final people = ref.watch(spacePeopleProvider(space.id)).value;
    final loop = DaybookLoop(ref, space, onEdit: (_) {});
    return DaybookChecklistPoints(
      post: post,
      words: _words(context),
      me: me,
      only: pointIds,
      nameOf: (id) => people?.member(id)?.person.fullName,
      onTick: viewer
          ? null
          : (point, {required on}) {
              unawaited(loop.tick(context, post, point, on: on));
            },
    );
  }
}

/// Work items under this one (N1): the label and "1 of 2 checked", then
/// each with its state, its stamp and its owner's face. A row opens its
/// card in the daybook.
class _UnderGroup extends StatelessWidget {
  const _UnderGroup({
    required this.space,
    required this.page,
    required this.items,
    required this.me,
  });

  final SpaceDetail space;
  final PostPage page;
  final List<PageChildItem> items;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final under = {for (final u in page.under) u.id: u};
    final live = [
      for (final u in page.under)
        if (!u.cancelled) u,
    ];
    final checked = live.where((u) => u.status == WorkStatus.checked).length;
    return Column(
      key: const Key('page-under'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BvPageSpec.underGap,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.pageUnder,
                style: type.bodySm.copyWith(color: BvColors.textPrimary),
              ),
            ),
            if (live.isNotEmpty)
              Text(
                l10n.pageUnderChecked(checked, live.length),
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
          ],
        ),
        for (final b in items)
          if (under[b.postId] case final u?)
            PageUnderRow(
              key: Key('page-under-${u.id}'),
              item: u,
              onTap: () => context.push(AppRoutes.spaceCard(space.id, u.id)),
            ),
      ],
    );
  }
}

/// A work item under this one: a round state, the title, its stamp
/// (DONE, CHECKED) and its owner's face.
class PageUnderRow extends StatelessWidget {
  const PageUnderRow({super.key, required this.item, this.onTap});

  final PageUnder item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final checked = item.status == WorkStatus.checked;
    final stamp = item.cancelled
        ? BvInkStamp(
            label: l10n.daybookStampCancelled,
            size: BvInkStampSize.xs,
            tone: BvInkStampTone.muted,
          )
        : switch (item.status) {
            WorkStatus.checked => BvInkStamp(
              label: l10n.daybookStampChecked,
              size: BvInkStampSize.xs,
              tone: BvInkStampTone.positive,
            ),
            WorkStatus.done => BvInkStamp(
              label: l10n.daybookStampDone,
              size: BvInkStampSize.xs,
            ),
            WorkStatus.open => null,
          };
    return Material(
      color: BvColors.surfaceSubtle,
      borderRadius: BvPageSpec.rowRadius,
      child: InkWell(
        borderRadius: BvPageSpec.rowRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BvPageSpec.rowPadding),
          child: Row(
            spacing: BvPageSpec.rowGap,
            children: [
              if (checked)
                const Icon(
                  BvIcons.checkCircle,
                  size: BvPageSpec.statusSize,
                  color: BvColors.textPositive,
                )
              else
                Container(
                  width: BvPageSpec.statusSize,
                  height: BvPageSpec.statusSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: BvColors.borderDefault,
                      width: BvStroke.medium,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  item.title,
                  textDirection: directionOf(item.title),
                  style: type.bodyMd.copyWith(
                    decoration: item.cancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              ?stamp,
              BvAvatar(
                name: personName(l10n, item.ownerName),
                size: BvAvatarSize.face,
                tint: item.ownerId == null
                    ? BvAvatarTints.plain
                    : BvAvatarTints.forId(item.ownerId!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
