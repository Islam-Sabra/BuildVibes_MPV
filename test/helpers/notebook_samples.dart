import 'package:buildvibes/data/models/note.dart';

import 'daybook_samples.dart';

/// My notebook and My calendar as NB1 (2557:35384, AR 2564:549) and CAL1
/// (2557:35587, AR 2564:653) draw them, on Thursday 15 October 2026.
class NotebookSamples {
  NotebookSamples(this.lang);

  final String lang;

  String t(String en, String ar) => lang == 'ar' ? ar : en;

  /// "Now" on the notebook: Thursday 15 October, 12:00.
  static final now = DateTime(2026, 10, 15, 12);

  static const khiran = 'space-khiran';

  String get pumpWords => t(
    'Pump booking: Al Bahar Ready Mix, 2 pm slot. Call Yousef at 1:30 to '
        'confirm.',
    'حجز المضخة: البحر للخرسانة الجاهزة، موعد 2 ظهراً. اتصل بيوسف 1:30 '
        'للتأكيد.',
  );
  String get sleevesTodo =>
      t('Order 40 more sleeves, 100 mm', 'اطلب 40 جلبة إضافية، 100 مم');
  String get walkTitle => t('Before the site walk', 'قبل جولة الموقع');
  List<String> get walkPoints => [
    t('Print A-501 Rev D', 'اطبع A-501 Rev D'),
    t('Charge the laser meter', 'اشحن جهاز القياس بالليزر'),
    t(
      'Bring the snag list from last week',
      'أحضر قائمة الملاحظات من الأسبوع الماضي',
    ),
  ];

  Note pinned() => Note(
    id: 'note-pump',
    kind: NoteKind.text,
    body: pumpWords,
    pinned: true,
    createdAt: DateTime(2026, 10, 15, 7, 40),
  );

  Note todo() => Note(
    id: 'note-sleeves',
    kind: NoteKind.todo,
    body: sleevesTodo,
    dueAt: DateTime(2026, 10, 15, 16),
    createdAt: DateTime(2026, 10, 15, 8, 2),
  );

  Note checklist() => Note(
    id: 'note-walk',
    kind: NoteKind.checklist,
    body: walkTitle,
    points: [
      NotePoint(walkPoints[0], done: true),
      NotePoint(walkPoints[1], done: true),
      NotePoint(walkPoints[2]),
    ],
    createdAt: DateTime(2026, 10, 15, 9, 15),
  );

  Note voice() => Note(
    id: 'note-voice',
    kind: NoteKind.voice,
    createdAt: DateTime(2026, 10, 15, 11, 40),
    recording: const NoteRecording(
      path: 'user-1/note-voice/voice.m4a',
      durationMs: 24000,
    ),
  );

  /// A note from yesterday, under its day's divider.
  Note yesterday() => Note(
    id: 'note-yesterday',
    kind: NoteKind.text,
    body: t(
      'Ask Lina for the door schedule before Sunday.',
      'اطلب من لينا جدول الأبواب قبل الأحد.',
    ),
    createdAt: DateTime(2026, 10, 14, 16, 20),
  );

  List<Note> notes() => [pinned(), todo(), checklist(), voice(), yesterday()];

  String get kct => t('Kuwait City Tower', 'برج مدينة الكويت');

  /// CAL1's rows: Thursday 15 and Friday 16.
  List<CalendarRow> rows() => [
    CalendarRow(
      kind: CalendarKind.checklist,
      title: t(
        'Sleeves at grid C7 before the pour',
        'جلب الأنابيب عند المحور C7 قبل الصب',
      ),
      day: DateTime(2026, 10, 15),
      spaceId: DaybookSamples.space,
      spaceName: kct,
      postId: 'post-sleeves-check',
      needsMe: true,
    ),
    CalendarRow(
      kind: CalendarKind.workItem,
      title: t(
        'Rebar spacing, level 3 slab',
        'تباعد حديد التسليح، بلاطة الطابق 3',
      ),
      day: DateTime(2026, 10, 15),
      startsAt: DateTime(2026, 10, 15, 14),
      spaceId: DaybookSamples.space,
      spaceName: kct,
      postId: 'post-rebar',
      status: 'open',
      needsMe: true,
    ),
    CalendarRow(
      kind: CalendarKind.todo,
      title: sleevesTodo,
      day: DateTime(2026, 10, 15),
      startsAt: DateTime(2026, 10, 15, 16),
      noteId: 'note-sleeves',
      status: 'open',
    ),
    CalendarRow(
      kind: CalendarKind.activity,
      title: t('Site walk with the consultant', 'جولة موقع مع الاستشاري'),
      day: DateTime(2026, 10, 16),
      startsAt: DateTime(2026, 10, 16, 7),
      spaceId: DaybookSamples.space,
      spaceName: kct,
      place: t('Gate office', 'مكتب البوابة'),
      postId: 'post-site-walk',
    ),
    CalendarRow(
      kind: CalendarKind.activity,
      title: t('Snag review, villa 12', 'مراجعة الملاحظات، فيلا 12'),
      day: DateTime(2026, 10, 16),
      startsAt: DateTime(2026, 10, 16, 10),
      spaceId: khiran,
      spaceName: t('Khiran villas', 'فلل الخيران'),
      postId: 'post-snag',
    ),
    // Earlier in the week: a dot on Monday and Wednesday.
    CalendarRow(
      kind: CalendarKind.workItem,
      title: t('Fire stopping, level 2', 'سد الفتحات ضد الحريق، الطابق 2'),
      day: DateTime(2026, 10, 12),
      spaceId: DaybookSamples.space,
      spaceName: kct,
      postId: 'post-fire',
      status: 'done',
    ),
    CalendarRow(
      kind: CalendarKind.todo,
      title: t('Call the lift supplier', 'اتصل بمورد المصاعد'),
      day: DateTime(2026, 10, 14),
      startsAt: DateTime(2026, 10, 14, 9),
      noteId: 'note-lift',
      status: 'done',
    ),
  ];
}
