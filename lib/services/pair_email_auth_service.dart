import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PairEmailAuthService {
  bool get isEmailVerified;
  String? get email;

  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  void clearPendingCode();
}

class SupabasePairEmailAuthService implements PairEmailAuthService {
  SupabasePairEmailAuthService(this.auth);

  final GoTrueClient auth;
  String? _pendingEmail;
  OtpType? _pendingType;
  String? _anonymousUserIdToConvert;

  @override
  bool get isEmailVerified {
    final user = auth.currentUser;
    return user != null &&
        !user.isAnonymous &&
        user.email != null &&
        user.emailConfirmedAt != null;
  }

  @override
  String? get email => auth.currentUser?.email;

  @override
  Future<void> sendCode(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const FormatException('Email is required.');
    }
    _pendingEmail = null;
    _pendingType = null;

    final currentUser = auth.currentUser;
    if (currentUser?.isAnonymous == true) {
      _anonymousUserIdToConvert = currentUser!.id;
    }
    if (_anonymousUserIdToConvert != null &&
        currentUser?.id == _anonymousUserIdToConvert &&
        !isEmailVerified) {
      await auth.updateUser(UserAttributes(email: normalizedEmail));
      _pendingType = OtpType.emailChange;
    } else {
      await auth.signInWithOtp(email: normalizedEmail);
      _pendingType = OtpType.email;
    }
    _pendingEmail = normalizedEmail;
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_pendingEmail != normalizedEmail || _pendingType == null) {
      throw const FormatException('Request an email code first.');
    }
    final response = await auth.verifyOTP(
      email: normalizedEmail,
      token: code.trim(),
      type: _pendingType!,
    );
    if (response.user == null ||
        response.user!.isAnonymous ||
        response.user!.emailConfirmedAt == null) {
      throw const AuthException('Email confirmation is required.');
    }
    _pendingEmail = null;
    _pendingType = null;
  }

  @override
  void clearPendingCode() {
    _pendingEmail = null;
    _pendingType = null;
  }
}
