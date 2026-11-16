import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/core/widgets/skeleton.dart';
import 'package:rejnox/core/widgets/undo_snack.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark(webFonts: false),
  home: Scaffold(body: home),
);

void main() {
  testWidgets('undo snack reports Späť when tapped', (tester) async {
    bool? undone;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                undone = await showUndoSnack(context, 'Správa zmazaná'),
            child: const Text('delete'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();
    expect(find.text('Správa zmazaná'), findsOneWidget);

    await tester.tap(find.text('Späť'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
  });

  testWidgets('undo snack commits after the window closes', (tester) async {
    bool? undone;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                undone = await showUndoSnack(context, 'Príspevok zmazaný'),
            child: const Text('delete'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();
    await tester.pump(undoWindow + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(undone, isFalse);
  });

  testWidgets('skeleton is announced as loading and stays still '
      'with animations off', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(const SkeletonList(count: 3)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonTile), findsNWidgets(3));
    expect(find.bySemanticsLabel('Načítava sa'), findsOneWidget);
  });
}
