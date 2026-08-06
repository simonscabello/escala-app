// Gera os icones web a partir do mesmo glifo da tela de login
// (Icons.music_note_rounded + primaryContainer).
//
// Uso (na raiz do app):
//   flutter test tooling/generate_web_icons.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_colors.dart';
import 'package:louvor_app/core/theme/app_spacing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadMaterialIcons();
  });

  testWidgets('gera icones web a partir do brand da login', (tester) async {
    final outDir = Directory('web/icons');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    await _writeIcon(
      tester,
      size: 512,
      maskable: false,
      path: 'web/icons/Icon-512.png',
    );
    await _writeIcon(
      tester,
      size: 192,
      maskable: false,
      path: 'web/icons/Icon-192.png',
    );
    await _writeIcon(
      tester,
      size: 512,
      maskable: true,
      path: 'web/icons/Icon-maskable-512.png',
    );
    await _writeIcon(
      tester,
      size: 192,
      maskable: true,
      path: 'web/icons/Icon-maskable-192.png',
    );
    await _writeIcon(
      tester,
      size: 32,
      maskable: false,
      path: 'web/favicon.png',
    );
  });
}

Future<void> _loadMaterialIcons() async {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}'
          r'\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    r'C:\Users\Acer\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  ];

  File? fontFile;
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      fontFile = file;
      break;
    }
  }
  if (fontFile == null) {
    fail('MaterialIcons-Regular.otf nao encontrada.');
  }

  final bytes = await fontFile.readAsBytes();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
  await loader.load();
}

Future<void> _writeIcon(
  WidgetTester tester, {
  required int size,
  required bool maskable,
  required String path,
}) async {
  final key = GlobalKey();
  final logical = size.toDouble();

  await tester.binding.setSurfaceSize(Size(logical, logical));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: AppColors.lightScheme(),
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: logical,
              height: logical,
              child: _BrandIcon(size: logical, maskable: maskable),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Espelha o card da login: fundo primaryContainer, radiusLg, music_note_rounded.
/// Proporcao login: 56px box / 28px icon / radius 16.
class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.size, required this.maskable});

  final double size;
  final bool maskable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = maskable ? size * 0.40 : size * 0.50;
    final radius = size * (AppSpacing.radiusLg / 56);

    if (maskable) {
      return ColoredBox(
        color: scheme.primaryContainer,
        child: Center(
          child: Icon(
            Icons.music_note_rounded,
            size: iconSize,
            color: scheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: iconSize,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}
