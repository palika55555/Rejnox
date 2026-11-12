import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

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
    try {
      final token = await _tokens.read();
      if (token == null) {
        state = const SignedOut();
        return;
      }
      final user = await _repository.me(token);
      state = SignedIn(user: user, token: token);
    } on ApiError catch (e) {
      // Neplatný token zahodíme. Pri výpadku spojenia ho necháme na ďalší pokus.
      if (e.isUnauthorized) await _tokens.clear();
      state = const SignedOut();
    } on Exception {
      state = const SignedOut();
    }
  }

  /// Pri chybe vyhodí [ApiError] so správou pre používateľa.
  Future<void> login({required String email, required String password}) async {
    await _signIn(await _repository.login(email: email, password: password));
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

  Future<void> _signIn(AuthSession session) async {
    await _tokens.write(session.token);
    state = SignedIn(user: session.user, token: session.token);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
