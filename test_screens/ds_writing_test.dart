// The Daybook's writing and action parts (slice 1a) for review, in English
// and Arabic. Sample text only; the app's words come from the ARB files.
// The parts don't fit one 390 × 844 sheet each without covering one
// another, so the menus and the pickers have sheets of their own.
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_give_to_picker.dart';
import 'package:buildvibes/shared/widgets/bv_popover_menu.dart';
import 'package:buildvibes/shared/widgets/bv_send_back_card.dart';
import 'package:buildvibes/shared/widgets/bv_undo_bar.dart';
import 'package:buildvibes/shared/widgets/bv_writing_card.dart';
import 'package:buildvibes/shared/widgets/bv_writing_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot.dart';

/// Sample words per language.
Map<String, String> _words(String lang) => lang == 'ar'
    ? const {
        'title': 'العنوان',
        'body': 'اكتب ما يجب عمله',
        'draft': 'مسودة',
        'workItem': 'بند عمل',
        'filledTitle': 'علّاقات حامل الكابلات، الطابق 4',
        'filledBody': 'ثبّت العلّاقات كل 1.5 م قبل إغلاق السقف.',
        'omar': 'عمر حداد',
        'due': 'الأحد 18 أكتوبر',
        'place': 'ممر الطابق 4',
        'assign': 'تكليف',
        'location': 'المكان',
        'dueDate': 'تاريخ الاستحقاق',
        'checklist': 'قائمة تحقق',
        'template': 'قالب',
        'announcement': 'إعلان',
        'scheduled': 'نشاط مجدول',
        'file': 'ملف',
        'check': 'افحص',
        'sendBack': 'إرجاع',
        'addUpdate': 'أضف تحديثًا',
        'discuss': 'ناقش في المحادثة',
        'edit': 'تعديل',
        'giveTo': 'أعطه لشخص آخر',
        'cancel': 'ألغِ بند العمل',
        'sendBackTo': 'إرجاع إلى عمر',
        'photoMissing': 'الصورة ناقصة',
        'notAsAsked': 'ليس كما طُلب',
        'notFinished': 'غير مكتمل',
        'somethingElse': 'سبب آخر',
        'note': 'كُمّ واحد أقصر بـ 50 مم. راجع M-201.',
        'notePlaceholder': 'أضف ملاحظة (اختياري)',
        'giveToSearch': 'أعطِ إلى…',
        'now': 'الآن',
        'rakesh': 'راكيش ناير',
        'lina': 'لينا سعد',
        'mona': 'منى فارس',
        'mep': 'MEP',
        'site': 'الموقع',
        'architecture': 'معماري',
        'checked': 'تم الفحص',
        'undo': 'تراجع',
      }
    : const {
        'title': 'Title',
        'body': 'Write what needs doing',
        'draft': 'Draft',
        'workItem': 'Work item',
        'filledTitle': 'Cable tray hangers, level 4',
        'filledBody': 'Fix the hangers every 1.5 m before the ceiling closes.',
        'omar': 'Omar Haddad',
        'due': 'Sun 18 Oct',
        'place': 'Level 4 corridor',
        'assign': 'Assign',
        'location': 'Location',
        'dueDate': 'Due date',
        'checklist': 'Checklist',
        'template': 'Template',
        'announcement': 'Announcement',
        'scheduled': 'Scheduled activity',
        'file': 'File',
        'check': 'Check',
        'sendBack': 'Send back',
        'addUpdate': 'Add update',
        'discuss': 'Discuss in chat',
        'edit': 'Edit',
        'giveTo': 'Give to someone else',
        'cancel': 'Cancel work item',
        'sendBackTo': 'Send back to Omar',
        'photoMissing': 'Photo missing',
        'notAsAsked': 'Not as asked',
        'notFinished': 'Not finished',
        'somethingElse': 'Something else',
        'note': 'One sleeve is 50 mm short. Check M-201.',
        'notePlaceholder': 'Add a note (optional)',
        'giveToSearch': 'Give to…',
        'now': 'now',
        'rakesh': 'Rakesh Nair',
        'lina': 'Lina Saad',
        'mona': 'Mona Faris',
        'mep': 'MEP',
        'site': 'Site',
        'architecture': 'Architecture',
        'checked': 'Checked',
        'undo': 'Undo',
      };

