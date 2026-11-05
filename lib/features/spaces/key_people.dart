import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/design/people_library_specs.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../core/routing/open_thread.dart';
import '../../core/share.dart';
import '../../data/models/key_people.dart';
import '../../data/models/space.dart';
import '../../data/repositories/key_people_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_post_bar.dart' show BvPassChip;
import '../../shared/widgets/bv_sheet.dart';
import 'pass_words.dart';
import 'space_errors.dart';

/// Review 121: Call fetches the number on the tap (person_phone) and opens
/// the phone's own dialler. Calls inside the app are paused (review 120).
Future<void> callKeyPerson(
  BuildContext context,
  WidgetRef ref, {
  required String spaceId,
  required SpacePerson person,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final openLink = ref.read(openLinkProvider);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  try {
    final phone = await ref
        .read(keyPeopleRepositoryProvider)
        .personPhone(person.id, spaceId: spaceId);
    if (phone == null) {
      say(l10n.keyPeopleNoNumber(inOwnDirection(person.firstName)));
      ref.invalidate(spaceKeyPeopleProvider(spaceId));
      return;
    }
    if (!await openLink(Uri(scheme: 'tel', path: phone))) {
      say(l10n.keyPeopleNoDialler);
    }
  } on SpaceException catch (e) {
    if (e.failure == SpaceFailure.limit) {
      say(l10n.keyPeopleTooMany);
    } else if (context.mounted) {
      showSpaceError(context, e);
    }
  }
}

/// Message opens (or starts) the direct message.
Future<void> messageKeyPerson(GoRouter router, SpacePerson person) =>
    openDmThread(router, AppRoutes.messagesWith(person.id));

/// "Who to call", with the shield (KP1, OC1).
class KeyPeopleHead extends StatelessWidget {
  const KeyPeopleHead({super.key});

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    return Row(
      spacing: BvKeyPeopleSpec.headGap,
      children: [
        const Icon(
          BvIcons.keyRole,
          size: BvKeyPeopleSpec.headIcon,
          color: BvColors.iconSecondary,
        ),
        Text(
          AppLocalizations.of(context).keyPeopleWhoToCall,
          style: type.bodySm.copyWith(color: BvColors.textSecondary),
        ),
      ],
    );
  }
}

