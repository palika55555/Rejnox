import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/widgets/plate_ring.dart';

void main() {
  testWidgets('kotúč hlási splnené kroky čítačke obrazovky', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: PlateRing(done: 3, total: 4))),
    );

    expect(find.bySemanticsLabel('Splnené 3 z 4'), findsOneWidget);
  });

  testWidgets('má zvolenú veľkosť', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: PlateRing(done: 0, total: 5, size: 80)),
      ),
    );

    expect(tester.getSize(find.byType(PlateRing)), const Size(80, 80));
  });
}
