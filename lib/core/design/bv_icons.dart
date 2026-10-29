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

  // A page's Collapse all · Expand all (review 106 T2): arrows-in-line-
  // vertical, arrows-out-line-vertical. Up and down don't mirror.
  static const collapseAll = IconData(0xe532, fontFamily: _family);
  static const expandAll = IconData(0xe536, fontFamily: _family);
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
  // Phosphor: sign-out. An arrow leaving, so it mirrors in right to left.
  static const signOut = IconData(
    0xe42a,
    fontFamily: _family,
    matchTextDirection: true,
  );

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

  // Phosphor: user-switch (Hand over Space admin)
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

  // Phosphor: seal-check (Useful on post cards and the post page, H1 v4
  // 2587:35849; review 54: "Useful" is not "Like", so no thumbs-up).
  // PhosphorIconsRegular.sealCheck in phosphor_flutter 2.1.0, the source
  // of the bundled font.
  static const useful = IconData(0xe606, fontFamily: _family);

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

  /// text-indent and text-outdent: a note's line in or out a level
  /// (review 93); in Arabic, in is to the left.
  static const indent = IconData(
    0xea1e,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const outdent = IconData(
    0xea1c,
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

  /// Share again (review 106 T5): the same turning arrow.
  static const shareAgain = sendBack;

  /// arrow-counter-clockwise again: a numbered list's Restart at 1.
  static const restartNumbering = sendBack;

  /// The line menu (review 98 NBY2): arrow-clockwise for Turn into (it
  /// mirrors), caret-up for Move up, caret-down for Move down, copy for
  /// Duplicate.
  static const turnInto = IconData(
    0xe036,
    fontFamily: _family,
    matchTextDirection: true,
  );
  static const moveUp = IconData(0xe13c, fontFamily: _family);
  static const moveDown = caretDown;
  static const duplicate = copy;

  /// plus: add an update (the bottom bar's Create is the same glyph).
  static const add = create;

  /// user: a person (give to someone, assign).
  static const person = profile;

  /// info: an announcement.
  static const info = about;

  /// calendar-blank: a due date.
  static const due = month;

  /// push-pin: an announcement pinned under the masthead.
  static const pin = IconData(0xe3e2, fontFamily: _family);

  /// bell: Remind me on a note (review 88 S3); the calendar glyph is My
  /// calendar.
  static const remind = activity;

  /// bell-slash: notifications aren't reaching this phone (F9).
  static const notificationsOff = IconData(0xe0d4, fontFamily: _family);

  /// bell-slash: a muted Space or conversation, beside its name (F102).
  static const muted = notificationsOff;

  /// arrow-down and arrow-up: "New" entries below (the Daybook's Now) or
  /// above (the Home feed's top). Up and down don't mirror.
  static const newBelow = IconData(0xe03e, fontFamily: _family);
  static const newAbove = IconData(0xe08e, fontFamily: _family);

  // The page's blocks (slice 5, N2–N3).
  // Phosphor: text-t (a text block)
  static const textBlock = IconData(0xe48a, fontFamily: _family);
  // Phosphor: text-h (a heading)
  static const headingBlock = IconData(0xe6ba, fontFamily: _family);
  // Phosphor: table
  static const tableBlock = IconData(0xe476, fontFamily: _family);
  // Phosphor: dots-six-vertical (⋮⋮, hold to move a block)
  static const dragHandle = IconData(0xeae2, fontFamily: _family);
  // Phosphor: square (a point not ticked, while the page is edited)
  static const checkbox = IconData(0xe45e, fontFamily: _family);

  // A note's categories (F107 NBX2 2619:36808), in the grid's order.
  // Phosphor: text-h-one, text-h-two
  static const headingOne = IconData(0xe6bc, fontFamily: _family);
  static const headingTwo = IconData(0xe6be, fontFamily: _family);
  // Phosphor: check-square (a to-do list)
  static const todoList = IconData(0xe186, fontFamily: _family);
  // Phosphor: list-bullets, list-numbers
  static const bulletList = IconData(0xe2f2, fontFamily: _family);
  static const numberList = IconData(0xe2f6, fontFamily: _family);
  // Phosphor: quotes
  static const quote = IconData(0xe660, fontFamily: _family);
  // Phosphor: minus (a divider)
  static const divider = IconData(0xe32a, fontFamily: _family);

  // Planning (slice 8)
  // Phosphor: notebook. My notebook: Home's way in (review 84 N1;
  // list-checks is the work item), the empty notebook, and Save to my
  // notebook on a held message.
  static const notebook = IconData(0xe34e, fontFamily: _family);

  // Notebook pages (review 99A). A page's icon is one of twelve: folder
  // (folder-simple), hard hat, building (building-office), phone, list
  // (list-checks), calendar, camera, warning, star, wrench, ruler and
  // notebook.
  static const pageFolder = library;
  static const pageHardHat = trade;
  // Phosphor: building-office
  static const pageBuilding = IconData(0xe0ff, fontFamily: _family);
  static const pageList = workItems;
  // Phosphor: phone (a handset; BvIcons.phone is the mobile phone).
  static const pagePhone = IconData(0xe3b8, fontFamily: _family);
  // Phosphor: star
  static const pageStar = IconData(0xe46a, fontFamily: _family);
  // Phosphor: wrench
  static const pageWrench = IconData(0xe5d4, fontFamily: _family);
  // Phosphor: tree-structure. Merge pages (PG5).
  static const merge = IconData(0xe67c, fontFamily: _family);
  // Move into… a page (PG5): folder-simple.
  static const moveInto = library;
  // A page's open to-dos (PG1): list-checks.
  static const openTodos = workItems;

  // Review 100: Phosphor archive (an entry's swipe toward the start),
  // funnel-simple (the notebook's Filter), arrow-bend-up-right (Share),
  // megaphone (Share to the feed).
  static const archive = IconData(0xe00c, fontFamily: _family);
  static const filter = IconData(0xe268, fontFamily: _family);
  static const shareEntry = IconData(
    0xe026,
    fontFamily: _family,
    matchTextDirection: true,
  );

  // Review 100 H19: a Draft's Discard (Phosphor x-circle).
  static const discard = declined;
  static const feed = IconData(0xe324, fontFamily: _family);

  // Review 102 N5, the Filter card's SORT (Phosphor clock-counter-clockwise,
  // text-aa, calendar-plus, sort-descending, sort-ascending).
  static const sortActivity = IconData(0xe1a0, fontFamily: _family);
  static const sortName = IconData(0xe6ee, fontFamily: _family);
  static const sortCreated = IconData(0xe714, fontFamily: _family);
  static const sortNewest = IconData(0xe446, fontFamily: _family);
  static const sortOldest = IconData(0xe444, fontFamily: _family);

  // Review 104 N7: Oldest created and Type (Phosphor calendar-blank,
  // shapes).
  static const sortOldestCreated = IconData(0xe10a, fontFamily: _family);
  static const sortType = IconData(0xec5e, fontFamily: _family);

  // Review 104 N11: the time picker's mode switch (Phosphor clock,
  // list-numbers).
  static const timeClock = scheduled;
  static const timeWheels = IconData(0xe2f6, fontFamily: _family);
}
