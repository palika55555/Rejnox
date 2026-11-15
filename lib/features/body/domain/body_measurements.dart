/// Časti tela, ktoré sa dajú merať krajčírskym metrom. [anchor] je bod na
/// postave v súradniciach 100 × 240 (stred postavy je x = 50); párové časti
/// sa merajú na ľavej strane postavy.
enum BodyPart {
  neck('Krk', (50, 35), 25, 70),
  chest('Hrudník', (50, 60), 50, 200),
  arm('Biceps', (20, 70), 15, 80),
  waist('Pás', (50, 90), 40, 200),
  belly('Brucho', (50, 102), 40, 220),
  hips('Boky', (50, 116), 50, 200),
  thigh('Stehno', (38.5, 148), 25, 120),
  calf('Lýtko', (38, 200), 15, 70);

  const BodyPart(this.label, this.anchor, this.minCm, this.maxCm);

  final String label;
  final (double, double) anchor;
  final double minCm;
  final double maxCm;

  /// Kde a ako merať, aby boli čísla porovnateľné.
  String get hint => switch (this) {
    neck => 'Pod ohryzkom, meter vodorovne.',
    chest => 'Cez bradavky, pri voľnom výdychu.',
    arm => 'Najširšie miesto, ruka voľne spustená.',
    waist => 'Najužšie miesto nad pupkom.',
    belly => 'Cez pupok, brucho nezaťahuj.',
    hips => 'Najširšie miesto cez zadok.',
    thigh => 'Najširšie miesto tesne pod zadkom.',
    calf => 'Najširšie miesto lýtka v stoji.',
  };
}

/// Jedno meranie jednej časti tela.
class Measurement {
  const Measurement({required this.date, required this.part, required this.cm});

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
    date: DateTime.parse(json['date'] as String),
    part: BodyPart.values.byName(json['part'] as String),
    cm: (json['cm'] as num).toDouble(),
  );

  /// Deň merania (bez času).
  final DateTime date;
  final BodyPart part;
  final double cm;

  Map<String, dynamic> toJson() => {
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'part': part.name,
    'cm': cm,
  };
}

/// Merania jednej časti od najstaršieho.
List<Measurement> historyOf(List<Measurement> all, BodyPart part) => [
  for (final m in all)
    if (m.part == part) m,
];

/// Posledné meranie každej časti (časti bez merania chýbajú).
Map<BodyPart, Measurement> latestByPart(List<Measurement> all) => {
  for (final m in all) m.part: m,
};

/// Zmena od prvého merania za posledných [days] dní po posledné.
/// Null, ak na porovnanie nie sú aspoň dve merania v tom období.
double? measurementChange(List<Measurement> history, {int days = 30}) {
  if (history.length < 2) return null;
  final last = history.last;
  final from = last.date.subtract(Duration(days: days));
  final base = history.firstWhere((m) => !m.date.isBefore(from));
  if (identical(base, last)) return null;
  return last.cm - base.cm;
}

/// „82“, „82,5“.
String formatCm(double cm) {
  final r = (cm * 10).roundToDouble() / 10;
  return r == r.roundToDouble()
      ? r.toInt().toString()
      : r.toString().replaceAll('.', ',');
}

/// „+1,5“, „−2“, „0“.
String formatCmChange(double cm) {
  final r = (cm * 10).roundToDouble() / 10;
  final sign = r > 0
      ? '+'
      : r < 0
      ? '−'
      : '';
  return '$sign${formatCm(r.abs())}';
}
