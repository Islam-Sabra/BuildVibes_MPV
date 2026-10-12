import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_dialog.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import 'new_space_screen.dart';
import 'space_errors.dart';

/// What Space info asks the Space screen to do when it closes.
enum SpaceInfoResult { showPeople }

/// S15 v2k (admin) and S15b (member), private-Space version. Access is
/// read-only. Admins also edit the name and About, choose who can invite,
/// transfer ownership and delete the Space.
class SpaceInfoScreen extends ConsumerWidget {
  const SpaceInfoScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final space = ref.watch(spaceDetailProvider(spaceId)).value;
    final people = ref.watch(spacePeopleProvider(spaceId)).value;
    final me = ref.watch(authUserIdProvider).value;

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

    // "Owners: Omar Haddad and you".
    final owners = [
      for (final m in people?.members ?? const <SpaceMember>[])
        if (m.isAdmin && m.person.id != me) m.person.fullName,
      if (space.iAmAdmin) l10n.youLower,
    ];
    String ownersText() {
      if (owners.isEmpty) return '';
      if (owners.length == 1) return owners.first;
      final head = owners.sublist(0, owners.length - 1);
      return l10n.listAnd(
        head.join(l10n.localeName == 'ar' ? '، ' : ', '),
        owners.last,
      );
    }

    String inviters(SpaceInviters v) => switch (v) {
      SpaceInviters.admins => l10n.spacesInviteAdmins,
      SpaceInviters.adminsAndLeads => l10n.spacesInviteLeads,
      SpaceInviters.everyone => l10n.spacesInviteEveryone,
    };
    String notify(SpaceNotify v) => switch (v) {
      SpaceNotify.all => l10n.spacesNotifyAll,
      SpaceNotify.needsYou => l10n.spacesNotifyNeedsYou,
      SpaceNotify.off => l10n.spacesNotifyOff,
    };

    Future<void> chooseInviters() async {
      final v = await showChoiceSheet<SpaceInviters>(
        context,
        title: l10n.spacesWhoCanInvite,
        subtitle: l10n.spacesWhoCanInviteNote,
        value: space.whoCanInvite,
        options: [
          BvChoiceOption(
            key: const Key('inviters-admins'),
            value: SpaceInviters.admins,
            title: l10n.spacesInviteAdmins,
            description: l10n.spacesInviteAdminsHelp,
          ),
          BvChoiceOption(
            key: const Key('inviters-leads'),
            value: SpaceInviters.adminsAndLeads,
            title: l10n.spacesInviteLeads,
            description: l10n.spacesInviteLeadsHelp,
          ),
          BvChoiceOption(
            key: const Key('inviters-everyone'),
            value: SpaceInviters.everyone,
            title: l10n.spacesInviteEveryone,
            description: l10n.spacesInviteEveryoneHelp,
          ),
        ],
      );
      if (v == null || v == space.whoCanInvite) return;
      await run(
        (repo) => repo.updateSpace(
          spaceId,
          name: space.name,
          about: space.about,
          whoCanInvite: v,
        ),
      );
    }

