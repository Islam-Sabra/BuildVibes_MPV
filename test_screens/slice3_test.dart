// Slice 3, direct messages (review 64), against Figma DM1 (EN 2560:35524,
// AR 2564:745), DM2 (2561:35447, 2563:170) and DM6 (2571:35584, 2574:360).
// Run:
//   flutter test test_screens/slice3_test.dart --update-goldens
import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/dm.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/repositories/dm_repository.dart';
import 'package:buildvibes/data/repositories/space_repository.dart';
import 'package:buildvibes/features/entry/entry_state.dart';
import 'package:buildvibes/features/messages/dm_thread_screen.dart';
import 'package:buildvibes/features/messages/messages_screen.dart';
import 'package:buildvibes/features/profile/edit/experience_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/dm_fakes.dart';
import '../test/helpers/space_fakes.dart';
import 'shot.dart';

const _folder = 'slice3';

/// Thursday 15 October, 11:00.
final _now = DateTime(2026, 10, 15, 11);

String _t(String lang, String en, String ar) => lang == 'ar' ? ar : en;

DmRow _row(
  String thread,
  String name, {
  required DateTime at,
  bool unread = false,
  bool fromMe = false,
  ChatKind kind = ChatKind.text,
  String? text,
  String? fileName,
  int? durationMs,
}) => DmRow(
  threadId: thread,
  person: DmPerson(id: 'p-$thread', name: name),
  lastMessageAt: at,
  unread: unread,
  last: DmPreview(
    fromMe: fromMe,
    kind: kind,
    at: at,
    text: text,
    fileName: fileName,
    durationMs: durationMs,
  ),
);

/// DM1 as drawn.
DmInbox _inbox(String lang) => DmInbox(
  threads: [
    _row(
      'omar',
      _t(lang, 'Omar Haddad', 'عمر حداد'),
      at: DateTime(2026, 10, 15, 10, 42),
      unread: true,
      text: _t(
        lang,
        'Also the pump is booked for Sunday 2 pm. We need the gate clear.',
        'المضخة محجوزة أيضًا يوم الأحد الساعة 2 ظهرًا. نحتاج البوابة فارغة.',
      ),
    ),
    _row(
      'sara',
      _t(lang, 'Sara Al-Mutairi', 'سارة المطيري'),
      at: DateTime(2026, 10, 15, 9, 20),
      fromMe: true,
      text: _t(
        lang,
        'Sent you the photos from this morning',
        'أرسلت لك صور هذا الصباح',
      ),
    ),
    _row(
      'rakesh',
      _t(lang, 'Rakesh Nair', 'راكيش ناير'),
      at: DateTime(2026, 10, 15, 8, 5),
      unread: true,
      kind: ChatKind.voice,
      durationMs: 24000,
    ),
    _row(
      'lina',
      _t(lang, 'Lina Khalil', 'لينا خليل'),
      at: DateTime(2026, 10, 14, 17),
      kind: ChatKind.file,
      fileName: 'Finishes schedule.pdf',
    ),
    _row(
      'mona',
      _t(lang, 'Mona Adel', 'منى عادل'),
      at: DateTime(2026, 10, 13, 16),
      text: _t(
        lang,
        'Thanks, see you at the walk on Friday.',
        'شكرًا، أراك في الجولة يوم الجمعة.',
      ),
    ),
  ],
  newestRequest: _row(
    'yousef',
    _t(lang, 'Yousef Karam', 'يوسف كرم'),
    at: DateTime(2026, 10, 15, 10),
    unread: true,
    text: _t(
      lang,
      'Salam, can we talk about the finishing work?',
      'السلام عليكم، هل يمكن أن نتحدث عن أعمال التشطيب؟',
    ),
  ),
);

