import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

/// [note] is an update's face (20, Y2); [face] one of the faces before a
/// post's latest reply (22) and [post] a post card's author (36, H1 v4).
enum BvAvatarSize {
  xxs,
  note,
  face,
  xs,
  xsm,
  list,
  sm,
  post,
  md,
  lg,
  profile,
  xl,
}

/// Spec §9 ("DS · Avatar & Badge"). A person is a circle; a company is a
/// rounded square. Without a photo it shows initials.
class BvAvatar extends StatelessWidget {
  const BvAvatar({
    super.key,
    required this.name,
    this.size = BvAvatarSize.md,
    this.company = false,
    this.image,
    this.twoLetters = false,
    this.tint,
  });

  /// The fill behind the initials (Daybook: [BvAvatarTints.forId]).
  /// Default: surface subtle.
  final Color? tint;

  final String name;
  final BvAvatarSize size;
  final bool company;
  final ImageProvider? image;

  /// Tiles such as chat threads (S7k): a one-word name still shows two
  /// letters ("Everyone" → EV).
  final bool twoLetters;

  static double dimension(BvAvatarSize size) => switch (size) {
    BvAvatarSize.xxs => BvAvatarSpec.xxs,
    BvAvatarSize.note => BvAvatarSpec.note,
    BvAvatarSize.face => BvAvatarSpec.face,
    BvAvatarSize.xs => BvAvatarSpec.xs,
    BvAvatarSize.xsm => BvAvatarSpec.xsm,
    BvAvatarSize.list => BvAvatarSpec.list,
    BvAvatarSize.sm => BvAvatarSpec.sm,
    BvAvatarSize.post => BvAvatarSpec.post,
    BvAvatarSize.md => BvAvatarSpec.md,
    BvAvatarSize.lg => BvAvatarSpec.lg,
    BvAvatarSize.profile => BvAvatarSpec.profile,
    BvAvatarSize.xl => BvAvatarSpec.xl,
  };

  static BorderRadius companyRadius(BvAvatarSize size) => switch (size) {
    BvAvatarSize.xxs ||
    BvAvatarSize.note ||
    BvAvatarSize.face ||
    BvAvatarSize.xs ||
    BvAvatarSize.xsm ||
    BvAvatarSize.list ||
    BvAvatarSize.sm ||
    BvAvatarSize.post ||
    BvAvatarSize.md => BvAvatarSpec.companyRadiusSmall,
    BvAvatarSize.lg ||
    BvAvatarSize.profile ||
    BvAvatarSize.xl => BvAvatarSpec.companyRadiusLarge,
  };

