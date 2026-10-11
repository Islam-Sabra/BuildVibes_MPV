// Debug-only screen that shows every BV component in all its states, for
// review on a phone. It is reachable from Profile only in debug builds.
//
// The sample text below is fixture data for review, not product copy, so it
// lives here instead of the ARB files. Product screens never do this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/bv_icons.dart';
import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';
import '../../data/models/market.dart';
import '../../data/repositories/market_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../shared/widgets/bv_avatar.dart';
import '../../shared/widgets/bv_badge.dart';
import '../../shared/widgets/bv_button.dart';
import '../../shared/widgets/bv_chip.dart';
import '../../shared/widgets/bv_choice_card.dart';
import '../../shared/widgets/bv_controls.dart';
import '../../shared/widgets/bv_list_row.dart';
import '../../shared/widgets/bv_pass_card.dart';
import '../../shared/widgets/bv_search_field.dart';
import '../../shared/widgets/bv_sheet.dart';
import '../../shared/widgets/bv_sign_off_strip.dart';
import '../../shared/widgets/bv_site_photo.dart';
import '../../shared/widgets/bv_site_tag.dart';
import '../../shared/widgets/bv_stamp.dart';
import '../../shared/widgets/bv_tabs.dart';
import '../../shared/widgets/bv_text_field.dart';
import '../../shared/widgets/bv_work_item_card.dart';
import '../settings/language_sheet.dart';

const _samplePhoto = AssetImage('assets/dev/site_sample.jpg');

class ComponentsGalleryScreen extends StatefulWidget {
  const ComponentsGalleryScreen({super.key});

  @override
  State<ComponentsGalleryScreen> createState() =>
      _ComponentsGalleryScreenState();
}

