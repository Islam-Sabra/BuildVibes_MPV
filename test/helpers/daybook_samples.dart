import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';

/// The prototype's daybook (D1 2518:33001, L1 2539:34633, DY1 2541:34679),
/// in English or with the AR frames' words (2547:35195), never a fresh
/// translation. Posts are shown as written, so the Arabic shots use the
/// Arabic frames' posts.
class DaybookSamples {
  const DaybookSamples(this.lang);

  final String lang;

  bool get _ar => lang == 'ar';
  String t(String en, String ar) => _ar ? ar : en;

  static const space = 'space-kct';
  static const islam = 'user-1';
  static const sara = 'p-sara';
  static const omar = 'p-omar';
  static const mona = 'p-mona';
  static const rakesh = 'p-rakesh';
  static const lina = 'p-lina';

  String get islamName => t('Islam Ahmed', 'إسلام أحمد');
  String get saraName => t('Sara Al-Mutairi', 'سارة المطيري');
  String get omarName => t('Omar Haddad', 'عمر حداد');
  String get rakeshName => t('Rakesh Nair', 'راكيش ناير');
  String get linaName => t('Lina Khalil', 'لينا خليل');
  String get monaName => t('Mona Adel', 'منى عادل');

  /// The Space's people (the give-to picker 2540:34840): Leads, Crew in
  /// their Teams, and a Viewer, who can't own a work item.
  SpacePeople people() {
    SpacePerson person(String id, String name) {
      final parts = name.split(' ');
      return SpacePerson(
        id: id,
        firstName: parts.first,
        lastName: parts.skip(1).join(' '),
      );
    }

    SpaceMember member(String id, String name, SpacePass pass) => SpaceMember(
      person: person(id, name),
      pass: pass,
      isAdmin: id == islam,
      confirmedAt: DateTime(2026, 9, 5),
    );
    return SpacePeople(
      members: [
        member(islam, islamName, SpacePass.lead),
        member(omar, omarName, SpacePass.crew),
        member(rakesh, rakeshName, SpacePass.crew),
        member(sara, saraName, SpacePass.lead),
        member(lina, linaName, SpacePass.crew),
        member(mona, monaName, SpacePass.viewer),
      ],
      teams: [
        SpaceTeam(
          id: 't-mep',
          name: t('MEP', 'الكهروميكانيك'),
          memberIds: const {omar, rakesh},
        ),
        SpaceTeam(
          id: 't-site',
          name: t('Site', 'الموقع'),
          memberIds: const {sara},
        ),
        SpaceTeam(
          id: 't-arch',
          name: t('Architecture', 'المعماري'),
          memberIds: const {lina},
        ),
      ],
    );
  }

  String get spaceName =>
      t('Kuwait City Tower — Site team', 'برج مدينة الكويت — فريق الموقع');

  /// Thursday 15 October 2026, day 41 on site.
  static final thursday = DateTime(2026, 10, 15, 10, 30);
  static final siteStart = DateTime(2026, 9, 5);

  SpaceDetail detail({
    SpacePass pass = SpacePass.lead,
    bool admin = true,
    DateTime? siteStart,
  }) => SpaceDetail(
    id: space,
    name: spaceName,
    projectId: 'proj-kct',
    projectName: t('Kuwait City Tower', 'برج مدينة الكويت'),
    myPass: pass,
    iAmAdmin: admin,
    myRights: MemberRights(
      createItems: pass != SpacePass.viewer,
      invite: admin,
      markDone: pass != SpacePass.viewer,
    ),
    siteStartDate: siteStart ?? DaybookSamples.siteStart,
  );

  DaybookPost item({
    required String id,
    required DateTime at,
    required String title,
    required String authorId,
    required String authorName,
    required String ownerId,
    required String ownerName,
    DateTime? due,
    DateTime? dueAt,
    String? place,
    int points = 0,
    DaybookStampKind? stamp,
    String? status,
    bool needsMe = false,
    String? cover,
    DaybookDueEdit? edit,
    List<DaybookAttachment> attachments = const [],
    DaybookGivenTo? givenTo,
  }) => DaybookPost(
    id: id,
    kind: DaybookPost.workItemKind,
    createdAt: at,
    title: title,
    authorId: authorId,
    authorName: authorName,
    place: place,
    dueDate: due,
    dueAt: dueAt,
    item: DaybookItem(
      status: switch (stamp) {
        DaybookStampKind.done => WorkStatus.done,
        DaybookStampKind.checked => WorkStatus.checked,
        _ => WorkStatus.open,
      },
      ownerId: ownerId,
      ownerName: ownerName,
    ),
    stamp: stamp == null ? null : DaybookStamp(kind: stamp, at: at),
    needsMe: needsMe,
    pointsTotal: points,
    coverPath: cover,
    dueEdit: edit,
    attachments: attachments,
    givenTo: givenTo,
  );

