import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/features/community/presentation/community_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(webFonts: false),
      home: const Scaffold(body: CommunityScreen()),
    ),
  );
}

void main() {
  testWidgets('feed ukáže príspevky a lajk pripočíta jeden', (tester) async {
    await _pump(tester);

    expect(find.text('Ďalší krok vpred!'), findsOneWidget);
    expect(find.text('86'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pump();

    expect(find.text('87'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('čipy prepínajú sekcie', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Výzvy'));
    await tester.pumpAndSettle();
    expect(find.text('30 DNÍ V POHYBE'), findsOneWidget);

    await tester.ensureVisible(find.text('Rebríčky'));
    await tester.tap(find.text('Rebríčky'));
    await tester.pumpAndSettle();
    expect(find.text('Martin K.'), findsOneWidget);
    expect(find.text('Veronika S.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nový príspevok sa dá zdieľať až s textom', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Podeľ sa o svoj progres…'));
    await tester.pumpAndSettle();
    expect(find.text('NOVÝ PRÍSPEVOK'), findsOneWidget);

    await tester.tap(find.text('Zdieľať príspevok'));
    await tester.pumpAndSettle();
    expect(find.text('NOVÝ PRÍSPEVOK'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Nový rekord v drepe');
    await tester.pump();
    await tester.tap(find.text('Zdieľať príspevok'));
    await tester.pumpAndSettle();

    expect(find.text('NOVÝ PRÍSPEVOK'), findsNothing);
    expect(find.text('Ukladanie príspevkov pribudne čoskoro.'), findsOneWidget);
  });
}
