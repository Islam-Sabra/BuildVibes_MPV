import 'package:flutter/painting.dart';

import 'bv_tokens.dart';

/// Messages (DM1 2560:35524, AR 2564:745) and a thread (DM2 2561:35447,
/// AR 2563:170).
abstract final class BvMessagesSpec {
  /// The list's rows sit inside the gutter as cards when unread.
  static const listInset = BvSpace.s8;
  static const rowPadding = BvSpace.s12;
  static const rowGap = BvSpace.s12;
  static const rowRadius = BorderRadius.all(Radius.circular(BvRadius.toast));

  /// The unread dot at the end of a row (never a number, rule 3).
  static const dot = 8.0;

  /// The Message request card on top.
  static const requestRadius = BorderRadius.all(Radius.circular(BvRadius.card));
  static const requestMargin = BvSpace.s8;

  /// Today / Earlier.
  static const groupPaddingTop = BvSpace.s16;
  static const groupPaddingBottom = BvSpace.s8;

  /// The + button.
  static const fab = 56.0;
  static const fabMargin = BvSpace.s16;

  /// A photo from someone you haven't answered, covered until tapped
  /// (DM6 2571:35584).
  static const hiddenWidth = 220.0;
  static const hiddenHeight = 150.0;

  /// "Both in …" and the request strip under the thread's header.
  static const stripPaddingVertical = BvSpace.s8;

  /// F98: the person card at the start of a conversation.
  static const personPadding = BvSpace.s16;
  static const personGap = BvSpace.s4;
  static const personMarginBottom = BvSpace.s16;

  /// One page of messages (dm_thread_page's p_limit). Fewer: the page
  /// reaches the start of the conversation.
  static const pageSize = 50;
}