/// The sheet: the app's paper colour, parts in a column at the end side
/// (where slips hang, after the time column).
Widget _sheet(List<Widget> children) => Material(
  color: BvColors.surfaceApp,
  child: Padding(
    padding: const EdgeInsetsDirectional.all(BvSpace.gutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: BvSpace.s12,
      children: children,
    ),
  ),
);

const _slipWidth = 310.0;

Widget _toolbar({required bool ready, bool moreActive = false}) =>
    BvWritingToolbar(
      cameraLabel: 'Camera',
      onCamera: () {},
      attachLabel: 'Attach',
      onAttach: () {},
      moreLabel: 'More',
      onMore: () {},
      moreActive: moreActive,
      postLabel: 'Post',
      onPost: ready ? () {} : null,
    );

void main() {
  setUpAll(loadAppFonts);

  TextEditingController controller(String text) {
    final c = TextEditingController(text: text);
    addTearDown(c.dispose);
    return c;
  }

  for (final lang in ['en', 'ar']) {
    final w = _words(lang);

    testWidgets('ds-writing $lang', (tester) async {
      await shoot(
        tester,
        'ds-writing',
        lang,
        (context) => _sheet([
          SizedBox(
            width: _slipWidth,
            child: BvWritingCard(
              titleController: controller(''),
              titlePlaceholder: w['title']!,
              bodyController: controller(''),
              bodyPlaceholder: w['body']!,
            ),
          ),
          SizedBox(
            width: _slipWidth,
            child: BvWritingCard(
              tear: 1,
              titleController: controller(w['filledTitle']!),
              titlePlaceholder: w['title']!,
              bodyController: controller(w['filledBody']!),
              bodyPlaceholder: w['body']!,
              draftLabel: w['draft'],
              kindLabel: w['workItem'],
              onKindTap: () {},
              properties: [
                BvWritingProperty.person(
                  label: w['omar']!,
                  tint: BvAvatarTints.green,
                ),
                BvWritingProperty.icon(icon: BvIcons.due, label: w['due']!),
                BvWritingProperty.icon(icon: BvIcons.place, label: w['place']!),
              ],
              cover: const ColoredBox(color: BvProjectColors.neutral),
              onRemoveCover: () {},
            ),
          ),
          const Spacer(),
          _toolbar(ready: false),
          _toolbar(ready: true),
        ]),
      );
    });

    testWidgets('ds-writing-menus $lang', (tester) async {
      await shoot(
        tester,
        'ds-writing-menus',
        lang,
        (context) => _sheet([
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BvPopoverMenu<String>.picker(
              selected: 'workItem',
              onSelected: (_) {},
              items: [
                BvMenuItem(
                  value: 'workItem',
                  label: w['workItem']!,
                  icon: BvIcons.confirmed,
                ),
                BvMenuItem(
                  value: 'checklist',
                  label: w['checklist']!,
                  icon: BvIcons.workItems,
                ),
                BvMenuItem(
                  value: 'announcement',
                  label: w['announcement']!,
                  icon: BvIcons.info,
                ),
                BvMenuItem(
                  value: 'scheduled',
                  label: w['scheduled']!,
                  icon: BvIcons.due,
                ),
                BvMenuItem(
                  value: 'file',
                  label: w['file']!,
                  icon: BvIcons.document,
                ),
              ],
            ),
          ),
          const Spacer(),
          // The More menu over the toolbar's More button (start 80).
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 64),
              child: BvPopoverMenu<String>.more(
                onSelected: (_) {},
                items: [
                  BvMenuItem(
                    value: 'assign',
                    label: w['assign']!,
                    icon: BvIcons.person,
                  ),
                  BvMenuItem(
                    value: 'location',
                    label: w['location']!,
                    icon: BvIcons.place,
                  ),
                  BvMenuItem(
                    value: 'due',
                    label: w['dueDate']!,
                    icon: BvIcons.due,
                  ),
                  BvMenuItem(
                    value: 'checklist',
                    label: w['checklist']!,
                    icon: BvIcons.workItems,
                  ),
                  BvMenuItem(
                    value: 'template',
                    label: w['template']!,
                    icon: BvIcons.copy,
                  ),
                ],
              ),
            ),
          ),
          _toolbar(ready: false, moreActive: true),
        ]),
      );
    });

    testWidgets('ds-actions $lang', (tester) async {
      await shoot(
        tester,
        'ds-actions',
        lang,
        (context) => _sheet([
          BvSlipMenu<String>(
            onSelected: (_) {},
            items: [
              BvSlipMenuItem(
                value: 'check',
                label: w['check']!,
                icon: BvIcons.check,
                tone: BvSlipMenuTone.positive,
              ),
              BvSlipMenuItem(
                value: 'sendBack',
                label: w['sendBack']!,
                icon: BvIcons.sendBack,
                tone: BvSlipMenuTone.destructive,
              ),
              BvSlipMenuItem(
                value: 'update',
                label: w['addUpdate']!,
                icon: BvIcons.add,
              ),
              BvSlipMenuItem(
                value: 'chat',
                label: w['discuss']!,
                icon: BvIcons.chat,
              ),
            ],
          ),
          BvSlipMenu<String>(
            onSelected: (_) {},
            items: [
              BvSlipMenuItem(
                value: 'edit',
                label: w['edit']!,
                icon: BvIcons.more,
              ),
              BvSlipMenuItem(
                value: 'update',
                label: w['addUpdate']!,
                icon: BvIcons.add,
              ),
              BvSlipMenuItem(
                value: 'give',
                label: w['giveTo']!,
                icon: BvIcons.person,
              ),
              BvSlipMenuItem(
                value: 'chat',
                label: w['discuss']!,
                icon: BvIcons.chat,
              ),
              BvSlipMenuItem(
                value: 'cancel',
                label: w['cancel']!,
                icon: BvIcons.close,
                tone: BvSlipMenuTone.destructive,
              ),
            ],
          ),
          const Spacer(),
          BvUndoBar(
            message: w['checked']!,
            actionLabel: w['undo']!,
            onAction: () {},
          ),
        ]),
      );
    });

    testWidgets('ds-actions-pickers $lang', (tester) async {
      await shoot(
        tester,
        'ds-actions-pickers',
        lang,
        (context) => _sheet([
          BvSendBackCard<String>(
            title: w['sendBackTo']!,
            reasons: [
              for (final r in [
                'photoMissing',
                'notAsAsked',
                'notFinished',
                'somethingElse',
              ])
                (value: r, label: w[r]!),
            ],
            selected: 'notAsAsked',
            onSelected: (_) {},
            noteController: controller(w['note']!),
            notePlaceholder: w['notePlaceholder']!,
            sendLabel: w['sendBack']!,
            onSend: () {},
          ),
          BvGiveToPicker(
            currentOwnerId: 'omar',
            currentLabel: w['now']!,
            searchPlaceholder: w['giveToSearch']!,
            onPick: (_) {},
            people: [
              BvGiveToPerson(id: 'omar', name: w['omar']!, team: w['site']),
              BvGiveToPerson(id: 'rakesh', name: w['rakesh']!, team: w['mep']),
              BvGiveToPerson(id: 'lina', name: w['lina']!, team: w['site']),
              BvGiveToPerson(
                id: 'mona',
                name: w['mona']!,
                team: w['architecture'],
              ),
            ],
          ),
        ]),
      );
    });
  }
}
