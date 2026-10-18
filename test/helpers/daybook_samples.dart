import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/repositories/daybook_repository.dart';

/// The prototype's daybook as cards (v13: EN 2581:35611, 2582:35982,
/// 2582:36114; AR 2583:373), in English or with the AR frames' words,
/// never a fresh translation. Posts are shown as written, so the Arabic
/// shots use the Arabic frames' posts.
///
/// The sleeves item has a timeline: raised on Wednesday, an update that
/// afternoon, then on Thursday an update, a sign-off, a send-back and a
/// second sign-off. [sleevesCard] gives its card as it stood at a time.
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

  String nameOf(String id) => switch (id) {
    islam => islamName,
    sara => saraName,
    omar => omarName,
    rakesh => rakeshName,
    lina => linaName,
    _ => monaName,
  };

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

  /// A work item as space_post_json gives it.
  DaybookPost item({
    required String id,
    required DateTime at,
    required String title,
    required String authorId,
    required String ownerId,
    String? ref,
    DateTime? due,
    DateTime? dueAt,
    String? place,
    int points = 0,
    WorkStatus status = WorkStatus.open,
    bool cancelled = false,
    String? cover,
    List<DaybookAttachment> attachments = const [],
  }) => DaybookPost(
    id: id,
    kind: DaybookPost.workItemKind,
    createdAt: at,
    title: title,
    cancelled: cancelled,
    authorId: authorId,
    authorName: nameOf(authorId),
    place: place,
    dueDate: due,
    dueAt: dueAt,
    item: DaybookItem(
      status: status,
      ownerId: ownerId,
      ownerName: nameOf(ownerId),
      ref: ref,
    ),
    pointsTotal: points,
    coverPath: cover,
    attachments: attachments,
  );

  /// A history line.
  DaybookEvent event(
    String id,
    DaybookEventKind kind,
    DateTime at,
    String byId, {
    String? note,
    SendBackReason? reason,
    List<WorkPhoto> photos = const [],
    String? toId,
    String? fromId,
    DaybookDueEdit? dueEdit,
  }) => DaybookEvent(
    id: id,
    kind: kind,
    at: at,
    byId: byId,
    byName: nameOf(byId),
    note: note,
    reason: reason,
    photos: photos,
    toName: toId == null ? null : nameOf(toId),
    fromName: fromId == null ? null : nameOf(fromId),
    dueEdit: dueEdit,
  );

  /// [post]'s card: raised by its author when it was made, then
  /// [events]; its proof is the latest sign-off and what came after it.
  /// The history is newest first, as the server sends it.
  DaybookCard card(
    DaybookPost post, {
    List<DaybookEvent> events = const [],
    DaybookNeed? need,
    bool historyMore = false,
  }) {
    final history =
        [
          event(
            '${post.id}-raised',
            DaybookEventKind.raised,
            post.createdAt,
            post.authorId!,
          ),
          ...events,
        ]..sort((a, b) {
          final t = b.at.compareTo(a.at);
          return t != 0 ? t : b.id.compareTo(a.id);
        });
    final done = history
        .where((e) => e.kind == DaybookEventKind.done)
        .firstOrNull;
    DaybookProof? proof;
    if (done != null) {
      final after = history
          .where(
            (e) =>
                e.at.isAfter(done.at) &&
                (e.kind == DaybookEventKind.checked ||
                    e.kind == DaybookEventKind.sentBack),
          )
          .lastOrNull;
      proof = DaybookProof(
        eventId: done.id,
        at: done.at,
        byId: done.byId,
        byName: done.byName,
        note: done.note,
        photos: done.photos,
        outcome: post.cancelled && after == null
            ? const DaybookOutcome(kind: DaybookOutcomeKind.cancelled)
            : after == null
            ? DaybookOutcome(
                kind: DaybookOutcomeKind.done,
                at: done.at,
                byId: done.byId,
                byName: done.byName,
              )
            : DaybookOutcome(
                kind: after.kind == DaybookEventKind.checked
                    ? DaybookOutcomeKind.checked
                    : DaybookOutcomeKind.sentBack,
                at: after.at,
                byId: after.byId,
                byName: after.byName,
                reason: after.reason,
                note: after.note,
              ),
      );
    }
    return DaybookCard(
      post: post,
      lastActivityAt: history.first.at,
      proof: proof,
      history: history,
      historyMore: historyMore,
      need: need,
    );
  }

  /// The sleeves' title (also on Needs you and Activity rows).
  String get sleeves => t(
    'Sleeves at grid C7 before the pour',
    'تركيب الجلب عند المحور C7 قبل الصبّ',
  );
  String get levelTwo => t('Level 2, grid C7', 'الدور 2، المحور C7');

  String get sleevesUpdate =>
      t('Sleeves arrived. Fixing them now.', 'وصلت الجلب. أركّبها الآن.');
  String get sleevesWedUpdate => t(
    'Sleeves are on order, on site tomorrow morning.',
    'الجلب قيد الطلب، تصل الموقع صباح الغد.',
  );
  String get sleevesFirstNote => t('All six fixed.', 'رُكّبت الست كلها.');
  String get sleevesNote => t(
    'All six fixed and checked with MEP.',
    'رُكّبت الست كلها وراجعتها مع فريق الكهروميكانيك.',
  );
  String get sentBackNote => t(
    'One sleeve is 50 mm short. Check M-201.',
    'حسب المخطط M-201، جلبة واحدة أقصر بـ 50 مم.',
  );

  static const proofPhoto = WorkPhoto(path: '$space/post-sleeves/proof.jpg');

  // The sleeves' timeline.
  static final sleevesRaisedAt = DateTime(2026, 10, 14, 15, 50);
  static final sleevesWedUpdateAt = DateTime(2026, 10, 14, 16, 7);
  static final sleevesUpdateAt = DateTime(2026, 10, 15, 9, 5);
  static final sleevesFirstDoneAt = DateTime(2026, 10, 15, 9, 40);
  static final sleevesSentBackAt = DateTime(2026, 10, 15, 10, 12);
  static final sleevesDoneAt = DateTime(2026, 10, 15, 10, 56);

  /// The sleeves card as it stood at [upTo] (by default after the second
  /// sign-off), as [me] sees it: Islam wrote it and checks it, Omar owns
  /// it and signs it; a [viewer] gets no clip. [photos] are the sign-offs'.
  DaybookCard sleevesCard({
    DateTime? upTo,
    String me = islam,
    bool viewer = false,
    List<WorkPhoto> photos = const [proofPhoto],
  }) {
    final until = upTo ?? sleevesDoneAt;
    final all = [
      event(
        'ev-sleeves-c1',
        DaybookEventKind.comment,
        sleevesWedUpdateAt,
        omar,
        note: sleevesWedUpdate,
      ),
      event(
        'ev-sleeves-c2',
        DaybookEventKind.comment,
        sleevesUpdateAt,
        omar,
        note: sleevesUpdate,
      ),
      event(
        'ev-sleeves-done1',
        DaybookEventKind.done,
        sleevesFirstDoneAt,
        omar,
        note: sleevesFirstNote,
        photos: photos,
      ),
      event(
        'ev-sleeves-back',
        DaybookEventKind.sentBack,
        sleevesSentBackAt,
        islam,
        reason: SendBackReason.photoMissing,
      ),
      event(
        'ev-sleeves-done2',
        DaybookEventKind.done,
        sleevesDoneAt,
        omar,
        note: sleevesNote,
        photos: photos,
      ),
    ];
    final events = [
      for (final e in all)
        if (!e.at.isAfter(until)) e,
    ];
    final last = events
        .where(
          (e) =>
              e.kind == DaybookEventKind.done ||
              e.kind == DaybookEventKind.sentBack,
        )
        .lastOrNull;
    final done = last?.kind == DaybookEventKind.done;
    return card(
      item(
        id: 'post-sleeves',
        at: sleevesRaisedAt,
        title: sleeves,
        ref: 'KCT-014',
        authorId: islam,
        ownerId: omar,
        due: DateTime(2026, 10, 15),
        dueAt: DateTime(2026, 10, 15, 14),
        place: levelTwo,
        status: done ? WorkStatus.done : WorkStatus.open,
      ),
      events: events,
      need: viewer
          ? null
          : done && me == islam
          ? DaybookNeed.toCheck
          : !done && me == omar
          ? DaybookNeed.toSign
          : null,
    );
  }

  String get rebarTitle =>
      t('Rebar spacing, level 3 slab', 'تباعد حديد التسليح، بلاطة الدور 3');

  /// 10:05: Sara's item for Islam, due today at 2 pm, moved from Thu.
  DaybookCard rebar({bool needsMe = true}) {
    final at = DateTime(2026, 10, 15, 10, 5);
    return card(
      item(
        id: 'post-rebar',
        at: at,
        title: rebarTitle,
        ref: 'KCT-016',
        authorId: sara,
        ownerId: islam,
        due: DateTime(2026, 10, 15),
        dueAt: DateTime(2026, 10, 15, 14),
        place: t('Level 3 slab', 'بلاطة الدور 3'),
      ),
      events: [
        event(
          'ev-rebar-edit',
          DaybookEventKind.edited,
          at,
          sara,
          dueEdit: DaybookDueEdit(
            from: DateTime(2026, 10, 22),
            to: DateTime(2026, 10, 15),
          ),
        ),
      ],
      need: needsMe ? DaybookNeed.toSign : null,
    );
  }

  /// DY1: Wednesday's checked item.
  DaybookCard gate() => card(
    item(
      id: 'post-gate',
      at: DateTime(2026, 10, 14, 16, 20),
      title: t(
        'Gate 3 access cleared for the pump truck',
        'تجهيز مدخل البوابة 3 لشاحنة المضخة',
      ),
      ref: 'KCT-012',
      authorId: islam,
      ownerId: omar,
      due: DateTime(2026, 10, 14),
      place: t('Gate 3', 'البوابة 3'),
      points: 2,
      status: WorkStatus.checked,
    ),
    events: [
      event(
        'ev-gate-done',
        DaybookEventKind.done,
        DateTime(2026, 10, 14, 17, 5),
        omar,
        note: t('Gate clear, cones out.', 'البوابة جاهزة والأقماع في مكانها.'),
        photos: const [WorkPhoto(path: '$space/post-gate/proof.jpg')],
      ),
      event(
        'ev-gate-checked',
        DaybookEventKind.checked,
        DateTime(2026, 10, 14, 17, 30),
        islam,
      ),
    ],
  );

  /// Islam's Thursday (v13 2581:35611): the sleeves to check, the rebar to
  /// sign; Wednesday's update left a trace.
  List<DaybookCard> v13() => [sleevesCard(), rebar()];

  /// The daybook with Wednesday's checked gate too (DY1).
  List<DaybookCard> d1({bool viewer = false}) => [
    gate(),
    sleevesCard(viewer: viewer),
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
  DaybookCard posted(NewWorkItem i, DateTime at) => card(
    item(
      id: i.id,
      at: at,
      title: i.title,
      authorId: islam,
      ownerId: i.ownerId,
      due: i.dueDate,
      dueAt: i.dueAt,
      place: i.place,
      cover: i.photoPaths.firstOrNull,
    ),
  );

  /// L1, Omar's Friday: the sleeves went late, the cable trays are due.
  static final friday = DateTime(2026, 10, 16, 11, 40);

  List<DaybookCard> l1() => [
    card(
      item(
        id: 'post-sleeves',
        at: DateTime(2026, 10, 16, 8, 14),
        title: sleeves,
        ref: 'KCT-014',
        authorId: islam,
        ownerId: omar,
        due: DateTime(2026, 10, 15),
        place: levelTwo,
        points: 2,
      ),
      need: DaybookNeed.toSign,
    ),
    cableTrays(),
  ];

  String get cableTraysTitle =>
      t('Cable tray hangers, level 4', 'علّاقات حوامل الكابلات، الدور 4');

  DaybookCard cableTrays() => card(
    item(
      id: 'post-trays',
      at: DateTime(2026, 10, 16, 11, 20),
      title: cableTraysTitle,
      ref: 'KCT-020',
      authorId: islam,
      ownerId: omar,
      due: DateTime(2026, 10, 16),
      cover: '$space/posts/post-trays/photo.jpg',
    ),
    need: DaybookNeed.toSign,
  );

  CalendarWorkItem cableTraysDue() => CalendarWorkItem(
    spaceId: space,
    title: cableTraysTitle,
    day: DateTime(2026, 10, 16),
    status: WorkStatus.open,
  );

  /// O1: Omar's Thursday morning. The sleeves are his to sign, the cable
  /// trays too.
  List<DaybookCard> o1() => [
    sleevesCard(me: omar, upTo: DateTime(2026, 10, 15, 9, 6)),
    traysForOmar(),
  ];

  /// The cable trays, Islam's, for Omar by Sunday (11:20, X1); given to
  /// Rakesh at [givenAt].
  DaybookCard traysForOmar({bool needsMe = true, DateTime? givenAt}) => card(
    item(
      id: 'post-trays',
      at: DateTime(2026, 10, 15, 11, 20),
      title: cableTraysTitle,
      ref: 'KCT-020',
      authorId: islam,
      ownerId: givenAt == null ? omar : rakesh,
      due: DateTime(2026, 10, 18),
      cover: '$space/posts/post-trays/photo.jpg',
    ),
    events: [
      if (givenAt != null)
        event(
          'ev-trays-given',
          DaybookEventKind.reassigned,
          givenAt,
          islam,
          fromId: omar,
          toId: rakesh,
        ),
    ],
    need: needsMe ? DaybookNeed.toSign : null,
  );

  /// X3: an item Islam cancelled at 12:05.
  DaybookCard doorHardware() => card(
    item(
      id: 'post-door',
      at: DateTime(2026, 10, 15, 11, 50),
      title: t('Door hardware for core B?', 'أقفال أبواب النواة B؟'),
      ref: 'KCT-021',
      authorId: islam,
      ownerId: omar,
      cancelled: true,
    ),
    events: [
      event(
        'post-door',
        DaybookEventKind.cancelled,
        DateTime(2026, 10, 15, 12, 5),
        islam,
      ),
    ],
  );
}
