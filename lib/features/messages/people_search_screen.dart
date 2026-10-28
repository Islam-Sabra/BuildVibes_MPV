import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/bv_tokens.dart';
import '../../core/l10n/bidi.dart';
import '../../core/routing/app_routes.dart';
import '../../data/models/space.dart';
import '../../data/repositories/people_search_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../entry/entry_state.dart';
import '../profile/widgets/profile_parts.dart';
import '../../core/routing/open_thread.dart';

/// Why people are searched: to write to one (Messages' +, "New message"),
/// or to open their profile (Home's "Search people").
enum PeopleSearchFor { message, profile }

/// The people [me] shares a Space with, A–Z.
final sharedSpacePeopleProvider = FutureProvider.autoDispose<List<SpacePerson>>(
  (ref) async {
    final me = ref.watch(authUserIdProvider).value;
    if (me == null) return const [];
    final people = await ref
        .watch(peopleSearchRepositoryProvider)
        .sharedSpaces(me: me);
    return [...people]..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  },
);

/// People matching a search, those [me] shares a Space with first.
final peopleSearchProvider = FutureProvider.autoDispose
    .family<List<SpacePerson>, String>((ref, query) async {
      final me = ref.watch(authUserIdProvider).value;
      if (me == null) return const [];
      final found = await ref
          .watch(peopleSearchRepositoryProvider)
          .search(query, me: me);
      final shared = {
        for (final p in await ref.watch(sharedSpacePeopleProvider.future)) p.id,
      };
      return [
        ...found.where((p) => shared.contains(p.id)),
        ...found.where((p) => !shared.contains(p.id)),
      ];
    });

/// F78 · Finding a person: a search by name, role or company, and before
/// typing the people you share a Space with, A–Z with their role. A tap
/// writes to them ([PeopleSearchFor.message]) or opens their profile.
/// Blocked and hidden accounts never show (the server's rule).
class PeopleSearchScreen extends ConsumerStatefulWidget {
  const PeopleSearchScreen({super.key, required this.purpose});

  final PeopleSearchFor purpose;

  @override
  ConsumerState<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends ConsumerState<PeopleSearchScreen> {
  final _field = TextEditingController();
  Timer? _wait;
  var _query = '';

  @override
  void dispose() {
    _wait?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _wait?.cancel();
    final q = text.trim();
    if (q.length < PeopleSearchRepository.minLength) {
      setState(() => _query = '');
      return;
    }
    _wait = Timer(BvMotion.searchWait, () {
      if (mounted) setState(() => _query = q);
    });
  }

  void _open(SpacePerson p) => switch (widget.purpose) {
    PeopleSearchFor.message => openDmThread(
      GoRouter.of(context),
      AppRoutes.messagesWith(p.id),
    ),
    PeopleSearchFor.profile => context.push(AppRoutes.person(p.id)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _query;
    final list = q.isEmpty
        ? ref.watch(sharedSpacePeopleProvider)
        : ref.watch(peopleSearchProvider(q));
    final Widget body;
    if (list.value case final people?) {
      if (people.isEmpty) {
        body = Padding(
          padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
          child: EmptyNote(
            q.isEmpty
                ? l10n.peopleSearchStart
                : l10n.peopleSearchNothing(inOwnDirection(q)),
          ),
        );
      } else {
        body = ListView(
          key: const Key('people-search-results'),
          children: [
            if (q.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BvSpace.gutter,
                  BvSpace.s16,
                  BvSpace.gutter,
                  BvSpace.s8,
                ),
                child: Text(
                  l10n.peopleInYourSpaces,
                  style: BvType.of(
                    context,
                  ).labelSm.copyWith(color: BvColors.textSecondary),
                ),
              ),
            for (final p in people)
              _PersonRow(
                key: Key('people-search-${p.id}'),
                person: p,
                onTap: () => _open(p),
              ),
          ],
        );
      }
    } else if (list.hasError) {
      body = Padding(
        padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
        child: EmptyNote(l10n.errorGeneric),
      );
    } else {
      body = const Padding(
        padding: EdgeInsetsDirectional.all(BvSpace.s32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.purpose == PeopleSearchFor.message
              ? l10n.messagesNew
              : l10n.homeSearch,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BvSpace.gutter,
              BvSpace.s8,
              BvSpace.gutter,
              BvSpace.s8,
            ),
            child: BvSearchField(
              key: const Key('people-search-field'),
              controller: _field,
              placeholder: l10n.peopleSearchHint,
              autofocus: true,
              onChanged: _changed,
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({super.key, required this.person, required this.onTap});

  final SpacePerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final p = person;
    // A typed company stays plain text (rule 4).
    final line = joinMeta([?p.roleLabel(lang), ?p.companyLabel]);
    return BvListRow(
      leading: BvAvatar(
        name: p.fullName,
        size: BvAvatarSize.list,
        tint: BvAvatarTints.forId(p.id),
      ),
      title: inOwnDirection(p.fullName),
      subtitle: line.isEmpty ? null : line,
      onTap: onTap,
    );
  }
}