class _ComponentsGalleryScreenState extends State<ComponentsGalleryScreen> {
  var _chip = 0;
  var _tab = 0;
  var _switchOn = true;
  var _checkOn = true;
  var _radio = 0;
  var _visibility = 0;
  var _notifications = true;
  var _pass = BvPassKind.crew;
  String? _team = 'structure';
  final _note = TextEditingController();
  final _filled = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _note.text = _Samples.of(context).noteNearLimit;
    _filled.text = _Samples.of(context).fieldValue;
  }

  @override
  void dispose() {
    _note.dispose();
    _filled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _Samples.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.componentsGallery),
        actions: [
          IconButton(
            key: const Key('gallery-language'),
            tooltip: l10n.settingsLanguage,
            icon: const Icon(BvIcons.language),
            onPressed: () => showLanguageSheet(context),
          ),
        ],
      ),
      body: ListView(
        key: const Key('gallery-list'),
        padding: const EdgeInsetsDirectional.only(bottom: BvSpace.s64),
        children: [
          _Section('1 · BvButton', [
            for (final size in BvButtonSize.values)
              for (final style in BvButtonStyle.values)
                Wrap(
                  spacing: BvSpace.s8,
                  runSpacing: BvSpace.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BvButton(
                      label: s.buttonLabel(style),
                      style: style,
                      size: size,
                      icon: style == BvButtonStyle.primary
                          ? BvIcons.check
                          : null,
                      onPressed: () {},
                    ),
                    BvButton(
                      label: s.buttonLabel(style),
                      style: style,
                      size: size,
                      onPressed: null,
                    ),
                  ],
                ),
            BvButton(
              label: s.buttonLabel(BvButtonStyle.primary),
              expand: true,
              onPressed: () {},
            ),
            BvButton(
              label: s.focused,
              style: BvButtonStyle.secondary,
              autofocus: true,
              onPressed: () {},
            ),
          ]),
          _Section('2 · BvChip', [
            BvChipRow(
              chips: [
                for (var i = 0; i < s.chips.length; i++)
                  BvChip(
                    label: s.chips[i],
                    ink: i == 0,
                    icon: i == 1 ? BvIcons.workItems : null,
                    selected: _chip == i,
                    onTap: () => setState(() => _chip = i),
                  ),
              ],
            ),
            BvChipRow(
              chips: [
                BvChip(label: s.chips[0], ink: true, onTap: () {}),
                BvChip(label: s.chips[1], selected: true, onTap: () {}),
              ],
            ),
          ], padded: false),
          _Section('3 · BvTabs', [
            BvTabs(
              labels: s.tabs,
              selectedIndex: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),
          ]),
          _Section('4 · BvTextField · BvSelect', [
            BvTextField(
              label: s.fieldLabel,
              placeholder: s.fieldPlaceholder,
              helper: s.fieldHelper,
            ),
            BvTextField(
              label: s.fieldLabel,
              controller: _filled,
              helper: s.fieldHelper,
            ),
            BvTextField(
              label: s.fieldLabel,
              placeholder: s.fieldPlaceholder,
              error: s.fieldError,
            ),
            BvTextField(
              label: s.fieldLabel,
              placeholder: s.fieldPlaceholder,
              enabled: false,
            ),
            BvSelect<String>(
              label: s.selectLabel,
              value: _team,
              options: [
                for (final e in s.teams.entries)
                  BvSelectOption(value: e.key, label: e.value),
              ],
              onChanged: (v) => setState(() => _team = v),
            ),
            // The dial code and example come from the market pack in
            // Supabase (the first live market).
            Consumer(
              builder: (context, ref, _) {
                final markets = ref.watch(marketsProvider).value ?? const [];
                final market = markets
                    .where((m) => m.status == MarketStatus.live)
                    .firstOrNull;
                return BvPhoneField(
                  key: const Key('gallery-phone'),
                  label: s.phoneLabel,
                  dialCode: market?.dialCode ?? '+',
                  placeholder: market?.phoneExample,
                );
              },
            ),
            BvCodeField(label: s.codeLabel),
            BvTextField(
              label: s.noteLabel,
              controller: _note,
              maxLines: 3,
              maxLength: 120,
            ),
          ]),
          _Section('5 · BvSearchField', [
            BvSearchField(placeholder: s.searchPlaceholder),
          ]),
          _Section('6 · BvSwitch · BvCheckbox · BvRadio', [
            Wrap(
              spacing: BvSpace.s8,
              children: [
                BvSwitch(
                  value: _switchOn,
                  onChanged: (v) => setState(() => _switchOn = v),
                ),
                BvSwitch(
                  value: !_switchOn,
                  onChanged: (v) => setState(() => _switchOn = !v),
                ),
                const BvSwitch(value: true, onChanged: null),
                const BvSwitch(value: false, onChanged: null),
              ],
            ),
            Wrap(
              spacing: BvSpace.s8,
              children: [
                BvCheckbox(
                  value: _checkOn,
                  onChanged: (v) => setState(() => _checkOn = v),
                ),
                BvCheckbox(
                  value: !_checkOn,
                  onChanged: (v) => setState(() => _checkOn = !v),
                ),
                const BvCheckbox(value: true, onChanged: null),
                for (var i = 0; i < 2; i++)
                  BvRadio(
                    selected: _radio == i,
                    onTap: () => setState(() => _radio = i),
                  ),
              ],
            ),
          ]),
          _Section('7 · BvListRow', [
            BvListGroup(
              rows: [
                BvListRow(
                  leading: const BvRowIcon(BvIcons.language),
                  title: s.rowLanguage,
                  trailing: BvRowTrailing.value(s.rowLanguageValue),
                  onTap: () {},
                ),
                BvListRow(
                  leading: const BvRowIcon(BvIcons.notifications),
                  title: s.rowNotifications,
                  trailing: BvRowTrailing.toggle(
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                ),
                BvListRow(
                  leading: BvAvatar(name: s.personName),
                  title: s.personName,
                  subtitle: s.personRole,
                  onTap: () {},
                ),
                BvListRow(
                  title: s.rowPasses,
                  subtitle: s.rowPassesSub,
                  onTap: () {},
                ),
                BvListRow(
                  title: s.rowReport,
                  trailing: const BvRowTrailing.none(),
                ),
              ],
            ),
          ], padded: false),
          _Section('8 · BvChoiceCard', [
            BvChoiceList<int>(
              value: _visibility,
              options: [
                for (var i = 0; i < s.visibility.length; i++)
                  BvChoiceOption(
                    value: i,
                    title: s.visibility[i].$1,
                    description: s.visibility[i].$2,
                    icon: [BvIcons.everyone, BvIcons.people, BvIcons.lock][i],
                  ),
              ],
              onChanged: (v) => setState(() => _visibility = v),
            ),
          ]),
          _Section('9 · BvAvatar', [
            Wrap(
              spacing: BvSpace.s12,
              runSpacing: BvSpace.s12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final size in BvAvatarSize.values)
                  BvAvatar(name: s.personName, size: size),
                for (final size in BvAvatarSize.values)
                  BvAvatar(name: s.companyName, size: size, company: true),
                BvAvatar(
                  name: s.personName,
                  size: BvAvatarSize.lg,
                  image: _samplePhoto,
                ),
                BvAvatar(
                  name: s.companyName,
                  size: BvAvatarSize.lg,
                  company: true,
                  image: _samplePhoto,
                ),
                for (final id in ['kw-001', 'kw-002', 'eg-003', 'eg-004'])
                  BvProjectAvatar(
                    id: id,
                    icon: BvIcons.company,
                    size: BvAvatarSize.lg,
                  ),
              ],
            ),
          ]),
          _Section('10 · BvBadge', [
            Wrap(
              spacing: BvSpace.s8,
              runSpacing: BvSpace.s8,
              children: [
                for (final tone in BvBadgeTone.values)
                  BvBadge(label: s.badge(tone), tone: tone),
              ],
            ),
          ]),
          _Section('11 · BvBottomSheet', [
            BvButton(
              key: const Key('gallery-open-sheet'),
              label: s.openSheet,
              style: BvButtonStyle.secondary,
              onPressed: () => _openSheet(context, s),
            ),
            BvSheet(
              title: s.sheetTitle,
              subtitle: s.sheetSubtitle,
              footer: BvSheetFooter(
                cancelLabel: l10n.commonCancel,
                confirmLabel: l10n.commonConfirm,
                onConfirm: () {},
                onCancel: () {},
              ),
              child: Text(s.sheetBody, style: BvType.of(context).bodyMd),
            ),
          ]),
          _Section('12 · BvStamp', [
            Wrap(
              spacing: BvSpace.s16,
              runSpacing: BvSpace.s16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const BvStamp(label: 'KCT-021'),
                BvStamp(
                  label: s.stampChecked,
                  tone: BvStampTone.positive,
                  tilted: true,
                ),
                BvStamp(label: l10n.stampSelected, tilted: true),
                BvStamp(label: s.stampMuted, tone: BvStampTone.muted),
              ],
            ),
          ]),
          _Section('13 · BvSiteTag', [
            BvSiteTag(
              itemId: 'KCT-021',
              team: s.team,
              title: s.itemTitle,
              place: s.place,
              from: s.fromName,
              owner: s.personName,
              due: s.due,
            ),
            BvSiteTag(
              itemId: 'KCT-024',
              team: s.team,
              title: s.itemTitle2,
              place: s.place,
              from: s.fromName,
              owner: s.personName,
              due: s.dueOverdue,
              overdue: true,
            ),
          ]),
          _Section('14 · BvSignOffStrip', [
            BvSignOffStrip(
              steps: [
                BvSignOffStep(
                  kind: BvSignOffStepKind.raised,
                  person: s.fromName,
                  when: s.when1,
                ),
                BvSignOffStep(
                  kind: BvSignOffStepKind.done,
                  person: s.personName,
                  when: s.when2,
                ),
                const BvSignOffStep(kind: BvSignOffStepKind.checked),
              ],
            ),
            BvSignOffStrip(
              steps: [
                BvSignOffStep(
                  kind: BvSignOffStepKind.raised,
                  person: s.fromName,
                  when: s.when1,
                ),
                const BvSignOffStep(kind: BvSignOffStepKind.done),
                const BvSignOffStep(kind: BvSignOffStepKind.checked),
              ],
            ),
          ]),
          _Section('15 · BvWorkItemCard', [
            for (final status in BvWorkStatus.values)
              BvWorkItemCard(
                reference: s.reference,
                status: status,
                statusLine: s.statusLine(status),
                title: s.itemTitle,
                place: s.place,
                people: s.people,
                evidence: switch (status) {
                  BvWorkStatus.done => BvWorkEvidence(
                    text: s.evidenceDone,
                    photo: _samplePhoto,
                  ),
                  BvWorkStatus.checked => BvWorkEvidence(
                    text: s.evidenceChecked,
                    photo: _samplePhoto,
                  ),
                  _ => null,
                },
                actionLabel: s.action(status),
                onTap: () {},
              ),
          ]),
          _Section('16 · BvPassCard', [
            for (final kind in BvPassKind.values)
              BvPassCard(
                kind: kind,
                opens: s.passOpens(kind),
                forWho: s.passFor(kind),
                selected: _pass == kind,
                onTap: () => setState(() => _pass = kind),
              ),
          ]),
          _Section('17 · BvSitePhoto', [
            BvSitePhoto(photo: _samplePhoto, stamp: s.photoStamp),
            BvSitePhoto(photo: null, stamp: s.photoStamp),
          ]),
        ],
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, _Samples s) {
    final l10n = AppLocalizations.of(context);
    var choice = 0;
    return showBvSheet(
      context: context,
      title: s.sheetTitle,
      subtitle: s.sheetSubtitle,
      footer: BvSheetFooter(
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.commonConfirm,
        onConfirm: () => Navigator.of(context).pop(),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => BvChoiceList<int>(
          value: choice,
          options: [
            for (var i = 0; i < s.visibility.length; i++)
              BvChoiceOption(
                value: i,
                title: s.visibility[i].$1,
                description: s.visibility[i].$2,
              ),
          ],
          onChanged: (v) => setSheet(() => choice = v),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children, {this.padded = true});

  final String title;
  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: BvGallerySpec.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BvGallerySpec.itemGap,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BvSpace.gutter,
            ),
            // Component names are code names, so they stay in Latin script.
            child: Text(
              title,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              style: BvType.latin.overline.copyWith(
                color: BvColors.textSecondary,
              ),
            ),
          ),
          for (final child in children)
            padded
                ? Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: BvSpace.gutter,
                    ),
                    child: child,
                  )
                : child,
        ],
      ),
    );
  }
}

