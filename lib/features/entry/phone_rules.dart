import '../../data/models/market.dart';
import '../../shared/widgets/bv_text_field.dart';

/// Phone number rules for entry (E2p). Pure functions: no Flutter, no
/// network, so they are easy to test.
abstract final class PhoneRules {
  static const minDigits = 6;
  static const maxDigits = 14;
  static final _nonDigits = RegExp(r'[^0-9]');

  /// Western digits only. Leading zeros are a local trunk prefix ("010…" in
  /// Egypt) and are dropped when a country code is chosen.
  static String national(String typed) => BvWesternDigitsFormatter.normalise(
    typed,
  ).replaceAll(_nonDigits, '').replaceFirst(RegExp('^0+'), '');

  /// "+965", "965" or "+ 91" → "+965" / "+91". Null when not a dial code.
  static String? dialCode(String typed) {
    final digits = BvWesternDigitsFormatter.normalise(
      typed,
    ).replaceAll(_nonDigits, '');
    if (digits.isEmpty || digits.length > 4 || digits.startsWith('0')) {
      return null;
    }
    return '+$digits';
  }

  /// True when [national] is a valid mobile number for [market], or, with
  /// no market (another country code), a plausible length.
  static bool isValid(String national, Market? market) {
    if (market != null) return market.isMobileNumber(national);
    return national.length >= minDigits && national.length <= maxDigits;
  }

  static Market? marketForDialCode(List<Market> markets, String dialCode) =>
      markets.where((m) => m.dialCode == dialCode).firstOrNull;

  /// The market of an E.164 number: the longest dial code that starts it,
  /// as the server's set_my_phone (review 121).
  static Market? marketForNumber(List<Market> markets, String e164) {
    final matching = [
      for (final m in markets)
        if (e164.startsWith(m.dialCode)) m,
    ]..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    return matching.firstOrNull;
  }

  /// An E.164 number spaced as its market writes it ("+965 5512 3456");
  /// as it is when no market knows it.
  static String formatE164(String e164, List<Market> markets) {
    final market = marketForNumber(markets, e164);
    if (market == null) return e164;
    final national = e164.substring(market.dialCode.length);
    return '${market.dialCode} ${format(national, example: market.phoneExample)}';
  }

  /// [typed] as [market]'s national digits, also when typed with its dial
  /// code in front ("+965 5512 3456").
  static String nationalIn(String typed, Market market) {
    final dial = market.dialCode.substring(1);
    final digits = BvWesternDigitsFormatter.normalise(
      typed,
    ).replaceAll(_nonDigits, '');
    final length = market.nationalLength;
    final withDial =
        typed.trim().startsWith('+') ||
        (length != null && digits.length == dial.length + length);
    return national(
      withDial && digits.startsWith(dial)
          ? digits.substring(dial.length)
          : digits,
    );
  }

  /// New accounts are open for a live market's numbers, and for anyone with
  /// a Space invite. Existing accounts always sign in. The server enforces
  /// the same rule (migration 3, hook_before_user_created).
  static bool canCreateAccount({Market? market, String? inviteCode}) =>
      (inviteCode != null && inviteCode.isNotEmpty) ||
      market?.status == MarketStatus.live;

  /// Groups the number like the market's example ("5000 0000",
  /// "100 000 0000"); otherwise in threes and fours.
  static String format(String national, {String? example}) {
    final groups = example == null
        ? <int>[]
        : [
            for (final g in example.split(RegExp(r'\s+')))
              if (g.isNotEmpty) g.length,
          ];
    if (groups.isEmpty || groups.fold(0, (a, b) => a + b) != national.length) {
      final out = StringBuffer();
      for (var i = 0; i < national.length; i++) {
        if (i > 0 && (national.length - i) % 4 == 0) out.write(' ');
        out.write(national[i]);
      }
      return out.toString();
    }
    final out = <String>[];
    var start = 0;
    for (final g in groups) {
      out.add(national.substring(start, start + g));
      start += g;
    }
    return out.join(' ');
  }
}
