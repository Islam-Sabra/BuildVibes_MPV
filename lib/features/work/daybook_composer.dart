import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/library_parts.dart' show fileSize;
import '../scan/pdf_smaller.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/daybook_writing_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/photo_privacy.dart' show photosPreparingProvider;
import '../../data/models/library.dart' show PhoneFile;
import '../../data/models/check_in.dart' show checkInFitsDay;
import '../../data/models/daybook.dart';
import '../../data/models/note.dart' show Note, noteBulletMark;
import '../../data/models/post_page.dart';
import '../../data/models/space.dart';
import '../../data/models/library_folder.dart';
import '../../data/repositories/library_repository.dart'
    show libraryFoldersProvider;
import '../../data/models/upload_rules.dart' show FileRefused, UploadProblem;
import '../../data/repositories/daybook_repository.dart'
    show spaceWorkTagsProvider;
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_icon_grid.dart';
import '../../shared/widgets/bv_popover_menu.dart';
import '../../shared/widgets/bv_quote_block.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_writing_rows.dart';
import '../chat/voice.dart' show voicePlayerProvider, voiceTime;
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../spaces/former_member.dart' show personName;
import 'composer_check_in.dart';
import 'composer_kinds.dart';
import 'composer_thanks.dart' show thanksRefusalText;
import 'composer_poll.dart';
import 'could_not_send.dart';
import 'daybook_draft.dart';
import 'daybook_photos.dart';
import 'daybook_report.dart';
import 'daybook_words.dart';
import 'daybook_writing.dart';
import 'work_outbox.dart' show RefusalWhy;
import 'work_places.dart';

export 'composer_kinds.dart';
export '../../shared/widgets/bv_icon_grid.dart' show BvIconGridTile;

/// Which grid shows in place of the keyboard: Type (the kinds), + (the
/// extras), or + → Tag's list (review 110 TG1).
enum ComposerPanel { kinds, extras, tags }

/// The short menu (review 113 (12)): on a long press in the text, and on
/// "/" at the start of a line.
enum ComposerQuick { dateTime, bullets, table }

/// Review 110 D: the composer is open in this Space. The Space screen then
/// hides its header and Work · Chat (CP1).
final spaceComposingProvider = NotifierProvider.autoDispose
    .family<SpaceComposing, bool, String>(SpaceComposing.new);

class SpaceComposing extends Notifier<bool> {
  SpaceComposing(this.spaceId);

  final String spaceId;

  @override
  bool build() => false;

  void set(bool on) => state = on;
}

/// Review 113 CV3 (2730:39817; review 110 D): writing in a Space, over the
/// whole screen. On top, × · the kind's name over the Space's · Templates
/// (W9) · Discard (× keeps the draft; Discard asks once and removes it).
/// Then the title and the details, which scroll; pinned at the bottom, what
/// was added from + as small chips, Type and the lines the kind needs, and
/// [bar] (+ · camera · mic · Send) on the keyboard; Type and + show their
/// grids in its place ([panel]). A long press in the text keeps the phone's
/// menu and adds Date & time · Bullets · Table; "/" at the start of a line
/// opens the same short menu.
class DaybookComposer extends ConsumerStatefulWidget {
  const DaybookComposer({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.words,
    required this.bar,
    required this.panel,
    required this.onPanel,
    required this.onClose,
    this.onDiscard,
    required this.onKind,
    required this.onExtra,
    required this.onMenu,
    required this.onPickPeople,
    required this.onPickStart,
    required this.onPickPin,
    required this.onPickPinTime,
    required this.onPickPlace,
    required this.onPickDue,
    required this.onPickThanksTo,
    required this.onPickThanksFor,
    this.kinds = composerKinds,
    this.onTemplates,
    this.overlay,
    this.editing = false,
    this.askWho,
    this.onWalk,
    this.onCheckIn,
    this.onTryAgain,
    this.onLinkFolder,
  });

  final String spaceId;
  final String spaceName;
  final DaybookWords words;
  final Widget bar;
  final ComposerPanel? panel;
  final ValueChanged<ComposerPanel?> onPanel;

  /// ×: back to the Space, what was written kept as its draft.
  final VoidCallback onClose;

  /// Discard (review 113 (1)): the draft is gone; null while editing.
  final VoidCallback? onDiscard;

  /// What Type offers: the kinds this person may post (W11; a Viewer:
  /// Thanks only).
  final List<DaybookKind> kinds;

  /// Templates on the top bar (W9): the template picker.
  final VoidCallback? onTemplates;
  final ValueChanged<DaybookKind> onKind;
  final ValueChanged<ComposerExtra> onExtra;
  final ValueChanged<DaybookWritingMenu> onMenu;
  final VoidCallback onPickPeople;
  final VoidCallback onPickStart;
  final VoidCallback onPickPin;

  /// "+ Time" on the pin (F82): the time on its last day it ends.
  final VoidCallback onPickPinTime;
  final VoidCallback onPickPlace;
  final VoidCallback onPickDue;

  /// A Thanks's To and For (review 110 TH1).
  final VoidCallback onPickThanksTo;
  final VoidCallback onPickThanksFor;

  /// The Give to and Team pickers, over the composer.
  final Widget? overlay;
  final bool editing;
  final Object? askWho;

  /// Walk, the last tile of Type's grid; null for who may not post work.
  final VoidCallback? onWalk;

  /// A Check-in's lines (review 109 CI1): For, Check-in and Place.
  final ValueChanged<CheckInPick>? onCheckIn;

  /// Review 113 bug 7: Tap to fix's Try again (Send again, when it may
  /// go) and Link folder (for a file too big for a Space).
  final VoidCallback? onTryAgain;
  final VoidCallback? onLinkFolder;

  @override
  ConsumerState<DaybookComposer> createState() => DaybookComposerState();
}

class DaybookComposerState extends ConsumerState<DaybookComposer> {
  late final DaybookWriter _writer = DaybookWriter(
    ref,
    widget.spaceId,
    editing: widget.editing,
  );
  late final TextEditingController _title;
  late final TextEditingController _body;
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  /// The keyboard's height, once the phone has shown it: the grids take
  /// its place.
  double _keyboard = BvIconGridSpec.panelHeight;

