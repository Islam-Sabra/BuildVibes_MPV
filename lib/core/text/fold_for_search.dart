import 'package:flutter/widgets.dart' show StringCharacters;

/// Words as a search compares them: lower case, Arabic letter forms and
/// digits folded as the server's search_fold does. The notebook's page
/// picker; review 122b, KP4's role examples.
String foldForSearch(String text) {
  const from = 'أإآٱىیةؤئک٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
  const to = 'ااااييهءءك01234567890123456789';
  final out = StringBuffer();
  for (final c in text.trim().toLowerCase().characters) {
    final i = from.indexOf(c);
    out.write(i < 0 || c.length != 1 ? c : to[i]);
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ');
}