/// Fixture content for the gallery, in English and Arabic.
class _Samples {
  const _Samples._({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.destructive,
    required this.focused,
    required this.chips,
    required this.tabs,
    required this.fieldLabel,
    required this.fieldPlaceholder,
    required this.fieldValue,
    required this.fieldHelper,
    required this.fieldError,
    required this.selectLabel,
    required this.teams,
    required this.phoneLabel,
    required this.codeLabel,
    required this.noteLabel,
    required this.noteNearLimit,
    required this.searchPlaceholder,
    required this.rowLanguage,
    required this.rowLanguageValue,
    required this.rowNotifications,
    required this.rowPasses,
    required this.rowPassesSub,
    required this.rowReport,
    required this.personName,
    required this.personRole,
    required this.companyName,
    required this.fromName,
    required this.visibility,
    required this.badges,
    required this.openSheet,
    required this.sheetTitle,
    required this.sheetSubtitle,
    required this.sheetBody,
    required this.stampChecked,
    required this.stampMuted,
    required this.team,
    required this.itemTitle,
    required this.itemTitle2,
    required this.place,
    required this.due,
    required this.dueOverdue,
    required this.when1,
    required this.when2,
    required this.reference,
    required this.statusLines,
    required this.people,
    required this.evidenceDone,
    required this.evidenceChecked,
    required this.actions,
    required this.passOpensLines,
    required this.passForLines,
    required this.photoStamp,
  });

