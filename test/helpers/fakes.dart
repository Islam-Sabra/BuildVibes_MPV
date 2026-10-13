import 'dart:async';

import 'package:buildvibes/data/models/market.dart';
import 'package:buildvibes/data/models/people.dart';
import 'package:buildvibes/data/repositories/auth_repository.dart';
import 'package:buildvibes/data/repositories/profile_repository.dart';
import 'package:buildvibes/data/repositories/reference_repository.dart';

// ---------------------------------------------------------------------------
// Market pack fixtures (shaped like migration 1 rows)
// ---------------------------------------------------------------------------

final kuwait = Market.fromJson({
  'id': 'kw',
  'status': 'live',
  'name': {'en': 'Kuwait', 'ar': 'الكويت'},
  'default_locale': 'ar',
  'dial_code': '+965',
  'phone_rules': {
    'national_length': 8,
    'mobile_prefixes': ['5', '6', '9'],
    'example': '5000 0000',
  },
  'code_channel': 'whatsapp',
  'currency': 'KWD',
  'currency_decimals': 3,
  'week_start': 0,
  'weekend': [5, 6],
  'needs_review': ['phone_rules'],
  'support_email': 'help@example.com',
  'legal': {
    'terms': {
      'en': 'https://example.com/terms',
      'ar': 'https://example.com/ar/terms',
    },
  },
});

final egypt = Market.fromJson({
  'id': 'eg',
  'status': 'soon',
  'name': {'en': 'Egypt', 'ar': 'مصر'},
  'default_locale': 'ar',
  'dial_code': '+20',
  'phone_rules': {
    'national_length': 10,
    'mobile_prefixes': ['10', '11', '12', '15'],
    'example': '100 000 0000',
  },
  'code_channel': 'whatsapp',
  'currency': 'EGP',
  'currency_decimals': 2,
  'week_start': 6,
  'weekend': [5, 6],
  'needs_review': ['phone_rules', 'status'],
});

final testMarkets = [kuwait, egypt];

Map<String, dynamic> _label(String en, String ar) => {'en': en, 'ar': ar};

final testRolePicker = buildRolePicker(
  families: [
    {'id': 'trades', 'name': _label('Site and trades', 'الموقع والحِرف')},
    {
      'id': 'engineering',
      'name': _label('Engineering and design', 'الهندسة والتصميم'),
    },
    {
      'id': 'management',
      'name': _label('Management and supply', 'الإدارة والتوريد'),
    },
  ],
  trades: [
    {
      'id': 'electrician',
      'family_id': 'trades',
      'name': _label('Electrician', 'كهربائي'),
      'description': _label(
        'Wiring, panels, testing',
        'تمديدات ولوحات واختبارات',
      ),
    },
    {
      'id': 'steel_fixer',
      'family_id': 'trades',
      'name': _label('Steel fixer', 'حدّاد تسليح'),
      'description': _label(
        'Rebar cutting and fixing',
        'قص وتركيب حديد التسليح',
      ),
    },
    {
      'id': 'site_engineer',
      'family_id': 'engineering',
      'name': _label('Site engineer', 'مهندس موقع'),
      'description': _label(
        'Runs the work on site day to day',
        'يدير العمل في الموقع يومياً',
      ),
    },
    {
      'id': 'foreman',
      'family_id': 'management',
      'name': _label('Foreman', 'رئيس عمال'),
      'description': _label('Leads a crew on site', 'يقود فريق عمل في الموقع'),
    },
    {'id': 'other', 'family_id': 'management', 'name': _label('Other', 'أخرى')},
  ],
  marketTrades: [
    {'trade_id': 'site_engineer', 'popular_sort': 1},
    {'trade_id': 'electrician', 'popular_sort': 2},
    {'trade_id': 'steel_fixer'},
    {'trade_id': 'foreman'},
    {'trade_id': 'other'},
  ],
);

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

typedef SentCode = ({
  String to,
  CodeChannel? channel,
  bool allowSignUp,
  Map<String, dynamic> data,
});

