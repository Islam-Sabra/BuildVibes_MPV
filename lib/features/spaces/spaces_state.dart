import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_controller.dart';

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
