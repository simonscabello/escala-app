import 'package:flutter/material.dart';

import 'app_colors.dart';

/// As quatro cores de estado, num lugar só.
///
/// **Por que existe.** O Material 3 nomeia os papéis pela posição na paleta
/// (`primary`, `tertiary`, `error`), não pelo que significam. Na prática isso
/// espalhava a decisão pelo app: uma tela escrevia `scheme.tertiary` querendo
/// dizer "atenção", outra escrevia `scheme.secondaryContainer` querendo dizer
/// "aviso do sistema", e quem chegava depois tinha de adivinhar a intenção pelo
/// contexto. Aqui o nome é o significado, e há **um** lugar para consultar.
///
/// Os quatro papéis, e a fronteira entre eles:
///
/// - **`success`** — deu certo. Só depois de uma ação, nunca como enfeite.
/// - **`warning`** (âmbar) — algo a resolver, sem susto: música sem tom,
///   ninguém escalado ainda. O vermelho aqui gastaria o alarme.
/// - **`danger`** (vermelho) — erro de verdade e ação destrutiva.
/// - **`info`** (ardósia) — o sistema contando algo: "sem conexão, atualizado
///   às 10:32". Deliberadamente **sem cor nova**: informação neutra não disputa
///   atenção, e um quinto tom só existiria para dizer "isto não é importante".
///
/// `warning` e `danger` apontam para o mesmo âmbar e o mesmo vermelho do
/// `ColorScheme`. Não é cópia: é o `ColorScheme` que continua sendo a
/// encanação do Material, e este arquivo que é a superfície de leitura.
@immutable
class StatusPalette {
  const StatusPalette({
    required this.foreground,
    required this.onForeground,
    required this.container,
    required this.onContainer,
  });

  /// Texto e ícone deste estado sobre a página ou o cartão. 4,5:1.
  final Color foreground;

  /// Texto sobre [foreground] quando ele é o preenchimento (botão, selo cheio).
  final Color onForeground;

  /// Fundo da faixa, do selo e do balão.
  final Color container;

  /// Texto sobre [container]. 4,5:1.
  final Color onContainer;

  static StatusPalette lerp(StatusPalette a, StatusPalette b, double t) {
    return StatusPalette(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      onForeground: Color.lerp(a.onForeground, b.onForeground, t)!,
      container: Color.lerp(a.container, b.container, t)!,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
    );
  }
}

/// O tom de um elemento tingido — selo, faixa, aviso.
///
/// Existe para que "de que cor é este selo?" seja uma escolha entre seis
/// intenções nomeadas, e não uma expressão de cor escrita à mão em cada tela.
enum AppTone { neutral, primary, success, warning, danger, info }

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final StatusPalette success;
  final StatusPalette warning;
  final StatusPalette danger;
  final StatusPalette info;

  static const AppStatusColors light = AppStatusColors(
    success: StatusPalette(
      foreground: AppColors.lightSuccess,
      onForeground: AppColors.lightOnSuccess,
      container: AppColors.lightSuccessContainer,
      onContainer: AppColors.lightOnSuccessContainer,
    ),
    warning: StatusPalette(
      foreground: AppColors.lightTertiary,
      onForeground: AppColors.lightOnTertiary,
      container: AppColors.lightTertiaryContainer,
      onContainer: AppColors.lightOnTertiaryContainer,
    ),
    danger: StatusPalette(
      foreground: AppColors.lightError,
      onForeground: AppColors.lightOnError,
      container: AppColors.lightErrorContainer,
      onContainer: AppColors.lightOnErrorContainer,
    ),
    info: StatusPalette(
      foreground: AppColors.lightSecondary,
      onForeground: AppColors.lightOnSecondary,
      container: AppColors.lightSecondaryContainer,
      onContainer: AppColors.lightOnSecondaryContainer,
    ),
  );

  static const AppStatusColors dark = AppStatusColors(
    success: StatusPalette(
      foreground: AppColors.darkSuccess,
      onForeground: AppColors.darkOnSuccess,
      container: AppColors.darkSuccessContainer,
      onContainer: AppColors.darkOnSuccessContainer,
    ),
    warning: StatusPalette(
      foreground: AppColors.darkTertiary,
      onForeground: AppColors.darkOnTertiary,
      container: AppColors.darkTertiaryContainer,
      onContainer: AppColors.darkOnTertiaryContainer,
    ),
    danger: StatusPalette(
      foreground: AppColors.darkError,
      onForeground: AppColors.darkOnError,
      container: AppColors.darkErrorContainer,
      onContainer: AppColors.darkOnErrorContainer,
    ),
    info: StatusPalette(
      foreground: AppColors.darkSecondary,
      onForeground: AppColors.darkOnSecondary,
      container: AppColors.darkSecondaryContainer,
      onContainer: AppColors.darkOnSecondaryContainer,
    ),
  );

  /// Recupera os papéis do tema.
  ///
  /// Cai no conjunto correspondente ao brilho quando a extensão não foi
  /// registrada — telas de teste montam `MaterialApp` sem o `AppTheme`, e uma
  /// cor faltando não deve derrubar o widget.
  static AppStatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppStatusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// A paleta de um tom, resolvendo `neutral` e `primary` no esquema da tela.
  ///
  /// É o ponto único de "que cores este elemento usa": o selo, a faixa e o
  /// snackbar perguntam aqui em vez de cada um montar a sua combinação.
  StatusPalette resolve(AppTone tone, ColorScheme scheme) => switch (tone) {
        AppTone.neutral => StatusPalette(
            foreground: scheme.onSurfaceVariant,
            onForeground: scheme.surface,
            container: scheme.surfaceContainerHighest,
            onContainer: scheme.onSurfaceVariant,
          ),
        AppTone.primary => StatusPalette(
            foreground: scheme.primary,
            onForeground: scheme.onPrimary,
            container: scheme.primaryContainer,
            onContainer: scheme.onPrimaryContainer,
          ),
        AppTone.success => success,
        AppTone.warning => warning,
        AppTone.danger => danger,
        AppTone.info => info,
      };

  @override
  AppStatusColors copyWith({
    StatusPalette? success,
    StatusPalette? warning,
    StatusPalette? danger,
    StatusPalette? info,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: StatusPalette.lerp(success, other.success, t),
      warning: StatusPalette.lerp(warning, other.warning, t),
      danger: StatusPalette.lerp(danger, other.danger, t),
      info: StatusPalette.lerp(info, other.info, t),
    );
  }
}