/// A key role's name in its tag: the shield, on the brand's soft colour.
/// A Latin name in Arabic keeps its own direction.
class KeyRoleTag extends StatelessWidget {
  const KeyRoleTag({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => BvBadge(
    label: inOwnDirection(name),
    tone: BvBadgeTone.brand,
    icon: BvIcons.keyRole,
  );
}

/// KP1 / KP2: a key person. Their face, name, role tag and what to call
/// them for; then Call (only when they show their number) and Message.
class KeyPersonCard extends StatelessWidget {
  const KeyPersonCard({
    super.key,
    required this.role,
    required this.holder,
    required this.onCall,
    required this.onMessage,
  });

  final KeyRole role;
  final KeyHolder holder;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final p = holder.person;
    final id = '${role.id}-${p.id}';
    final callFor = role.callFor;
    final message = BvButton(
      key: Key('key-message-$id'),
      label: l10n.keyPeopleMessage,
      icon: BvIcons.chat,
      style: BvButtonStyle.secondary,
      size: BvButtonSize.medium,
      expand: true,
      onPressed: onMessage,
    );
    return Container(
      key: Key('key-person-$id'),
      padding: const EdgeInsetsDirectional.all(BvKeyPeopleSpec.cardPadding),
      decoration: BoxDecoration(
        color: BvColors.surfaceElevated,
        borderRadius: BvRadius.cardAll,
        border: Border.all(color: BvColors.borderDefault, width: BvStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvKeyPeopleSpec.actionsTop,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvKeyPeopleSpec.faceGap,
            children: [
              BvAvatar(
                name: p.fullName,
                size: BvAvatarSize.post,
                tint: BvAvatarTints.forId(p.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BvKeyPeopleSpec.lineGap,
                  children: [
                    Text(
                      inOwnDirection(p.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.emphasis,
                    ),
                    KeyRoleTag(name: role.name),
                    if (callFor != null && callFor.isNotEmpty)
                      Text(
                        l10n.keyPeopleCallFor(inOwnDirection(callFor)),
                        style: type.metadata.copyWith(
                          color: BvColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (holder.canCall)
            Row(
              spacing: BvKeyPeopleSpec.actionsGap,
              children: [
                Expanded(
                  child: BvButton(
                    key: Key('key-call-$id'),
                    label: l10n.keyPeopleCall,
                    icon: BvIcons.call,
                    size: BvButtonSize.medium,
                    expand: true,
                    onPressed: onCall,
                  ),
                ),
                Expanded(child: message),
              ],
            )
          else
            message,
        ],
      ),
    );
  }
}

/// Who to call's cards, one per person per role, Call and Message wired.
/// [before] runs first (a sheet closes before Message opens).
class KeyPeopleCards extends ConsumerWidget {
  const KeyPeopleCards({
    super.key,
    required this.spaceId,
    required this.people,
    this.beforeMessage,
  });

  final String spaceId;
  final KeyPeople people;
  final VoidCallback? beforeMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: BvKeyPeopleSpec.cardGap,
    children: [
      for (final c in people.toCall)
        KeyPersonCard(
          role: c.role,
          holder: c.holder,
          onCall: () => callKeyPerson(
            context,
            ref,
            spaceId: spaceId,
            person: c.holder.person,
          ),
          onMessage: () {
            final router = GoRouter.of(context);
            beforeMessage?.call();
            messageKeyPerson(router, c.holder.person);
          },
        ),
    ],
  );
}

/// OC1: a key person from a chip, on a short sheet with Call and Message.
Future<void> showKeyPersonSheet(
  BuildContext context, {
  required String spaceId,
  required KeyRole role,
  required KeyHolder holder,
}) => showBvSheet<void>(
  context: context,
  builder: (sheet) => Column(
    key: const Key('key-person-sheet'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KeyPeopleCards(
        spaceId: spaceId,
        people: KeyPeople(
          roles: [
            KeyRole(
              id: role.id,
              name: role.name,
              callFor: role.callFor,
              holders: [holder],
            ),
          ],
        ),
        beforeMessage: () => Navigator.of(sheet).pop(),
      ),
    ],
  ),
);

/// KP2: the first time a person opens the Space after being let in, and
/// only when it has key people: Who to call, once. Got it, or closing the
/// sheet, marks it seen.
Future<void> showKeyPeopleWelcome(
  BuildContext context,
  WidgetRef ref, {
  required SpaceDetail space,
  required KeyPeople people,
}) async {
  final repo = ref.read(keyPeopleRepositoryProvider);
  await showBvSheet<void>(
    context: context,
    builder: (sheet) {
      final l10n = AppLocalizations.of(sheet);
      final type = BvType.of(sheet);
      return Column(
        key: const Key('key-people-welcome'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvKeyPeopleSpec.cardGap,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BvPassChip(
              label: l10n.keyPeopleJoined(
                passName(l10n, space.myPass).toUpperCase(),
              ),
              tone: passTone(space.myPass),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BvSpace.s2,
            children: [
              Text(
                l10n.keyPeopleWelcome(inOwnDirection(space.name)),
                style: type.emphasis,
              ),
              Text(
                l10n.keyPeopleFirst,
                style: type.metadata.copyWith(color: BvColors.textSecondary),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: KeyPeopleCards(
                spaceId: space.id,
                people: people,
                beforeMessage: () => Navigator.of(sheet).pop(),
              ),
            ),
          ),
          BvButton(
            key: const Key('key-people-got-it'),
            label: l10n.keyPeopleGotIt,
            expand: true,
            onPressed: () => Navigator.of(sheet).pop(),
          ),
          Text(
            l10n.keyPeopleStayOnTop,
            textAlign: TextAlign.center,
            style: type.metadata.copyWith(color: BvColors.textSecondary),
          ),
        ],
      );
    },
  );
  try {
    await repo.markSeen(space.id);
  } on SpaceException {
    // Not marked: it shows once more next time, no harm.
  }
  ref.invalidate(spaceKeyPeopleProvider(space.id));
}
