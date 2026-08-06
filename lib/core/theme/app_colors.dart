import 'package:flutter/material.dart';

/// Tokens de cor da identidade azul (claro e escuro).
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

  static const Color lightTertiary = Color(0xFF0E7490);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFCFEEF7);
  static const Color lightOnTertiaryContainer = Color(0xFF06333F);

  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9DEDC);
  static const Color lightOnErrorContainer = Color(0xFF410E0B);

  static const Color lightSurface = Color(0xFFF7F9FC);
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightOnSurfaceVariant = Color(0xFF52607A);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF1F5FA);
  static const Color lightSurfaceContainer = Color(0xFFE9EFF7);
  static const Color lightSurfaceContainerHigh = Color(0xFFE2E9F3);
  static const Color lightSurfaceContainerHighest = Color(0xFFDBE3EF);
  static const Color lightOutline = Color(0xFFC4CEDD);
  static const Color lightOutlineVariant = Color(0xFFDCE3ED);
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

  static const Color darkTertiary = Color(0xFF7DD3E0);
  static const Color darkOnTertiary = Color(0xFF06333F);
  static const Color darkTertiaryContainer = Color(0xFF10485A);
  static const Color darkOnTertiaryContainer = Color(0xFFCFEEF7);

  static const Color darkError = Color(0xFFF2B8B5);
  static const Color darkOnError = Color(0xFF601410);
  static const Color darkErrorContainer = Color(0xFF8C1D18);
  static const Color darkOnErrorContainer = Color(0xFFF9DEDC);

  static const Color darkSurface = Color(0xFF0B1017);
  static const Color darkOnSurface = Color(0xFFE6ECF5);
  static const Color darkOnSurfaceVariant = Color(0xFFA3B0C4);
  static const Color darkSurfaceContainerLowest = Color(0xFF070B10);
  static const Color darkSurfaceContainerLow = Color(0xFF11171F);
  static const Color darkSurfaceContainer = Color(0xFF161D27);
  static const Color darkSurfaceContainerHigh = Color(0xFF1F2733);
  static const Color darkSurfaceContainerHighest = Color(0xFF2A333F);
  static const Color darkOutline = Color(0xFF2F3A48);
  static const Color darkOutlineVariant = Color(0xFF3A4553);
  static const Color darkInverseSurface = Color(0xFFE6ECF5);
  static const Color darkOnInverseSurface = Color(0xFF161D27);
  static const Color darkInversePrimary = Color(0xFF1D4ED8);
  static const Color darkScrim = Color(0xFF000000);
  static const Color darkShadow = Color(0xFF000000);

  // --- Acento de destaque (aliases do primary) ---
  // Antes era dourado; agora segue o azul da marca para nao competir com o
  // heroi nem engordar faixas de Ministrante / VOCÊ.
  static const Color lightAccent = lightPrimary;
  static const Color lightAccentContainer = lightPrimaryContainer;
  static const Color lightOnAccentContainer = lightOnPrimaryContainer;

  static const Color darkAccent = darkPrimary;
  static const Color darkAccentContainer = darkPrimaryContainer;
  static const Color darkOnAccentContainer = darkOnPrimaryContainer;

  // --- Gradiente do cartao heroi ---
  static const List<Color> lightHeroGradient = [
    Color(0xFF153E9E),
    Color(0xFF2563EB),
  ];
  static const List<Color> darkHeroGradient = [
    Color(0xFF0D2A63),
    Color(0xFF17408F),
  ];

  static bool _isDark(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark;

  static Color accent(ColorScheme scheme) =>
      _isDark(scheme) ? darkAccent : lightAccent;

  static Color accentContainer(ColorScheme scheme) =>
      _isDark(scheme) ? darkAccentContainer : lightAccentContainer;

  static Color onAccentContainer(ColorScheme scheme) =>
      _isDark(scheme) ? darkOnAccentContainer : lightOnAccentContainer;

  static List<Color> heroGradient(ColorScheme scheme) =>
      _isDark(scheme) ? darkHeroGradient : lightHeroGradient;

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
