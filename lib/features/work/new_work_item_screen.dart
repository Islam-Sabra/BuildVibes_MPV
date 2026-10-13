import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/models/library.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/work_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_site_photo.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../entry/widgets/entry_scaffold.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import 'attach_files.dart';
import 'work_outbox.dart';

/// W2 · New work item: the photo first (camera, gallery as a fallback),
/// then the title, Owner, Due, Place on site and Team, and drawings or files
/// from the Library (W2-A). Voice notes come in week 6 part 3.
class NewWorkItemScreen extends ConsumerStatefulWidget {
  const NewWorkItemScreen({super.key, required this.spaceId});

  final String spaceId;

  static const titleMax = 140;
  static const placeMax = 80;

  @override
  ConsumerState<NewWorkItemScreen> createState() => _NewWorkItemScreenState();
}

/// The photo kept on the phone, and when it was taken.
class _Photo {
  const _Photo(this.local, this.takenAt);
  final String local;
  final DateTime takenAt;
}

class _NewWorkItemScreenState extends ConsumerState<NewWorkItemScreen> {
  final _id = newUuid();
  final _title = TextEditingController();
  _Photo? _photo;
  SpaceMember? _owner;
  DateTime? _due;
  String? _place;
  SpaceTeam? _team;

  /// W2-A: Library files to attach once the item is made.
  final _attached = <LibraryFile>[];
  var _showErrors = false;
  var _sending = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _titleOk => _title.text.trim().length >= 2;

  /// Close the keyboard before a sheet or the camera, so focus doesn't jump
  /// back into the title when it closes.
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _takePhoto({required bool camera}) async {
    _unfocus();
    final picked = await ref.read(pickPhotoProvider)(camera: camera);
    if (picked == null || !mounted) return;
    // Kept in the app's own folder at once: never lose a photo.
    final kept = await ref.read(keepPhotoProvider)(picked);
    if (mounted) {
      setState(() => _photo = _Photo(kept, ref.read(clockProvider)()));
    }
  }

