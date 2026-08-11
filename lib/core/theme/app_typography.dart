import 'package:flutter/material.dart';

/// A voz tipográfica do app.
///
/// A escala do Material é feita para servir a qualquer produto, e por isso não
/// serve bem a nenhum: entrega tamanhos redondos com espacejamento neutro, e o
/// resultado tem sempre o mesmo sotaque. Esta escala foi montada para **este**
/// app, e três decisões a definem:
///
/// 1. **Espacejamento negativo cresce com o tamanho.** É o ajuste que mais
///    separa um título desenhado de um título só grande. A Plus Jakarta Sans
///    abre bastante nas grandes; a 34px, sem apertar, "Domingo, 9 de agosto"
///    vira uma linha frouxa. A regra é ~-0.03em no display e vai zerando até o
///    corpo do texto, que não leva aperto nenhum — texto corrido apertado
///    cansa.
/// 2. **Número é sempre tabular.** Horário, tom, contagem. Com largura de
///    dígito variável, "08:30" e "19:00" numa coluna desalinham os dois-pontos,
///    e a coluna de horários é justamente o que se lê de relance nesta tela.
/// 3. **Quatro pesos, usados como quatro degraus.** 400 lê, 500 apoia, 600
///    titula, 700 destaca. Sem 300 nem 800 no pacote, e não faltam: peso demais
///    numa escala é o que produz aquela hierarquia em que nada se destaca
///    porque tudo se destaca.
class AppTypography {
  const AppTypography._();

  /// Empacotada em assets/fonts (ver pubspec). Nao ha download em runtime:
  /// a tipografia precisa estar correta ja no primeiro frame, mesmo offline.
  static const String fontFamily = 'PlusJakartaSans';

  /// Algarismos de largura fixa.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(ColorScheme scheme) {
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    TextStyle style(
      double size,
      FontWeight weight,
      double tracking,
      double height, {
      Color? color,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking,
        height: height,
        color: color ?? ink,
      );
    }

    return TextTheme(
      // --- Display: a data de uma escala, e nada mais. ---
      displayLarge: style(44, FontWeight.w700, -1.4, 1.05),
      displayMedium: style(38, FontWeight.w700, -1.2, 1.06),
      displaySmall: style(32, FontWeight.w700, -1.0, 1.08),

      // --- Headline: título de tela e de bloco grande. ---
      headlineLarge: style(28, FontWeight.w700, -0.8, 1.12),
      headlineMedium: style(25, FontWeight.w700, -0.6, 1.14),
      headlineSmall: style(22, FontWeight.w700, -0.5, 1.18),

      // --- Title: cabeçalho de cartão, de seção, de linha. ---
      titleLarge: style(19, FontWeight.w700, -0.35, 1.25),
      titleMedium: style(16, FontWeight.w600, -0.2, 1.3),
      titleSmall: style(14.5, FontWeight.w600, -0.1, 1.35),

      // --- Body: texto que se lê, sem aperto. ---
      bodyLarge: style(15.5, FontWeight.w400, 0, 1.5),
      bodyMedium: style(14, FontWeight.w400, 0, 1.5),
      bodySmall: style(13, FontWeight.w400, 0, 1.45, color: muted),

      // --- Label: botão, aba, etiqueta. ---
      labelLarge: style(14.5, FontWeight.w600, 0, 1.2),
      labelMedium: style(12.5, FontWeight.w500, 0.1, 1.3, color: muted),
      labelSmall: style(11.5, FontWeight.w600, 0.2, 1.3, color: muted),
    );
  }

  /// Rótulo de sobrancelha: "PRÓXIMA ESCALA".
  ///
  /// Maiúsculas pequenas com espacejamento **positivo** — em caixa alta as
  /// letras encostam e viram um bloco cinza ilegível. É o inverso da regra dos
  /// títulos, e pelo mesmo motivo: o espacejamento serve ao tamanho, não ao
  /// gosto.
  static TextStyle eyebrow(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      height: 1.2,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// O horário como âncora da linha: grande, tabular, peso médio.
  static TextStyle time(BuildContext context, {bool emphasized = true}) {
    final theme = Theme.of(context);
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: emphasized ? 19 : 16,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.1,
      fontFeatures: tabular,
      color: emphasized
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurfaceVariant,
    );
  }
}
