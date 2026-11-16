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
  testWidgets('feed bez údajov zo servera ukáže prázdny stav', (tester) async {
    await _pump(tester);

    expect(find.text('Zatiaľ nič…'), findsOneWidget);
    expect(find.text('Zatiaľ tu nie sú žiadne príspevky.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('čipy prepínajú sekcie s prázdnym stavom', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Výzvy'));
    await tester.pumpAndSettle();
    expect(find.text('Zatiaľ nie sú žiadne výzvy.'), findsOneWidget);

    await tester.ensureVisible(find.text('Rebríčky'));
    await tester.tap(find.text('Rebríčky'));
    await tester.pumpAndSettle();
    expect(find.text('Zatiaľ nie sú žiadne rebríčky.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
