// The Daybook's paper (slice 1a): slips, ink stamps and the paper clip,
// against Figma D1 (2518:33001) and 2519:33049.
import 'dart:async';

import 'package:buildvibes/core/design/bv_icons.dart';
import 'package:buildvibes/core/design/bv_tokens.dart';
import 'package:buildvibes/core/design/daybook_paper_specs.dart';
import 'package:buildvibes/shared/widgets/bv_slip.dart';
import 'package:buildvibes/shared/widgets/bv_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot.dart';

const _photo = AssetImage('assets/dev/site_sample.jpg');

/// Sample text, English and Arabic: the prototype's words (D1 2518:33001,
/// AR 2547:35195), never a fresh translation.
class _S {
  const _S(this.ar);
  final bool ar;

  String t(String en, String arabic) => ar ? arabic : en;
}

// The Space's slip column: 56 time column and 8 gap at the start, 16 at
// the end, so the slips are 310 wide as in Figma.
const _sheetPadding = EdgeInsetsDirectional.fromSTEB(64, 24, 16, 16);
const _gap = 22.0;
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
      tint: BvAvatarTints.plain,
    ),
    BvSlipTitle(
      s.t(
        'Sleeves at grid C7 before the pour',
        'تركيب الجلب عند المحور C7 قبل الصبّ',
      ),
    ),
    BvSlipMeta(
      s.t('For Omar Haddad, by Thu 15 Oct', 'لعمر حداد، قبل الخميس 15 أكتوبر'),
    ),
    BvSlipPlace(s.t('Level 2, grid C7', 'الدور 2، المحور C7')),
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

Widget _proofSlip(_S s, {bool checked = false}) => BvSlip(
  clip: !checked,
  children: [
    BvSlipHeader(
      name: s.t('Omar Haddad', 'عمر حداد'),
      action: s.t('signed as done', 'وقّع كمنجز'),
      tint: BvAvatarTints.green,
    ),
    BvSlipQuote(
      s.t(
        'Sleeves at grid C7 before the pour',
        'تركيب الجلب عند المحور C7 قبل الصبّ',
      ),
    ),
    BvSlipPhoto(
      height: BvSlipSpec.photoHeightProof,
      image: _photo,
      stamp: checked
          ? BvInkStamp(
              label: s.t('CHECKED', 'تم الفحص'),
              size: BvInkStampSize.lg,
              tone: BvInkStampTone.positive,
              subline: s.t('ISLAM A · 10:12', 'إسلام أ · 10:12'),
            )
          : BvInkStamp(
              label: s.t('DONE', 'منجز'),
              size: BvInkStampSize.lg,
              subline: s.t('OMAR H · 09:40', 'عمر ح · 09:40'),
            ),
    ),
    BvSlipNote(
      s.t(
        'All six fixed and checked with MEP.',
        'رُكّبت الست كلها وراجعتها مع فريق الكهروميكانيك.',
      ),
    ),
    if (checked)
      BvSlipHistory(
        s.t(
          "You checked it at 10:12. It's locked now, this is the record.",
          'فحصته الساعة 10:12. أصبح مقفلاً الآن، وهذا هو السجل.',
        ),
      )
    else
      BvSlipPill.hint(
        label: s.t(
          'Double-tap the photo to check it',
          'انقر مرتين على الصورة لفحصها',
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
      tint: BvAvatarTints.clay,
    ),
    BvSlipTitle(
      s.t('Rebar spacing, level 3 slab', 'تباعد حديد التسليح، بلاطة الدور 3'),
    ),
    BvSlipMeta(s.t('For you, by today 2 pm', 'لك، قبل الساعة 2 ظهرًا اليوم')),
    BvSlipHistory(
      s.t(
        'Edited: due moved from Thu to today',
        'عُدّل: نُقل الموعد من الخميس إلى اليوم',
      ),
    ),
  ],
);

Widget _omarSlip(_S s) => BvSlip(
  tear: 1,
  clip: true,
  children: [
    BvSlipHeader(
      name: s.t('Sara Al-Mutairi', 'سارة المطيري'),
      tint: BvAvatarTints.clay,
    ),
    BvSlipTitle(
      s.t('Rebar spacing, level 3 slab', 'تباعد حديد التسليح، بلاطة الدور 3'),
    ),
    BvSlipMeta(s.t('For you, by today 2 pm', 'لك، قبل الساعة 2 ظهرًا اليوم')),
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
    BvSlipMeta(s.t('Cancelled by you at 12:05', 'ألغيته الساعة 12:05')),
  ],
);

Widget _stamps(_S s) {
  final tones = [
    (BvInkStampTone.action, s.t('DONE', 'منجز')),
    (BvInkStampTone.positive, s.t('CHECKED', 'تم الفحص')),
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

Future<void> _warmPhoto(WidgetTester tester) => tester.runAsync(() {
  final done = Completer<void>();
  final stream = _photo.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener((_, _) {
    stream.removeListener(listener);
    done.complete();
  }, onError: (e, _) => done.completeError(e));
  stream.addListener(listener);
  return done.future;
});

void main() {
  setUpAll(loadAppFonts);

  for (final lang in ['en', 'ar']) {
    final s = _S(lang == 'ar');

    testWidgets('ds-paper [$lang]', (tester) async {
      await _warmPhoto(tester);
      await shoot(
        tester,
        'ds-paper',
        lang,
        (_) => _sheet([_workItemSlip(s), _proofSlip(s), _saraSlip(s)]),
      );
    });

    testWidgets('ds-paper-2 [$lang]', (tester) async {
      await _warmPhoto(tester);
      await shoot(
        tester,
        'ds-paper-2',
        lang,
        (_) => _sheet([
          _proofSlip(s, checked: true),
          _omarSlip(s),
          _cancelledSlip(s),
        ]),
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
