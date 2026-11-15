import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/home/application/body_weight.dart';

WeightEntry _w(int day, double kg) =>
    WeightEntry(date: DateTime(2026, 11, day), kg: kg);

void main() {
  test('zmena za 30 dní berie najstaršie váženie v tom období', () {
    final change = weightChange([
      WeightEntry(date: DateTime(2026, 9, 1), kg: 90),
      _w(1, 84),
      _w(8, 83.5),
      _w(15, 82.4),
    ]);
    expect(change, closeTo(-1.6, 1e-9));
  });

  test('bez dvoch vážení zmena nie je', () {
    expect(weightChange(const []), isNull);
    expect(weightChange([_w(1, 80)]), isNull);
    // Jediné váženie za posledných 30 dní nemá s čím porovnať.
    expect(
      weightChange([
        WeightEntry(date: DateTime(2026, 1, 1), kg: 90),
        _w(15, 80),
      ]),
      isNull,
    );
  });

  test('váženie prežije uloženie', () {
    final back = WeightEntry.fromJson(_w(15, 82.4).toJson());
    expect(back.date, DateTime(2026, 11, 15));
    expect(back.kg, 82.4);
  });
}
