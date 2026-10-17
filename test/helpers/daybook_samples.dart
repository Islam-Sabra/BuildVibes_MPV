import 'package:buildvibes/data/models/daybook.dart';
import 'package:buildvibes/data/models/space.dart';
import 'package:buildvibes/data/models/work_item.dart';

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

  String get islamName => t('Islam Ahmed', 'إسلام أحمد');
  String get saraName => t('Sara Al-Mutairi', 'سارة المطيري');
  String get omarName => t('Omar Haddad', 'عمر حداد');

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

  /// D1 08:14: Omar signed it; it waits for my check.
  DaybookPost sleevesDone({bool needsMe = true}) => item(
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

  List<DaybookPost> d1({bool viewer = false}) => [
    gate(),
    sleevesDone(needsMe: !viewer),
    rebar(needsMe: !viewer),
  ];

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
}