  final String primary, secondary, tertiary, destructive, focused;
  final List<String> chips, tabs;
  final String fieldLabel, fieldPlaceholder, fieldValue, fieldHelper;
  final String fieldError, selectLabel;
  final Map<String, String> teams;
  final String phoneLabel, codeLabel, noteLabel, noteNearLimit;
  final String searchPlaceholder;
  final String rowLanguage, rowLanguageValue, rowNotifications;
  final String rowPasses, rowPassesSub, rowReport;
  final String personName, personRole, companyName, fromName;
  final List<(String, String)> visibility;
  final List<String> badges;
  final String openSheet, sheetTitle, sheetSubtitle, sheetBody;
  final String stampChecked, stampMuted;
  final String team, itemTitle, itemTitle2, place, due, dueOverdue;
  final String when1, when2, reference;
  final List<String> statusLines;
  final String people, evidenceDone, evidenceChecked;
  final List<String?> actions;
  final List<String> passOpensLines, passForLines;
  final String photoStamp;

  String buttonLabel(BvButtonStyle style) => switch (style) {
    BvButtonStyle.primary => primary,
    BvButtonStyle.secondary => secondary,
    BvButtonStyle.tertiary => tertiary,
    BvButtonStyle.destructive => destructive,
  };
  String badge(BvBadgeTone tone) => badges[tone.index];
  String statusLine(BvWorkStatus status) => statusLines[status.index];
  String? action(BvWorkStatus status) => actions[status.index];
  String passOpens(BvPassKind kind) => passOpensLines[kind.index];
  String passFor(BvPassKind kind) => passForLines[kind.index];

