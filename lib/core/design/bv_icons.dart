// BuildVibes icons: Phosphor, regular weight (the Figma icon set).
//
// Rules:
// - Widgets use BvIcons only. Never use Material `Icons.*`.
// - One glyph per meaning. Active tabs use the same glyph as inactive tabs.
// - Only arrows and carets mirror in right-to-left. Mirroring is set per icon.
//
// The font is bundled in assets/fonts (family "PhosphorRegular"), not used
// through the phosphor_flutter package: its latest version (2.1.0) doesn't
// compile on Flutter 3.44. Code points come from that package's
// `PhosphorIconsRegular` table. See assets/fonts/SOURCE.md.

import 'package:flutter/widgets.dart';

abstract final class BvIcons {
  static const _family = 'PhosphorRegular';

  // Bottom bar
  // Phosphor: house
  static const home = IconData(0xe2c2, fontFamily: _family);
  // Phosphor: compass
  static const explore = IconData(0xe1c8, fontFamily: _family);
  // Phosphor: plus
  static const create = IconData(0xe3d4, fontFamily: _family);
  // Phosphor: bell
  static const activity = IconData(0xe0ce, fontFamily: _family);
  // Phosphor: user
  static const profile = IconData(0xe4c2, fontFamily: _family);

  // General
  // Phosphor: magnifying-glass
  static const search = IconData(0xe30c, fontFamily: _family);
  // Phosphor: x
  static const close = IconData(0xe4f6, fontFamily: _family);
  // Phosphor: check
  static const check = IconData(0xe182, fontFamily: _family);
  // Phosphor: translate
  static const language = IconData(0xe4a2, fontFamily: _family);

  // Phosphor: warning-circle
  static const warning = IconData(0xe4e2, fontFamily: _family);
  // Phosphor: caret-down
  static const caretDown = IconData(0xe136, fontFamily: _family);
  // Phosphor: map-pin
  static const place = IconData(0xe316, fontFamily: _family);
  // Phosphor: camera
  static const camera = IconData(0xe10e, fontFamily: _family);
  // Phosphor: image
  static const image = IconData(0xe2ca, fontFamily: _family);
  // Phosphor: eye-slash
  static const unavailable = IconData(0xe224, fontFamily: _family);
  // Phosphor: lock
  static const lock = IconData(0xe2fa, fontFamily: _family);
  // Phosphor: flag (Report)
  static const report = IconData(0xe244, fontFamily: _family);
  // Phosphor: prohibit (Block)
  static const block = IconData(0xe3de, fontFamily: _family);
  // Phosphor: globe
  static const everyone = IconData(0xe288, fontFamily: _family);
  // Phosphor: users
  static const people = IconData(0xe4d6, fontFamily: _family);
  // Phosphor: users-three
  static const team = IconData(0xe68e, fontFamily: _family);
  // Phosphor: buildings
  static const company = IconData(0xe102, fontFamily: _family);
  // Phosphor: hard-hat
  static const trade = IconData(0xed46, fontFamily: _family);
  // Phosphor: bell-simple
  static const notifications = IconData(0xe0d0, fontFamily: _family);
  // Phosphor: chat-circle
  static const chat = IconData(0xe168, fontFamily: _family);
  // Phosphor: list-checks
  static const workItems = IconData(0xeadc, fontFamily: _family);
  // Phosphor: shield-check
  static const pass = IconData(0xe40c, fontFamily: _family);
  // Phosphor: folder-simple (the Space's Library tab, MN1)
  static const library = IconData(0xe25a, fontFamily: _family);
  // Phosphor: calendar
  static const calendar = IconData(0xe108, fontFamily: _family);
  // Phosphor: gear
  static const settings = IconData(0xe270, fontFamily: _family);
  // Phosphor: sign-out
  static const signOut = IconData(0xe42a, fontFamily: _family);

  // Phosphor: google-logo
  static const google = IconData(0xe292, fontFamily: _family);
  // Phosphor: apple-logo
  static const apple = IconData(0xe516, fontFamily: _family);
  // Phosphor: linkedin-logo
  static const linkedIn = IconData(0xe2ee, fontFamily: _family);
  // Phosphor: seal-check
  static const confirmed = IconData(0xe606, fontFamily: _family);
  // Phosphor: check-circle
  static const checkCircle = IconData(0xe184, fontFamily: _family);
  // Phosphor: envelope-simple
  static const email = IconData(0xe218, fontFamily: _family);
  // Phosphor: device-mobile
  static const phone = IconData(0xe1e0, fontFamily: _family);
  // Phosphor: briefcase
  static const briefcase = IconData(0xe0ee, fontFamily: _family);
  // Phosphor: crane
  static const crane = IconData(0xed48, fontFamily: _family);
  // Phosphor: hammer
  static const hammer = IconData(0xe80e, fontFamily: _family);
  // Phosphor: truck
  static const truck = IconData(0xe4b4, fontFamily: _family);
  // Phosphor: cube
  static const cube = IconData(0xe1da, fontFamily: _family);
  // Phosphor: ruler
  static const ruler = IconData(0xe6b8, fontFamily: _family);
  // Phosphor: clipboard-text
  static const clipboard = IconData(0xe198, fontFamily: _family);

