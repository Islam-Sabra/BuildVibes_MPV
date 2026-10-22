// The Daybook's paper: cards, ink stamps and the paper clip, against
// Figma D1 (2518:33001), 2519:33049 and v13's cards (2581:35611, review 53
// Part B): the header with the ref and the time, the facts, the history
// and the trace.

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/shared/widgets/bv_card_history.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:buildvibes/shared/widgets/bv_trace_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot.dart';

/// Sample text, English and Arabic: the prototype's words (D1 2518:33001,
/// AR 2547:35195), never a fresh translation.
class _S {
  const _S(this.ar);
  final bool ar;

  String t(String en, String arabic) => ar ? arabic : en;
}

// v13: cards take the full width, 16 from each edge, 12 apart.
const _sheetPadding = EdgeInsetsDirectional.fromSTEB(16, 24, 16, 16);
const _gap = 12.0;
const _stampsPadding = EdgeInsetsDirectional.all(32);

Widget _sheet(
  List<Widget> children, {
  EdgeInsetsDirectional padding = _sheetPadding,
}) => Material(
  color: BvColors.surfaceApp,
  child: Padding(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _gap,
      children: children,
    ),
  ),
);

Widget _workItemSlip(_S s) => BvSlip(
  tear: 2,
  stamp: BvInkStamp(label: s.t('DONE', 'منجز')),
  children: [
    BvSlipHeader(
      name: s.t('Islam Ahmed', 'إسلام أحمد'),
      label: s.t('You', 'أنت'),
      ref: '· KCT-014',
      time: '08:14',
      tint: BvAvatarTints.plain,
    ),
    BvSlipTitle(
      s.t(
        'Sleeves at grid C7 before the pour',
        'تركيب الجلب عند المحور C7 قبل الصبّ',
      ),
    ),
    _facts(
      s.t(
        'For Omar Haddad · by Thu 15 Oct',
        'لعمر حداد · موعده الخميس 15 أكتوبر',
      ),
      s.t('Level 2, grid C7', 'الدور 2، المحور C7'),
    ),
    BvSlipChips(
      children: [
        BvSlipChip(
          icon: BvIcons.document,
          label: s.t('M-201 Rev C', 'M-201 Rev C'),
        ),
        BvSlipChip(icon: BvIcons.workItems, label: s.t('2 points', 'نقطتان')),
      ],
    ),
  ],
);

Widget _facts(String who, [String? place]) => BvSlipFacts(
  children: [
    BvSlipFact(icon: BvIcons.person, text: who),
    if (place != null) BvSlipFact(icon: BvIcons.place, text: place),
  ],
);

BvHistoryLine _line(
  String id,
  String name,
  String lead,
  String time, {
  String? detail,
  Color? tint,
}) => BvHistoryLine(
  id: id,
  name: name,
  lead: lead,
  detail: detail,
  time: (time: time, period: null),
  tint: tint,
);

Widget _proofSlip(_S s, {bool checked = false}) => BvSlip(
  clip: !checked,
  children: [
    BvSlipHeader(
      name: s.t('Islam Ahmed', 'إسلام أحمد'),
      label: s.t('You', 'أنت'),
      ref: '· KCT-014',
      time: checked ? '10:58' : '10:56',
      tint: BvAvatarTints.plain,
    ),
    BvSlipTitle(
      s.t(
        'Sleeves at grid C7 before the pour',
        'تركيب الجلب عند المحور C7 قبل الصبّ',
      ),
    ),
    _facts(
      s.t(
        'For Omar Haddad · by today 14:00',
        'لعمر حداد · قبل الساعة 14:00 اليوم',
      ),
    ),
    BvSlipPhoto(
      height: BvSlipSpec.photoHeightCard,
      image: samplePhoto,
      stamp: checked
          ? BvInkStamp(
              label: s.t('CHECKED', 'تم التحقق'),
              size: BvInkStampSize.lg,
              tone: BvInkStampTone.positive,
              subline: s.t('ISLAM A · 10:58', 'إسلام أ · 10:58'),
            )
          : BvInkStamp(
              label: s.t('DONE', 'منجز'),
              size: BvInkStampSize.lg,
              subline: s.t('OMAR H · 10:56', 'عمر ح · 10:56'),
            ),
    ),
    BvCardHistory(
      earlierLabel: s.t('Show earlier', 'عرض الأقدم'),
      lines: [
        _line(
          'a',
          s.t('Islam Ahmed', 'إسلام أحمد'),
          s.t('You sent it back:', 'أرجعته:'),
          '10:12',
          detail: s.t('Photo missing', 'الصورة غير موجودة'),
        ),
        _line(
          'b',
          s.t('Omar Haddad', 'عمر حداد'),
          s.t('Omar Haddad signed as done:', 'وُقّع كمنجز من قِبل عمر حداد:'),
          '10:56',
          detail: s.t(
            'All six fixed and checked with MEP.',
            'رُكّبت الست كلها وراجعتها مع فريق الكهروميكانيك.',
          ),
          tint: BvAvatarTints.green,
        ),
        if (checked)
          _line(
            'c',
            s.t('Islam Ahmed', 'إسلام أحمد'),
            s.t('You checked it', 'تحقّقت منه'),
            '10:58',
          ),
      ],
    ),
    if (!checked)
      BvSlipPill.hint(
        label: s.t(
          'Double-tap the photo to check it',
          'انقر مرتين على الصورة للتحقق',
        ),
      ),
  ],
);

