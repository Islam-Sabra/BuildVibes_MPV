import 'package:buildvibes/data/models/chat.dart';
import 'package:buildvibes/data/models/work_item.dart';
import 'package:buildvibes/data/models/week_report.dart';

import 'chat_fakes.dart';
import 'daybook_samples.dart';

/// Slice 9 as R3 (2540:34503) and MR1 (2566:35515) draw it, on Thursday
/// 15 October 2026, in the Kuwait City Tower Space.
class MeetingReportSamples {
  MeetingReportSamples(this.lang);

  final String lang;

  String t(String en, String ar) => lang == 'ar' ? ar : en;

  static const everyone = 'thread-everyone';
  static const mep = 'thread-mep';
  static const meeting = 'msg-meeting';
  static const oneLine = 'msg-one-line';

  /// Thursday 15 October, 11:00; the week is 11–17 October.
  static final now = DateTime(2026, 10, 15, 11);
  static final week = DateTime(2026, 10, 11);

  String get meetingTitle =>
      t('Coordination meeting, 10:00', 'اجتماع التنسيق، 10:00');
  List<String> get meetingLines => [
    t(
      'Raise the duct at grid D4 by 150 mm',
      'ارفع مجرى الهواء عند المحور D4 بمقدار 150 مم',
    ),
    t('Send the revised door schedule', 'أرسل جدول الأبواب المعدّل'),
    t('Order 40 more sleeves, 100 mm', 'اطلب 40 جلبة إضافية، 100 مم'),
    t('Next meeting Sunday 10:00', 'الاجتماع القادم الأحد 10:00'),
  ];

  /// Islam's meeting notes in Everyone, and a one-line message under it.
  FakeChatRepository chat() => FakeChatRepository(now: now)
    ..threadsBySpace[DaybookSamples.space] = [
      const ChatThread(id: everyone),
      ChatThread(id: mep, teamId: 't-mep', teamName: t('MEP', 'الكهروميكانيك')),
    ]
    ..messagesByThread[everyone] = [
      ChatMessage(
        id: oneLine,
        threadId: everyone,
        kind: ChatKind.text,
        createdAt: DateTime(2026, 10, 15, 10, 42),
        authorId: DaybookSamples.omar,
        authorName: DaybookSamples(lang).omarName,
        body: t('Pump booked for 2 pm.', 'المضخة محجوزة الساعة 2 ظهرًا.'),
      ),
      ChatMessage(
        id: meeting,
        threadId: everyone,
        kind: ChatKind.text,
        createdAt: DateTime(2026, 10, 15, 10, 40),
        authorId: DaybookSamples.islam,
        authorName: DaybookSamples(lang).islamName,
        body: [meetingTitle, ...meetingLines].join('\n'),
      ),
    ]
    ..messagesByThread[mep] = [];

  /// MR1's week.
  WeekReport report() => WeekReport(
    needsDecision: [
      DecisionRow(
        postId: 'post-rebar',
        title: t(
          'Rebar spacing, level 3 slab',
          'تباعد حديد التسليح، بلاطة الطابق 3',
        ),
        state: DecisionState.late,
        ownerName: DaybookSamples(lang).omarName,
        dueDate: DateTime(2026, 10, 13),
        needsMe: true,
      ),
      DecisionRow(
        postId: 'post-trays',
        title: t(
          'Cable tray hangers, level 4',
          'حمّالات حوامل الكابلات، الطابق 4',
        ),
        state: DecisionState.sentBack,
        ownerName: DaybookSamples(lang).rakeshName,
        reason: SendBackReason.photoMissing,
      ),
      DecisionRow(
        postId: 'post-d4',
        title: t('Sleeves at grid D4', 'الجلب عند المحور D4'),
        state: DecisionState.done,
        ownerName: DaybookSamples(lang).omarName,
        doneAt: DateTime(2026, 10, 15, 14, 10),
      ),
    ],
    checked: [
      CheckedRow(
        postId: 'post-sleeves',
        title: t(
          'Sleeves at grid C7 before the pour',
          'الجلب عند المحور C7 قبل الصب',
        ),
        checkedAt: DateTime(2026, 10, 15, 10, 12),
        photoPath: '${DaybookSamples.space}/post-sleeves/proof.jpg',
        checkerName: DaybookSamples(lang).islamName,
      ),
      CheckedRow(
        postId: 'post-rebar2',
        title: t(
          'Rebar spacing, level 2 slab',
          'تباعد حديد التسليح، بلاطة الطابق 2',
        ),
        checkedAt: DateTime(2026, 10, 14, 15),
        photoPath: '${DaybookSamples.space}/post-rebar2/proof.jpg',
        checkerName: DaybookSamples(lang).saraName,
      ),
      CheckedRow(
        postId: 'post-trays3',
        title: t(
          'Cable tray hangers, level 3',
          'حمّالات حوامل الكابلات، الطابق 3',
        ),
        checkedAt: DateTime(2026, 10, 12, 9),
        photoPath: '${DaybookSamples.space}/post-trays3/proof.jpg',
        checkerName: DaybookSamples(lang).islamName,
      ),
    ],
    targets: [
      TargetRow(
        postId: 'post-ceiling',
        title: t(
          'Level 3 ready to close the ceiling',
          'الطابق 3 جاهز لإغلاق السقف',
        ),
        checked: 2,
        total: 4,
        dueDate: DateTime(2026, 10, 18),
      ),
    ],
    comingUp: [
      ComingRow(
        postId: 'post-site-walk',
        title: t('Site walk with the consultant', 'جولة موقع مع الاستشاري'),
        activity: true,
        startsAt: DateTime(2026, 10, 16, 9),
        place: t('Gate office', 'مكتب البوابة'),
      ),
      ComingRow(
        postId: 'post-delivery',
        title: t('Delivery: 40 sleeves, 100 mm', 'توريد: 40 جلبة، 100 مم'),
        activity: false,
        dueDate: DateTime(2026, 10, 17),
        dueAt: DateTime(2026, 10, 17, 12),
        ownerName: DaybookSamples(lang).saraName,
      ),
    ],
  );
}
