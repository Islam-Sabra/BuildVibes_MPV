import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/models/market.dart';
import '../../data/models/people.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';

// ---------------------------------------------------------------------------
// Who is using the app
// ---------------------------------------------------------------------------

/// The signed-in user id; null when signed out.
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(authRepositoryProvider);
  yield auth.currentUserId;
  yield* auth.userIdChanges().distinct();
});

final myProfileProvider = FutureProvider<MyProfile?>((ref) async {
  final userId = ref.watch(authUserIdProvider).value;
  if (userId == null) return null;
  try {
    return await ref.watch(profileRepositoryProvider).fetchMine(userId);
  } catch (e) {
    debugPrint('Loading my profile failed: $e');
    rethrow;
  }
});

/// "Skip to Home": browsing without an account. Not kept across restarts.
final guestModeProvider = NotifierProvider<GuestMode, bool>(GuestMode.new);

class GuestMode extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;
  void leave() => state = false;
}

/// A Space invite code from an invite link. Set by the Spaces join flow
/// (week 4); with one, new accounts are open whatever the phone country.
final inviteCodeProvider = NotifierProvider<InviteCode, String?>(
  InviteCode.new,
);

class InviteCode extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

/// Phone sign-in on or off (decision 04: off in the MVP). A provider so
/// tests can switch it on.
final phoneSignInProvider = Provider<bool>((ref) => AppConfig.phoneSignIn);

/// The phone's region ("KW", "EG", …), used for the welcome pill and the
/// default country code. Overridden in tests.
final deviceRegionProvider = Provider<String?>(
  (ref) => PlatformDispatcher.instance.locale.countryCode,
);

/// Where the app should be.
enum AppGate { loading, signedOut, guest, onboarding, ready, profileError }

final appGateProvider = Provider<AppGate>((ref) {
  final user = ref.watch(authUserIdProvider);
  if (!user.hasValue) {
    return user.hasError ? AppGate.signedOut : AppGate.loading;
  }
  if (user.value == null) {
    return ref.watch(guestModeProvider) ? AppGate.guest : AppGate.signedOut;
  }
  final profile = ref.watch(myProfileProvider);
  final userId = user.value!;
  final p = profile.value;
  // While the profile reloads, keep the last answer only if it belongs to
  // the same person: right after signing in, the previous value is the
  // signed-out "no profile" and must not send a finished user to
  // onboarding.
  final stale = profile.isLoading && (p == null || p.id != userId);
  if (profile.hasValue && !stale) {
    return p != null && p.isComplete ? AppGate.ready : AppGate.onboarding;
  }
  return profile.hasError ? AppGate.profileError : AppGate.loading;
});

// ---------------------------------------------------------------------------
// Markets for entry
// ---------------------------------------------------------------------------

/// The market to show first: the phone's region when it is a market,
/// otherwise the first live market.
Market? defaultMarket(List<Market> markets, String? region) {
  final code = region?.toLowerCase();
  final regional = markets.where((m) => m.id == code).firstOrNull;
  return regional ??
      markets.where((m) => m.status == MarketStatus.live).firstOrNull;
}

List<Market> liveMarkets(List<Market> markets) =>
    markets.where((m) => m.status == MarketStatus.live).toList();

// ---------------------------------------------------------------------------
// The code in progress
// ---------------------------------------------------------------------------

enum EntryMethod { phone, email }

/// Where the 6-digit code was sent, kept while the person types it.
@immutable
class EntryDraft {
  const EntryDraft({
    required this.method,
    this.dialCode,
    this.national,
    this.market,
    this.channel = CodeChannel.whatsapp,
    this.email,
  });

  final EntryMethod method;
  final String? dialCode;
  final String? national;
  final Market? market;
  final CodeChannel channel;
  final String? email;

  String? get phoneE164 =>
      dialCode == null || national == null ? null : '$dialCode$national';
}

final entryDraftProvider = NotifierProvider<EntryDraftNotifier, EntryDraft?>(
  EntryDraftNotifier.new,
);

class EntryDraftNotifier extends Notifier<EntryDraft?> {
  @override
  EntryDraft? build() => null;

  void set(EntryDraft draft) => state = draft;
  void clear() => state = null;
}

/// What sign-up stores on the new user (read by handle_new_user).
Map<String, dynamic> signUpData({
  required String locale,
  Market? market,
  String? inviteCode,
}) => {
  'locale': locale,
  if (market != null && market.status == MarketStatus.live)
    'home_market_id': market.id,
  if (inviteCode != null && inviteCode.isNotEmpty) 'invite_code': inviteCode,
};