  @override
  void initState() {
    super.initState();
    final draft = _writer.draft;
    _title = TextEditingController(text: draft?.title);
    _body = TextEditingController(text: draft?.body);
    for (final f in [_titleFocus, _bodyFocus]) {
      // A field in hand brings the keyboard back: the grid goes.
      f.addListener(() {
        if (f.hasFocus && widget.panel != null) widget.onPanel(null);
      });
    }
    // Z13: a file gone from the phone says so as the draft opens.
    if (draft != null && !draft.couldNotSend) {
      final gone = goneDraftFile(
        ref.read(localFileThereProvider),
        photos: draft.photos,
        voice: draft.voiceLocal,
        files: draft.files,
      );
      if (gone != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_writer.fileGone(gone));
        });
      }
    }
  }

  @override
  void didUpdateWidget(DaybookComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panel != null && oldWidget.panel == null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (widget.panel == null && oldWidget.panel == ComposerPanel.kinds) {
      // A kind picked: the keyboard comes back on the title.
      _titleFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// Review 113 bug 7: "Couldn't send · Tap to fix" says what is wrong,
  /// with Try again or Remove: Remove takes off the refused file, or puts
  /// the post away when no file was the problem.
  Future<void> _fix(DaybookPostDraft draft) async {
    // Review 113 (17): the last place was refused: the fix is a place.
    if (draft.refusal == samePlaceRefused) {
      widget.onCheckIn?.call(CheckInPick.place);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final refused = FileRefused.fromCode(draft.refusal);
    final why = refused != null
        ? fileRefusedText(l10n, refused)
        : draft.kind == DaybookKind.thanks
        ? thanksRefusalText(l10n, draft.refusal)
        : draft.refusal == RefusalWhy.forSomeoneElse.name
        ? l10n.workItemForSomeoneElse
        : l10n.couldNotSendGeneric;
    final picked = await showCouldNotSendFix(
      context,
      why: why,
      refused: refused,
      tryAgain:
          widget.onTryAgain != null && refused?.problem != UploadProblem.gone,
      linkFolder: widget.onLinkFolder != null,
    );
    if (!mounted) return;
    runCouldNotSendFix(
      picked,
      tryAgain: widget.onTryAgain,
      linkFolder: widget.onLinkFolder,
      remove: () async {
        final file = refused == null
            ? null
            : draft.files
                  .where((f) => f.libraryId == refused.fileId)
                  .firstOrNull;
        if (refused != null) {
          if (file != null) await _writer.removeFile(file);
          // Z13: a photo or a voice note is named by its place on the phone.
          final photo = draft.photos.indexOf(refused.fileId ?? '');
          if (photo >= 0) await _writer.removePhoto(photo);
          if (draft.voiceLocal != null && draft.voiceLocal == refused.fileId) {
            await _writer.removeVoice();
          }
          await _writer.clearRefusal();
          return;
        }
        await ref.read(daybookDraftProvider(widget.spaceId).notifier).discard();
        widget.onClose();
      },
    );
  }

  /// Bullets (CP3): a new line in the details that starts with a bullet.
  void addBullet() {
    final text = _body.text;
    final line = '$noteBulletMark ';
    final next = text.isEmpty || text.endsWith('\n')
        ? '$text$line'
        : '$text\n$line';
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _lastTyped = next;
    unawaited(_writer.setBody(next));
    _bodyFocus.requestFocus();
  }

  /// Date & time (review 113 (12)): today's, as text, where the cursor is
  /// in [field].
  void insertNow(TextEditingController field) {
    final now = ref.read(clockProvider)();
    final words = widget.words;
    final stamp = '${words.dayMonth(now)} ${words.time.clock(now)}';
    final v = field.value;
    final at = v.selection.isValid ? v.selection.start : v.text.length;
    final end = v.selection.isValid ? v.selection.end : at;
    final next = v.text.replaceRange(at, end, stamp);
    field.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + stamp.length),
    );
    if (identical(field, _body)) _lastTyped = next;
    unawaited(
      identical(field, _title) ? _writer.setTitle(next) : _writer.setBody(next),
    );
  }

  /// What the short menu offers for this kind: Date & time always; Bullets
  /// and Table where + has them.
  List<ComposerQuick> _quick(DaybookKind kind) {
    final offered = composerOffered(kind, editing: widget.editing);
    return [
      ComposerQuick.dateTime,
      if (offered.contains(ComposerExtra.bullets)) ComposerQuick.bullets,
      if (offered.contains(ComposerExtra.table)) ComposerQuick.table,
    ];
  }

  void _doQuick(ComposerQuick q, TextEditingController field) => switch (q) {
    ComposerQuick.dateTime => insertNow(field),
    ComposerQuick.bullets => addBullet(),
    ComposerQuick.table => widget.onExtra(ComposerExtra.table),
  };

  String _quickName(AppLocalizations l10n, ComposerQuick q) => switch (q) {
    ComposerQuick.dateTime => l10n.cpDateTime,
    ComposerQuick.bullets => l10n.cpBullets,
    ComposerQuick.table => l10n.pageTable,
  };

  /// The phone's own menu (Paste, Select all…), then ours (CV3 (12)).
  /// B4 (review 114): a tap elsewhere closes the long-press menu; the
  /// keyboard stays, as before.
  static void _closeMenu(PointerDownEvent _) =>
      ContextMenuController.removeAny();

  Widget _textMenu(
    AppLocalizations l10n,
    DaybookKind kind,
    TextEditingController field,
    EditableTextState state,
  ) => AdaptiveTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    // Z8: ours first, so they never fall under the phone's ⋮.
    buttonItems: [
      for (final q in _quick(kind))
        ContextMenuButtonItem(
          label: _quickName(l10n, q),
          onPressed: () {
            state.hideToolbar();
            _doQuick(q, field);
          },
        ),
      ...state.contextMenuButtonItems,
    ],
  );

  /// "/" typed at the start of a line (CV3 (12)): it goes, and the same
  /// short menu opens.
  late String _lastTyped = _body.text;

  void _slash(TextEditingController field, DaybookKind kind) {
    final v = field.value;
    final at = v.selection.baseOffset;
    final title = identical(field, _title);
    final typed = v.text.length == (title ? 1 : _lastTyped.length + 1);
    if (!title) _lastTyped = v.text;
    if (!typed || at < 1 || v.text[at - 1] != '/') return;
    if (at > 1 && v.text[at - 2] != '\n') return;
    final next = v.text.replaceRange(at - 1, at, '');
    field.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at - 1),
    );
    if (!title) _lastTyped = next;
    unawaited(title ? _writer.setTitle(next) : _writer.setBody(next));
    unawaited(_openQuick(field, kind));
  }

  Future<void> _openQuick(TextEditingController field, DaybookKind kind) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showGeneralDialog<ComposerQuick>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: BvColors.surfaceElevated.withValues(alpha: 0),
      pageBuilder: (menu, _, _) => Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: BvSpace.gutter,
            bottom:
                MediaQuery.viewInsetsOf(menu).bottom +
                BvWritingLineSpec.quickMenuBottom,
          ),
          child: BvPopoverMenu<ComposerQuick>.screen(
            key: const Key('composer-quick'),
            items: [
              for (final q in _quick(kind))
                BvMenuItem(
                  key: Key('quick-${q.name}'),
                  value: q,
                  label: _quickName(l10n, q),
                  icon: switch (q) {
                    ComposerQuick.dateTime => BvIcons.dateTime,
                    ComposerQuick.bullets => BvIcons.bulletList,
                    ComposerQuick.table => BvIcons.tableBlock,
                  },
                ),
            ],
            onSelected: (q) => Navigator.of(menu).pop(q),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _doQuick(picked, field);
  }

  /// Discard (review 113 (1)): asked once, then the draft is gone.
  Future<void> _discard(DaybookPostDraft draft) async {
    final discard = widget.onDiscard;
    if (discard == null) return;
    if (draft.isEmpty) return discard();
    final l10n = AppLocalizations.of(context);
    final sure = await showBvDialog(
      context: context,
      title: l10n.cpDiscardTitle,
      body: l10n.cpDiscardBody,
      cancelLabel: l10n.cpDiscardKeep,
      confirmLabel: l10n.cpDiscard,
      destructive: true,
    );
    if (sure && mounted) discard();
  }

  String _top(AppLocalizations l10n, DaybookKind kind) => widget.editing
      ? l10n.cpEdit(kindName(l10n, kind))
      : switch (kind) {
          DaybookKind.note => l10n.cpNewNote,
          DaybookKind.workItem => l10n.cpNewWorkItem,
          DaybookKind.checklist => l10n.cpNewChecklist,
          DaybookKind.announcement => l10n.cpNewAnnouncement,
          DaybookKind.activity => l10n.cpNewActivity,
          DaybookKind.thanks => l10n.cpNewThanks,
          DaybookKind.checkIn => l10n.cpNewCheckIn,
          DaybookKind.poll => l10n.cpNewPoll,
          DaybookKind.file || DaybookKind.report => kindName(l10n, kind),
        };

  String _addTo(AppLocalizations l10n, DaybookKind kind) => switch (kind) {
    DaybookKind.note => l10n.cpAddNote,
    DaybookKind.workItem => l10n.cpAddWorkItem,
    DaybookKind.checklist => l10n.cpAddChecklist,
    DaybookKind.announcement => l10n.cpAddAnnouncement,
    DaybookKind.activity => l10n.cpAddActivity,
    DaybookKind.thanks => l10n.cpAddThanks,
    DaybookKind.checkIn => l10n.cpAddCheckIn,
    DaybookKind.poll => l10n.cpAddPoll,
    DaybookKind.file || DaybookKind.report => l10n.daybookAttachTitle,
  };

  String _bodyHint(AppLocalizations l10n, DaybookKind kind) => switch (kind) {
    // W6: a Thanks has Details (optional) under its words (TH1).
    DaybookKind.workItem ||
    DaybookKind.thanks ||
    DaybookKind.checkIn => l10n.cpDetails,
    DaybookKind.announcement => l10n.daybookBodyAnnouncement,
    DaybookKind.activity => l10n.daybookBodyActivity,
    _ => l10n.daybookBodyNote,
  };

  static String extraName(AppLocalizations l10n, ComposerExtra e) =>
      switch (e) {
        ComposerExtra.place => l10n.daybookRowPlace,
        ComposerExtra.people => l10n.cpPeople,
        ComposerExtra.due => l10n.daybookRowDue,
        ComposerExtra.tag => l10n.cpTag,
        ComposerExtra.photos => l10n.cpPhotos,
        ComposerExtra.file => l10n.cpFile,
        ComposerExtra.checklist => l10n.daybookKindChecklist,
        ComposerExtra.bullets => l10n.cpBullets,
        ComposerExtra.table => l10n.pageTable,
        ComposerExtra.taskTable => l10n.pageTaskTable,
        ComposerExtra.pin => l10n.cpPin,
        ComposerExtra.checkOut => l10n.checkInExtraOut,
        ComposerExtra.everyDay => l10n.checkInEveryDay,
        ComposerExtra.closes => l10n.pollClosesExtra,
      };

  static IconData extraIcon(ComposerExtra e) => switch (e) {
    ComposerExtra.place => BvIcons.place,
    ComposerExtra.people => BvIcons.people,
    ComposerExtra.due => BvIcons.calendar,
    ComposerExtra.tag => BvIcons.tag,
    ComposerExtra.photos => BvIcons.image,
    ComposerExtra.file => BvIcons.document,
    ComposerExtra.checklist => BvIcons.workItems,
    ComposerExtra.bullets => BvIcons.bulletList,
    ComposerExtra.table => BvIcons.tableBlock,
    ComposerExtra.taskTable => BvIcons.todoList,
    ComposerExtra.pin => BvIcons.pin,
    ComposerExtra.checkOut => BvIcons.checkOut,
    ComposerExtra.everyDay => BvIcons.repeat,
    ComposerExtra.closes => BvIcons.clock,
  };

  /// # (CP2): the kind's icon on the bar.
  static IconData composerKindIcon(DaybookKind kind) => switch (kind) {
    DaybookKind.announcement => BvIcons.announcement,
    DaybookKind.activity => BvIcons.calendar,
    _ => kindIcon(kind),
  };

  /// The kind's own lines (CP1): For and Team for a work item, When and
  /// Team for an activity, Team for the others.
  List<BvWritingRow> _lines(
    AppLocalizations l10n,
    DaybookPostDraft draft,
    DateTime now, {
    required String? me,
    required List<SpaceTeam> teams,
  }) {
    final words = widget.words;
    final kind = draft.kind;
    BvWritingRow choose(VoidCallback onTap) => BvWritingRow(
      key: const Key('writing-who'),
      label: l10n.daybookRowFor,
      value: widget.askWho == null
          ? l10n.daybookRowChoose
          : l10n.daybookChooseWho,
      empty: true,
      ask: widget.askWho,
      onTap: onTap,
    );
    BvWritingRow owner() {
      final id = draft.ownerId;
      if (id == null) {
        return choose(() => widget.onMenu(DaybookWritingMenu.assign));
      }
      final name = personName(l10n, draft.ownerName);
      return BvWritingRow(
        key: const Key('writing-who'),
        label: l10n.daybookRowFor,
        value: id == me ? l10n.daybookYou : name,
        person: name,
        tint: BvAvatarTints.forId(id),
        onTap: widget.editing
            ? null
            : () => widget.onMenu(DaybookWritingMenu.assign),
      );
    }

    BvWritingRow people() => draft.people.isEmpty
        ? choose(widget.onPickPeople)
        : BvWritingRow(
            key: const Key('writing-who'),
            label: l10n.daybookRowFor,
            value: words.peopleFor([
              for (final p in draft.people)
                DaybookPerson(id: p.id, name: p.name),
            ], me: me),
            onTap: widget.onPickPeople,
          );
    if (kind == DaybookKind.thanks) return _thanksLines(l10n, draft);
    // Review 109 CI1: For · Check-in · Place.
    if (kind == DaybookKind.checkIn) {
      return checkInLines(
        l10n,
        words,
        draft,
        reading: ref.watch(checkInPlaceReadingProvider(widget.spaceId)),
        ask: widget.askWho,
        onPick: (p) => widget.onCheckIn?.call(p),
      );
    }
    final team = BvWritingRow(
      key: const Key('writing-to'),
      label: l10n.daybookRowTeam,
      value: draft.teamName ?? l10n.daybookWholeSpace,
      onTap: teams.isEmpty || widget.editing
          ? null
          : () => widget.onMenu(DaybookWritingMenu.audience),
    );
    return switch (kind) {
      DaybookKind.workItem => [owner(), team],
      DaybookKind.checklist => [people(), team],
      DaybookKind.activity => [
        BvWritingRow(
          key: const Key('writing-when-row'),
          label: l10n.daybookRowWhen,
          value: draft.startsAt == null
              ? l10n.daybookRowAdd
              : words.activityWhen(draft.startsAt!, draft.endsAt, now),
          empty: draft.startsAt == null,
          onTap: widget.onPickStart,
        ),
        team,
      ],
      DaybookKind.note ||
      DaybookKind.announcement ||
      DaybookKind.poll => [team],
      // Answered above (_thanksLines, checkInLines).
      DaybookKind.thanks || DaybookKind.checkIn => const [],
      DaybookKind.file || DaybookKind.report => [
        BvWritingRow(
          key: const Key('writing-to'),
          label: l10n.daybookRowTeam,
          // B4 (review 114): one word for the whole Space.
          value: draft.teamName ?? l10n.daybookWholeSpace,
          onTap: teams.isEmpty || widget.editing || kind == DaybookKind.file
              ? null
              : () => widget.onMenu(DaybookWritingMenu.audience),
        ),
      ],
    };
  }

  /// A Thanks's lines (TH1): To (required: a person or a Team) and For
  /// (optional: a work item; × clears it).
  List<BvWritingRow> _thanksLines(
    AppLocalizations l10n,
    DaybookPostDraft draft,
  ) {
    final to = draft.thanksToId;
    final person = to == null || draft.thanksToTeam
        ? null
        : personName(l10n, draft.thanksToName);
    final label = draft.thanksForLabel;
    return [
      BvWritingRow(
        key: const Key('writing-thanks-to'),
        label: l10n.thanksTo,
        value: to == null
            ? (widget.askWho == null
                  ? l10n.daybookRowChoose
                  : l10n.daybookChooseWho)
            : person ?? draft.thanksToName ?? '',
        person: person,
        tint: person == null ? null : BvAvatarTints.forId(to!),
        empty: to == null,
        ask: widget.askWho,
        onTap: widget.onPickThanksTo,
      ),
      BvWritingRow(
        key: const Key('writing-thanks-for'),
        label: l10n.thanksFor,
        value: label ?? l10n.thanksForOptional,
        empty: label == null,
        onTap: widget.onPickThanksFor,
        onClear: draft.thanksForId == null
            ? null
            : () => unawaited(_writer.setThanksFor(null)),
        clearLabel: l10n.cpRemoveThe(l10n.thanksFor),
        clearKey: const Key('writing-thanks-for-clear'),
      ),
    ];
  }

  /// What was added from + (CP4): small chips with ×.
  /// Review 103: the smaller copy in place of [f], when it is used.
  Future<void> _smaller(DraftFile f) async {
    final smaller = await makeSmaller(
      context,
      ref,
      PhoneFile(local: f.local!, name: f.name, mime: f.mime, bytes: f.bytes),
    );
    if (smaller == null || !mounted) return;
    await _writer.swapFile(f, local: smaller.local, bytes: smaller.bytes);
  }

  List<Widget> _added(
    AppLocalizations l10n,
    DaybookPostDraft draft,
    DateTime now,
  ) {
    final words = widget.words;
    final where =
        placeName(
          ref.watch(spacePlacesProvider(widget.spaceId)).value,
          draft.placeId,
        ) ??
        draft.place;
    final lang = Localizations.localeOf(context).languageCode;
    final checklist = draft.blocks
        .where((b) => b['type'] == PageChecklist.kind)
        .firstOrNull;
    return [
      // Review 109 CI1: Check-out and Every day, from +.
      if (draft.kind == DaybookKind.checkIn)
        for (final c in checkInChips(l10n, words, draft))
          BvFilterChip(
            key: c.key,
            clearKey: c.clearKey,
            icon: c.icon,
            label: c.label,
            clearLabel: l10n.cpRemoveThe(
              c.chip == CheckInChip.checkOut
                  ? l10n.checkInExtraOut
                  : l10n.checkInEveryDay,
            ),
            onTap: c.chip == CheckInChip.checkOut
                ? () => widget.onExtra(ComposerExtra.checkOut)
                : null,
            onClear: () => unawaited(
              c.chip == CheckInChip.checkOut
                  ? _writer.setCheckOut(null)
                  : _writer.setDaily(false),
            ),
          ),
      // Review 116 PL1: a poll's closing time, from + → Closes.
      if (draft.kind == DaybookKind.poll && draft.pollClosesAt != null)
        BvFilterChip(
          key: const Key('writing-poll-closes'),
          clearKey: const Key('writing-poll-closes-clear'),
          icon: BvIcons.clock,
          label: l10n.pollCloses(words.pollWhen(draft.pollClosesAt!, now)),
          clearLabel: l10n.cpRemoveThe(l10n.pollClosesExtra),
          onTap: () => widget.onExtra(ComposerExtra.closes),
          onClear: () => unawaited(_writer.setPollClosesAt(null)),
        ),
      // Review 113 (11): the voice note; a tap plays it.
      if (draft.voiceLocal case final voice?)
        BvFilterChip(
          key: const Key('writing-voice-chip'),
          clearKey: const Key('writing-voice-chip-clear'),
          icon: BvIcons.microphone,
          label: voiceTime(Duration(milliseconds: draft.voiceMs)),
          clearLabel: l10n.cpRemoveThe(l10n.cpVoice),
          onTap: () => unawaited(
            ref
                .read(voicePlayerProvider.notifier)
                .toggle('draft-${draft.id}', voice, isFile: true),
          ),
          onClear: () => unawaited(_writer.removeVoice()),
        ),
      // TG1: the one tag, red when it is a danger tag (Safety).
      if (draft.tag case final tag?)
        BvFilterChip(
          key: const Key('writing-tag-chip'),
          clearKey: const Key('writing-tag-chip-clear'),
          icon: BvIcons.tag,
          label: tag.nameIn(lang),
          danger: tag.danger,
          clearLabel: l10n.cpRemoveThe(l10n.cpTag),
          onTap: () => widget.onPanel(ComposerPanel.tags),
          onClear: () => unawaited(_writer.setTag(null)),
        ),
      // Step 5: + → Checklist's points; a tap edits them.
      if (checklist != null)
        BvFilterChip(
          key: const Key('writing-checklist-chip'),
          clearKey: const Key('writing-checklist-chip-clear'),
          icon: BvIcons.workItems,
          label: l10n.cpChecklistChip(
            (checklist['point_ids'] as List? ?? const []).length,
          ),
          clearLabel: l10n.cpRemoveThe(l10n.daybookKindChecklist),
          onTap: () => unawaited(editComposerChecklist(context, _writer)),
          onClear: () => unawaited(_writer.setChecklist(const [])),
        ),
      if (draft.templateName != null && draft.templateId != null)
        BvFilterChip(
          key: const Key('writing-template'),
          clearKey: const Key('writing-template-clear'),
          icon: BvIcons.clipboard,
          label: l10n.templateFrom(inOwnDirection(draft.templateName!)),
          clearLabel: l10n.templateDrop,
          onClear: () => unawaited(_writer.dropTemplate()),
        ),
      if (where != null)
        BvFilterChip(
          key: const Key('writing-place-chip'),
          clearKey: const Key('writing-place-chip-clear'),
          icon: BvIcons.place,
          label: where,
          clearLabel: l10n.cpRemoveThe(l10n.daybookRowPlace),
          onTap: widget.onPickPlace,
          onClear: () => unawaited(_writer.pickPlace(null)),
        ),
      if (draft.dueDate != null)
        BvFilterChip(
          key: const Key('writing-due-chip'),
          clearKey: const Key('writing-due-chip-clear'),
          icon: BvIcons.calendar,
          label: words.dueProperty(draft.dueDate!, draft.dueAt),
          clearLabel: l10n.cpRemoveThe(l10n.daybookRowDue),
          onTap: widget.onPickDue,
          onClear: () => unawaited(_writer.setDue((day: null, at: null))),
        ),
      if (draft.kind == DaybookKind.announcement && draft.pinnedUntil != null)
        ..._pin(l10n, draft.pinnedUntil!, now),
      // A scheduled activity's people (F56: required), once chosen on the
      // sheet Send opens; a tap chooses again.
      if (draft.kind == DaybookKind.activity && draft.people.isNotEmpty)
        BvFilterChip(
          key: const Key('writing-people-chip'),
          clearKey: const Key('writing-people-chip-clear'),
          icon: BvIcons.team,
          label: words.peopleFor([
            for (final p in draft.people) DaybookPerson(id: p.id, name: p.name),
          ], me: ref.watch(authUserIdProvider).value),
          clearLabel: l10n.cpRemoveThe(l10n.daybookRowFor),
          onTap: widget.onPickPeople,
          onClear: () => unawaited(_writer.clearPeople()),
        ),
      for (final (i, f) in draft.files.indexed)
        BvFilterChip(
          key: Key('writing-file-$i'),
          icon: f.scanned ? BvIcons.scan : BvIcons.document,
          // The lead's checks: the name without ".pdf", in its own
          // direction (D17, D23), shortened with "…"; the facts and the size
          // (D11) always in full (D24).
          label: f.revLabel == null
              ? fileTitle(f.name)
              : l10n.daybookFileChip(fileTitle(f.name), f.revLabel!),
          detail: switch (joinMeta([
            // Review 103 SC4: "Scanned · 3 pages".
            if (f.scanned && f.pages != null)
              l10n.scannedPages(l10n.scanPages(f.pages!)),
            if (f.bytes != null) fileSize(l10n, f.bytes),
          ])) {
            '' => null,
            final facts => facts,
          },
          clearLabel: l10n.daybookRemoveFile,
          onClear: () => unawaited(_writer.removeFile(f)),
        ),
      // Review 103: Make it smaller, on a PDF of 1 MB or more still on
      // the phone; an offer, never automatic.
      for (final (i, f) in draft.files.indexed)
        if (offersSmaller(f.local, f.mime, f.bytes))
          BvChip(
            key: Key('writing-file-smaller-$i'),
            label: l10n.pdfSmaller,
            tight: true,
            onTap: () => unawaited(_smaller(f)),
          ),
      // F71: "Replaces M-201.pdf · Rev C", with × to make it a new file.
      for (final f in draft.files)
        if (f.supersedesRev != null && f.local != null)
          BvFilterChip(
            key: Key('writing-replaces-${f.libraryId}'),
            icon: BvIcons.newAbove,
            label: l10n.daybookReplacesOption(f.supersedesRev!),
            clearLabel: l10n.daybookNotNewVersion,
            onClear: () => unawaited(_writer.notReplacing(f)),
          ),
      for (final b in draft.blocks)
        if (b['type'] == PageTable.kind || b['type'] == PageTaskTable.kind)
          BvFilterChip(
            key: Key('writing-block-${b['id']}'),
            icon: b['type'] == PageTable.kind
                ? BvIcons.tableBlock
                : BvIcons.todoList,
            label: b['type'] == PageTable.kind
                ? l10n.cpTableChip((b['rows'] as List? ?? const []).length)
                : l10n.cpTaskTableChip((b['rows'] as List? ?? const []).length),
            clearLabel: l10n.cpRemoveThe(
              b['type'] == PageTable.kind ? l10n.pageTable : l10n.pageTaskTable,
            ),
            onTap: () => unawaited(
              b['type'] == PageTable.kind
                  ? editComposerTable(context, _writer, b)
                  : editComposerTasks(context, _writer, b),
            ),
            onClear: () => unawaited(_writer.removeBlock('${b['id']}')),
          ),
    ];
  }

  /// The pin (F82): with no time, × takes the pin off and "+ Time" sets
  /// the time it ends; with a time, × takes the time away, and the pin
  /// ends with its day again.
  List<Widget> _pin(AppLocalizations l10n, DateTime until, DateTime now) {
    final timed = pinHasTime(until);
    return [
      BvFilterChip(
        key: const Key('writing-pin'),
        clearKey: const Key('writing-pin-clear'),
        icon: BvIcons.pin,
        label: l10n.daybookPinnedProperty(widget.words.pinnedShort(until, now)),
        clearLabel: timed
            ? l10n.daybookPinRemoveTime
            : l10n.cpRemoveThe(l10n.cpPin),
        onTap: widget.onPickPin,
        onClear: () => unawaited(
          _writer.setPin(
            timed ? pinToEndOf(dayOf(pinnedLastDay(until))) : null,
          ),
        ),
      ),
      if (!timed)
        BvChip(
          key: const Key('pin-add-time'),
          icon: BvIcons.due,
          label: l10n.daybookPinAddTime,
          onTap: widget.onPickPinTime,
        ),
    ];
  }

  Widget _grid(
    AppLocalizations l10n,
    DaybookPostDraft draft, {
    required bool walk,
  }) => switch (widget.panel!) {
    ComposerPanel.kinds => BvIconGrid(
      key: const Key('composer-kinds'),
      title: l10n.cpWhatPosting,
      keyPrefix: 'composer-kind',
      columns: BvIconGridSpec.kindsColumns,
      largeColumns: BvIconGridSpec.kindsColumnsLarge,
      items: [
        for (final k in widget.kinds)
          BvIconGridItem(
            id: k.json,
            icon: composerKindIcon(k),
            label: kindName(l10n, k),
            selected: draft.kind == k,
          ),
        if (walk)
          BvIconGridItem(
            id: kindChipWalk,
            icon: BvIcons.walk,
            label: l10n.daybookKindWalk,
          ),
      ],
      onSelected: (id) => id == kindChipWalk
          ? widget.onWalk?.call()
          : widget.onKind(DaybookKind.fromJson(id)),
    ),
    ComposerPanel.extras => BvIconGrid(
      key: const Key('composer-extras'),
      title: _addTo(l10n, draft.kind),
      keyPrefix: 'composer-extra',
      columns: BvIconGridSpec.extrasColumns,
      largeColumns: BvIconGridSpec.extrasColumnsLarge,
      items: [
        for (final e in composerOffered(draft.kind, editing: widget.editing))
          BvIconGridItem(
            id: e.key,
            icon: extraIcon(e),
            label: extraName(l10n, e),
          ),
      ],
      onSelected: (id) {
        final e = ComposerExtra.values.firstWhere((e) => e.key == id);
        // TG1: Tag's list takes the grid's place.
        if (e == ComposerExtra.tag) return widget.onPanel(ComposerPanel.tags);
        widget.onPanel(null);
        e == ComposerExtra.bullets ? addBullet() : widget.onExtra(e);
      },
    ),
    ComposerPanel.tags => ComposerTagPanel(
      key: const Key('composer-tags'),
      spaceId: widget.spaceId,
      chosen: draft.tag?.id,
      onPick: (t) => unawaited(
        _writer.setTag(t == null || t.id == draft.tag?.id ? null : t),
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final provider = widget.editing
        ? daybookEditProvider(widget.spaceId)
        : daybookDraftProvider(widget.spaceId);
    // A template filled the card: its boxes show the new words.
    ref.listen(provider, (was, now) {
      if (now == null || now.templateId == null) return;
      if (was?.templateId == now.templateId) return;
      if (_title.text != now.title) _title.text = now.title;
      if (_body.text != now.body) _body.text = now.body;
    });
    final draft = ref.watch(provider);
    if (draft == null) return const SizedBox.shrink();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard > 0) _keyboard = keyboard;
    final now = ref.watch(clockProvider)();
    final me = ref.watch(authUserIdProvider).value;
    final teams = audienceTeams(
      ref.watch(spacePeopleProvider(widget.spaceId)).value,
      me: me,
      admin:
          ref.watch(spaceDetailProvider(widget.spaceId)).value?.iAmAdmin ??
          false,
    );
    final kind = draft.kind;
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    // CV3: Type is the first of the pinned lines. It opens the kinds' grid
    // (who may only thank has no choice of kind; an edit keeps its kind,
    // which the top bar names).
    final lines = [
      if (widget.kinds.length > 1 && !widget.editing)
        BvWritingRow(
          key: const Key('writing-kind'),
          label: l10n.cpType,
          value: kindName(l10n, kind),
          accent: true,
          onTap: widget.kinds.contains(kind)
              ? () => widget.onPanel(
                  widget.panel == ComposerPanel.kinds
                      ? null
                      : ComposerPanel.kinds,
                )
              : null,
        ),
      ..._lines(l10n, draft, now, me: me, teams: teams),
    ];
    final added = _added(l10n, draft, now);
    final preparing = ref.watch(
      photosPreparingProvider('daybook:${widget.spaceId}'),
    );
    // CP1: plain lines, no boxes (the app's field theme draws borders).
    final field = InputDecoration.collapsed(hintText: '').copyWith(
      hintStyle: type.bodyMd.copyWith(color: BvColors.textSecondary),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
    );
    return Column(
      key: const Key('composer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // × · the kind's name over the Space's · Templates (W9).
        Padding(
          key: const Key('composer-top'),
          padding: BvComposerSpec.topPadding,
          child: Row(
            spacing: BvSpace.s8,
            children: [
              IconButton(
                key: const Key('composer-close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(BvIcons.close, color: BvColors.iconPrimary),
                onPressed: widget.onClose,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _top(l10n, kind),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.titleMd.copyWith(color: BvColors.textPrimary),
                    ),
                    Text(
                      l10n.cpSpaceLine(
                        widget.spaceName,
                        l10n.spacesPrivateWork,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: quiet,
                    ),
                  ],
                ),
              ),
              if (widget.onTemplates != null &&
                  writingHasTemplates(
                    ref,
                    widget.spaceId,
                    draft,
                    editing: widget.editing,
                  ))
                TextButton(
                  key: const Key('composer-templates'),
                  onPressed: widget.onTemplates,
                  child: Text(l10n.cpTemplates, style: quiet),
                ),
              if (widget.onDiscard != null)
                TextButton(
                  key: const Key('composer-discard'),
                  onPressed: () => unawaited(_discard(draft)),
                  child: Text(
                    l10n.cpDiscard,
                    style: type.emphasisSm.copyWith(color: BvColors.textAction),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  padding: BvComposerSpec.bodyPadding,
                  children: [
                    if (kind != DaybookKind.report) ...[
                      TextField(
                        key: const Key('writing-title'),
                        controller: _title,
                        focusNode: _titleFocus,
                        // Review 118 F1: in the direction of what is
                        // written ("Pour time on level 4?" in Arabic too, and
                        // a poll made a work item).
                        textDirection: _title.text.trim().isEmpty
                            ? null
                            : directionOf(_title.text),
                        autofocus: widget.panel == null,
                        maxLength: draft.titleLimit,
                        buildCounter: _noCounter,
                        // TH1: a Thanks's words, on as many lines as they
                        // take.
                        minLines: 1,
                        maxLines: kind == DaybookKind.thanks ? null : 1,
                        textInputAction: kind == DaybookKind.thanks
                            ? TextInputAction.newline
                            : TextInputAction.next,
                        style: type.titleLg.copyWith(
                          color: BvColors.textPrimary,
                        ),
                        decoration: field.copyWith(
                          hintText: kind == DaybookKind.thanks
                              ? l10n.thanksWordsHint
                              // Review 116 PL1: the poll's question.
                              : kind == DaybookKind.poll
                              ? l10n.pollQuestionHint
                              : l10n.daybookWritingTitle,
                          hintStyle: type.titleLg.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                        contextMenuBuilder: (_, state) =>
                            _textMenu(l10n, kind, _title, state),
                        onTapOutside: _closeMenu,
                        onChanged: (text) {
                          unawaited(_writer.setTitle(text));
                          _slash(_title, kind);
                        },
                      ),
                      // W6: a Thanks too (TH1): Details (optional) under
                      // its words; both go as its one body.
                      const SizedBox(height: BvSpace.s8),
                      // Review 116 PL1: a poll's options in place of its
                      // details.
                      if (kind == DaybookKind.poll)
                        ComposerPollEditor(draft: draft, writer: _writer)
                      else
                        TextField(
                          key: const Key('writing-body'),
                          controller: _body,
                          focusNode: _bodyFocus,
                          maxLength: DaybookPostDraft.bodyMax,
                          buildCounter: _noCounter,
                          minLines: 1,
                          maxLines: null,
                          style: type.bodyMd.copyWith(
                            color: BvColors.textPrimary,
                          ),
                          decoration: field.copyWith(
                            hintText: _bodyHint(l10n, kind),
                          ),
                          contextMenuBuilder: (_, state) =>
                              _textMenu(l10n, kind, _body, state),
                          onTapOutside: _closeMenu,
                          onChanged: (text) {
                            unawaited(_writer.setBody(text));
                            _slash(_body, kind);
                          },
                        ),
                    ],
                    if (draft.quote case final q?) ...[
                      const SizedBox(height: BvSpace.s12),
                      BvQuoteBlock(
                        key: const Key('writing-quote'),
                        from: widget.words.quoteFrom(q, now),
                        text: q.text,
                        maxLines: BvQuoteSpec.linesWriting,
                      ),
                    ],
                    // A daily report's title is its day, written for it.
                    if (kind == DaybookKind.report) ...[
                      Text(
                        draft.title,
                        key: const Key('report-title'),
                        style: type.titleMd.copyWith(
                          color: BvColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: BvSpace.s8),
                    ],
                    if (kind == DaybookKind.report)
                      ReportWriting(
                        key: ValueKey('report-${draft.id}'),
                        writer: _writer,
                        draft: draft,
                        words: widget.words,
                        writing: true,
                      ),
                    if (kind == DaybookKind.checklist) ...[
                      const SizedBox(height: BvSpace.s12),
                      DaybookPointsEditor(
                        key: ValueKey('points-${draft.id}-${draft.templateId}'),
                        points: draft.points,
                        writing: true,
                        onChanged: _writer.setPoints,
                      ),
                    ],
                    // CP4: the photos, as thumbnails above the lines.
                    if (draft.photos.isNotEmpty || preparing > 0) ...[
                      const SizedBox(height: BvSpace.s12),
                      Wrap(
                        spacing: BvSpace.s8,
                        runSpacing: BvSpace.s8,
                        children: [
                          for (final (i, p) in draft.photos.indexed)
                            _Thumb(
                              key: Key('writing-photo-$i'),
                              image: ref.watch(localPhotoProvider(p)),
                              removeLabel: l10n.daybookRemovePhoto,
                              onRemove: widget.editing
                                  ? null
                                  : () => unawaited(_writer.removePhoto(i)),
                            ),
                          for (var i = 0; i < preparing; i++)
                            const _Thumb(image: null),
                        ],
                      ),
                    ],
                    // Review 109: the server's time rules, said before Send
                    // can hit them (Send stays off).
                    if (kind == DaybookKind.checkIn &&
                        !draft.checkInTimesFit) ...[
                      const SizedBox(height: BvSpace.s8),
                      Text(
                        checkInFitsDay(draft.inTime!, draft.inAllow)
                            ? l10n.checkInOutTooEarly
                            : l10n.checkInDayFit,
                        key: const Key('writing-check-in-times-clash'),
                        style: type.metadata.copyWith(
                          color: BvColors.textDestructive,
                        ),
                      ),
                    ],
                    if (draft.couldNotSend) ...[
                      const SizedBox(height: BvSpace.s8),
                      // Review 113 bug 7: Tap to fix opens what is wrong.
                      CouldNotSendLine(
                        text: kind == DaybookKind.thanks
                            ? thanksRefusalText(l10n, draft.refusal)
                            : draft.refusal == samePlaceRefused
                            ? l10n.checkInSamePlaceRefused
                            : draft.refusal == RefusalWhy.forSomeoneElse.name
                            ? l10n.workItemForSomeoneElse
                            : l10n.daybookCouldNotSend,
                        onTap: () => unawaited(_fix(draft)),
                      ),
                    ],
                  ],
                ),
              ),
              ?widget.overlay,
            ],
          ),
        ),
        // CV3: pinned, always in the same place: the chips, then the lines.
        if (added.isNotEmpty)
          Padding(
            padding: BvWritingLineSpec.chipsPadding,
            child: Wrap(
              key: const Key('writing-added'),
              spacing: BvSpace.s8,
              runSpacing: BvSpace.s8,
              children: added,
            ),
          ),
        // Z14: a post shares its file with everyone who sees the post.
        if (draft.files.any((f) => f.folderId != null) &&
            (ref.watch(libraryFoldersProvider(widget.spaceId)).value ??
                    const <LibraryFolder>[])
                .any(
                  (folder) =>
                      draft.files.any((f) => f.folderId == folder.id) &&
                      folderNarrowerThanPost(folder, draft.teamId),
                ))
          Padding(
            padding: BvWritingLineSpec.chipsPadding,
            child: Text(
              l10n.postFileAudienceLine,
              key: const Key('writing-file-audience'),
              style: quiet,
            ),
          ),
        if (kind == DaybookKind.thanks)
          Padding(
            padding: BvWritingLineSpec.chipsPadding,
            child: Text(
              l10n.thanksProfileNote,
              key: const Key('writing-thanks-profile-note'),
              style: quiet,
            ),
          ),
        if (lines.isNotEmpty) BvWritingLines(rows: lines),
        widget.bar,
        if (widget.panel != null)
          SizedBox(
            height: _keyboard,
            child: _grid(l10n, draft, walk: widget.onWalk != null),
          ),
      ],
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

/// A photo on the composer (CP4): a small square, × at its corner.
class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.image,
    this.removeLabel,
    this.onRemove,
  });

  final ImageProvider? image;
  final String? removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final picture = ClipRRect(
      borderRadius: BvComposerSpec.thumbRadius,
      child: SizedBox.square(
        dimension: BvComposerSpec.thumb,
        child: image == null
            ? const ColoredBox(
                color: BvColors.surfaceSubtle,
                child: Center(child: CircularProgressIndicator()),
              )
            : Image(image: image!, fit: BoxFit.cover),
      ),
    );
    if (onRemove == null) return picture;
    return Stack(
      children: [
        picture,
        PositionedDirectional(
          top: BvSpace.s2,
          end: BvSpace.s2,
          child: Semantics(
            button: true,
            label: removeLabel,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsetsDirectional.all(BvSpace.s2),
                decoration: const BoxDecoration(
                  color: BvColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  BvIcons.close,
                  size: BvSize.iconSm,
                  color: BvColors.iconPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Table (CP3): a small grid of words, rows by columns; Done puts it on
/// the post as a table block.
Future<void> editComposerTable(
  BuildContext context,
  DaybookWriter writer, [
  Map<String, dynamic>? block,
]) async {
  final l10n = AppLocalizations.of(context);
  final start = [
    for (final r in block?['rows'] as List? ?? const [])
      [for (final c in r as List) '${c ?? ''}'],
  ];
  final rows = await showBvSheet<List<List<String>>>(
    context: context,
    form: true,
    title: l10n.pageTable,
    builder: (sheet) => _TableSheet(
      rows: start.isEmpty
          ? [
              for (var r = 0; r < BvComposerSpec.tableRows; r++)
                List.filled(BvComposerSpec.tableColumns, ''),
            ]
          : start,
    ),
  );
  if (rows == null) return;
  final kept = [
    for (final r in rows)
      if (r.any((c) => c.trim().isNotEmpty)) r,
  ];
  if (kept.isEmpty) {
    if (block != null) await writer.removeBlock('${block['id']}');
    return;
  }
  await writer.putBlock({
    'id': block?['id'] ?? writer.newBlockId(),
    'type': PageTable.kind,
    'rows': kept,
  });
}

/// Table of tasks (CP3): one task a line; Done puts it on the work item.
Future<void> editComposerTasks(
  BuildContext context,
  DaybookWriter writer, [
  Map<String, dynamic>? block,
]) async {
  final l10n = AppLocalizations.of(context);
  final start = [
    for (final r in block?['rows'] as List? ?? const [])
      TaskRow.fromJson((r as Map).cast<String, dynamic>()),
  ];
  final tasks = await showBvSheet<List<String>>(
    context: context,
    form: true,
    title: l10n.pageTaskTable,
    builder: (sheet) => _LinesSheet(
      lines: [for (final t in start) t.text],
      hint: l10n.cpTaskHint,
      addLabel: l10n.cpAddTask,
      max: PageTaskTable.maxRows,
      cellMax: PageTaskTable.cellMax,
    ),
  );
  if (tasks == null) return;
  final kept = [
    for (final t in tasks)
      if (t.trim().isNotEmpty) t.trim(),
  ];
  if (kept.isEmpty) {
    if (block != null) await writer.removeBlock('${block['id']}');
    return;
  }
  await writer.putBlock({
    'id': block?['id'] ?? writer.newBlockId(),
    'type': PageTaskTable.kind,
    'rows': [
      for (final (i, t) in kept.indexed)
        TaskRow(
          i < start.length ? start[i].id : writer.newBlockId(),
          t,
        ).toJson(),
    ],
  });
}

/// + → Checklist on a work item (review 110 step 5): one point a line;
/// Done puts them on it with their checklist block.
Future<void> editComposerChecklist(
  BuildContext context,
  DaybookWriter writer,
) async {
  final l10n = AppLocalizations.of(context);
  final d = writer.draft;
  final block = d?.blocks
      .where((b) => b['type'] == PageChecklist.kind)
      .firstOrNull;
  final start = [
    for (final id in block?['point_ids'] as List? ?? const [])
      ?d!.points.where((p) => p.id == '$id').firstOrNull?.text,
  ];
  final lines = await showBvSheet<List<String>>(
    context: context,
    title: l10n.daybookKindChecklist,
    builder: (sheet) => _LinesSheet(
      lines: start,
      hint: l10n.cpPointHint,
      addLabel: l10n.cpAddPoint,
      max: Note.pointsMax,
      cellMax: PageChecklist.pointMax,
    ),
  );
  if (lines == null) return;
  await writer.setChecklist([
    for (final l in lines)
      if (l.trim().isNotEmpty) l.trim(),
  ]);
}

/// + → Tag (TG1 2715:39661): in place of the keyboard, the market's tags
/// as chips, one choice, a danger one red; a tap on the chosen one takes
/// it off.
class ComposerTagPanel extends ConsumerWidget {
  const ComposerTagPanel({
    super.key,
    required this.spaceId,
    required this.chosen,
    required this.onPick,
  });

  final String spaceId;
  final String? chosen;
  final ValueChanged<DaybookTag?> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final quiet = type.metadata.copyWith(color: BvColors.textSecondary);
    final lang = Localizations.localeOf(context).languageCode;
    final tags = ref.watch(spaceWorkTagsProvider(spaceId));
    return ColoredBox(
      color: BvColors.surfaceApp,
      child: SingleChildScrollView(
        padding: BvIconGridSpec.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BvIconGridSpec.titleGap,
          children: [
            Text(l10n.cpTagPanel, style: quiet),
            switch (tags) {
              AsyncData(:final value) => Wrap(
                spacing: BvSpace.s8,
                runSpacing: BvSpace.s8,
                children: [
                  for (final t in value)
                    BvChip(
                      key: Key('tag-option-${t.id}'),
                      label: t.nameIn(lang),
                      icon: BvIcons.tag,
                      selected: t.id == chosen,
                      danger: t.danger,
                      onTap: () => onPick(t),
                    ),
                ],
              ),
              AsyncError() => Text(l10n.cpTagsError, style: quiet),
              _ => const Center(child: CircularProgressIndicator()),
            },
            Text(l10n.cpTagNote, style: quiet),
          ],
        ),
      ),
    );
  }
}

class _TableSheet extends StatefulWidget {
  const _TableSheet({required this.rows});

  final List<List<String>> rows;

  @override
  State<_TableSheet> createState() => _TableSheetState();
}

class _TableSheetState extends State<_TableSheet> {
  late final List<List<TextEditingController>> _cells = [
    for (final r in widget.rows)
      [for (final c in r) TextEditingController(text: c)],
  ];

  int get _columns => _cells.first.length;

  @override
  void dispose() {
    for (final r in _cells) {
      for (final c in r) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return BvSheetForm(
      gap: BvSpace.s8,
      body: Column(
        key: const Key('composer-table-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s8,
        children: [
          for (final (r, row) in _cells.indexed)
            Row(
              spacing: BvSpace.s6,
              children: [
                for (final (c, cell) in row.indexed)
                  Expanded(
                    child: TextField(
                      key: Key('table-cell-$r-$c'),
                      controller: cell,
                      maxLength: PageTable.cellMax,
                      buildCounter: DaybookComposerState._noCounter,
                      style: (r == 0 ? type.emphasis : type.bodyMd).copyWith(
                        color: BvColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          Row(
            spacing: BvSpace.s8,
            children: [
              if (_cells.length < PageTable.maxRows)
                BvButton(
                  key: const Key('table-add-row'),
                  label: l10n.cpAddRow,
                  icon: BvIcons.add,
                  style: BvButtonStyle.quiet,
                  size: BvButtonSize.medium,
                  onPressed: () => setState(
                    () => _cells.add([
                      for (var c = 0; c < _columns; c++)
                        TextEditingController(),
                    ]),
                  ),
                ),
              if (_columns < PageTable.maxColumns)
                BvButton(
                  key: const Key('table-add-column'),
                  label: l10n.cpAddColumn,
                  icon: BvIcons.add,
                  style: BvButtonStyle.quiet,
                  size: BvButtonSize.medium,
                  onPressed: () => setState(() {
                    for (final r in _cells) {
                      r.add(TextEditingController());
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
      action: BvButton(
        key: const Key('table-done'),
        label: l10n.notebookDone,
        expand: true,
        onPressed: () => Navigator.of(context).pop([
          for (final r in _cells) [for (final c in r) c.text.trim()],
        ]),
      ),
    );
  }
}

/// Lines to fill, one a field, + to add one (a table of tasks).
class _LinesSheet extends StatefulWidget {
  const _LinesSheet({
    required this.lines,
    required this.hint,
    required this.addLabel,
    required this.max,
    required this.cellMax,
  });

  final List<String> lines;
  final String hint;
  final String addLabel;
  final int max;
  final int cellMax;

  @override
  State<_LinesSheet> createState() => _LinesSheetState();
}

class _LinesSheetState extends State<_LinesSheet> {
  late final List<TextEditingController> _lines = [
    for (final l in widget.lines.isEmpty ? const [''] : widget.lines)
      TextEditingController(text: l),
  ];

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    return BvSheetForm(
      gap: BvSpace.s8,
      body: Column(
        key: const Key('composer-lines-sheet'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: BvSpace.s8,
        children: [
          for (final (i, l) in _lines.indexed)
            TextField(
              key: Key('line-$i'),
              controller: l,
              autofocus: i == _lines.length - 1,
              maxLength: widget.cellMax,
              buildCounter: DaybookComposerState._noCounter,
              style: type.bodyMd.copyWith(color: BvColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hint,
                border: const OutlineInputBorder(),
              ),
            ),
          if (_lines.length < widget.max)
            BvButton(
              key: const Key('line-add'),
              label: widget.addLabel,
              icon: BvIcons.add,
              style: BvButtonStyle.quiet,
              size: BvButtonSize.medium,
              onPressed: () =>
                  setState(() => _lines.add(TextEditingController())),
            ),
        ],
      ),
      action: BvButton(
        key: const Key('lines-done'),
        label: l10n.notebookDone,
        expand: true,
        onPressed: () =>
            Navigator.of(context).pop([for (final l in _lines) l.text]),
      ),
    );
  }
}
