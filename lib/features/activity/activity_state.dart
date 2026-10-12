import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../data/models/activity.dart';
import '../../data/repositories/activity_repository.dart';
import '../entry/entry_state.dart';
import '../profile/edit/experience_screens.dart' show clockProvider;

/// The phone's midnight today: where "today" starts on Home.
DateTime dayStartOf(DateTime now) => DateTime(now.year, now.month, now.day);

final activityProvider = FutureProvider.autoDispose<List<ActivityRow>>(
  (ref) => ref.watch(activityRepositoryProvider).activity(),
);

/// The dot on the Activity tab. Guests have no Activity.
final unreadActivityProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (ref.watch(appGateProvider) != AppGate.ready) return false;
  return ref.watch(activityRepositoryProvider).unread();
});

/// Needs you: Home's first 3 and all of them in Activity.
final needsCardsProvider = FutureProvider.autoDispose<List<NeedsCard>>(
  (ref) => ref.watch(activityRepositoryProvider).needs(),
);

final homeDayProvider = FutureProvider.autoDispose<HomeDay>(
  (ref) => ref
      .watch(activityRepositoryProvider)
      .homeDay(dayStartOf(ref.watch(clockProvider)())),
);

final todayInSpacesProvider = FutureProvider.autoDispose<List<SpaceToday>>(
  (ref) => ref
      .watch(activityRepositoryProvider)
      .today(dayStartOf(ref.watch(clockProvider)())),
);

/// After something changed in a Space (a visit, a sign-off, a decision):
/// Home and Activity read again.
void refreshDay(void Function(ProviderOrFamily) invalidate) {
  invalidate(needsCardsProvider);
  invalidate(homeDayProvider);
  invalidate(todayInSpacesProvider);
  invalidate(unreadActivityProvider);
}
