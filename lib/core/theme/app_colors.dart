import 'package:flutter/material.dart';

/// Tokens de cor da identidade verde (claro e escuro).
class AppColors {
  const AppColors._();

  // --- Light ---
  static const Color lightPrimary = Color(0xFF1B7A4E);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFD8F3E3);
  static const Color lightOnPrimaryContainer = Color(0xFF0A3D26);

  static const Color lightSecondary = Color(0xFF3D6B5A);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFD5EBE1);
  static const Color lightOnSecondaryContainer = Color(0xFF1A3329);

  static const Color lightTertiary = Color(0xFF2F6B7A);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFD0EAF0);
  static const Color lightOnTertiaryContainer = Color(0xFF0E3340);

  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9DEDC);
  static const Color lightOnErrorContainer = Color(0xFF410E0B);

  static const Color lightSurface = Color(0xFFF6FAF7);
  static const Color lightOnSurface = Color(0xFF14201A);
  static const Color lightOnSurfaceVariant = Color(0xFF4A5C52);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFEFF6F1);
  static const Color lightSurfaceContainer = Color(0xFFE8F1EB);
  static const Color lightSurfaceContainerHigh = Color(0xFFE2EDE6);
  static const Color lightSurfaceContainerHighest = Color(0xFFDCE8E1);
  static const Color lightOutline = Color(0xFFC5D5CC);
  static const Color lightOutlineVariant = Color(0xFFD8E4DC);
  static const Color lightInverseSurface = Color(0xFF1A221E);
  static const Color lightOnInverseSurface = Color(0xFFEFF6F1);
  static const Color lightInversePrimary = Color(0xFF4ADE80);
  static const Color lightScrim = Color(0xFF000000);
  static const Color lightShadow = Color(0xFF000000);

  // --- Dark ---
  static const Color darkPrimary = Color(0xFF4ADE80);
  static const Color darkOnPrimary = Color(0xFF052E1C);
  static const Color darkPrimaryContainer = Color(0xFF14532D);
  static const Color darkOnPrimaryContainer = Color(0xFFD8F3E3);

  static const Color darkSecondary = Color(0xFF86EFAC);
  static const Color darkOnSecondary = Color(0xFF0A2E1C);
  static const Color darkSecondaryContainer = Color(0xFF1E3F30);
  static const Color darkOnSecondaryContainer = Color(0xFFD5EBE1);

  static const Color darkTertiary = Color(0xFF7DD3E0);
  static const Color darkOnTertiary = Color(0xFF0A2F38);
  static const Color darkTertiaryContainer = Color(0xFF1A4550);
  static const Color darkOnTertiaryContainer = Color(0xFFD0EAF0);

  static const Color darkError = Color(0xFFF2B8B5);
  static const Color darkOnError = Color(0xFF601410);
  static const Color darkErrorContainer = Color(0xFF8C1D18);
  static const Color darkOnErrorContainer = Color(0xFFF9DEDC);

  static const Color darkSurface = Color(0xFF0F1412);
  static const Color darkOnSurface = Color(0xFFE4EEE8);
  static const Color darkOnSurfaceVariant = Color(0xFFA8B8B0);
  static const Color darkSurfaceContainerLowest = Color(0xFF0A0E0C);
  static const Color darkSurfaceContainerLow = Color(0xFF151B18);
  static const Color darkSurfaceContainer = Color(0xFF1A221E);
  static const Color darkSurfaceContainerHigh = Color(0xFF242C28);
  static const Color darkSurfaceContainerHighest = Color(0xFF2F3733);
  static const Color darkOutline = Color(0xFF2F3F37);
  static const Color darkOutlineVariant = Color(0xFF3A4A42);
  static const Color darkInverseSurface = Color(0xFFE4EEE8);
  static const Color darkOnInverseSurface = Color(0xFF1A221E);
  static const Color darkInversePrimary = Color(0xFF1B7A4E);
  static const Color darkScrim = Color(0xFF000000);
  static const Color darkShadow = Color(0xFF000000);

  // --- Acento "voce" ---
  // Tudo no app e verde; o estado pessoal precisava de uma cor propria para
  // saltar. Dourado quente contrasta com o verde sem brigar com ele, e carrega
  // a ideia de destaque.
  static const Color lightAccent = Color(0xFFB25E00);
  static const Color lightAccentContainer = Color(0xFFFFE7C4);
  static const Color lightOnAccentContainer = Color(0xFF432500);

  static const Color darkAccent = Color(0xFFFFBC6B);
  static const Color darkAccentContainer = Color(0xFF573100);
  static const Color darkOnAccentContainer = Color(0xFFFFE7C4);

  // --- Gradiente do cartao heroi ---
  static const List<Color> lightHeroGradient = [
    Color(0xFF156942),
    Color(0xFF23935F),
  ];
  static const List<Color> darkHeroGradient = [
    Color(0xFF0E3F29),
    Color(0xFF175A3B),
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
