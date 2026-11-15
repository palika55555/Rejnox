import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/body/domain/body_measurements.dart';

Measurement _m(DateTime date, BodyPart part, double cm) =>
    Measurement(date: date, part: part, cm: cm);

void main() {
  final waist = [
    _m(DateTime(2026, 9, 1), BodyPart.waist, 90),
    _m(DateTime(2026, 11, 1), BodyPart.waist, 86),
    _m(DateTime(2026, 11, 15), BodyPart.waist, 84.5),
  ];

  test('zmena za 30 dní berie najstaršie meranie v tom období', () {
    expect(measurementChange(waist), closeTo(-1.5, 1e-9));
  });

  test('bez dvoch meraní v období zmena nie je', () {
    expect(measurementChange(const []), isNull);
    expect(measurementChange([waist.first]), isNull);
    expect(measurementChange([waist.first, waist.last]), isNull);
  });

  test('história a posledný rozmer podľa časti', () {
    final all = [...waist, _m(DateTime(2026, 11, 2), BodyPart.arm, 38)];
    expect(historyOf(all, BodyPart.waist), hasLength(3));
    final latest = latestByPart(all);
    expect(latest[BodyPart.waist]!.cm, 84.5);
    expect(latest[BodyPart.arm]!.cm, 38);
    expect(latest.containsKey(BodyPart.calf), isFalse);
  });

  test('meranie prežije uloženie', () {
    final back = Measurement.fromJson(waist.last.toJson());
    expect(back.date, DateTime(2026, 11, 15));
    expect(back.part, BodyPart.waist);
    expect(back.cm, 84.5);
  });

  test('čísla po slovensky', () {
    expect(formatCm(82), '82');
    expect(formatCm(82.46), '82,5');
    expect(formatCmChange(-1.5), '−1,5');
    expect(formatCmChange(2), '+2');
    expect(formatCmChange(0), '0');
  });
}