/// DM2: the thread with Omar.
DmThreadPage _omar(String lang, {DmState state = DmState.open}) => DmThreadPage(
  threadId: 'omar',
  person: DmPerson(
    id: 'p-omar',
    name: _t(lang, 'Omar Haddad', 'عمر حداد'),
    headline: _t(lang, 'Site Engineer', 'مهندس موقع'),
    company: 'Al Hamra Contracting',
  ),
  state: state,
  sharedSpaceId: 's-kct',
  sharedSpaceName: _t(lang, 'Kuwait City Tower', 'برج مدينة الكويت'),
  messages: [
    DmMessage(
      id: 'm4',
      fromMe: false,
      kind: ChatKind.text,
      createdAt: DateTime(2026, 10, 15, 10, 42),
      body: _t(
        lang,
        'Also the pump is booked for Sunday 2 pm. We need the gate clear.',
        'المضخة محجوزة أيضًا يوم الأحد الساعة 2 ظهرًا. نحتاج البوابة فارغة.',
      ),
    ),
    DmMessage(
      id: 'm3',
      fromMe: true,
      kind: ChatKind.text,
      createdAt: DateTime(2026, 10, 15, 10, 31),
      body: _t(
        lang,
        'Yes, at 7. I\'ll bring the drawings.',
        'نعم، الساعة 7. سأحضر المخططات.',
      ),
      replyTo: DmReply(
        id: 'm2',
        fromMe: false,
        text: _t(lang, 'Can we meet at the gate?', 'هل نلتقي عند البوابة؟'),
      ),
    ),
    DmMessage(
      id: 'm2',
      fromMe: false,
      kind: ChatKind.text,
      createdAt: DateTime(2026, 10, 15, 10, 30),
      body: _t(lang, 'Can we meet at the gate?', 'هل نلتقي عند البوابة؟'),
    ),
    DmMessage(
      id: 'm1',
      fromMe: false,
      kind: ChatKind.file,
      createdAt: DateTime(2026, 10, 15, 10, 28),
      tapToShow: state == DmState.request,
      files: const [
        DmFile(
          path: 'p-omar/m1/pour.pdf',
          mime: 'application/pdf',
          name: 'Pour sequence L3.pdf',
          bytes: 1258291,
        ),
      ],
    ),
  ],
);

List<Override> _overrides(FakeDmRepository dm, {String lang = 'en'}) => [
  dmRepositoryProvider.overrideWithValue(dm),
  clockProvider.overrideWithValue(() => _now),
  authUserIdProvider.overrideWithValue(const AsyncData('user-1')),
  myProfileProvider.overrideWith((ref) async => null),
  // DM4: the Spaces you're in; you post in two, you only read the third.
  spaceRepositoryProvider.overrideWithValue(
    FakeSpaceRepository()
      ..spaces.addAll([
        SpaceSummary(
          id: 's-kct',
          name: _t(
            lang,
            'Kuwait City Tower — Site team',
            'برج مدينة الكويت — فريق الموقع',
          ),
          pass: SpacePass.lead,
          isAdmin: true,
        ),
        SpaceSummary(
          id: 's-khiran',
          name: _t(
            lang,
            'Khiran villas — Finishing',
            'فلل الخيران — التشطيبات',
          ),
          pass: SpacePass.crew,
          isAdmin: false,
        ),
        SpaceSummary(
          id: 's-office',
          name: _t(
            lang,
            'Gulf Build Co. — Office',
            'شركة الخليج للبناء — المكتب',
          ),
          pass: SpacePass.viewer,
          isAdmin: false,
        ),
      ]),
  ),
];

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .alwaysUse24HourFormatTestValue =
        true;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAlwaysUse24HourTestValue(),
  );

  for (final lang in ['en', 'ar']) {
    testWidgets('DM1 Messages [$lang]', (tester) async {
      await shoot(
        tester,
        'DM1-messages',
        lang,
        (_) => const MessagesScreen(),
        folder: _folder,
        overrides: _overrides(FakeDmRepository()..inboxValue = _inbox(lang)),
      );
    });

    testWidgets('DM2 a thread with Omar [$lang]', (tester) async {
      await shoot(
        tester,
        'DM2-thread',
        lang,
        (_) => const DmThreadScreen(threadId: 'omar'),
        folder: _folder,
        overrides: _overrides(FakeDmRepository()..pages['omar'] = _omar(lang)),
      );
    });

    // Review 64: hold a message (DM3), Put in a Space (DM4).
    for (final sheet in [false, true]) {
      testWidgets('${sheet ? 'DM4 Put in a Space' : 'DM3 hold a message'} '
          '[$lang]', (tester) async {
        await shoot(
          tester,
          sheet ? 'DM4-put-in-space' : 'DM3-hold',
          lang,
          (_) => const DmThreadScreen(threadId: 'omar'),
          folder: _folder,
          overrides: _overrides(
            FakeDmRepository()..pages['omar'] = _omar(lang),
            lang: lang,
          ),
          before: (tester) async {
            await tester.longPress(find.byKey(const Key('chat-message-m4')));
            await tester.pumpAndSettle();
            if (sheet) {
              await tester.tap(find.byKey(const Key('dm-action-space')));
              await tester.pumpAndSettle();
            }
          },
        );
      });
    }

    testWidgets('DM6 a request from someone new [$lang]', (tester) async {
      final page = _omar(lang, state: DmState.request);
      await shoot(
        tester,
        'DM6-request',
        lang,
        (_) => const DmThreadScreen(threadId: 'omar'),
        folder: _folder,
        overrides: _overrides(
          FakeDmRepository()
            ..pages['omar'] = DmThreadPage(
              threadId: page.threadId,
              person: page.person,
              state: DmState.request,
              messages: page.messages,
            ),
        ),
      );
    });
  }
}
