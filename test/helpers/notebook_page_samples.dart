import 'package:buildvibes/data/models/note.dart';
import 'package:buildvibes/data/models/notebook_page.dart';
import 'package:buildvibes/data/models/post_page.dart';

import 'notebook_fakes.dart';

/// My notebook's pages as PG1–PG5b draw them (review 99A, EN 2635:37785…,
/// AR 2635:38736…), on Thursday 15 October 2026 at 12:00.
class NotebookPageSamples {
  NotebookPageSamples(this.lang);

  final String lang;

  String t(String en, String ar) => lang == 'ar' ? ar : en;

  static final now = DateTime(2026, 10, 15, 12);

  static const siteA = 'page-site-a';
  static const phones = 'page-phones';
  static const siteB = 'page-site-b';
  static const pump = 'page-pump';
  static const meetings = 'page-meetings';
  static const myNotes = FakeNotebookRepository.myNotesId;
  static const level3 = 'page-level-3';
  static const pourDay = 'page-pour-day';

  String get siteATitle => t('Site A – Tower', 'الموقع أ – البرج');
  String get phonesTitle => t('Phone numbers', 'أرقام الهواتف');
  String get siteBTitle => t('Site B – Villa', 'الموقع ب – الفيلا');
  String get pumpTitle => t('Pump booked 2 pm', 'حجز المضخة 2 ظهرًا');
  String get meetingsTitle =>
      t('Meetings with consultant', 'اجتماعات الاستشاري');
  String get beforePour => t('Before the pour, level 3', 'قبل الصب، الطابق 3');

  NotebookPage _page(
    String id,
    String title,
    PageIcon icon,
    DateTime at, {
    String? parent,
    bool pinned = false,
    bool isNew = false,
  }) => NotebookPage(
    id: id,
    parentId: parent,
    title: title,
    icon: icon,
    pinned: pinned,
    isNew: isNew,
    createdAt: DateTime(2026, 10, 1),
    lastActivityAt: at,
  );

  List<NotebookPage> pages() => [
    _page(
      siteA,
      siteATitle,
      PageIcon.hardHat,
      DateTime(2026, 10, 15, 10, 40),
      pinned: true,
    ),
    _page(
      phones,
      phonesTitle,
      PageIcon.phone,
      DateTime(2026, 10, 12, 9),
      pinned: true,
    ),
    _page(siteB, siteBTitle, PageIcon.building, DateTime(2026, 10, 14, 15)),
    _page(
      pump,
      pumpTitle,
      PageIcon.notebook,
      DateTime(2026, 10, 15, 9, 5),
      isNew: true,
    ),
    _page(meetings, meetingsTitle, PageIcon.folder, DateTime(2026, 10, 8, 11)),
    NotebookPage(
      id: myNotes,
      myNotes: true,
      createdAt: DateTime(2026, 10, 1),
      lastActivityAt: DateTime(2026, 10, 6, 8),
    ),
    _page(
      level3,
      t('Level 3', 'الطابق 3'),
      PageIcon.folder,
      DateTime(2026, 10, 15, 8),
      parent: siteA,
    ),
    _page(
      pourDay,
      t('Pour day', 'يوم الصب'),
      PageIcon.folder,
      DateTime(2026, 10, 15, 7),
      parent: siteA,
    ),
  ];

  Note _entry(
    String id,
    String page,
    DateTime at,
    String title,
    List<PageBlock> blocks,
  ) => Note(
    id: id,
    kind: NoteKind.text,
    title: title,
    blocks: blocks,
    body: pageDigest(title, blocks),
    createdAt: at,
    pageId: page,
  );

  List<Note> notes() => [
    _entry('entry-pour', siteA, DateTime(2026, 10, 15, 10, 40), beforePour, [
      PageNumbered('b-1', t('Clean the formwork', 'تنظيف القوالب')),
      PageNumbered('b-2', t('Check the rebar cover', 'فحص غطاء الحديد')),
    ]),
    _entry('entry-gate', siteA, DateTime(2026, 10, 15, 9, 5), pumpTitle, [
      PageText(
        'b-3',
        t(
          'Gate 2, driver calls 30 min before',
          'البوابة 2، السائق يتصل قبل 30 دقيقة',
        ),
      ),
    ]),
    _entry(
      'entry-lobby',
      siteA,
      DateTime(2026, 10, 14, 16, 20),
      t('Snags, lobby', 'ملاحظات، الردهة'),
      [
        PageText(
          'b-4',
          t('Cracked tile at the stair', 'بلاطة مشروخة عند الدرج'),
        ),
      ],
    ),
    _entry(
      'entry-cubes',
      siteA,
      DateTime(2026, 10, 13, 14),
      t('Cube tests', 'اختبارات المكعبات'),
      [PageTodo('b-12', t('Collect the 7-day results', 'استلام نتائج 7 أيام'))],
    ),
    _entry(
      'entry-spacers',
      level3,
      DateTime(2026, 10, 15, 8),
      t('Spacers at the beams', 'فواصل عند الجسور'),
      [
        PageTodo('b-5', t('Grid C, beam 4', 'المحور C، الجسر 4')),
        PageTodo('b-6', t('Grid D, beam 2', 'المحور D، الجسر 2')),
      ],
    ),
    _entry(
      'entry-gate-2',
      pourDay,
      DateTime(2026, 10, 15, 7),
      t('Pump at gate 2', 'المضخة عند البوابة 2'),
      [PageText('b-7', t('Tell the guard', 'إبلاغ الحارس'))],
    ),
    _entry(
      'entry-ali',
      phones,
      DateTime(2026, 10, 12, 9),
      t('Pump supplier, Ali', 'مورّد المضخة، علي'),
      [PageText('b-8', '+965 5000 0000')],
    ),
    _entry(
      'entry-snags',
      siteB,
      DateTime(2026, 10, 14, 15),
      t('Snags, ground floor', 'ملاحظات، الطابق الأرضي'),
      [PageTodo('b-9', t('Door 3 hinge', 'مفصّلة الباب 3'))],
    ),
    _entry('entry-pump-new', pump, DateTime(2026, 10, 15, 9, 5), pumpTitle, [
      PageText('b-10', t('Gate 2', 'البوابة 2')),
    ]),
    _entry(
      'entry-facade',
      meetings,
      DateTime(2026, 10, 8, 11),
      t('Façade samples', 'عينات الواجهة'),
      [PageText('b-11', t('Bring two colours', 'إحضار لونين'))],
    ),
    _entry(
      'entry-earlier',
      myNotes,
      DateTime(2026, 10, 6, 8),
      t('Earlier entries', 'تدوينات سابقة'),
      [],
    ),
  ];

  FakeNotebookRepository repository() =>
      FakeNotebookRepository(notes: notes(), pages: pages());
}