/// Behaves like Supabase Auth with test numbers: the code is [validCode];
/// new numbers are refused when sign-up is not allowed.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.userId, this.phone});

  final _changes = StreamController<String?>.broadcast();
  String? userId;
  String? phone;

  /// Accounts that already exist, by phone or email.
  final existing = <String>{};
  final sent = <SentCode>[];
  String validCode = '123456';
  AuthFailure? sendFailure;
  var signOuts = 0;

  /// The id given to a newly signed-in user.
  static const newUserId = 'user-new';

  @override
  String? get currentUserId => userId;

  @override
  String? get currentPhone => phone;

  /// The signed-in account's email (S10, S13).
  String? email = 'omar@example.com';

  @override
  String? get currentEmail => userId == null ? null : email;

  /// S13 codes sent to the signed-in account.
  final confirmCodes = <String>[];

  @override
  Future<void> sendConfirmCode(String email) async {
    if (sendFailure != null) throw AuthFailureException(sendFailure!);
    confirmCodes.add(email);
  }

  /// The invite code the account was created with.
  String? inviteCode;

  @override
  String? get signUpInviteCode => inviteCode;

  @override
  Stream<String?> userIdChanges() => _changes.stream;

  void _signIn(String? signedInPhone) {
    userId = newUserId;
    phone = signedInPhone;
    _changes.add(userId);
  }

  @override
  Future<void> sendPhoneCode({
    required String phoneE164,
    required CodeChannel channel,
    required bool allowSignUp,
    required Map<String, dynamic> signUpData,
  }) async {
    if (sendFailure != null) throw AuthFailureException(sendFailure!);
    if (!allowSignUp && !existing.contains(phoneE164)) {
      throw const AuthFailureException(AuthFailure.signupNotOpen);
    }
    sent.add((
      to: phoneE164,
      channel: channel,
      allowSignUp: allowSignUp,
      data: signUpData,
    ));
  }

  @override
  Future<void> sendEmailCode({
    required String email,
    required Map<String, dynamic> signUpData,
  }) async {
    if (sendFailure != null) throw AuthFailureException(sendFailure!);
    sent.add((to: email, channel: null, allowSignUp: true, data: signUpData));
  }

  @override
  Future<void> verifyPhoneCode({
    required String phoneE164,
    required String code,
  }) async {
    if (code != validCode) {
      throw const AuthFailureException(AuthFailure.wrongCode);
    }
    _signIn(phoneE164);
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    if (code != validCode) {
      throw const AuthFailureException(AuthFailure.wrongCode);
    }
    // Already signed in (S13): the same account, a fresh session.
    if (userId != null) return;
    _signIn(null);
  }

  @override
  Future<void> signInWith(SocialProvider provider) async {}

  @override
  Future<void> signOut() async {
    signOuts++;
    userId = null;
    phone = null;
    _changes.add(null);
  }
}

/// In-memory profiles. A new user gets an empty profile, like the
/// handle_new_user trigger.
class FakeProfileRepository implements ProfileRepository {
  final profiles = <String, MyProfile>{};
  final companies = <CompanySummary>[
    const CompanySummary(id: 'co-1', name: 'Gulf Build Co.'),
  ];
  var suggested = <PersonSuggestion>[];
  final follows = <String>{};
  AboutYouInput? lastSaved;

  /// How long fetchMine takes, like a real network call.
  Duration fetchDelay = Duration.zero;

  @override
  Future<MyProfile?> fetchMine(String userId) async {
    if (fetchDelay > Duration.zero) await Future<void>.delayed(fetchDelay);
    return _fetchMine(userId);
  }

  MyProfile? _fetchMine(String userId) => profiles.putIfAbsent(
    userId,
    () => MyProfile(id: userId, firstName: '', lastName: '', locale: 'en'),
  );

  @override
  Future<void> saveAboutYou(String userId, AboutYouInput input) async {
    lastSaved = input;
    final company = companies.where((c) => c.id == input.companyId).firstOrNull;
    profiles[userId] = MyProfile(
      id: userId,
      firstName: input.firstName.trim(),
      lastName: input.lastName.trim(),
      locale: input.locale,
      tradeId: input.role.trade.id,
      tradeName: input.role.trade.name,
      headline: input.role.customText,
      homeMarketId: input.homeMarketId,
      companyId: input.companyId,
      companyName: company?.name,
      companyNameText: input.companyNameText,
    );
  }

  @override
  Future<List<CompanySummary>> searchCompanies(
    String query, {
    String? marketId,
  }) async => companies
      .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
      .toList();

  @override
  Future<List<PersonSuggestion>> suggestions(MyProfile me) async => suggested;

  @override
  Future<Set<String>> following(String userId) async => {...follows};

  @override
  Future<void> follow(String userId, String otherId) async =>
      follows.add(otherId);

  @override
  Future<void> unfollow(String userId, String otherId) async =>
      follows.remove(otherId);
}

class FakeReferenceRepository implements ReferenceRepository {
  @override
  Future<RolePicker> fetchRolePicker(String marketId) async => testRolePicker;
}

/// A profile that has finished onboarding step 1.
MyProfile completeProfile(String id) => const MyProfile(
  id: 'placeholder',
  firstName: 'Omar',
  lastName: 'Haddad',
  locale: 'en',
  tradeId: 'site_engineer',
  homeMarketId: 'kw',
).copyWithId(id);

extension MyProfileCopy on MyProfile {
  MyProfile copyWithNames(String first, String last, {String? tradeId}) =>
      MyProfile(
        id: id,
        firstName: first,
        lastName: last,
        locale: locale,
        tradeId: tradeId ?? this.tradeId,
        tradeName: tradeName,
        headline: headline,
        homeMarketId: homeMarketId,
        placeId: placeId,
        companyId: companyId,
        companyName: companyName,
        companyNameText: companyNameText,
      );
}

extension on MyProfile {
  MyProfile copyWithId(String id) => MyProfile(
    id: id,
    firstName: firstName,
    lastName: lastName,
    locale: locale,
    tradeId: tradeId,
    tradeName: tradeName,
    homeMarketId: homeMarketId,
  );
}
