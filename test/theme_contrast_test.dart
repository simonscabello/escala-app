import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_colors.dart';

/// Contraste é a parte da acessibilidade que se mede.
///
/// Estes testes existem porque a paleta anterior passava em toda a revisão
/// visual e mesmo assim entregava borda de campo a 1,45:1 — ela estava no
/// código e não na tela. Olho não mede razão de luminância; conta mede.
///
/// Mínimos do WCAG 2.2:
///  - 4.5:1 para texto normal (1.4.3)
///  - 3:1 para a borda que delimita um controle (1.4.11, "non-text contrast")
void main() {
  /// Luminância relativa, conforme a definição do WCAG.
  double luminance(Color c) {
    double channel(double v) {
      final s = v / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * channel(c.r * 255) +
        0.7152 * channel(c.g * 255) +
        0.0722 * channel(c.b * 255);
  }

  double ratio(Color a, Color b) {
    final x = luminance(a);
    final y = luminance(b);
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  void expectContrast(
    String what,
    Color foreground,
    Color background,
    double min,
  ) {
    final r = ratio(foreground, background);
    expect(
      r,
      greaterThanOrEqualTo(min),
      reason: '$what: ${r.toStringAsFixed(2)}:1, mínimo $min:1',
    );
  }

  for (final entry in {
    'claro': AppColors.lightScheme(),
    'escuro': AppColors.darkScheme(),
  }.entries) {
    final tema = entry.key;
    final s = entry.value;

    group('contraste no tema $tema', () {
      test('texto sobre a página e sobre o cartão', () {
        expectContrast('principal/página', s.onSurface, s.surface, 4.5);
        expectContrast(
          'principal/cartão',
          s.onSurface,
          s.surfaceContainerLowest,
          4.5,
        );
        expectContrast('secundário/página', s.onSurfaceVariant, s.surface, 4.5);
        expectContrast(
          'secundário/cartão',
          s.onSurfaceVariant,
          s.surfaceContainerLowest,
          4.5,
        );
      });

      test('cores de papel legíveis sobre o cartão', () {
        expectContrast('primária', s.primary, s.surfaceContainerLowest, 4.5);
        expectContrast('erro', s.error, s.surfaceContainerLowest, 4.5);
        expectContrast('atenção', s.tertiary, s.surfaceContainerLowest, 4.5);
      });

      test('texto sobre as tintas de container', () {
        expectContrast('azul', s.onPrimaryContainer, s.primaryContainer, 4.5);
        expectContrast('âmbar', s.onTertiaryContainer, s.tertiaryContainer, 4.5);
        expectContrast('erro', s.onErrorContainer, s.errorContainer, 4.5);
      });

      // O que falhava antes: a borda do campo e do chip, que é o que diz onde
      // o controle começa.
      test('borda de controle tem 3:1 contra tudo que fica atrás dela', () {
        expectContrast('outline/cartão', s.outline, s.surfaceContainerLowest, 3);
        expectContrast('outline/fill do campo', s.outline, s.surfaceContainerLow, 3);
        expectContrast('outline/página', s.outline, s.surface, 3);
      });

      test('o cartão se distingue da página sem depender da borda', () {
        // Sutil por natureza -- não é texto, e um degrau forte demais viraria
        // listra. O que não pode é ser a mesma cor: o par anterior dava
        // 1,055:1 no claro e 1,034:1 no escuro.
        final separacao = ratio(s.surfaceContainerLowest, s.surface);
        expect(
          separacao,
          greaterThanOrEqualTo(1.1),
          reason: 'separação cartão/página: ${separacao.toStringAsFixed(3)}:1',
        );
      });

      test('o cartão é mais claro que a página no escuro, e não mais escuro',
          () {
        // A inversão de elevação fazia o cartão ler como buraco. Vale nos dois
        // temas: no claro o cartão é branco sobre cinza; no escuro, cinza sobre
        // quase-preto.
        expect(
          luminance(s.surfaceContainerLowest),
          greaterThan(luminance(s.surface)),
          reason: 'o cartão precisa ficar um passo acima da página',
        );
      });
    });
  }
}
