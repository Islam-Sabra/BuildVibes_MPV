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
