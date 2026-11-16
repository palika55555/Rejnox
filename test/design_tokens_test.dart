import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rejnox/core/theme/app_spacing.dart';
import 'package:rejnox/core/theme/app_theme.dart';
import 'package:rejnox/core/widgets/adaptive_dialog.dart';

Widget _host(TargetPlatform platform, ValueSetter<bool> onResult) {
  return MaterialApp(
    theme: AppTheme.dark(webFonts: false, platform: platform),
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => onResult(
          await showAppConfirm(
            context,
            title: 'Zmazať?',
            message: 'Nedá sa vrátiť.',
            confirmLabel: 'Zmazať',
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  test('spacing scale stays on the 4-point grid', () {
    for (final v in AppSpacing.scale.skip(1)) {
      expect(v % 4, 0, reason: '$v is off-grid');
    }
  });

  test('radius scale is strictly increasing', () {
    for (var i = 1; i < AppRadius.scale.length; i++) {
      expect(AppRadius.scale[i], greaterThan(AppRadius.scale[i - 1]));
    }
  });

  test('display styles are larger than headlines', () {
    final t = AppTheme.dark(webFonts: false).textTheme;
    expect(t.displayLarge!.fontSize, greaterThan(t.displayMedium!.fontSize!));
    expect(t.displaySmall!.fontSize, greaterThan(t.headlineLarge!.fontSize!));
  });

  test('iOS theme drops the Material ripple', () {
    final ios = AppTheme.dark(webFonts: false, platform: TargetPlatform.iOS);
    final android = AppTheme.dark(
      webFonts: false,
      platform: TargetPlatform.android,
    );
    expect(ios.splashFactory, NoSplash.splashFactory);
    expect(android.splashFactory, InkRipple.splashFactory);
  });

  testWidgets('confirm shows a Cupertino alert on iOS', (tester) async {
    bool? result;
    await tester.pumpWidget(_host(TargetPlatform.iOS, (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Zmazať').last);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('confirm shows a Material dialog on Android', (tester) async {
    bool? result;
    await tester.pumpWidget(_host(TargetPlatform.android, (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Zrušiť'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
