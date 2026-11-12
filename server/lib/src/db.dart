import 'package:postgres/postgres.dart';

/// Prístup k databáze. Každá práca v mene používateľa beží v transakcii,
/// v ktorej je nastavené app.user_id, takže databáza vydá len jeho riadky.
class Database {
  Database._(this._pool);

  final Pool<void> _pool;

  factory Database.connect(Uri url) {
    final credentials = url.userInfo.split(':');
    final isLocal = url.host == 'localhost' || url.host == '127.0.0.1';
    return Database._(
      Pool.withEndpoints(
        [
          Endpoint(
            host: url.host,
            port: url.hasPort ? url.port : 5432,
            database: url.pathSegments.first,
            username: Uri.decodeComponent(credentials.first),
            password: credentials.length > 1
                ? Uri.decodeComponent(credentials.sublist(1).join(':'))
                : null,
          ),
        ],
        settings: PoolSettings(
          maxConnectionCount: 10,
          // Mimo lokálneho počítača musí byť spojenie šifrované.
          sslMode: isLocal ? SslMode.disable : SslMode.require,
        ),
      ),
    );
  }

  /// Transakcia bez prihláseného používateľa (registrácia, overenie tokenu).
  Future<T> transaction<T>(Future<T> Function(TxSession tx) body) =>
      _pool.runTx(body);

  /// Transakcia v mene používateľa [userId].
  Future<T> asUser<T>(String userId, Future<T> Function(TxSession tx) body) =>
      _pool.runTx((tx) async {
        await actAs(tx, userId);
        return body(tx);
      });

  static Future<void> actAs(TxSession tx, String userId) => tx.execute(
    Sql.named("SELECT set_config('app.user_id', @id, true)"),
    parameters: {'id': userId},
  );

  Future<void> close() => _pool.close();
}
