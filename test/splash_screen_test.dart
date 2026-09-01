import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/auth/presentation/splash_screen.dart';
import 'package:louvor_app/shared/widgets/app_brand_mark.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }

  testWidgets('centraliza a marca na viewport larga', (tester) async {
    await pumpAt(tester, const Size(1400, 900));

    final screen = tester.getSize(find.byType(Scaffold));
    final mark = tester.getRect(find.byType(AppBrandGlyph));
    final spinner = tester.getRect(find.byType(CircularProgressIndicator));

    expect(mark.center.dx, closeTo(screen.width / 2, 1));
    expect(spinner.center.dx, closeTo(screen.width / 2, 1));
    expect(
      (mark.center.dy + spinner.center.dy) / 2,
      closeTo(screen.height / 2, 48),
    );
  });

  testWidgets('centraliza a marca na viewport estreita', (tester) async {
    await pumpAt(tester, const Size(360, 800));

    final screen = tester.getSize(find.byType(Scaffold));
    final mark = tester.getRect(find.byType(AppBrandGlyph));
    final spinner = tester.getRect(find.byType(CircularProgressIndicator));

    expect(mark.center.dx, closeTo(screen.width / 2, 1));
    expect(spinner.center.dx, closeTo(screen.width / 2, 1));
    expect(
      (mark.center.dy + spinner.center.dy) / 2,
      closeTo(screen.height / 2, 48),
    );
  });
}
