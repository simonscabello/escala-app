import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// "Voltar" do Android com o teclado aberto só fecha o teclado.
///
/// Com o voltar preditivo (padrão a partir do Android 16), o gesto chega ao
/// Flutter antes de o teclado reagir, e o roteador desempilhava a tela: quem
/// digitava o nome de uma música nova e só queria esconder o teclado perdia o
/// formulário. Aqui o voltar é interceptado enquanto há teclado na tela;
/// fechado o teclado, o próximo voltar segue o caminho normal.
///
/// Precisa ser registrado **antes** do `runApp`: o `WidgetsBinding` consulta
/// os observadores na ordem em que entraram, e o do roteador entra depois.
class KeyboardBackGuard with WidgetsBindingObserver {
  KeyboardBackGuard._();

  static void install() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    WidgetsBinding.instance.addObserver(KeyboardBackGuard._());
  }

  bool get _keyboardOpen {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.any((view) => view.viewInsets.bottom > 0);
  }

  bool _closeKeyboard() {
    if (!_keyboardOpen) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    return true;
  }

  @override
  Future<bool> didPopRoute() async => _closeKeyboard();

  // Voltar preditivo: assumir o gesto no começo é o que faz o fim dele chegar
  // aqui, e não ao `Navigator`.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => _keyboardOpen;

  @override
  void handleCommitBackGesture() => _closeKeyboard();
}
