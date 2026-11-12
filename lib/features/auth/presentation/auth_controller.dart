import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';
import 'celebration_state.dart';

sealed class AuthState {
  const AuthState();
}

/// Appka sa práve spustila a zisťuje, či je niekto prihlásený.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn({required this.user, required this.token});

  final AuthUser user;
  final String token;
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  AuthState build() {
    _restore();
    return const AuthRestoring();
  }

  Future<void> _restore() async {
    String? token;
    AuthUser? cached;
    try {
      token = await _tokens.read();
      cached = token == null ? null : await _tokens.readUser();
    } on Object {
      token = null;
    }
    if (token == null) {
      state = const SignedOut();
      return;
    }

    // So zapamätaným profilom appka naskočí hneď, aj bez internetu.
    if (cached != null) state = SignedIn(user: cached, token: token);

    try {
      final user = await _repository.me(token);
      await _tokens.writeUser(user);
      state = SignedIn(user: user, token: token);
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        // Token už neplatí (odhlásenie inde, zmazaný účet): preč s ním.
        await _tokens.clear();
        state = const SignedOut();
      } else if (cached == null) {
        // Bez spojenia a bez profilu nevieme, kto je prihlásený.
        // Token ostáva na ďalší pokus.
        state = const SignedOut();
      }
    } on Exception {
      if (cached == null) state = const SignedOut();
    }
  }

  /// Pri chybe vyhodí [ApiError] so správou pre používateľa.
  Future<void> login({required String email, required String password}) async {
    await _signIn(
      await _repository.login(email: email, password: password),
      registered: false,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    await _signIn(
      await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      ),
      registered: true,
    );
  }

  Future<void> logout() async {
    final current = state;
    await _tokens.clear();
    state = const SignedOut();
    if (current is SignedIn) {
      try {
        await _repository.logout(current.token);
      } on ApiError {
        // Token je z telefónu preč; na serveri vyprší sám.
      }
    }
  }

  Future<void> _signIn(AuthSession session, {required bool registered}) async {
    await _tokens.write(session.token);
    await _tokens.writeUser(session.user);
    state = SignedIn(user: session.user, token: session.token);
    // Oslava len po ručnom prihlásení / registrácii, nie pri obnovení relácie.
    ref
        .read(celebrationProvider.notifier)
        .show(
          Celebration(
            firstName: session.user.firstName,
            registered: registered,
          ),
        );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
