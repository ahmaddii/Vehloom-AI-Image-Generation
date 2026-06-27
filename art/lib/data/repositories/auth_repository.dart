import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': username},
    );

    final user = response.user;
    // Only insert profile if they are fully logged in (e.g. Email Confirmations are OFF)
    if (user != null && response.session != null) {
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'username': username,
          'display_name': username,
          'bio': '',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // ignore if RLS prevents it
      }
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );

    final user = response.user;
    if (user != null && response.session != null) {
      final metadata = user.userMetadata ?? {};
      final username = metadata['username'] ?? email.split('@').first;

      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'username': username,
          'display_name': username,
          'bio': '',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // ignore if already exists or fails
      }
    }

    return response;
  }

  Future<void> resendOTP({required String email}) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }
}
