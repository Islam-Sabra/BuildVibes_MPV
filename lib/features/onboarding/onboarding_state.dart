import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/market.dart';
import '../../data/models/space.dart';
import '../../data/repositories/space_repository.dart';
import '../entry/entry_state.dart';

/// The name typed in OB4, kept until OB5 saves it with the work (review
/// 107): one save, with "Saving…", once both are known.
typedef OnboardingName = ({String first, String last});

final onboardingNameProvider =
    NotifierProvider<OnboardingNameDraft, OnboardingName?>(
      OnboardingNameDraft.new,
    );

class OnboardingNameDraft extends Notifier<OnboardingName?> {
  @override
  OnboardingName? build() => null;

  void set(OnboardingName name) => state = name;
}

/// The Space invite code this person came with: [typed] on the welcome
/// (or OB4's Change code), else the one [signUp] kept on the account. Null
/// without one, and after Skip, which sets an empty code.
String? onboardingInviteCode(String? typed, String? signUp) {
  final code = typed ?? signUp;
  return code == null || code.isEmpty ? null : code;
}

/// What a kept invite code opens, once signed in (review 107 Q1): null for
/// a code that is wrong, expired or refused.
final onboardingInviteProvider = FutureProvider.family<InvitePreview?, String>(
  (ref, code) => ref.read(spaceRepositoryProvider).invitePreview(code),
);

/// Set while OB5 saves and moves on: the profile is complete then, and your
/// work stays open until it does (review 107 Q5).
final onboardingFinishingProvider = NotifierProvider<OnboardingFinishing, bool>(
  OnboardingFinishing.new,
);

class OnboardingFinishing extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

/// The home market, taken without asking (review 107): the one the account
/// was created with; otherwise the phone's region when it is a live market
/// (with an invite, any market: the server lets invited people choose,
/// decision 04), else the first live market. Null while the markets load.
String? homeMarketWithoutAsking({
  required List<Market> markets,
  required String? region,
  required String? accountMarketId,
  required bool invited,
}) {
  bool may(Market m) => invited || m.status == MarketStatus.live;
  final code = region?.toLowerCase();
  return markets
          .where((m) => m.id == accountMarketId && may(m))
          .firstOrNull
          ?.id ??
      markets.where((m) => m.id == code && may(m)).firstOrNull?.id ??
      liveMarkets(markets).firstOrNull?.id;
}