  String get sleeves => t(
    'Sleeves at grid C7 before the pour',
    'تركيب الجلب عند المحور C7 قبل الصبّ',
  );
  String get levelTwo => t('Level 2, grid C7', 'الدور 2، المحور C7');

  /// DY1: yesterday's checked item.
  DaybookPost gate() => item(
    id: 'post-gate',
    at: DateTime(2026, 10, 14, 16, 20),
    title: t(
      'Gate 3 access cleared for the pump truck',
      'تجهيز مدخل البوابة 3 لشاحنة المضخة',
    ),
    authorId: islam,
    authorName: islamName,
    ownerId: omar,
    ownerName: omarName,
    due: DateTime(2026, 10, 14),
    place: t('Gate 3', 'البوابة 3'),
    points: 2,
    stamp: DaybookStampKind.checked,
  );

  /// D1 08:14: Omar signed it. The clip for my check is on his sign-off,
  /// never on this slip (review 45 M2).
  DaybookPost sleevesDone() => item(
    id: 'post-sleeves',
    at: DateTime(2026, 10, 15, 8, 14),
    title: sleeves,
    authorId: islam,
    authorName: islamName,
    ownerId: omar,
    ownerName: omarName,
    due: DateTime(2026, 10, 15),
    place: levelTwo,
    points: 2,
    stamp: DaybookStampKind.done,
    attachments: const [
      DaybookAttachment(name: 'M-201.pdf', revLabel: 'Rev C'),
    ],
  );

  String get sleevesNote => t(
    'All six fixed and checked with MEP.',
    'رُكّبت الست كلها وراجعتها مع فريق الكهروميكانيك.',
  );

  /// D1 09:40: Omar's proof, waiting for my check.
  DaybookSignOff sleevesSignOff({
    bool needsMe = true,
    DaybookOutcome outcome = const DaybookOutcome(
      kind: DaybookOutcomeKind.done,
    ),
  }) => DaybookSignOff(
    id: 'event-sleeves-done',
    at: DateTime(2026, 10, 15, 9, 40),
    postId: 'post-sleeves',
    title: sleeves,
    ref: 'KCT-021',
    actorId: omar,
    actorName: omarName,
    note: sleevesNote,
    photos: const [WorkPhoto(path: '$space/post-sleeves/proof.jpg')],
    outcome: outcome,
    needsMe: needsMe,
  );

  /// D1 10:05: Sara's item for me, due today at 2 pm, moved from Thu.
  DaybookPost rebar({bool needsMe = true}) => item(
    id: 'post-rebar',
    at: DateTime(2026, 10, 15, 10, 5),
    title: t(
      'Rebar spacing, level 3 slab',
      'تباعد حديد التسليح، بلاطة الدور 3',
    ),
    authorId: sara,
    authorName: saraName,
    ownerId: islam,
    ownerName: islamName,
    due: DateTime(2026, 10, 15),
    dueAt: DateTime(2026, 10, 15, 14),
    needsMe: needsMe,
    edit: DaybookDueEdit(
      from: DateTime(2026, 10, 22),
      to: DateTime(2026, 10, 15),
    ),
  );

  List<DaybookRecord> d1({bool viewer = false}) => [
    gate(),
    sleevesDone(),
    sleevesSignOff(needsMe: !viewer),
    rebar(needsMe: !viewer),
  ];

  /// E3 2524:33577 and AR 2547:35369: the work item being written.
  String get traysBody => t(
    'Fix the hangers every 1.5 m before the ceiling closes.',
    'ركّب العلّاقات كل 1.5 م قبل إغلاق السقف.',
  );
  String get traysPlace => t('Level 4 corridor', 'ممر الدور 4');

  /// A work item written in place, as the server reads it back: by Islam,
  /// at [at].
  DaybookPost posted(NewWorkItem i, DateTime at) => item(
    id: i.id,
    at: at,
    title: i.title,
    authorId: islam,
    authorName: islamName,
    ownerId: i.ownerId,
    ownerName:
        [
          for (final m in people().members)
            if (m.person.id == i.ownerId) m.person.fullName,
        ].firstOrNull ??
        '',
    due: i.dueDate,
    dueAt: i.dueAt,
    place: i.place,
    cover: i.photoPaths.firstOrNull,
  );

  /// L1, Omar's Friday: the sleeves went late, the cable trays are due.
  static final friday = DateTime(2026, 10, 16, 11, 40);

  List<DaybookPost> l1() => [
    item(
      id: 'post-sleeves',
      at: DateTime(2026, 10, 16, 8, 14),
      title: sleeves,
      authorId: islam,
      authorName: islamName,
      ownerId: omar,
      ownerName: omarName,
      due: DateTime(2026, 10, 15),
      place: levelTwo,
      points: 2,
      needsMe: true,
    ),
    cableTrays(),
  ];

  String get cableTraysTitle =>
      t('Cable tray hangers, level 4', 'علّاقات حوامل الكابلات، الدور 4');