    Future<void> chooseNotify() async {
      final v = await showChoiceSheet<SpaceNotify>(
        context,
        title: l10n.spacesNotifications,
        subtitle: l10n.spacesNotificationsNote,
        value: space.myNotify,
        options: [
          BvChoiceOption(
            key: const Key('notify-all'),
            value: SpaceNotify.all,
            title: l10n.spacesNotifyAll,
            description: l10n.spacesNotifyAllHelp,
          ),
          BvChoiceOption(
            key: const Key('notify-needs-you'),
            value: SpaceNotify.needsYou,
            title: l10n.spacesNotifyNeedsYou,
            description: l10n.spacesNotifyNeedsYouHelp,
          ),
          BvChoiceOption(
            key: const Key('notify-off'),
            value: SpaceNotify.off,
            title: l10n.spacesNotifyOff,
            description: l10n.spacesNotifyOffHelp,
          ),
        ],
      );
      if (v == null || v == space.myNotify) return;
      await run((repo) => repo.setNotifications(spaceId, v));
    }

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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.spacesInfoTitle, style: type.titleLg),
        actions: [
          if (space.iAmAdmin)
            BvButton(
              key: const Key('space-edit'),
              label: l10n.spacesEdit,
              style: BvButtonStyle.tertiary,
              size: BvButtonSize.medium,
              onPressed: edit,
            ),
        ],
      ),
      body: ListView(
        key: const Key('space-info'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s32),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s16,
              BvSpace.gutter,
              BvSpace.s16,
            ),
            child: Column(
              spacing: BvSpace.s8,
              children: [
                BvAvatar(
                  name: space.name,
                  size: BvAvatarSize.xl,
                  company: true,
                ),
                Text(
                  space.name,
                  textAlign: TextAlign.center,
                  style: type.headingMd,
                ),
                if ((space.about ?? '').isNotEmpty)
                  UserText(
                    space.about!,
                    style: type.bodySm.copyWith(color: BvColors.textSecondary),
                  ),
              ],
            ),
          ),
          BvListGroup(
            rows: [
              // Read-only in the MVP: every Space is private work.
              BvListRow(
                key: const Key('info-access'),
                leading: const BvRowIcon(BvIcons.everyone, ink: true),
                title: l10n.spacesAccess,
                subtitle: space.projectName == null
                    ? l10n.spacesPrivateWork
                    : l10n.spacesAccessLinked(space.projectName!),
                trailing: const BvRowTrailing.none(),
              ),
              if (space.canInvite)
                BvListRow(
                  key: const Key('info-invite'),
                  leading: const BvRowIcon(BvIcons.invite, ink: true),
                  title: l10n.spacesInvitePeople,
                  subtitle: l10n.spacesInviteRowSub,
                  onTap: () => context.push(AppRoutes.spaceInvite(spaceId)),
                ),
              BvListRow(
                key: const Key('info-members'),
                leading: const BvRowIcon(BvIcons.people, ink: true),
                title: l10n.spacesMembers,
                subtitle: owners.isEmpty
                    ? null
                    : l10n.spacesOwnersLine(ownersText()),
                onTap: () =>
                    Navigator.of(context).pop(SpaceInfoResult.showPeople),
              ),
              if (space.iAmAdmin)
                BvListRow(
                  key: const Key('info-inviters'),
                  leading: const BvRowIcon(BvIcons.lock, ink: true),
                  title: l10n.spacesWhoCanInvite,
                  subtitle: inviters(space.whoCanInvite),
                  onTap: chooseInviters,
                ),
              BvListRow(
                key: const Key('info-notify'),
                leading: const BvRowIcon(BvIcons.notifications, ink: true),
                title: l10n.spacesNotifications,
                subtitle: notify(space.myNotify),
                onTap: chooseNotify,
              ),
              if (space.iAmAdmin) ...[
                BvListRow(
                  key: const Key('info-transfer'),
                  leading: const BvRowIcon(BvIcons.transfer, destructive: true),
                  title: l10n.spacesTransfer,
                  trailing: const BvRowTrailing.none(),
                  destructive: true,
                  onTap: () => context.push(AppRoutes.spaceTransfer(spaceId)),
                ),
                BvListRow(
                  key: const Key('info-delete'),
                  leading: const BvRowIcon(BvIcons.delete, destructive: true),
                  title: l10n.spacesDeleteSpace,
                  subtitle: l10n.spacesDeleteSpaceHelp,
                  trailing: const BvRowTrailing.none(),
                  destructive: true,
                  onTap: delete,
                ),
              ],
              BvListRow(
                key: const Key('info-leave'),
                leading: const BvRowIcon(BvIcons.arrowBack, destructive: true),
                title: l10n.spacesLeave,
                trailing: const BvRowTrailing.none(),
                destructive: true,
                onTap: leave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One single choice in a sheet, with Cancel and Save (S15k-I, S15k-N).
/// Returns the saved value, or null.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required T value,
  required List<BvChoiceOption<T>> options,
}) {
  final l10n = AppLocalizations.of(context);
  var chosen = value;
  return showBvSheet<T>(
    context: context,
    title: title,
    subtitle: subtitle,
    footer: BvSheetFooter(
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.save,
      onConfirm: () => Navigator.of(context, rootNavigator: true).pop(chosen),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, setSheet) => BvChoiceList<T>(
        options: options,
        value: chosen,
        onChanged: (v) => setSheet(() => chosen = v),
      ),
    ),
  );
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