  Future<void> _pickOwner(List<SpaceMember> members, String? me) async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    // Owners must be able to sign as done: never a Viewer (the server
    // checks the same).
    final candidates = [
      for (final m in members)
        if (m.pass != SpacePass.viewer) m,
    ];
    final picked = await showBvSheet<SpaceMember>(
      context: context,
      title: l10n.workCellOwner,
      builder: (sheetContext) => BvChoiceList<String>(
        value: _owner?.person.id,
        options: [
          for (final m in candidates)
            BvChoiceOption(
              key: Key('owner-${m.person.id}'),
              value: m.person.id,
              title: m.person.id == me
                  ? joinMeta([m.person.fullName, l10n.spacesYouTag])
                  : m.person.fullName,
              description: joinMeta([
                ?m.person.roleLabel(lang),
                ?m.person.companyLabel,
              ]),
            ),
        ],
        onChanged: (id) => Navigator.of(
          sheetContext,
        ).pop(candidates.firstWhere((m) => m.person.id == id)),
      ),
    );
    if (picked != null && mounted) setState(() => _owner = picked);
  }

  Future<void> _pickDue() async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    final today = DateUtils.dateOnly(ref.read(clockProvider)());
    final choice = await showBvSheet<String>(
      context: context,
      title: l10n.workCellDue,
      builder: (sheetContext) => BvChoiceList<String>(
        value: null,
        options: [
          BvChoiceOption(
            key: const Key('due-none'),
            value: 'none',
            title: l10n.workNoDue,
          ),
          BvChoiceOption(
            key: const Key('due-today'),
            value: 'today',
            title: l10n.workToday,
          ),
          BvChoiceOption(
            key: const Key('due-tomorrow'),
            value: 'tomorrow',
            title: l10n.workTomorrow,
          ),
          BvChoiceOption(
            key: const Key('due-pick'),
            value: 'pick',
            title: l10n.workPickDate,
          ),
        ],
        onChanged: (v) => Navigator.of(sheetContext).pop(v),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'none':
        setState(() => _due = null);
      case 'today':
        setState(() => _due = today);
      case 'tomorrow':
        setState(() => _due = today.add(const Duration(days: 1)));
      case 'pick':
        final picked = await showDatePicker(
          context: context,
          initialDate: _due ?? today,
          firstDate: today,
          lastDate: today.add(const Duration(days: 365)),
        );
        if (picked != null && mounted) setState(() => _due = picked);
    }
  }

  Future<void> _pickPlace() async {
    _unfocus();
    final place = await showBvSheet<String>(
      context: context,
      title: AppLocalizations.of(context).workCellPlace,
      builder: (_) => _PlaceSheet(initial: _place),
    );
    if (place != null && mounted) {
      setState(() => _place = place.isEmpty ? null : place);
    }
  }

  Future<void> _pickTeam(List<SpaceTeam> teams) async {
    _unfocus();
    final l10n = AppLocalizations.of(context);
    const none = '__none__';
    final picked = await showBvSheet<String>(
      context: context,
      title: l10n.workCellTeam,
      builder: (sheetContext) => BvChoiceList<String>(
        value: _team?.id ?? none,
        options: [
          BvChoiceOption(
            key: const Key('team-none'),
            value: none,
            title: l10n.workNoTeam,
          ),
          for (final t in teams)
            BvChoiceOption(
              key: Key('team-${t.id}'),
              value: t.id,
              title: t.name,
            ),
        ],
        onChanged: (v) => Navigator.of(sheetContext).pop(v),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _team = teams.where((t) => t.id == picked).firstOrNull;
      // A Team file only fits that Team's items.
      _attached.removeWhere((f) => f.teamId != null && f.teamId != _team?.id);
    });
  }

  /// W2-A: from the Library, from the phone, or the tag's photo.
  Future<void> _attach() async {
    _unfocus();
    final fileId = await chooseFileToAttach(
      context,
      spaceId: widget.spaceId,
      itemRef: ref.read(_nextRefProvider(widget.spaceId)).value ?? '',
      teamId: _team?.id,
      teamName: _team?.name,
      exclude: {for (final f in _attached) f.id},
      // One photo on the tag: offered while there is none yet.
      onTakePhoto: _photo == null ? () => _takePhoto(camera: true) : null,
    );
    if (fileId == null || !mounted) return;
    // A file just added from the phone is new to the list.
    ref.invalidate(libraryFilesProvider(widget.spaceId));
    final files = await ref.read(libraryFilesProvider(widget.spaceId).future);
    final file = files.where((f) => f.id == fileId).firstOrNull;
    if (file == null || !mounted) return;
    setState(() => _attached.add(file));
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final owner = _owner;
    if (!_titleOk || owner == null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _sending = true);
    final photo = _photo;
    final item = PendingItem(
      id: _id,
      spaceId: widget.spaceId,
      title: _title.text.trim(),
      ownerId: owner.person.id,
      ownerName: owner.person.fullName,
      due: _due,
      teamId: _team?.id,
      place: _place,
      photos: [
        if (photo != null)
          PendingPhoto(
            local: photo.local,
            takenAt: photo.takenAt,
            place: _place,
          ),
      ],
      attachFileIds: [for (final f in _attached) f.id],
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sent = await ref.read(workOutboxProvider.notifier).send(item);
    if (!mounted) return;
    navigator.pop();
    if (!sent) {
      // Kept on the phone; the Work tab shows "Not sent yet · Retry".
      messenger.showSnackBar(SnackBar(content: Text(l10n.workNotSentNote)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final me = ref.watch(authUserIdProvider).value;
    final space = ref.watch(spaceDetailProvider(widget.spaceId)).value;
    final people = ref.watch(spacePeopleProvider(widget.spaceId)).value;
    final nextRef = ref.watch(_nextRefProvider(widget.spaceId)).value;
    final photo = _photo;

    String day(DateTime d) => BvWesternDigitsFormatter.normalise(
      DateFormat('EEE d MMM', locale).format(d),
    );
    final ownerName = _owner?.person.id == me
        ? l10n.spacesYouTag
        : _owner?.person.fullName;

    return EntryScaffold(
      title: l10n.workNewTitle,
      onBack: _sending ? () {} : null,
      bodyPadding: const EdgeInsetsDirectional.all(BvSpace.gutter),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s12,
        children: [
          Text(
            _owner == null
                ? l10n.workNewFooterNoOwner
                : l10n.workNewFooter(inOwnDirection(_owner!.person.firstName)),
            textAlign: TextAlign.center,
            style: type.bodySm.copyWith(color: BvColors.textSecondary),
          ),
          BvButton(
            key: const Key('work-create'),
            label: l10n.workCreate,
            expand: true,
            onPressed: _sending ? null : _create,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s16,
        children: [
          if (space != null)
            Text(
              space.name,
              textAlign: TextAlign.center,
              style: type.bodySm.copyWith(color: BvColors.textSecondary),
            ),
          if (photo == null)
            _PhotoPrompt(
              onCamera: () => _takePhoto(camera: true),
              onGallery: () => _takePhoto(camera: false),
            )
          else
            Stack(
              children: [
                BvSitePhoto(
                  key: const Key('work-new-photo'),
                  photo: FileImage(File(photo.local)),
                  stamp: joinMeta([
                    ?_place,
                    BvWesternDigitsFormatter.normalise(
                      DateFormat.Hm(locale).format(photo.takenAt),
                    ),
                    l10n.spacesYouTag,
                  ]),
                ),
                PositionedDirectional(
                  top: BvSpace.s12,
                  end: BvSpace.s12,
                  child: BvButton(
                    key: const Key('work-retake'),
                    label: l10n.workRetake,
                    style: BvButtonStyle.secondary,
                    size: BvButtonSize.medium,
                    onPressed: () => _takePhoto(camera: true),
                  ),
                ),
              ],
            ),
          ProfileCard(
            padding: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    BvSpace.s16,
                    BvSpace.s16,
                    BvSpace.s16,
                    BvSpace.s4,
                  ),
                  child: Row(
                    children: [
                      BvStamp(
                        label: nextRef == null
                            ? l10n.workNewStampPlain
                            : l10n.workNewStamp(nextRef),
                      ),
                      const SizedBox(width: BvSpace.s8),
                      // The Team name gives way to the stamp when space is
                      // tight (larger text sizes).
                      Expanded(
                        child: _team == null
                            ? const SizedBox.shrink()
                            : Text(
                                _team!.name,
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.overline.copyWith(
                                  color: BvColors.textSecondary,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: BvSpace.s16,
                  ),
                  child: BvTextField(
                    key: const Key('work-title'),
                    placeholder: l10n.workTitleHint,
                    controller: _title,
                    maxLength: NewWorkItemScreen.titleMax,
                    error: _showErrors && !_titleOk
                        ? l10n.workTitleRequired
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: BvSpace.s12),
                _CellGrid(
                  cells: [
                    _CellData(
                      key: 'work-owner',
                      label: l10n.workCellOwner,
                      value: ownerName,
                      error: _showErrors && _owner == null
                          ? l10n.workOwnerRequired
                          : null,
                      onTap: people == null
                          ? null
                          : () => _pickOwner(people.members, me),
                    ),
                    _CellData(
                      key: 'work-due',
                      label: l10n.workCellDue,
                      value: _due == null ? null : day(_due!),
                      onTap: _pickDue,
                    ),
                    _CellData(
                      key: 'work-place',
                      label: l10n.workCellPlace,
                      value: _place,
                      onTap: _pickPlace,
                    ),
                    _CellData(
                      key: 'work-team',
                      label: l10n.workCellTeam,
                      value: _team?.name,
                      onTap: people == null || people.teams.isEmpty
                          ? null
                          : () => _pickTeam(people.teams),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_attached.isNotEmpty)
            ProfileCard(
              key: const Key('work-new-attached'),
              padding: false,
              child: DividedColumn(
                children: [
                  for (final f in _attached)
                    AttachedFileRow(
                      spaceId: widget.spaceId,
                      file: f,
                      onRemove: () => setState(() => _attached.remove(f)),
                    ),
                ],
              ),
            ),
          // Voice notes come in week 6 part 3.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BvButton(
              key: const Key('work-new-attach'),
              label: l10n.workAttach,
              icon: BvIcons.create,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              padded: false,
              onPressed: _sending ? null : _attach,
            ),
          ),
        ],
      ),
    );
  }
}

final _nextRefProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, spaceId) => ref.watch(workRepositoryProvider).nextRef(spaceId),
);

/// Before the photo: take one (camera) or choose one (gallery).
class _PhotoPrompt extends StatelessWidget {
  const _PhotoPrompt({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AspectRatio(
      aspectRatio: BvSitePhotoSpec.aspectRatio,
      child: DecoratedBox(
        key: const Key('work-photo-prompt'),
        decoration: const BoxDecoration(
          color: BvColors.surfaceSubtle,
          borderRadius: BvRadius.cardAll,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: BvSpace.s8,
          children: [
            const Icon(
              BvIcons.camera,
              size: BvSize.iconLg,
              color: BvColors.iconSecondary,
            ),
            EmptyNote(l10n.workPhotoFirst),
            BvButton(
              key: const Key('work-take-photo'),
              label: l10n.workTakePhoto,
              icon: BvIcons.camera,
              size: BvButtonSize.medium,
              onPressed: onCamera,
            ),
            BvButton(
              key: const Key('work-from-gallery'),
              label: l10n.workFromGallery,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              onPressed: onGallery,
            ),
          ],
        ),
      ),
    );
  }
}

class _CellData {
  const _CellData({
    required this.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
  });

  final String key;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final String? error;
}

/// The 2 × 2 grid of the site tag (Owner, Due, Place on site, Team).
class _CellGrid extends StatelessWidget {
  const _CellGrid({required this.cells});

  final List<_CellData> cells;

  @override
  Widget build(BuildContext context) {
    const line = BorderSide(
      color: BvColors.borderDefault,
      width: BvStroke.thin,
    );
    Widget cell(_CellData c, {required bool end}) => Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: line,
            end: end ? BorderSide.none : line,
          ),
        ),
        child: _Cell(data: c),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell(cells[i], end: false),
                if (i + 1 < cells.length) cell(cells[i + 1], end: true),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.data});

  final _CellData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final empty = (data.value ?? '').isEmpty;
    return InkWell(
      key: Key(data.key),
      onTap: data.onTap,
      splashFactory: NoSplash.splashFactory,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BvSiteTagSpec.cellPaddingHorizontal,
          vertical: BvSiteTagSpec.cellPaddingVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: BvSiteTagSpec.cellGap,
          children: [
            Text(
              data.label,
              style: type.overline.copyWith(color: BvColors.textSecondary),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    empty ? l10n.workChoose : data.value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.labelMd.copyWith(
                      color: empty
                          ? BvColors.textSecondary
                          : BvColors.textPrimary,
                    ),
                  ),
                ),
                if (data.onTap != null)
                  const Icon(
                    BvIcons.caretDown,
                    size: BvSize.iconSm,
                    color: BvColors.iconSecondary,
                  ),
              ],
            ),
            if (data.error != null)
              Text(
                data.error!,
                style: type.labelSm.copyWith(color: BvColors.textDestructive),
              ),
          ],
        ),
      ),
    );
  }
}

/// Place on site: free text, in the language people write it ("Grid C7").
class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({this.initial});

  final String? initial;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  late final _place = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('work-place-field'),
          placeholder: l10n.workPlaceHint,
          controller: _place,
          autofocus: true,
          maxLength: NewWorkItemScreen.placeMax,
        ),
        BvButton(
          key: const Key('work-place-save'),
          label: l10n.save,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_place.text.trim()),
        ),
      ],
    );
  }
}
