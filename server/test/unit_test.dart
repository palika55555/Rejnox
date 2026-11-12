import 'package:rejnox_server/src/auth/validators.dart';
import 'package:rejnox_server/src/http/api_exception.dart';
import 'package:rejnox_server/src/http/rate_limiter.dart';
import 'package:test/test.dart';

Matcher throwsApi(int status, String code) => throwsA(
  isA<ApiException>()
      .having((e) => e.status, 'status', status)
      .having((e) => e.code, 'code', code),
);

void main() {
  group('validátory', () {
    test('e-mail sa oreže a zmení na malé písmená', () {
      expect(
        validateEmail({'email': '  Pavol@Example.COM '}),
        'pavol@example.com',
      );
    });

    test('neplatný e-mail sa odmietne', () {
      for (final bad in ['', 'bez-zavinaca', 'a@b', 'a b@c.sk', 42, null]) {
        expect(
          () => validateEmail({'email': bad}),
          throwsApi(400, 'invalid_email'),
        );
      }
    });

    test('heslo musí mať 8 až 72 bajtov', () {
      expect(validateNewPassword({'password': '12345678'}), '12345678');
      expect(
        () => validateNewPassword({'password': '1234567'}),
        throwsApi(400, 'invalid_password'),
      );
      expect(
        () => validateNewPassword({'password': 'a' * 73}),
        throwsApi(400, 'invalid_password'),
      );
      // 40 znakov s diakritikou = 80 bajtov.
      expect(
        () => validateNewPassword({'password': 'š' * 40}),
        throwsApi(400, 'invalid_password'),
      );
    });

    test('meno a rola', () {
      expect(validateDisplayName({'displayName': ' Pavol '}), 'Pavol');
      expect(
        () => validateDisplayName({'displayName': '   '}),
        throwsApi(400, 'invalid_displayName'),
      );
      expect(validateRole({}), 'member');
      expect(validateRole({'role': 'trainer'}), 'trainer');
      expect(
        () => validateRole({'role': 'admin'}),
        throwsApi(400, 'invalid_role'),
      );
    });
  });

  group('RateLimiter', () {
    test('po vyčerpaní limitu blokuje a po uplynutí okna pustí', () {
      var now = DateTime(2026);
      final limiter = RateLimiter(
        maxAttempts: 2,
        window: const Duration(minutes: 5),
        clock: () => now,
      );

      expect(limiter.tryAcquire('a'), isTrue);
      expect(limiter.tryAcquire('a'), isTrue);
      expect(limiter.tryAcquire('a'), isFalse);
      expect(
        limiter.tryAcquire('b'),
        isTrue,
        reason: 'iný kľúč má vlastný limit',
      );

      now = now.add(const Duration(minutes: 5));
      expect(limiter.tryAcquire('a'), isTrue);
    });

    test('reset limit vynuluje', () {
      final limiter = RateLimiter(
        maxAttempts: 1,
        window: const Duration(hours: 1),
      );
      expect(limiter.tryAcquire('a'), isTrue);
      expect(limiter.tryAcquire('a'), isFalse);
      limiter.reset('a');
      expect(limiter.tryAcquire('a'), isTrue);
    });
  });
}