Widget _saraSlip(_S s) => BvSlip(
  tear: 1,
  clip: true,
  children: [
    BvSlipHeader(
      name: s.t('Sara Al-Mutairi', 'سارة المطيري'),
      ref: '· KCT-016',
      time: '10:05',
      tint: BvAvatarTints.clay,
    ),
    BvSlipTitle(
      s.t('Rebar spacing, level 3 slab', 'تباعد حديد التسليح، بلاطة الدور 3'),
    ),
    _facts(
      s.t('For you · by today 2 pm', 'لك · قبل الساعة 2 ظهرًا اليوم'),
      s.t('Level 3 slab', 'بلاطة الدور 3'),
    ),
    BvCardHistory(
      lines: [
        _line(
          'a',
          s.t('Sara Al-Mutairi', 'سارة المطيري'),
          s.t(
            'Sara Al-Mutairi moved the due date from Thu to today',
            'نُقل الموعد من الخميس إلى اليوم من قِبل سارة المطيري',
          ),
          '10:05',
          tint: BvAvatarTints.clay,
        ),
      ],
    ),
  ],
);

Widget _omarSlip(_S s) => BvSlip(
  tear: 1,
  clip: true,
  children: [
    BvSlipHeader(
      name: s.t('Sara Al-Mutairi', 'سارة المطيري'),
      ref: '· KCT-016',
      time: '10:05',
      tint: BvAvatarTints.clay,
    ),
    BvSlipTitle(
      s.t('Rebar spacing, level 3 slab', 'تباعد حديد التسليح، بلاطة الدور 3'),
    ),
    _facts(s.t('For you · by today 2 pm', 'لك · قبل الساعة 2 ظهرًا اليوم')),
    BvSlipPill.action(
      icon: BvIcons.camera,
      label: s.t('Sign as done', 'وقّع كمنجز'),
      onTap: () {},
    ),
  ],
);

Widget _cancelledSlip(_S s) => BvSlip(
  tear: 2,
  cancelled: true,
  stamp: BvInkStamp(
    label: s.t('CANCELLED', 'ملغى'),
    size: BvInkStampSize.sm,
    tone: BvInkStampTone.muted,
  ),
  children: [
    BvSlipHeader(
      name: s.t('Islam Ahmed', 'إسلام أحمد'),
      label: s.t('You', 'أنت'),
      tint: BvAvatarTints.plain,
    ),
    BvSlipTitle(
      s.t('Clean the level 1 store', 'تنظيف مخزن الدور 1'),
      cancelled: true,
    ),
    _facts(s.t('For Omar Haddad', 'لعمر حداد')),
    BvCardHistory(
      lines: [
        _line(
          'a',
          s.t('Islam Ahmed', 'إسلام أحمد'),
          s.t('You cancelled it', 'ألغيته'),
          '12:05',
        ),
      ],
    ),
  ],
);

Widget _trace(_S s) => BvTraceRow(
  name: s.t('Omar Haddad', 'عمر حداد'),
  tint: BvAvatarTints.green,
  text: s.t(
    'Omar Haddad added an update · Sleeves at grid C7 before the pour',
    'تحديث من عمر حداد · تركيب الجلب عند المحور C7 قبل الصبّ',
  ),
  time: '16:07',
  onTap: () {},
);

Widget _stamps(_S s) {
  final tones = [
    (BvInkStampTone.action, s.t('DONE', 'منجز')),
    (BvInkStampTone.positive, s.t('CHECKED', 'تم التحقق')),
    (BvInkStampTone.muted, s.t('CANCELLED', 'ملغى')),
    (BvInkStampTone.destructive, s.t('SENT BACK', 'مُرجَع')),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: _gap,
    children: [
      for (final size in BvInkStampSize.values)
        Wrap(
          spacing: BvSpace.s16,
          runSpacing: BvSpace.s24,
          children: [
            for (final (tone, label) in tones)
              BvInkStamp(
                label: label,
                size: size,
                tone: tone,
                subline: size == BvInkStampSize.lg
                    ? s.t('OMAR H · 09:40', 'عمر ح · 09:40')
                    : null,
              ),
          ],
        ),
    ],
  );
}

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = _S(lang == 'ar');

    testWidgets('ds-paper [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'ds-paper',
        lang,
        (_) => _sheet([_workItemSlip(s), _proofSlip(s)]),
      );
    });

    testWidgets('ds-paper-2 [$lang]', (tester) async {
      await warmSamplePhoto(tester);
      await shoot(
        tester,
        'ds-paper-2',
        lang,
        (_) => _sheet([_proofSlip(s, checked: true), _saraSlip(s)]),
      );
    });

    testWidgets('ds-paper-4 [$lang]', (tester) async {
      await shoot(
        tester,
        'ds-paper-4',
        lang,
        (_) => _sheet([_omarSlip(s), _cancelledSlip(s), _trace(s)]),
      );
    });

    testWidgets('ds-paper-3 [$lang]', (tester) async {
      await shoot(
        tester,
        'ds-paper-3',
        lang,
        (_) => _sheet([_stamps(s)], padding: _stampsPadding),
      );
    });
  }
}
