// The Daybook's day parts: the one-line masthead and the day divider (v13,
// review 53 Part B), Home's spine, the post bars, the month drop-down and
// the day-one card. Run:
//   flutter test test_screens/ds_days_test.dart --update-goldens
import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/shared/widgets/bv_day_divider.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_masthead.dart';
import 'package:buildvibes/shared/widgets/bv_daybook_spine.dart';
import 'package:buildvibes/shared/widgets/bv_first_page.dart';
import 'package:buildvibes/shared/widgets/bv_month_dropdown.dart';
import 'package:buildvibes/shared/widgets/bv_post_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot.dart';

const _text = {
  'en': {
    'weekday': 'Thursday',
    'date': '15 October',
    'now': 'Now',
    'yesterday': 'Wednesday 14 October',
    'workItem': 'Work item',
    'viewer': 'Viewer',
    'readOnly': 'Read only',
    'posts': 'Posts',
    'due': 'Something due',
    'title': 'The first page of your daybook',
    'body': 'Everything your team posts will hang here, day by day.',
    'first': 'Post the first work item',
    'invite': 'Invite your team',
  },
  'ar': {
    'weekday': 'الخميس',
    'date': '15 أكتوبر',
    'now': 'الآن',
    'yesterday': 'الأربعاء 14 أكتوبر',
    'workItem': 'بند عمل',
    'viewer': 'مُطّلع',
    'readOnly': 'للقراءة فقط',
    'posts': 'منشورات',
    'due': 'موعد مستحق',
    'title': 'الصفحة الأولى من يومية فريقك',
    'body': 'كل ما ينشره فريقك سيُعلَّق هنا، يومًا بيوم.',
    'first': 'انشر أول بند عمل',
    'invite': 'ادعُ فريقك',
  },
};

Widget _slip(double height) => Container(
  height: height,
  decoration: const BoxDecoration(
    color: BvColors.surfaceElevated,
    borderRadius: BvRadius.controlAll,
    boxShadow: BvShadow.slip,
  ),
);

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final t = _text[lang]!;

    testWidgets('days sheet 1 [$lang]', (tester) async {
      await shoot(
        tester,
        'ds-days',
        lang,
        (_) => Material(
          color: BvColors.surfaceApp,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: BvSpace.s24),
              BvDaybookMasthead(
                weekday: t['weekday']!,
                date: t['date']!,
                onTap: () {},
              ),
              BvDaybookSpine(
                children: [
                  BvSpineEntry(time: '08:14', child: _slip(72)),
                  BvSpineEntry(time: '09:40', child: _slip(96)),
                  BvSpineEntry(
                    time: t['now']!,
                    dot: BvSpineDot.now,
                    child: _slip(56),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.s16,
                  vertical: BvSpace.s12,
                ),
                child: BvDayDivider(label: t['yesterday']!),
              ),
              const Spacer(),
              BvPostBar(placeholder: t['workItem']!),
              const SizedBox(height: BvSpace.s24),
              BvPostBar.viewer(
                passLabel: t['viewer']!,
                readOnly: t['readOnly']!,
              ),
              const SizedBox(height: BvSpace.s24),
            ],
          ),
        ),
      );
    });

    testWidgets('days sheet 2 [$lang]', (tester) async {
      await shoot(
        tester,
        'ds-days-2',
        lang,
        (_) => Material(
          color: BvColors.surfaceApp,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BvMonthDropdown(
                month: DateTime(2026, 10),
                today: DateTime(2026, 10, 15),
                firstWeekday: 0,
                postDays: const {1, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15},
                dueDays: const {16, 18, 19},
                postsLabel: t['posts']!,
                dueLabel: t['due']!,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BvSpace.s16,
                ),
                child: BvFirstPage(
                  title: t['title']!,
                  body: t['body']!,
                  actions: [
                    BvFirstPageAction(
                      icon: BvIcons.confirmed,
                      label: t['first']!,
                      primary: true,
                    ),
                    // No "Pin an announcement" until slice 2 (C5).
                    BvFirstPageAction(icon: BvIcons.team, label: t['invite']!),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
    });
  }
}
