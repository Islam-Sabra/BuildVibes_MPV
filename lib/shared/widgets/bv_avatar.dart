import 'package:flutter/material.dart';

import '../../core/design/bv_specs.dart';
import '../../core/design/bv_tokens.dart';

enum BvAvatarSize { sm, md, lg, xl }

/// Spec §9 ("DS · Avatar & Badge"). A person is a circle; a company is a
/// rounded square. Without a photo it shows initials.
class BvAvatar extends StatelessWidget {
  const BvAvatar({
    super.key,
    required this.name,
    this.size = BvAvatarSize.md,
    this.company = false,
    this.image,
  });

  final String name;
  final BvAvatarSize size;
  final bool company;
  final ImageProvider? image;

  static double dimension(BvAvatarSize size) => switch (size) {
    BvAvatarSize.sm => BvAvatarSpec.sm,
    BvAvatarSize.md => BvAvatarSpec.md,
    BvAvatarSize.lg => BvAvatarSpec.lg,
    BvAvatarSize.xl => BvAvatarSpec.xl,
  };

  static BorderRadius companyRadius(BvAvatarSize size) => switch (size) {
    BvAvatarSize.sm || BvAvatarSize.md => BvAvatarSpec.companyRadiusSmall,
    BvAvatarSize.lg || BvAvatarSize.xl => BvAvatarSpec.companyRadiusLarge,
  };

  /// Up to two initials: first and last word. Arabic letters are kept
  /// apart (zero-width non-joiner) so they read as initials, not a word,
  /// and the prefixes "ال" and "لل" are skipped ("النور للمقاولات" → ن م).
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
    final letters = runes.map(String.fromCharCode);
    final arabic = runes.any(_isArabic);
    return arabic
        ? letters.join(String.fromCharCode(_zeroWidthNonJoiner))
        : letters.join().toUpperCase();
  }

  static int _initialRune(List<int> word) {
    final hasPrefix =
        word.length > _prefixLength + 1 &&
        (word[0] == _alef || word[0] == _lam) &&
        word[1] == _lam;
    return hasPrefix ? word[_prefixLength] : word.first;
  }

  static bool _isArabic(int rune) =>
      rune >= _arabicFirst && rune <= _arabicLast;

  // Unicode Arabic block, the letters of the prefixes, and the mark that
  // stops letters joining.
  static const _arabicFirst = 0x0600;
  static const _arabicLast = 0x06FF;
  static const _alef = 0x0627;
  static const _lam = 0x0644;
  static const _prefixLength = 2;
  static const _zeroWidthNonJoiner = 0x200C;

  @override
  Widget build(BuildContext context) {
    final type = BvType.of(context);
    final d = dimension(size);
    final style = switch (size) {
      BvAvatarSize.sm => type.labelSm,
      BvAvatarSize.md => type.labelMd,
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
          color: BvColors.surfaceSubtle,
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
                  initialsOf(name),
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