  static _Samples of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? _ar : _en;

  static const _en = _Samples._(
    primary: 'Sign as done',
    secondary: 'Send back',
    tertiary: 'Add photo',
    destructive: 'Delete item',
    focused: 'Focused',
    chips: ['All', 'Needs you', 'Open', 'Done', 'Checked'],
    tabs: ['Feed', 'Spaces'],
    fieldLabel: 'Work item title',
    fieldPlaceholder: 'e.g. Fix rebar at grid C7',
    fieldValue: 'Fix rebar spacing at grid C7',
    fieldHelper: 'Keep it short. People see it in the list.',
    fieldError: 'Write a title.',
    selectLabel: 'Team',
    teams: {'structure': 'Structure', 'mep': 'MEP', 'finishes': 'Finishes'},
    phoneLabel: 'Phone number',
    codeLabel: 'Sign-in code',
    noteLabel: 'Note',
    noteNearLimit:
        'Rebar at C7 is 200 mm apart, the drawing says 150. Please fix '
        'before the pour on Sunday.',
    searchPlaceholder: 'Search people',
    rowLanguage: 'App language',
    rowLanguageValue: 'English',
    rowNotifications: 'Notifications',
    rowPasses: 'Space passes',
    rowPassesSub: 'Lead, Crew, Viewer',
    rowReport: 'Report a problem',
    personName: 'Omar Haddad',
    personRole: 'Site supervisor',
    companyName: 'Al Noor Contracting',
    fromName: 'Sara Al-Mutairi',
    visibility: [
      ('Everyone', 'Anyone on BuildVibes can see it.'),
      ('Connections only', 'Only people you are connected with.'),
      ('Only me', 'Nobody else can see it.'),
    ],
    badges: ['Draft', 'New', 'Checked', 'Due today'],
    openSheet: 'Open a sheet',
    sheetTitle: 'Who can see this link?',
    sheetSubtitle: 'Choose one.',
    sheetBody: 'Sheet content goes here.',
    stampChecked: 'CHECKED',
    stampMuted: 'DRAFT',
    team: 'STRUCTURE',
    itemTitle: 'Fix rebar spacing at grid C7',
    itemTitle2: 'Close the slab opening at grid D4',
    place: 'Level 2 · Grid C7',
    due: 'Sun 12 Oct',
    dueOverdue: 'Thu 9 Oct',
    when1: '9 Oct · 08:10',
    when2: '11 Oct · 14:22',
    reference: 'KCT-021 · STRUCTURE',
    statusLines: [
      'OPEN · DUE SUN 12 OCT',
      'DONE · YOU CHECK IT',
      'CHECKED · THU 9 OCT',
      'OVERDUE · 2 DAYS',
    ],
    people: 'Owner: you · from Sara Al-Mutairi',
    evidenceDone: '“Fixed to the drawing, 150 mm.”',
    evidenceChecked: 'Checked by Sara · 1 photo',
    actions: ['Sign as done', 'Check it', null, 'Sign as done'],
    passOpensLines: [
      'Opens: all items, Teams, Library, settings',
      'Opens: items given to them, Chat, Library',
      'Opens: read only',
    ],
    passForLines: [
      'For the site engineer or supervisor',
      'For foremen and trades',
      'For the consultant or the client',
    ],
    photoStamp: 'Level 2 · Grid C7 · 09:40 · Omar Haddad',
  );

