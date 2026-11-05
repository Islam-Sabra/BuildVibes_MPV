import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/dm_fakes.dart';
import '../../helpers/key_people_fakes.dart';
import '../../helpers/pump_app.dart';

/// Review 121b: Call from a direct message, for someone whose choice is
/// "My Spaces and people I message".

final _now = DateTime(2026, 10, 15, 11);

const _omar = DmThreadPage(
  threadId: 't-omar',
  person: DmPerson(id: 'p-omar', name: 'Omar Haddad'),
  state: DmState.open,
  messages: [],
);

Finder _key(String k) => find.byKey(Key(k));

Future<({TestApp app, FakeKeyPeopleRepository keys})> _open(
  WidgetTester tester,
  String lang, {
  bool canCall = true,
  String? phone = '+96590001234',
}) async {
  final keys = FakeKeyPeopleRepository();
  if (canCall) keys.callable.add('p-omar');
  if (phone != null) keys.phones['p-omar'] = phone;
  final app = await pumpApp(
    tester,
    language: lang,
    dm: FakeDmRepository()..pages['t-omar'] = _omar,
    keyPeople: keys,
    now: _now,
  );
  GoRouter.of(
    tester.element(find.byType(Scaffold).first),
  ).push('/messages/t-omar');
  await tester.pumpAndSettle();
  return (app: app, keys: keys);
}

void main() {
  for (final lang in ['en', 'ar']) {
    group('121b Call from a direct message [$lang]', () {
      testWidgets('the phone icon sits before ⋯, the size of the bar\'s '
          'other icons', (tester) async {
        await _open(tester, lang);
        expect(_key('dm-call'), findsOneWidget);
        final call = tester.getCenter(_key('dm-call')).dx;
        final more = tester.getCenter(_key('dm-more')).dx;
        // Before ⋯ in reading order: left of it in English, right in Arabic.
        expect(lang == 'ar' ? call > more : call < more, isTrue);
        final icon = tester.widget<Icon>(
          find.descendant(of: _key('dm-call'), matching: find.byType(Icon)),
        );
        final dots = tester.widget<Icon>(
          find.descendant(of: _key('dm-more'), matching: find.byType(Icon)),
        );
        expect(icon.icon, BvIcons.call);
        expect(icon.size, dots.size);
        expect(icon.color, dots.color);
      });

      testWidgets('a tap reads the number from the DM and opens the dialler', (
        tester,
      ) async {
        final (:app, :keys) = await _open(tester, lang);
        await tester.tap(_key('dm-call'));
        await tester.pumpAndSettle();
        expect(keys.asked, ['p-omar']);
        expect(keys.askedFrom, [null]);
        expect(app.opened, [Uri(scheme: 'tel', path: '+96590001234')]);
      });

      testWidgets('no icon when their choice doesn\'t let me call', (
        tester,
      ) async {
        await _open(tester, lang, canCall: false);
        expect(_key('dm-more'), findsOneWidget);
        expect(_key('dm-call'), findsNothing);
      });

      testWidgets('taken back meanwhile: says so, and the icon goes', (
        tester,
      ) async {
        final (:app, :keys) = await _open(tester, lang, phone: null);
        keys.callable.clear();
        await tester.tap(_key('dm-call'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            lang == 'ar'
                ? 'لم يعد هذا الرقم متاحاً'
                : 'This number isn\'t shared any more',
          ),
          findsOneWidget,
        );
        expect(app.opened, isEmpty);
        expect(_key('dm-call'), findsNothing);
      });
    });
  }
}
