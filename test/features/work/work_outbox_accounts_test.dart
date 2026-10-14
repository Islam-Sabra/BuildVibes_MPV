import 'dart:convert';

import 'package:buildvibes/core/l10n/locale_controller.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/work/work_outbox.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _item = PendingItem(
  id: 'item-1',
  spaceId: 'space-1',
  title: 'Rebar check level 3',
  ownerId: 'p-rakesh',
  ownerName: 'Rakesh Nair',
);

Future<List<PendingItem>> _outboxOf(String? userId) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authUserIdProvider.overrideWithValue(AsyncData(userId)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(workOutboxProvider);
}

void main() {
  // Found by the end-to-end test (integration_test/main_journey_test.dart):
  // on a phone a crew shares, one person's unsent work showed for the next.
  test('unsent work belongs to the account that made it', () async {
    SharedPreferences.setMockInitialValues({
      'work_outbox:user-omar': jsonEncode([_item.toJson()]),
    });
    expect((await _outboxOf('user-omar')).single.title, _item.title);
    expect(await _outboxOf('user-rakesh'), isEmpty);
    expect(await _outboxOf(null), isEmpty);
  });

  test('the old shared outbox, of unknown accounts, is cleared', () async {
    SharedPreferences.setMockInitialValues({
      'work_outbox': jsonEncode([_item.toJson()]),
    });
    expect(await _outboxOf('user-rakesh'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    await Future<void>.delayed(Duration.zero);
    expect(prefs.containsKey('work_outbox'), isFalse);
  });
}
