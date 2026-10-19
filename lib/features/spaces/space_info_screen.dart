import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/around_specs.dart';
import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/l10n/months.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_info_slip.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_segmented.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_space_emblem.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;
import '../profile/widgets/profile_parts.dart';
import 'invite_screen.dart' show renewInviteCode;
import 'new_space_screen.dart';
import 'pass_words.dart';
import 'space_errors.dart';

/// Picks the "On site since" day: the phone's date picker, from [initial].
/// Null when the person cancels. A provider so tests can stand in for it.
typedef PickSiteStart =
    Future<DateTime?> Function(
      BuildContext context, {
      required DateTime initial,
      required DateTime last,
    });

final pickSiteStartProvider = Provider<PickSiteStart>(
  (ref) =>
      (context, {required initial, required last}) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: _firstSiteDay,
        lastDate: last,
      ),
);

/// The server's earliest site day (set_site_start_date).
final _firstSiteDay = DateTime(2000);

/// How far ahead a site can start: a Space set up before work begins.
const _siteDaysAhead = Duration(days: 365);

/// SI1 2562:35576 · Space info and settings, opened from the Space name or
/// the Space menu. You: your pass and your notifications (one choice).
/// Invite: the code with Copy, a new code (admins) and who can invite (one
/// choice, admins). Space: its admins, "On site since" (set by an admin;
/// others see it once set) and Leave Space. Admins also edit the name and
/// About, transfer ownership and delete the Space.
class SpaceInfoScreen extends ConsumerWidget {
  const SpaceInfoScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final locale = Localizations.localeOf(context);
    final space = ref.watch(spaceDetailProvider(spaceId)).value;
    final people = ref.watch(spacePeopleProvider(spaceId)).value;
    final invite = space?.canInvite ?? false
        ? ref.watch(spaceInviteProvider(spaceId)).value
        : null;

