import 'bv_tokens.dart';

/// Review 113 ST1 (2730:40062): the Spaces tab, the first tab while the
/// feed is hidden. Its title and Messages · Notebook on top, one "N need
/// you" line, then each Space as a row (its emblem, its name, the pass and
/// whether anything is new today, its needs-you mark and ›), and the small
/// word buttons New Space · Join with a code at the end.
abstract final class BvSpacesTabSpec {
  static const barPaddingStart = BvSpace.gutter;
  static const barPaddingEnd = BvSpace.s8;
  static const barPaddingVertical = BvSpace.s2;

  static const listPaddingTop = BvSpace.s4;
  static const listPaddingBottom = BvSpace.s32;

  /// Under the needs-you line, before the first Space.
  static const needsGap = BvSpace.s8;

  static const rowMinHeight = 64.0;
  static const rowPaddingVertical = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const lineGap = BvSpace.s2;

  static const markGap = BvSpace.s8;

  /// The word buttons under the list: " · " between them.
  static const wordsTop = BvSpace.s8;
  static const wordGap = BvSpace.s4;
  static const wordIcon = BvSize.iconSm;

  /// The empty state's lines.
  static const emptyTop = BvSpace.s24;
  static const emptyGap = BvSpace.s12;
}
