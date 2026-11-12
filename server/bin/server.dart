import 'dart:io';

import 'package:rejnox_server/src/app.dart';
import 'package:rejnox_server/src/auth/auth_service.dart';
import 'package:rejnox_server/src/config.dart';
import 'package:rejnox_server/src/db.dart';
import 'package:rejnox_server/src/trainer/trainer_service.dart';
import 'package:rejnox_server/src/training/training_service.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final config = AppConfig.load();
  final db = Database.connect(config.databaseUrl);
  final app = buildApp(
    auth: AuthService(db, sessionTtl: config.sessionTtl),
    training: TrainingService(db),
    trainers: TrainerService(db),
    corsOrigins: config.corsOrigins,
    trustedProxies: config.trustedProxies,
    onError: (error, stack) => stderr.writeln('CHYBA: $error\n$stack'),
  );

  final server = await shelf_io.serve(app, config.host, config.port);
  stdout.writeln(
    'Rejnox server beží na http://${server.address.host}:${server.port}',
  );

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    await db.close();
    exit(0);
  });
}