    if (space == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    void refresh() => ref
      ..invalidate(spaceDetailProvider(spaceId))
      ..invalidate(mySpacesProvider);

    Future<void> run(Future<void> Function(SpaceRepository repo) call) async {
      try {
        await call(ref.read(spaceRepositoryProvider));
        refresh();
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    final admins = [
      for (final m in people?.members ?? const <SpaceMember>[])
        if (m.isAdmin) inOwnDirection(m.person.fullName),
    ];

    Future<void> edit() async {
      final saved = await showBvSheet<({String name, String about})>(
        context: context,
        title: l10n.spacesEditTitle,
        builder: (_) => _EditSpace(name: space.name, about: space.about),
      );
      if (saved == null) return;
      await run(
        (repo) => repo.updateSpace(
          spaceId,
          name: saved.name,
          about: saved.about,
          whoCanInvite: space.whoCanInvite,
        ),
      );
    }

    Future<void> copy(SpaceInvite code) async {
      await Clipboard.setData(ClipboardData(text: code.grouped));
      if (context.mounted) showSpaceMessage(context, l10n.spacesCodeCopied);
    }

    Future<void> siteStart() async {
      final today = ref.read(clockProvider)();
      final current = space.siteStartDate;
      Future<void> pick() async {
        final day = await ref.read(pickSiteStartProvider)(
          context,
          initial: current ?? today,
          last: today.add(_siteDaysAhead),
        );
        if (day == null) return;
        await run((repo) => repo.setSiteStartDate(spaceId, day));
      }

      if (current == null) return pick();
      final change = await showBvSheet<bool>(
        context: context,
        title: l10n.spacesOnSiteSince,
        subtitle: l10n.spacesOnSiteNote,
        builder: (sheet) => ClipRRect(
          borderRadius: BvRadius.cardAll,
          child: BvListGroup(
            rows: [
              BvListRow(
                key: const Key('site-start-change'),
                leading: const BvRowIcon(BvIcons.month, ink: true),
                title: l10n.spacesOnSiteChange,
                trailing: const BvRowTrailing.none(),
                onTap: () => Navigator.of(sheet).pop(true),
              ),
              BvListRow(
                key: const Key('site-start-remove'),
                leading: const BvRowIcon(BvIcons.delete, destructive: true),
                title: l10n.spacesOnSiteRemove,
                destructive: true,
                trailing: const BvRowTrailing.none(),
                onTap: () => Navigator.of(sheet).pop(false),
              ),
            ],
          ),
        ),
      );
      if (change == null || !context.mounted) return;
      if (change) return pick();
      await run((repo) => repo.setSiteStartDate(spaceId, null));
    }

    Future<void> delete() async {
      final yes = await showBvDialog(
        context: context,
        title: l10n.spacesDeleteTitle(space.name),
        body: l10n.spacesDeleteBody,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.spacesDeleteButton,
        destructive: true,
      );
      if (!yes || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      try {
        await ref.read(spaceRepositoryProvider).deleteSpace(spaceId);
        ref.invalidate(mySpacesProvider);
        router.go(AppRoutes.home);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.spacesDeleted(space.name))),
        );
      } on SpaceException catch (e) {
        if (context.mounted) showSpaceError(context, e);
      }
    }

    Future<void> leave() async {
      final yes = await showBvDialog(
        context: context,
        title: l10n.spacesLeaveTitle(space.name),
        body: l10n.spacesLeaveBodyPrivate,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.spacesLeaveButton,
        destructive: true,
      );
      if (!yes || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      try {
        await ref.read(spaceRepositoryProvider).leaveSpace(spaceId);
        ref.invalidate(mySpacesProvider);
        router.go(AppRoutes.home);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.spacesLeft(space.name))),
        );
      } on SpaceException catch (e) {
        if (!context.mounted) return;
        if (e.failure == SpaceFailure.rule) {
          // The last admin: make someone else an admin, or delete.
          showSpaceMessage(context, l10n.spacesLastAdmin);
        } else {
          showSpaceError(context, e);
        }
      }
    }

    final siteDay = space.siteStartDate;
    final place = space.projectPlace?.of(locale) ?? space.projectLocation ?? '';
    final code = BvType.latin.titleLg;

    return Scaffold(
      backgroundColor: BvColors.surfaceApp,
      appBar: AppBar(
        backgroundColor: BvColors.surfaceApp,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(l10n.spacesInfoTitle, style: type.titleLg),
      ),
      body: ListView(
        key: const Key('space-info'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          BvSpace.gutter,
          BvInfoSpec.bodyPaddingTop,
          BvSpace.gutter,
          BvSpace.s32,
        ),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: BvInfoSpec.identityPaddingVertical,
            ),
            child: Row(
              spacing: BvInfoSpec.identityGap,
              children: [
                const BvSpaceEmblem(height: BvSpaceEmblemSpec.info),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BvInfoSpec.nameGap,
                    children: [
                      Text(space.name, style: type.headingMd),
                      if (space.projectId != null && space.projectName != null)
                        _ProjectTag(
                          color: BvProjectColors.forId(space.projectId!),
                          name: space.projectName!,
                          place: place,
                          onTap: () => context.push(
                            '${AppRoutes.projects}/${space.projectId}',
                          ),
                        ),
                      if ((space.about ?? '').isNotEmpty)
                        UserText(
                          space.about!,
                          style: type.bodySm.copyWith(
                            color: BvColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BvInfoSpec.groupGap),
          BvInfoGroup(
            label: l10n.spacesInfoYou,
            rows: [
              BvInfoRow(
                key: const Key('info-pass'),
                title: l10n.spacesYourPass,
                trailing: BvInfoPill(
                  label: passName(l10n, space.myPass),
                  icon: BvIcons.confirmed,
                ),
              ),
              BvInfoRow(
                key: const Key('info-notify'),
                title: l10n.spacesNotifications,
                below: BvSegmented<SpaceNotify>(
                  value: space.myNotify,
                  onChanged: (v) =>
                      run((repo) => repo.setNotifications(spaceId, v)),
                  segments: [
                    BvSegment(
                      key: const Key('notify-all'),
                      value: SpaceNotify.all,
                      label: l10n.spacesNotifyChoiceAll,
                    ),
                    BvSegment(
                      key: const Key('notify-needs-you'),
                      value: SpaceNotify.needsYou,
                      label: l10n.spacesNotifyChoiceNeedsYou,
                    ),
                    BvSegment(
                      key: const Key('notify-off'),
                      value: SpaceNotify.off,
                      label: l10n.spacesNotifyOff,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (space.canInvite) ...[
            const SizedBox(height: BvInfoSpec.groupGap),
            BvInfoGroup(
              label: l10n.spacesInfoInvite,
              rows: [
                BvInfoRow(
                  key: const Key('info-invite'),
                  title: l10n.spacesInviteCode,
                  subtitle: invite == null
                      ? null
                      : Text(
                          invite.grouped,
                          key: const Key('info-code'),
                          textDirection: TextDirection.ltr,
                          style: code.copyWith(
                            letterSpacing:
                                code.fontSize! * BvInfoSpec.codeTrackingEm,
                          ),
                        ),
                  trailing: invite == null
                      ? null
                      : BvInfoPill(
                          key: const Key('info-copy'),
                          label: l10n.spacesCopy,
                          icon: BvIcons.copy,
                          onTap: () => copy(invite),
                        ),
                ),
                if (space.iAmAdmin)
                  BvInfoRow(
                    key: const Key('info-new-code'),
                    title: l10n.spacesNewCode,
                    tone: BvInfoTone.quiet,
                    onTap: () => renewInviteCode(context, ref, spaceId),
                  ),
                if (space.iAmAdmin)
                  BvInfoRow(
                    key: const Key('info-inviters'),
                    title: l10n.spacesWhoCanInvite,
                    below: BvSegmented<SpaceInviters>(
                      value: space.whoCanInvite,
                      onChanged: (v) => run(
                        (repo) => repo.updateSpace(
                          spaceId,
                          name: space.name,
                          about: space.about,
                          whoCanInvite: v,
                        ),
                      ),
                      segments: [
                        BvSegment(
                          key: const Key('inviters-admins'),
                          value: SpaceInviters.admins,
                          label: l10n.spacesInviteChoiceAdmins,
                        ),
                        BvSegment(
                          key: const Key('inviters-leads'),
                          value: SpaceInviters.adminsAndLeads,
                          label: l10n.spacesInviteChoiceLeads,
                        ),
                        BvSegment(
                          key: const Key('inviters-everyone'),
                          value: SpaceInviters.everyone,
                          label: l10n.spacesInviteChoiceEveryone,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: BvInfoSpec.groupGap),
          BvInfoGroup(
            label: l10n.spacesInfoSpace,
            rows: [
              if (admins.isNotEmpty)
                BvInfoRow(
                  key: const Key('info-admins'),
                  title: l10n.spacesAdminRow,
                  value: admins.join(l10n.localeName == 'ar' ? '، ' : ', '),
                ),
              // Set by a Space admin; others see it once it is set
              // (review 44, answer 2).
              if (space.iAmAdmin || siteDay != null)
                BvInfoRow(
                  key: const Key('info-site-start'),
                  title: l10n.spacesOnSiteSince,
                  value: siteDay == null
                      ? l10n.spacesOnSiteNotSet
                      : formatLongDate(siteDay, locale.toLanguageTag()),
                  onTap: space.iAmAdmin ? siteStart : null,
                ),
              if (space.iAmAdmin) ...[
                BvInfoRow(
                  key: const Key('space-edit'),
                  title: l10n.spacesEditNameAbout,
                  onTap: edit,
                ),
                BvInfoRow(
                  key: const Key('info-transfer'),
                  title: l10n.spacesTransfer,
                  onTap: () => context.push(AppRoutes.spaceTransfer(spaceId)),
                ),
                BvInfoRow(
                  key: const Key('info-delete'),
                  title: l10n.spacesDeleteSpace,
                  tone: BvInfoTone.destructive,
                  onTap: delete,
                ),
              ],
              BvInfoRow(
                key: const Key('info-leave'),
                title: l10n.spacesLeave,
                tone: BvInfoTone.destructive,
                onTap: leave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The linked project under the Space name: a dot, its name, its place and
/// a caret; opens the project record.
class _ProjectTag extends StatelessWidget {
  const _ProjectTag({
    required this.color,
    required this.name,
    required this.place,
    required this.onTap,
  });

  /// The project's own colour.
  final Color color;
  final String name;
  final String place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('info-project'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.only(
            start: BvInfoSpec.tagPaddingStart,
            end: BvInfoSpec.tagPaddingEnd,
            top: BvInfoSpec.tagPaddingVertical,
            bottom: BvInfoSpec.tagPaddingVertical,
          ),
          decoration: const BoxDecoration(
            color: BvColors.surfaceSubtle,
            borderRadius: BvRadius.smallAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: BvInfoSpec.tagGap,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: BvInfoSpec.tagDot),
              ),
              Flexible(
                child: Text(
                  inOwnDirection(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelMd,
                ),
              ),
              if (place.isNotEmpty)
                Text(
                  place,
                  style: type.labelMd.copyWith(color: BvColors.textSecondary),
                ),
              const Icon(
                BvIcons.caretForward,
                size: BvInfoSpec.tagCaret,
                color: BvColors.iconPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name and About (admins), with the New Space rules.
class _EditSpace extends StatefulWidget {
  const _EditSpace({required this.name, this.about});

  final String name;
  final String? about;

  @override
  State<_EditSpace> createState() => _EditSpaceState();
}

class _EditSpaceState extends State<_EditSpace> {
  late final _name = TextEditingController(text: widget.name);
  late final _about = TextEditingController(text: widget.about);
  var _showErrors = false;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ok = _name.text.trim().length >= NewSpaceScreen.nameMin;
    return Column(
      key: const Key('edit-space-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: BvSpace.s16,
      children: [
        BvTextField(
          key: const Key('edit-space-name'),
          label: l10n.spacesNameLabel,
          controller: _name,
          maxLength: NewSpaceScreen.nameMax,
          error: _showErrors && !ok ? l10n.spacesNameRequired : null,
          onChanged: (_) => setState(() {}),
        ),
        BvTextField(
          key: const Key('edit-space-about'),
          label: l10n.spacesAboutLabel,
          helper: l10n.spacesAboutHelp,
          controller: _about,
          maxLines: 3,
          maxLength: NewSpaceScreen.aboutMax,
        ),
        BvButton(
          key: const Key('edit-space-save'),
          label: l10n.save,
          expand: true,
          onPressed: () {
            if (!ok) {
              setState(() => _showErrors = true);
              return;
            }
            Navigator.of(
              context,
            ).pop((name: _name.text.trim(), about: _about.text.trim()));
          },
        ),
      ],
    );
  }
}
