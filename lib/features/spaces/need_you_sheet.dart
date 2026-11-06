import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../data/models/need_you.dart';
import '../../data/models/space.dart';
import '../../data/repositories/need_you_repository.dart';
import '../../data/repositories/safety_repository.dart';
import '../../data/repositories/space_repository.dart';
import '../../data/repositories/work_repository.dart' show newUuid;
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import 'former_member.dart';
import 'need_you_notice.dart';
import 'people_tab.dart' show RoleCompanyLine;
import 'space_errors.dart';

/// Review 113 NN1 (2730:39983): the sheet, from a person's face in a Space
/// or the People list: the person, an optional one-line reason, Add place,
/// Need you now. And the Space's line, where a call and its answer show.

/// Who I blocked, as far as known (a block is checked on the server too).
Future<Set<String>> needYouBlocked(WidgetRef ref) async {
  try {
    return {for (final b in await ref.read(blockedProvider.future)) b.id};
  } on Exception {
    return const {};
  }
}

/// From a face: opens the sheet when [personId] may be called; a face that
/// may not does nothing.
Future<void> openNeedYou(
  BuildContext context,
  WidgetRef ref, {
  required SpaceDetail space,
  required String personId,
}) async {
  final SpacePeople people;
  try {
    people = await ref.read(spacePeopleProvider(space.id).future);
  } on SpaceException {
    return;
  }
  final blocked = await needYouBlocked(ref);
  if (!context.mounted) return;
  final me = ref.read(authUserIdProvider).value;
  final may = mayCallNeedYou(
    space: space,
    people: people,
    me: me,
    target: personId,
    blocked: blocked,
  );
  if (!may) return;
  await showNeedYouSheet(
    context,
    spaceId: space.id,
    member: people.member(personId)!,
  );
}

Future<void> showNeedYouSheet(
  BuildContext context, {
  required String spaceId,
  required SpaceMember member,
}) async {
  final sent = await showBvSheet<bool>(
    context: context,
    form: true,
    builder: (_) => NeedYouSheet(spaceId: spaceId, member: member),
  );
  if (sent == true && context.mounted) {
    showSpaceMessage(
      context,
      AppLocalizations.of(
        context,
      ).needYouSent(inOwnDirection(member.person.firstName)),
    );
  }
}

class NeedYouSheet extends ConsumerStatefulWidget {
  const NeedYouSheet({super.key, required this.spaceId, required this.member});

  final String spaceId;
  final SpaceMember member;

  @override
  ConsumerState<NeedYouSheet> createState() => _NeedYouSheetState();
}

class _NeedYouSheetState extends ConsumerState<NeedYouSheet> {
  final _reason = TextEditingController();
  final _place = TextEditingController();
  var _withPlace = false;
  var _sending = false;
  String? _refused;

  /// The call's id, once: Send again is the same call.
  final _id = newUuid();

  SpacePerson get _person => widget.member.person;

