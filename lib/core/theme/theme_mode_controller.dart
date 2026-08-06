import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/events/data/event_repository.dart';

/// Escolha de tema do usuario, guardada no aparelho.
///
/// Fica em `SharedPreferences` e nao no backend: e preferencia do aparelho,
/// nao da conta -- a mesma pessoa pode querer escuro no celular e claro no
/// tablet. E le sincrono no bootstrap, entao o app abre ja no tema certo, sem
/// o flash de branco que uma leitura assincrona causaria.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_read(_prefs));

  static const _key = 'theme_mode';

  final SharedPreferences _prefs;

  static ThemeMode _read(SharedPreferences prefs) {
    return switch (prefs.getString(_key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> select(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await _prefs.setString(_key, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(sharedPreferencesProvider));
});

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Escuro',
      ThemeMode.system => 'Sistema',
    };
