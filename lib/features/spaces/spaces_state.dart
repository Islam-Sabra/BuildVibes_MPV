import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';
import '../entry/entry_state.dart';

/// "Not confirmed" rows the person dismissed on My Spaces. Kept on this
/// phone only: the request itself stays on the server for 30 days.
final dismissedJoinRequestsProvider =
    NotifierProvider<DismissedJoinRequests, Set<String>>(
      DismissedJoinRequests.new,
    );

class DismissedJoinRequests extends Notifier<Set<String>> {
  static const _key = 'dismissed_join_requests';

  @override
  Set<String> build() =>
      (ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [])
          .toSet();

  Future<void> dismiss(String requestId) async {
    state = {...state, requestId};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, state.toList());
  }
}

/// The Space this person opened last, on this phone: Create lists it
/// first (review 50 F1). One per account, so a shared phone keeps each
/// person's own.
final lastSpaceProvider = NotifierProvider<LastSpace, String?>(LastSpace.new);

class LastSpace extends Notifier<String?> {
  String? get _key {
    final me = ref.watch(authUserIdProvider).value;
    return me == null ? null : 'last_space:$me';
  }

  @override
  String? build() {
    final key = _key;
    return key == null
        ? null
        : ref.watch(sharedPreferencesProvider).getString(key);
  }

  Future<void> opened(String spaceId) async {
    final key = _key;
    if (key == null || state == spaceId) return;
    state = spaceId;
    await ref.read(sharedPreferencesProvider).setString(key, spaceId);
  }
}

/// Review 113 (5): the tab each Space was last left on (Work or Chat), on
/// this phone and for this account; null before it was ever opened, so
/// the first open is Work.
final spaceLastTabProvider =
    NotifierProvider.family<SpaceLastTab, String?, String>(SpaceLastTab.new);

class SpaceLastTab extends Notifier<String?> {
  SpaceLastTab(this.spaceId);

  final String spaceId;

  /// What [show] keeps.
  static const work = 'work';
  static const chat = 'chat';

  String? get _key {
    final me = ref.watch(authUserIdProvider).value;
    return me == null ? null : 'space_tab:$me:$spaceId';
  }

  @override
  String? build() {
    final key = _key;
    return key == null
        ? null
        : ref.watch(sharedPreferencesProvider).getString(key);
  }

  Future<void> show(String tab) async {
    final key = _key;
    if (key == null || state == tab) return;
    state = tab;
    await ref.read(sharedPreferencesProvider).setString(key, tab);
  }
}
