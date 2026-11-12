import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Oslava hneď po prihlásení alebo registrácii (nie pri obnovení relácie).
class Celebration {
  const Celebration({required this.firstName, required this.registered});

  final String firstName;
  final bool registered;

  String get title =>
      registered ? 'Vitaj v Rejnoxe, $firstName' : 'Ahoj, $firstName';
}

class CelebrationController extends Notifier<Celebration?> {
  @override
  Celebration? build() => null;

  void show(Celebration celebration) => state = celebration;

  void done() => state = null;
}

final celebrationProvider =
    NotifierProvider<CelebrationController, Celebration?>(
      CelebrationController.new,
    );