  static const _ar = _Samples._(
    primary: 'وقّع كمنجز',
    secondary: 'إرجاع',
    tertiary: 'أضف صورة',
    destructive: 'حذف البند',
    focused: 'محدد بالتركيز',
    chips: ['الكل', 'بانتظارك', 'مفتوحة', 'منجز', 'تم الفحص'],
    tabs: ['المنشورات', 'المساحات'],
    fieldLabel: 'عنوان بند العمل',
    fieldPlaceholder: 'مثال: إصلاح حديد التسليح عند المحور C7',
    fieldValue: 'تعديل تباعد حديد التسليح عند المحور C7',
    fieldHelper: 'اجعله قصيراً، فهو يظهر في القائمة.',
    fieldError: 'اكتب عنواناً.',
    selectLabel: 'الفريق',
    teams: {
      'structure': 'الفريق الإنشائي',
      'mep': 'الأعمال الكهروميكانيكية',
      'finishes': 'التشطيبات',
    },
    phoneLabel: 'رقم الهاتف',
    codeLabel: 'رمز الدخول',
    noteLabel: 'ملاحظة',
    noteNearLimit:
        'المسافة بين حديد التسليح عند C7 هي 200 مم والمخطط يقول 150. '
        'يرجى التعديل قبل الصب يوم الأحد.',
    searchPlaceholder: 'ابحث عن أشخاص',
    rowLanguage: 'لغة التطبيق',
    rowLanguageValue: 'العربية',
    rowNotifications: 'الإشعارات',
    rowPasses: 'تصاريح المساحة',
    rowPassesSub: 'مسؤول، فريق تنفيذ، مُطّلع',
    rowReport: 'الإبلاغ عن مشكلة',
    personName: 'عمر حداد',
    personRole: 'مشرف موقع',
    companyName: 'النور للمقاولات',
    fromName: 'سارة المطيري',
    visibility: [
      ('الجميع', 'يراه أي شخص على BuildVibes.'),
      ('جهات الاتصال فقط', 'يراه فقط من تتواصل معهم.'),
      ('أنا فقط', 'لا يراه أحد غيرك.'),
    ],
    badges: ['مسودة', 'جديد', 'تم الفحص', 'مستحق اليوم'],
    openSheet: 'افتح نافذة',
    sheetTitle: 'من يمكنه رؤية هذا الرابط؟',
    sheetSubtitle: 'اختر واحداً.',
    sheetBody: 'هنا محتوى النافذة.',
    stampChecked: 'تم الفحص',
    stampMuted: 'مسودة',
    team: 'إنشائي',
    itemTitle: 'تعديل تباعد حديد التسليح عند المحور C7',
    itemTitle2: 'إغلاق فتحة البلاطة عند المحور D4',
    place: 'الطابق 2 · المحور C7',
    due: 'الأحد 12 أكتوبر',
    dueOverdue: 'الخميس 9 أكتوبر',
    when1: '9 أكتوبر · 08:10',
    when2: '11 أكتوبر · 14:22',
    reference: 'KCT-021 · إنشائي',
    statusLines: [
      'مفتوحة · الاستحقاق الأحد 12 أكتوبر',
      'منجز · بانتظار فحصك',
      'تم الفحص · الخميس 9 أكتوبر',
      'متأخر · يومان',
    ],
    people: 'المكلّف: أنت · من سارة المطيري',
    evidenceDone: '«تم التعديل وفق المخطط، 150 مم.»',
    evidenceChecked: 'فحصته سارة · صورة واحدة',
    actions: ['وقّع كمنجز', 'افحصه', null, 'وقّع كمنجز'],
    passOpensLines: [
      'يفتح: كل البنود، الفرق، المكتبة، الإعدادات',
      'يفتح: البنود المكلّف بها، المحادثة، المكتبة',
      'يفتح: القراءة فقط',
    ],
    passForLines: [
      'لمهندس الموقع أو المشرف',
      'لرؤساء العمال والفنيين',
      'للاستشاري أو المالك',
    ],
    photoStamp: 'الطابق 2 · المحور C7 · 09:40 · عمر حداد',
  );
}
