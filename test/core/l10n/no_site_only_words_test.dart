import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Review 50 F4: BuildVibes is for the whole industry (rule 2), so no
/// general phrase assumes a site. The few that still say "site" or "موقع"
/// are listed here with why they stay; a new one must be added on purpose.
void main() {
  Map<String, String> strings(String lang) {
    final json =
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        if (!e.key.startsWith('@') && e.value is String)
          e.key: e.value as String,
    };
  }

  const fixed = [
    'postWritingHint',
    'feedEmpty',
    'spacesEmptyBody',
    'daybookPlaceHint',
    'spacesInviteHow',
  ];

  test('the general phrases no longer assume a site', () {
    final en = strings('en');
    final ar = strings('ar');
    for (final key in fixed) {
      expect(en[key], isNot(matches(RegExp('site', caseSensitive: false))));
      expect(ar[key], isNot(contains('موقع')));
    }
    expect(en['postWritingHint'], 'What happened at work today?');
    expect(en['daybookPlaceHint'], 'Where');
    expect(en.containsKey('homeDayTitle'), isFalse);
  });

  test('every other "site" or "موقع" is one that is meant', () {
    // "day N on site" and On site since: shown only when a Space admin
    // sets the day. The rest name a site among other places, or mean
    // "location" (الموقع in the project record).
    const kept = {
      'entryAudience2Title',
      'entryAudience6Body',
      'roleIntro',
      'matchSameSite',
      'cellLocation',
      'wrongLocation',
      'correctValueHelp',
      'daybookDateLine',
      'spacesOnSiteSince',
      'spacesOnSiteNote',
      // The daily report's first heading, as R2 and the built-in Daily
      // report (key on_site) name it (slice 7).
      'dailyReportOnSite',
    };
    final en = strings('en');
    final ar = strings('ar');
    final found = {
      for (final e in en.entries)
        if (e.value.toLowerCase().contains('site')) e.key,
      for (final e in ar.entries)
        if (e.value.contains('موقع')) e.key,
    };
    expect(found.difference(kept), isEmpty);
  });
}
