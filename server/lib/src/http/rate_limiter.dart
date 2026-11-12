/// Jednoduché obmedzenie počtu pokusov v časovom okne (v pamäti servera).
class RateLimiter {
  RateLimiter({
    required this.maxAttempts,
    required this.window,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxAttempts;
  final Duration window;
  final DateTime Function() _clock;
  final _entries = <String, _Entry>{};

  /// Zaráta pokus. Vráti false, ak je limit pre [key] vyčerpaný.
  bool tryAcquire(String key) {
    final now = _clock();
    if (_entries.length > 10000) {
      _entries.removeWhere((_, e) => !now.isBefore(e.resetAt));
    }
    final entry = _entries[key];
    if (entry == null || !now.isBefore(entry.resetAt)) {
      _entries[key] = _Entry(now.add(window));
      return true;
    }
    if (entry.count >= maxAttempts) return false;
    entry.count++;
    return true;
  }

  /// Po úspechu (napr. správne heslo) limit vynuluje.
  void reset(String key) => _entries.remove(key);
}

class _Entry {
  _Entry(this.resetAt);

  final DateTime resetAt;
  int count = 1;
}