  // Phosphor: dots-three
  static const more = IconData(0xe1fe, fontFamily: _family);

  // Phosphor: user-plus (Invite people)
  static const invite = IconData(0xe4d0, fontFamily: _family);

  // Phosphor: user-switch (Transfer ownership)
  static const transfer = IconData(0xe756, fontFamily: _family);

  // Phosphor: paper-plane-right (send a comment)
  static const send = IconData(
    0xe396,
    fontFamily: _family,
    matchTextDirection: true,
  );

  // Phosphor: paperclip (attach in chat, S8k)
  static const attach = IconData(0xe39a, fontFamily: _family);

  // Phosphor: file-text (a PDF drawing in the Library and chat)
  static const document = IconData(0xe23a, fontFamily: _family);

  // Phosphor: download-simple (F1 Download)
  static const download = IconData(0xe20c, fontFamily: _family);

  // Phosphor: upload-simple (upload a new revision)
  static const upload = IconData(0xe4c0, fontFamily: _family);

  // Phosphor: share-fat (F1: share the file through the phone). An arrow
  // shape, so it mirrors in right to left.
  static const shareFile = IconData(
    0xed52,
    fontFamily: _family,
    matchTextDirection: true,
  );

  // Phosphor: microphone (hold to record a voice note, S8k)
  static const microphone = IconData(0xe326, fontFamily: _family);

  // Phosphor: play and pause (voice notes). Media controls keep their
  // shape in right to left.
  static const play = IconData(0xe3d0, fontFamily: _family);
  static const pause = IconData(0xe39e, fontFamily: _family);

  // Phosphor: thumbs-up (Useful on posts and replies, H1)
  static const useful = IconData(0xe48e, fontFamily: _family);

  // Phosphor: translate (the post language line, L5)
  static const postLanguage = IconData(0xe4a2, fontFamily: _family);

  // Phosphor: copy (copy a message, S8b)
  static const copy = IconData(0xe1ca, fontFamily: _family);

  // Phosphor: arrow-bend-up-left (replying to a message). An arrow, so it
  // mirrors in right to left.
  static const reply = IconData(
    0xe024,
    fontFamily: _family,
    matchTextDirection: true,
  );

  // Phosphor: share-network (share an invite code)
  static const share = IconData(0xe408, fontFamily: _family);

  // Phosphor: hourglass (a join request waiting for the Space admin)
  static const waiting = IconData(0xe2b2, fontFamily: _family);

  // Phosphor: x-circle (a join request that was not confirmed)
  static const declined = IconData(0xe4f8, fontFamily: _family);

  // Phosphor: pencil-simple
  static const edit = IconData(0xe3b4, fontFamily: _family);
  // Phosphor: trash
  static const delete = IconData(0xe4a6, fontFamily: _family);
  // Phosphor: calendar-blank
  static const month = IconData(0xe10a, fontFamily: _family);

  // Settings and account (week 8 part 2)
  // Phosphor: shield-check (Account and security)
  static const security = IconData(0xe40c, fontFamily: _family);
  // Phosphor: question (Help and feedback)
  static const help = IconData(0xe3e8, fontFamily: _family);
  // Phosphor: info (About BuildVibes and legal)
  static const about = IconData(0xe2ce, fontFamily: _family);
  // Phosphor: globe-hemisphere-west (the country, S8)
  static const country = IconData(0xe28c, fontFamily: _family);
  // Phosphor: clock (deletion scheduled, S14)
  static const scheduled = IconData(0xe19a, fontFamily: _family);
  // Phosphor: seal-check (request received, S11)
  static const received = IconData(0xe606, fontFamily: _family);

  // Directional: mirrored in right-to-left.
  /// Points to the next screen: right in English, left in Arabic.
  static const caretForward = IconData(
    0xe13a,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const caretBack = IconData(
    0xe138,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const arrowForward = IconData(
    0xe06c,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const arrowBack = IconData(
    0xe058,
    fontFamily: _family,
    matchTextDirection: true,
  );

  // The Daybook.
  /// arrow-counter-clockwise: Send back. A turning arrow, so it mirrors.
  static const sendBack = IconData(
    0xe038,
    fontFamily: _family,
    matchTextDirection: true,
  );

  /// plus: add an update (the bottom bar's Create is the same glyph).
  static const add = create;

  /// user: a person (give to someone, assign).
  static const person = profile;

  /// info: an announcement.
  static const info = about;

  /// calendar-blank: a due date.
  static const due = month;

  /// bell-slash: notifications aren't reaching this phone (F9).
  static const notificationsOff = IconData(0xe0d4, fontFamily: _family);

  /// arrow-down and arrow-up: "New" entries below (the Daybook's Now) or
  /// above (the Home feed's top). Up and down don't mirror.
  static const newBelow = IconData(0xe03e, fontFamily: _family);
  static const newAbove = IconData(0xe08e, fontFamily: _family);
}
