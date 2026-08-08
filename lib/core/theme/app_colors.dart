import 'package:flutter/material.dart';

/// Tokens de cor da identidade azul (claro e escuro).
///
/// Três regras sustentam a paleta, e cada uma existe porque a versão anterior
/// falhava nela:
///
/// 1. **O cartão fica um passo acima da página, nos dois temas.** No escuro
///    isso inverte a ordem do Material 3 (lá `surfaceContainerLowest` é mais
///    escuro que `surface`), e a inversão é deliberada: o app usa esse token
///    como "a superfície do cartão", e seguir o M3 fazia o cartão ficar mais
///    escuro que a página — lido como buraco, não como cartão.
/// 2. **Borda de controle tem 3:1** contra o que está atrás dela (WCAG 1.4.11,
///    "non-text contrast"). O `outline` antigo dava 1,45:1 sobre o campo: a
///    borda existia no código e não na tela.
/// 3. **Fundo e cartão precisam se distinguir sem depender só da borda.** O par
///    antigo (#F7F9FC / #FFFFFF) era 1,055:1 — praticamente a mesma cor.
class AppColors {
  const AppColors._();

  // --- Light ---
  static const Color lightPrimary = Color(0xFF1D4ED8);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFDBE6FE);
  static const Color lightOnPrimaryContainer = Color(0xFF0B2A6B);

  static const Color lightSecondary = Color(0xFF475569);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFE2E8F0);
  static const Color lightOnSecondaryContainer = Color(0xFF1E293B);

  /// Âmbar: o papel de **atenção**, que não é erro.
  ///
  /// "Falta o tom desta música", "ninguém escalado ainda", "esta pessoa avisou
  /// que não pode" são coisas para notar, não para se assustar — e usar o
  /// vermelho nelas gastava o alarme em situações comuns. O azul não servia:
  /// ele é a cor do que está certo e do que se toca.
  static const Color lightTertiary = Color(0xFF9A4E06);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFFDECD3);
  static const Color lightOnTertiaryContainer = Color(0xFF7A3E00);

  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9DEDC);
  static const Color lightOnErrorContainer = Color(0xFF410E0B);

  /// A página. Mais funda que antes para o cartão branco existir sem depender
  /// da borda.
  static const Color lightSurface = Color(0xFFEDF1F7);
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightOnSurfaceVariant = Color(0xFF4E5D75);

  /// A superfície do cartão.
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);

  /// Preenchimento de campo e cartão discreto.
  static const Color lightSurfaceContainerLow = Color(0xFFF6F8FC);
  static const Color lightSurfaceContainer = Color(0xFFE4EAF4);
  static const Color lightSurfaceContainerHigh = Color(0xFFDAE2EF);
  static const Color lightSurfaceContainerHighest = Color(0xFFCFD9E9);

  /// Borda de controle: campo, botão contornado, o que se toca. 3:1.
  static const Color lightOutline = Color(0xFF7B8CA8);

  /// Fio de divisão entre blocos do mesmo cartão. Decorativo — separa, não
  /// delimita um controle, então não precisa dos 3:1.
  static const Color lightOutlineVariant = Color(0xFFD3DCEA);

  static const Color lightInverseSurface = Color(0xFF16202E);
  static const Color lightOnInverseSurface = Color(0xFFF1F5FA);
  static const Color lightInversePrimary = Color(0xFF93B4FF);
  static const Color lightScrim = Color(0xFF000000);
  static const Color lightShadow = Color(0xFF000000);

  // --- Dark ---
  static const Color darkPrimary = Color(0xFF93B4FF);
  static const Color darkOnPrimary = Color(0xFF06265E);
  static const Color darkPrimaryContainer = Color(0xFF123A85);
  static const Color darkOnPrimaryContainer = Color(0xFFDBE6FE);

  static const Color darkSecondary = Color(0xFFA8B6CC);
  static const Color darkOnSecondary = Color(0xFF1E293B);
  static const Color darkSecondaryContainer = Color(0xFF2A3648);
  static const Color darkOnSecondaryContainer = Color(0xFFE2E8F0);

  static const Color darkTertiary = Color(0xFFF0B357);
  static const Color darkOnTertiary = Color(0xFF412402);
  static const Color darkTertiaryContainer = Color(0xFF5A3405);
  static const Color darkOnTertiaryContainer = Color(0xFFFDECD3);

  static const Color darkError = Color(0xFFF2B8B5);
  static const Color darkOnError = Color(0xFF601410);
  static const Color darkErrorContainer = Color(0xFF8C1D18);
  static const Color darkOnErrorContainer = Color(0xFFF9DEDC);

  /// A página, e o ponto mais escuro do tema.
  static const Color darkSurface = Color(0xFF0A0F16);
  static const Color darkOnSurface = Color(0xFFE6ECF5);
  static const Color darkOnSurfaceVariant = Color(0xFFA3B0C4);

  /// A superfície do cartão — **mais clara** que a página, ao contrário do que
  /// o nome do Material 3 sugere. Ver a regra 1 no topo do arquivo.
  static const Color darkSurfaceContainerLowest = Color(0xFF141C26);

  /// Preenchimento de campo e cartão discreto: acima da página, abaixo do
  /// cartão.
  static const Color darkSurfaceContainerLow = Color(0xFF10161E);
  static const Color darkSurfaceContainer = Color(0xFF1A2431);
  static const Color darkSurfaceContainerHigh = Color(0xFF222E3D);
  static const Color darkSurfaceContainerHighest = Color(0xFF2B3849);

  static const Color darkOutline = Color(0xFF5E6E86);
  static const Color darkOutlineVariant = Color(0xFF2F3B4B);

  static const Color darkInverseSurface = Color(0xFFE6ECF5);
  static const Color darkOnInverseSurface = Color(0xFF161D27);
  static const Color darkInversePrimary = Color(0xFF1D4ED8);
  static const Color darkScrim = Color(0xFF000000);
  static const Color darkShadow = Color(0xFF000000);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      secondary: lightSecondary,
      onSecondary: lightOnSecondary,
      secondaryContainer: lightSecondaryContainer,
      onSecondaryContainer: lightOnSecondaryContainer,
      tertiary: lightTertiary,
      onTertiary: lightOnTertiary,
      tertiaryContainer: lightTertiaryContainer,
      onTertiaryContainer: lightOnTertiaryContainer,
      error: lightError,
      onError: lightOnError,
      errorContainer: lightErrorContainer,
      onErrorContainer: lightOnErrorContainer,
      surface: lightSurface,
      onSurface: lightOnSurface,
      onSurfaceVariant: lightOnSurfaceVariant,
      surfaceContainerLowest: lightSurfaceContainerLowest,
      surfaceContainerLow: lightSurfaceContainerLow,
      surfaceContainer: lightSurfaceContainer,
      surfaceContainerHigh: lightSurfaceContainerHigh,
      surfaceContainerHighest: lightSurfaceContainerHighest,
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
      inverseSurface: lightInverseSurface,
      onInverseSurface: lightOnInverseSurface,
      inversePrimary: lightInversePrimary,
      scrim: lightScrim,
      shadow: lightShadow,
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: darkSecondary,
      onSecondary: darkOnSecondary,
      secondaryContainer: darkSecondaryContainer,
      onSecondaryContainer: darkOnSecondaryContainer,
      tertiary: darkTertiary,
      onTertiary: darkOnTertiary,
      tertiaryContainer: darkTertiaryContainer,
      onTertiaryContainer: darkOnTertiaryContainer,
      error: darkError,
      onError: darkOnError,
      errorContainer: darkErrorContainer,
      onErrorContainer: darkOnErrorContainer,
      surface: darkSurface,
      onSurface: darkOnSurface,
      onSurfaceVariant: darkOnSurfaceVariant,
      surfaceContainerLowest: darkSurfaceContainerLowest,
      surfaceContainerLow: darkSurfaceContainerLow,
      surfaceContainer: darkSurfaceContainer,
      surfaceContainerHigh: darkSurfaceContainerHigh,
      surfaceContainerHighest: darkSurfaceContainerHighest,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      inverseSurface: darkInverseSurface,
      onInverseSurface: darkOnInverseSurface,
      inversePrimary: darkInversePrimary,
      scrim: darkScrim,
      shadow: darkShadow,
    );
  }
}
