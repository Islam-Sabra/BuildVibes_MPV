import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market.dart';
import '../supabase/supabase_provider.dart';

/// Why sending or checking a code failed, in words the screens can show.
enum AuthFailure {
  /// New accounts are not open for this phone country (and no invite).
  signupNotOpen,
  wrongCode,
  tooManyRequests,
  network,
  sendFailed,
  unknown,
}

class AuthFailureException implements Exception {
  const AuthFailureException(this.failure);
  final AuthFailure failure;

  @override
  String toString() => 'AuthFailureException($failure)';
}

enum SocialProvider { google, apple }

/// Sign-in without passwords: a 6-digit code by phone (WhatsApp or SMS) or
/// email, or Google / Apple.
abstract class AuthRepository {
  String? get currentUserId;

  /// The verified sign-in phone in E.164, when the person used one.
  String? get currentPhone;

  /// The signed-in account's email.
  String? get currentEmail;

  /// The Space invite code the account was created with, if any.
  String? get signUpInviteCode;

  /// Emits the signed-in user id, or null after signing out.
  Stream<String?> userIdChanges();

  /// Each time the sign-in token is new: refreshed, or signed in again.
  /// Live channels join again with it (F100).
  Stream<void> sessionRenewed();

  /// [allowSignUp] is false when new accounts are not open for this
  /// number: existing accounts still get a code.
  Future<void> sendPhoneCode({
    required String phoneE164,
    required CodeChannel channel,
    required bool allowSignUp,
    required Map<String, dynamic> signUpData,
  });

  Future<void> sendEmailCode({
    required String email,
    required Map<String, dynamic> signUpData,
  });

  Future<void> verifyPhoneCode({
    required String phoneE164,
    required String code,
  });

  Future<void> verifyEmailCode({required String email, required String code});

  /// S13: a fresh code to the signed-in account's email, never creating an
  /// account. Entering it (verifyEmailCode) refreshes the session's sign-in
  /// time, which the server checks before deleting (review 26).
  Future<void> sendConfirmCode(String email);

  Future<void> signInWith(SocialProvider provider);

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Where Google and Apple send people back to the app.
  static const redirectUrl = 'com.buildvibes.buildvibes://login-callback';

  GoTrueClient get _auth => _client.auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  String? get currentPhone {
    final phone = _auth.currentUser?.phone;
    if (phone == null || phone.isEmpty) return null;
    return phone.startsWith('+') ? phone : '+$phone';
  }

  @override
  String? get currentEmail {
    final email = _auth.currentUser?.email;
    return email == null || email.isEmpty ? null : email;
  }

  @override
  String? get signUpInviteCode {
    final code = _auth.currentUser?.userMetadata?['invite_code'];
    return code is String && code.isNotEmpty ? code : null;
  }

  @override
  Stream<String?> userIdChanges() =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Stream<void> sessionRenewed() => _auth.onAuthStateChange
      .where(
        (s) =>
            s.event == AuthChangeEvent.tokenRefreshed ||
            s.event == AuthChangeEvent.signedIn,
      )
      .map((_) {});

  @override
  Future<void> sendPhoneCode({
    required String phoneE164,
    required CodeChannel channel,
    required bool allowSignUp,
    required Map<String, dynamic> signUpData,
  }) => _guard(
    () => _auth.signInWithOtp(
      phone: phoneE164,
      channel: channel == CodeChannel.whatsapp
          ? OtpChannel.whatsapp
          : OtpChannel.sms,
      shouldCreateUser: allowSignUp,
      data: signUpData,
    ),
    sending: true,
  );

  @override
  Future<void> sendEmailCode({
    required String email,
    required Map<String, dynamic> signUpData,
  }) => _guard(
    () => _auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
      data: signUpData,
    ),
    sending: true,
  );

  @override
  Future<void> sendConfirmCode(String email) => _guard(
    () => _auth.signInWithOtp(email: email, shouldCreateUser: false),
    sending: true,
  );

  @override
  Future<void> verifyPhoneCode({
    required String phoneE164,
    required String code,
  }) => _guard(
    () => _auth.verifyOTP(type: OtpType.sms, phone: phoneE164, token: code),
  );

  @override
  Future<void> verifyEmailCode({required String email, required String code}) =>
      _guard(
        () => _auth.verifyOTP(type: OtpType.email, email: email, token: code),
      );

  @override
  Future<void> signInWith(SocialProvider provider) => _guard(
    () => _auth.signInWithOAuth(
      provider == SocialProvider.google
          ? OAuthProvider.google
          : OAuthProvider.apple,
      redirectTo: redirectUrl,
    ),
  );

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthRetryableFetchException {
      // The phone is already signed out (the session is removed before the
      // server is told). With no connection the server's copy just expires.
    } on SocketException {
      // The same, when the connection drops before Supabase wraps it.
    }
  }

  Future<void> _guard(
    Future<Object?> Function() run, {
    bool sending = false,
  }) async {
    try {
      await run();
    } on AuthException catch (e) {
      throw AuthFailureException(mapAuthError(e, sending: sending));
    } on SocketException {
      throw const AuthFailureException(AuthFailure.network);
    } on TimeoutException {
      throw const AuthFailureException(AuthFailure.network);
    }
  }
}

/// Maps a Supabase Auth error to what the person is told.
AuthFailure mapAuthError(AuthException e, {bool sending = false}) {
  final code = e.code ?? '';
  final message = e.message.toLowerCase();
  if (e is AuthRetryableFetchException) return AuthFailure.network;
  // The sign-up gate (migration 3 hook) or "shouldCreateUser: false".
  if (message.contains('signup_not_open_for_country') ||
      code == 'otp_disabled' ||
      message.contains('signups not allowed')) {
    return AuthFailure.signupNotOpen;
  }
  if (code.startsWith('over_') || e.statusCode == '429') {
    return AuthFailure.tooManyRequests;
  }
  if (code == 'otp_expired' || message.contains('token has expired')) {
    return AuthFailure.wrongCode;
  }
  return sending ? AuthFailure.sendFailed : AuthFailure.unknown;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);
