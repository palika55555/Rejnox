import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/features/home/presentation/widgets/workout_cards.dart';

void main() {
  test('rozloží váhu na kotúče na jednu stranu 20 kg tyče', () {
    expect(BarbellLoad.plates(120), [25, 25]);
    expect(BarbellLoad.plates(102.5), [25, 15, 1.25]);
    expect(BarbellLoad.plates(20), isEmpty);
    expect(BarbellLoad.plates(10), isEmpty);
  });

  testWidgets('nálož má popis pre čítačku obrazovky', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: BarbellLoad(weightKg: 90))),
    );

    expect(
      find.bySemanticsLabel('Na jednu stranu: 25 + 10 kg'),
      findsOneWidget,
    );
  });
}