  /// Latin: the first letters of the first and last word, as typed
  /// ("Sara Al-Mutairi" → SA). Arabic: one letter, as the AR frames show;
  /// two read as a word ("سم"). The prefixes "ال" and "لل" are skipped
  /// ("النور للمقاولات" → ن). Review 44 C1. An Arabic name starting with an
  /// alef (ا أ إ آ) shows its first two letters ("إس", "أح"): alone at
  /// avatar size, "إ" reads as "!" (review 46).
  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final picked = words.length == 1
        ? [words.first]
        : [words.first, words.last];
    final runes = [for (final w in picked) _initialRune(w.runes.toList())];
    if (runes.any(_isArabic)) return _arabicInitial(picked.first);
    return runes.map(String.fromCharCode).join().toUpperCase();
  }

  /// One letter of an Arabic [word], or two when it starts with an alef.
  static String _arabicInitial(String word) {
    final runes = word.runes.toList();
    final first = _initialRune(runes);
    final at = runes.indexOf(first);
    final take = _alefs.contains(first) && at + 1 < runes.length ? 2 : 1;
    return String.fromCharCodes(runes.sublist(at, at + take));
  }

  /// [initialsOf], but a single Latin word gives its first two letters,
  /// after an article ("Al-Rashid" → RA).
  static String tileInitialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length != 1 || words.first.isEmpty) return initialsOf(name);
    var runes = _withoutLatinArticle(words.first).runes.toList();
    final first = _initialRune(runes);
    runes = runes.sublist(runes.indexOf(first));
    if (runes.any(_isArabic)) return _arabicInitial(words.first);
    return runes.take(2).map(String.fromCharCode).join().toUpperCase();
  }

  static int _initialRune(List<int> word) {
    final hasPrefix =
        word.length > _prefixLength + 1 &&
        (word[0] == _alef || word[0] == _lam) &&
        word[1] == _lam;
    return hasPrefix ? word[_prefixLength] : word.first;
  }

  /// "Al-Mansour" and "El-Sayed" are indexed by the name after the
  /// article.
  static String _withoutLatinArticle(String word) {
    final dash = word.indexOf('-');
    if (dash <= 0 || dash == word.length - 1) return word;
    final article = word.substring(0, dash).toLowerCase();
    return article == 'al' || article == 'el' ? word.substring(dash + 1) : word;
  }

  /// The 18 avatar holds one Latin letter; an Arabic name keeps what
  /// [initialsOf] gives, so an alef name still shows two ("إ" alone reads
  /// as "!", review 46).
  static String _smallestInitials(String name) {
    final initials = initialsOf(name);
    if (initials.runes.any(_isArabic)) return initials;
    return initials.characters.take(1).toString();
  }

  static bool _isArabic(int rune) =>
      rune >= _arabicFirst && rune <= _arabicLast;

  // Unicode Arabic block and the letters of the prefixes.
  static const _arabicFirst = 0x0600;
  static const _arabicLast = 0x06FF;
  static const _alef = 0x0627;

  /// ا أ إ آ.
  static const _alefs = {_alef, 0x0623, 0x0625, 0x0622};
  static const _lam = 0x0644;
  static const _prefixLength = 2;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final d = dimension(size);
    final style = switch (size) {
      // 18 holds one letter in the smallest type (12 spills out, a Figma slip).
      BvAvatarSize.xxs => type.metadata.copyWith(
        fontSize: BvAvatarSpec.xxsInitials,
        height: 1,
      ),
      BvAvatarSize.note => type.labelSm.copyWith(
        fontSize: BvAvatarSpec.noteInitials,
        height: 1,
      ),
      BvAvatarSize.face => type.labelSm.copyWith(
        fontSize: BvAvatarSpec.faceInitials,
        height: 1,
      ),
      BvAvatarSize.xs || BvAvatarSize.list || BvAvatarSize.sm => type.labelSm,
      BvAvatarSize.xsm || BvAvatarSize.post => type.labelMd,
      BvAvatarSize.md || BvAvatarSize.profile => type.labelMd,
      BvAvatarSize.lg => type.titleLg,
      BvAvatarSize.xl => type.headingXl,
    };
    final shape = company
        ? RoundedRectangleBorder(borderRadius: companyRadius(size))
        : const CircleBorder();

    return Semantics(
      label: name,
      image: image != null,
      child: Container(
        width: d,
        height: d,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: tint ?? BvColors.surfaceSubtle,
          shape: image == null
              ? shape.copyWith(
                  side: const BorderSide(
                    color: BvColors.borderDefault,
                    width: BvStroke.thin,
                  ),
                )
              : shape,
          image: image == null
              ? null
              : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: image == null
            ? ExcludeSemantics(
                child: Text(
                  size == BvAvatarSize.xxs
                      ? _smallestInitials(name)
                      : twoLetters
                      ? tileInitialsOf(name)
                      : initialsOf(name),
                  maxLines: 1,
                  style: style.copyWith(color: BvColors.textPrimary),
                ),
              )
            : null,
      ),
    );
  }
}

/// Project and Space avatars: a tile in the project colour with a white
/// icon. The colour is stable for an id.
class BvProjectAvatar extends StatelessWidget {
  const BvProjectAvatar({
    super.key,
    required this.id,
    required this.icon,
    this.size = BvAvatarSize.md,
  });

  final String id;
  final IconData icon;
  final BvAvatarSize size;

  @override
  Widget build(BuildContext context) {
    final d = BvAvatar.dimension(size);
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BvProjectColors.forId(id),
        borderRadius: BvAvatar.companyRadius(size),
      ),
      child: Icon(
        icon,
        size: d * BvAvatarSpec.projectIconRatio,
        color: BvColors.iconInverse,
      ),
    );
  }
}
