import 'dart:io';

/// Nastavenia servera. Čítajú sa z premenných prostredia, inak z config/.env.
class AppConfig {
  AppConfig({
    required this.databaseUrl,
    this.host = '127.0.0.1',
    this.port = 8080,
    this.corsOrigins = const {'http://localhost:5173'},
    this.sessionTtl = const Duration(days: 30),
    this.trustedProxies = const {},
  });

  final Uri databaseUrl;

  /// Predvolene počúva len na tomto počítači.
  final String host;
  final int port;
  final Set<String> corsOrigins;
  final Duration sessionTtl;

  /// Adresy, ktorým server verí hlavičku x-forwarded-for (napr. Next.js web).
  final Set<String> trustedProxies;

  factory AppConfig.load({Map<String, String>? environment}) {
    final env = {..._readEnvFile(), ...(environment ?? Platform.environment)};
    final url = env['DATABASE_URL'];
    if (url == null || url.isEmpty) {
      throw StateError(
        'Chýba DATABASE_URL (nastav premennú prostredia alebo config/.env).',
      );
    }
    final origins = env['CORS_ORIGINS'];
    return AppConfig(
      databaseUrl: Uri.parse(url),
      host: env['HOST'] ?? '127.0.0.1',
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      corsOrigins: origins == null
          ? const {'http://localhost:5173'}
          : origins.split(',').map((o) => o.trim()).toSet(),
      trustedProxies: _list(env['TRUSTED_PROXIES']),
    );
  }

  static Set<String> _list(String? value) {
    if (value == null) return const {};
    return value
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
  }

  /// Hľadá config/.env v aktuálnom priečinku alebo o úroveň vyššie.
  static Map<String, String> _readEnvFile() {
    for (final path in ['config/.env', '../config/.env']) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final values = <String, String>{};
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        final split = trimmed.indexOf('=');
        if (trimmed.isEmpty || trimmed.startsWith('#') || split < 1) continue;
        values[trimmed.substring(0, split)] = trimmed.substring(split + 1);
      }
      return values;
    }
    return const {};
  }
}