  DaybookPost cableTrays() => item(
    id: 'post-trays',
    at: DateTime(2026, 10, 16, 11, 20),
    title: cableTraysTitle,
    authorId: islam,
    authorName: islamName,
    ownerId: omar,
    ownerName: omarName,
    due: DateTime(2026, 10, 16),
    needsMe: true,
    cover: '$space/posts/post-trays/photo.jpg',
  );

  CalendarWorkItem cableTraysDue() => CalendarWorkItem(
    spaceId: space,
    title: cableTraysTitle,
    day: DateTime(2026, 10, 16),
    status: WorkStatus.open,
  );

  // The loop (part 1d): Omar's side O1–O3, S1, Y1–Y2; your side B1–B3,
  // X1–X3.

  /// O1 2529:33382: Omar's Thursday. The sleeves are his to sign (the
  /// clip on the slip, review 45 M2), the cable trays too.
  List<DaybookRecord> o1() => [
    item(
      id: 'post-sleeves',
      at: DateTime(2026, 10, 15, 8, 14),
      title: sleeves,
      authorId: islam,
      authorName: islamName,
      ownerId: omar,
      ownerName: omarName,
      due: DateTime(2026, 10, 15),
      place: levelTwo,
      points: 2,
      needsMe: true,
      attachments: const [
        DaybookAttachment(name: 'M-201.pdf', revLabel: 'Rev C'),
      ],
    ),
    traysForOmar(),
  ];

  /// The cable trays, Islam's, for Omar by Sunday (O1 11:20, X1).
  DaybookPost traysForOmar({bool needsMe = true, DaybookGivenTo? givenTo}) =>
      item(
        id: 'post-trays',
        at: DateTime(2026, 10, 15, 11, 20),
        title: cableTraysTitle,
        authorId: islam,
        authorName: islamName,
        ownerId: givenTo == null ? omar : rakesh,
        ownerName: givenTo == null ? omarName : rakeshName,
        due: DateTime(2026, 10, 18),
        needsMe: needsMe,
        cover: '$space/posts/post-trays/photo.jpg',
        givenTo: givenTo,
      );

  String get sentBackNote => t(
    'One sleeve is 50 mm short. Check M-201.',
    'حسب المخطط M-201، جلبة واحدة أقصر بـ 50 مم.',
  );

  /// S1 2530:33826: Islam sent Omar's proof back at 10:12; the sleeves are
  /// open again, Omar's to sign: his clip is on the send-back (migration
  /// 24), not on the item.
  List<DaybookRecord> s1() => [
    item(
      id: 'post-sleeves',
      at: DateTime(2026, 10, 15, 8, 14),
      title: sleeves,
      authorId: islam,
      authorName: islamName,
      ownerId: omar,
      ownerName: omarName,
      due: DateTime(2026, 10, 15),
      place: levelTwo,
      stamp: DaybookStampKind.sentBack,
    ),
    sleevesSignOff(
      needsMe: false,
      outcome: DaybookOutcome(
        kind: DaybookOutcomeKind.sentBack,
        at: DateTime(2026, 10, 15, 10, 12),
        byId: islam,
        byName: islamName,
        reason: SendBackReason.notAsAsked,
        note: sentBackNote,
      ),
    ),
    sleevesSentBack(),
  ];

  /// S1's send-back at 10:12, with Omar's clip while it is the latest.
  DaybookSentBack sleevesSentBack({bool needsMe = true}) => DaybookSentBack(
    id: 'event-sleeves-back',
    at: DateTime(2026, 10, 15, 10, 12),
    postId: 'post-sleeves',
    title: sleeves,
    ref: 'KCT-021',
    actorId: islam,
    actorName: islamName,
    reason: SendBackReason.notAsAsked,
    note: sentBackNote,
    needsMe: needsMe,
  );

  /// Y2 2530:34038: Omar's update at 09:05.
  DaybookUpdate sleevesUpdate() => DaybookUpdate(
    id: 'event-sleeves-update',
    at: DateTime(2026, 10, 15, 9, 5),
    postId: 'post-sleeves',
    title: sleeves,
    actorId: omar,
    actorName: omarName,
    note: t('Sleeves arrived. Fixing them now.', 'وصلت الجلب. أركّبها الآن.'),
  );

  /// X3 2530:34263: an item Islam cancelled at 12:05.
  DaybookPost doorHardware() => DaybookPost(
    id: 'post-door',
    kind: DaybookPost.workItemKind,
    createdAt: DateTime(2026, 10, 15, 12, 5),
    title: t('Door hardware for core B?', 'أقفال أبواب النواة B؟'),
    cancelled: true,
    authorId: islam,
    authorName: islamName,
    item: DaybookItem(
      status: WorkStatus.open,
      ownerId: omar,
      ownerName: omarName,
    ),
    stamp: DaybookStamp(
      kind: DaybookStampKind.cancelled,
      at: DateTime(2026, 10, 15, 12, 5),
      byName: islamName,
    ),
  );
}