  @override
  void dispose() {
    _reason.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final first = inOwnDirection(_person.firstName);
    setState(() {
      _sending = true;
      _refused = null;
    });
    try {
      await ref
          .read(needYouRepositoryProvider)
          .send(
            id: _id,
            spaceId: widget.spaceId,
            toId: _person.id,
            reason: _reason.text,
            place: _withPlace ? _place.text : null,
          );
    } on SpaceException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _refused = (e.message ?? '').contains('at most 3 an hour')
            ? l10n.needYouTooMany(first)
            : e.failure == SpaceFailure.notAllowed
            ? l10n.needYouRefused(first)
            : spaceErrorText(l10n, e);
      });
      return;
    }
    if (!mounted) return;
    ref.invalidate(needYouCallsProvider(widget.spaceId));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final refused = _refused;
    return BvSheetForm(
      gap: BvFolderSpec.sheetGap,
      body: Column(
        key: const Key('need-you-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvFolderSpec.sheetGap,
        children: [
          Row(
            spacing: BvPeopleSpec.rowGap,
            children: [
              BvAvatar(
                name: _person.fullName,
                size: BvAvatarSize.list,
                tint: BvAvatarTints.forId(_person.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvSpace.s2,
                  children: [
                    Text(
                      inOwnDirection(_person.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.emphasis,
                    ),
                    RoleCompanyLine(person: _person, lang: lang),
                  ],
                ),
              ),
            ],
          ),
          BvTextField(
            key: const Key('need-you-reason'),
            controller: _reason,
            placeholder: l10n.needYouReasonHint,
            maxLength: NeedYouRules.reasonMax,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_withPlace)
            BvTextField(
              key: const Key('need-you-place'),
              controller: _place,
              placeholder: l10n.needYouPlaceHint,
              maxLength: NeedYouRules.placeMax,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BvChip(
                key: const Key('need-you-add-place'),
                label: l10n.needYouAddPlace,
                icon: BvIcons.place,
                onTap: () => setState(() => _withPlace = true),
              ),
            ),
          if (refused != null)
            Text(
              refused,
              key: const Key('need-you-refused'),
              style: type.bodySm.copyWith(color: BvColors.textDestructive),
            ),
        ],
      ),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvFolderSpec.sheetGap,
        children: [
          BvButton(
            key: const Key('need-you-send'),
            label: l10n.needYouNow,
            icon: BvIcons.needYou,
            expand: true,
            onPressed: _sending ? null : () => unawaited(_send()),
          ),
          Text(
            l10n.needYouStrongNote(inOwnDirection(_person.firstName)),
            textAlign: TextAlign.center,
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// How long my own call stays on the Space's line, answered or not.
const needYouShownFor = Duration(hours: 2);

/// The calls that need showing, newest first, at most 3: what I got and
/// haven't answered, then my own while recent.
List<NeedYouCall> needYouShown(
  List<NeedYouCall> calls,
  String? me,
  DateTime now,
) {
  const most = 3;
  final got = [
    for (final c in calls)
      if (c.toId == me && c.answer == null) c,
  ];
  final mine = [
    for (final c in calls)
      if (c.fromId == me && now.difference(c.createdAt) < needYouShownFor) c,
  ];
  int newest(NeedYouCall a, NeedYouCall b) =>
      b.createdAt.compareTo(a.createdAt);
  return [...got..sort(newest), ...mine..sort(newest)].take(most).toList();
}

/// The Space's line, under Work · Chat: a call I got, with On my way ·
/// Can't now (for when the notification went); my call, waiting or
/// answered. Nothing at all when there is none.
class NeedYouStrip extends ConsumerWidget {
  const NeedYouStrip({super.key, required this.spaceId});

  final String spaceId;

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    NeedYouCall call,
    NeedYouAnswer answer,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(needYouRepositoryProvider).answer(call.id, answer);
    } on SpaceException catch (e) {
      if (!context.mounted) return;
      if ((e.message ?? '').contains('already answered')) {
        showSpaceMessage(context, l10n.needYouAlreadyAnswered);
      } else {
        showSpaceError(context, e);
      }
    }
    if (context.mounted) ref.invalidate(needYouCallsProvider(spaceId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final me = ref.watch(authUserIdProvider).value;
    final now = ref.watch(clockProvider)();
    final calls = needYouShown(
      ref.watch(needYouCallsProvider(spaceId)).value ?? const [],
      me,
      now,
    );
    if (calls.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('need-you-strip'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BvSpace.gutter,
        vertical: BvSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvSpace.s4,
        children: [
          for (final c in calls)
            Container(
              key: Key('need-you-call-${c.id}'),
              padding: BvFolderSpec.warningPadding,
              decoration: const BoxDecoration(
                color: BvColors.surfaceBrandSoft,
                borderRadius: BvFolderSpec.warningRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BvSpace.s8,
                children: [
                  Row(
                    spacing: BvSpace.s8,
                    children: [
                      const Icon(
                        BvIcons.needYou,
                        size: BvChipSpec.iconSize,
                        color: BvColors.textAction,
                      ),
                      Expanded(
                        child: Text(
                          _line(l10n, c, me),
                          style: type.labelMd.copyWith(
                            color: BvColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ([?c.place, ?c.reason].isNotEmpty)
                    Text(
                      joinMeta([?c.place, ?c.reason]),
                      style: type.bodySm.copyWith(
                        color: BvColors.textSecondary,
                      ),
                    ),
                  if (c.toId == me && c.answer == null)
                    Row(
                      spacing: BvSpace.s8,
                      children: [
                        Expanded(
                          child: BvButton(
                            key: Key('need-you-cant-${c.id}'),
                            label: l10n.needYouCantNow,
                            style: BvButtonStyle.secondary,
                            size: BvButtonSize.medium,
                            expand: true,
                            onPressed: () => unawaited(
                              _answer(context, ref, c, NeedYouAnswer.cant),
                            ),
                          ),
                        ),
                        Expanded(
                          child: BvButton(
                            key: Key('need-you-coming-${c.id}'),
                            label: l10n.needYouOnMyWay,
                            size: BvButtonSize.medium,
                            expand: true,
                            onPressed: () => unawaited(
                              _answer(context, ref, c, NeedYouAnswer.coming),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _line(AppLocalizations l10n, NeedYouCall c, String? me) {
    if (c.toId == me) {
      return l10n.needYouFrom(inOwnDirection(personName(l10n, c.fromName)));
    }
    final name = inOwnDirection(personName(l10n, c.toName));
    final answer = c.answer;
    return answer == null
        ? l10n.needYouWaiting(name)
        : l10n.needYouAnswerLine(name, needYouAnswerWord(l10n, answer));
  }
}
