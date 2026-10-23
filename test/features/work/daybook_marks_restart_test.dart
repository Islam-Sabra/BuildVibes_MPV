import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/core/network/signal_state.dart';
import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/repositories/daybook_live.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/work/daybook_marks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/daybook_fakes.dart';
import '../../helpers/daybook_samples.dart';

void main() {
  test(
    'review 88 S2: a tick and a Got it made with no signal are kept on '
    'the phone across a restart and sent once when the signal is back',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final daybook = FakeDaybookRepository();
      ProviderContainer open(String me) => ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authUserIdProvider.overrideWithValue(AsyncData(me)),
          daybookRepositoryProvider.overrideWithValue(daybook),
          daybookLiveProvider.overrideWithValue(FakeDaybookLive()),
        ],
      );
      final at = DateTime.utc(2026, 10, 22, 10, 40);

      // In the basement: a tick and a Got it, no signal.
      final first = open(DaybookSamples.sara);
      final marks = first.read(daybookMarksProvider.notifier);
      daybook.failMarks = 2;
      await marks.send(
        DaybookMark(
          spaceId: DaybookSamples.space,
          postId: DaybookSamples.handoverId,
          on: true,
          at: at,
          pointId: 'pt-2',
          pointText: 'Sleeves fixed',
        ),
      );
      await marks.send(
        DaybookMark(
          spaceId: DaybookSamples.space,
          postId: 'post-pour',
          on: true,
          at: at,
          ack: DaybookAck.gotIt,
        ),
      );
      expect(daybook.marks, isEmpty);
      expect(first.read(daybookMarksProvider).every((m) => m.waiting), isTrue);
      // The app is closed.
      first.dispose();
      expect(
        prefs.getString('daybook_marks:${DaybookSamples.sara}'),
        isNotNull,
      );

      // Another account on the same phone never sees (or sends) them.
      final other = open(DaybookSamples.omar);
      expect(other.read(daybookMarksProvider), isEmpty);
      other.dispose();

      // Opened again, still in the basement: they stay, waiting.
      final next = open(DaybookSamples.sara);
      addTearDown(next.dispose);
      final kept = next.read(daybookMarksProvider);
      expect(kept, hasLength(2));
      expect(kept.every((m) => m.waiting), isTrue);
      expect(kept.first.pointText, 'Sleeves fixed');
      expect(kept.first.at, at);
      daybook.failMarks = 2;
      await next.read(daybookMarksProvider.notifier).flushAll();
      expect(next.read(signalProvider), isFalse);

      // The signal is back: each goes once.
      next.read(signalProvider.notifier).back();
      await pumpEventQueue();
      expect(daybook.marks, ['tick pt-2 true', 'ack post-pour got_it true']);
      expect(next.read(daybookMarksProvider), isEmpty);
      expect(prefs.getString('daybook_marks:${DaybookSamples.sara}'), isNull);
      await next.read(daybookMarksProvider.notifier).flushAll();
      expect(daybook.marks, hasLength(2));
    },
  );
}
