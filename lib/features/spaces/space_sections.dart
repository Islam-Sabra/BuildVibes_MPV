import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/chat.dart';
import '../../data/models/library.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../library/library_tab.dart';
import '../profile/widgets/profile_parts.dart' show EmptyNote;
import '../../shared/widgets/bv_writing_card.dart' show bvBareField;
import 'people_tab.dart';

/// A file post the Library asked for (review 69 1b): back on the Space's
/// Work, as a new version of [replaces] when it has one.
class SpaceFileAsk {
  const SpaceFileAsk({this.replaces});

  final LibraryFile? replaces;
}

/// The Space's People (review 105 Part 1, SP8 2670:38796), from the
/// header's People icon: its own screen, with Invite at the top end for
/// who may invite.
class SpacePeopleScreen extends ConsumerStatefulWidget {
  const SpacePeopleScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<SpacePeopleScreen> createState() => _SpacePeopleState();
}

/// Search in People's header (review 105 SP8, the lead's ruling: a Space
/// with 100+ members needs it): the field takes the title's place.
class _SpacePeopleState extends ConsumerState<SpacePeopleScreen> {
  final _query = TextEditingController();
  var _searching = false;

  String get spaceId => widget.spaceId;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(bool on) => setState(() {
    _searching = on;
    if (!on) _query.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final type = BvType.of(context);
    final detail = ref.watch(spaceDetailProvider(spaceId)).value;
    return _SectionScaffold(
      title: l10n.spacesTabPeople,
      titleField: _searching
          ? TextField(
              key: const Key('people-search-field'),
              controller: _query,
              autofocus: true,
              style: type.bodyMd,
              onChanged: (_) => setState(() {}),
              decoration: bvBareField(
                hint: l10n.peopleSearchHint,
                style: type.bodyMd,
              ),
            )
          : null,
      actions: [
        IconButton(
          key: const Key('people-search'),
          tooltip: _searching ? l10n.searchClear : l10n.searchMenu,
          onPressed: () => _search(!_searching),
          icon: Icon(
            _searching ? BvIcons.close : BvIcons.search,
            size: BvSize.iconLg,
          ),
        ),
        if (detail?.myRights.invite ?? false)
          IconButton(
            key: const Key('people-invite'),
            tooltip: l10n.spacesInfoInvite,
            onPressed: () => context.push(AppRoutes.spaceInvite(spaceId)),
            icon: const Icon(BvIcons.invite, size: BvSize.iconLg),
          ),
      ],
      body: detail == null
          ? null
          : PeopleTab(space: detail, query: _query.text),
    );
  }
}

/// The Space's Library (review 105 Part 1), from the header's folder icon.
/// Adding a file goes back to Work, writing its post ([SpaceFileAsk]).
class SpaceLibraryScreen extends ConsumerWidget {
  const SpaceLibraryScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(spaceDetailProvider(spaceId)).value;
    return _SectionScaffold(
      title: l10n.spacesTabLibrary,
      body: detail == null
          ? null
          : LibraryTab(
              space: detail,
              onAddFile: ({replaces}) =>
                  context.pop(SpaceFileAsk(replaces: replaces)),
            ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.title,
    required this.body,
    this.actions = const [],
    this.titleField,
  });

  final String title;
  final Widget? body;
  final List<Widget> actions;

  /// In the title's place (People's search).
  final Widget? titleField;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BvColors.surfaceApp,
    appBar: AppBar(
      backgroundColor: BvColors.surfaceApp,
      centerTitle: false,
      titleSpacing: 0,
      title: titleField ?? Text(title, style: BvType.of(context).titleLg),
      actions: actions,
    ),
    body:
        body ??
        Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(AppLocalizations.of(context).spacesNotFound),
        ),
  );
}

/// What Space info hands back to the Space (review 105 Part 1: it holds
/// what ⋯ held): the daily report opens on Work.
enum SpaceInfoAction { dailyReport }

/// The Space's whole Chat unread, for its Work · Chat switch.
int spaceUnread(List<ChatThread> threads) =>
    threads.fold(0, (n, t) => n + t.unread);

/// A Space member who wants in is waiting (Needs you): People's dot.
bool joinWaiting(SpacePeople? people) => people?.requests.isNotEmpty ?? false;
